"""ADTOF Frame_RNN (Zehren et al., 2021/2023) como DrumTranscriber.

Implementação própria da arquitetura descrita nos artigos: CNN de 2 blocos (32 e 64 filtros 3×3,
ReLU, BatchNorm, max-pooling de 3 na frequência) + 3 GRUs bidirecionais de 60 unidades + saída
sigmoide para 5 classes. Os pesos são os oficiais do ADTOF (Keras), convertidos para PyTorch pelo
projeto ADTOF-pytorch; baixados de um commit fixo e conferidos por sha256 (ADR 0011).

Licença dos pesos: CC BY-NC-SA 4.0 (ADTOF). Por isso o Palheta & Baqueta é não comercial.

Entrada: espectrograma log-filtrado como o do madmom, que o ADTOF usou no treino (janela 2048,
100 quadros/s, 12 bandas por oitava de 20 Hz a 20 kHz, log10(1 + x)). A implementação aqui é em
numpy, sem madmom (abandonado, frágil no Python 3.12).
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import numpy as np
import numpy.typing as npt

from pbq.audio import Audio
from pbq.models.download import Asset, fetch

SAMPLE_RATE = 44100
FPS = 100
FRAME_SIZE = 2048
BANDS_PER_OCTAVE, FMIN, FMAX = 12, 20.0, 20000.0
# Classes da saída, na ordem da rede (notas MIDI do General MIDI usadas pelo ADTOF).
CLASSES = ("kick", "snare", "tom", "hihat", "cymbal")
# Limiares por classe calibrados pelos autores no conjunto de validação do ADTOF.
THRESHOLDS = (0.22, 0.24, 0.32, 0.22, 0.30)
WEIGHTS = Asset(
    "https://raw.githubusercontent.com/xavriley/ADTOF-pytorch/85c192e78f716ea0b111cc8a5ee4a8f6a3a4f8a9/"
    "src/adtof_pytorch/data/adtof_frame_rnn_pytorch_weights.pth",
    "1bc986e596ec47ba0b44916f87cd4a39f0b2bec23596df3fb5d0e87749217320",
)
CHUNK_FRAMES = 6000  # 60 s por inferência: a GRU bidirecional vê contexto de sobra e a memória fica baixa
OVERLAP_FRAMES = 400  # 4 s de sobreposição entre pedaços, descartados nas bordas

Floats = npt.NDArray[np.float64]


# --- entrada: espectrograma log-filtrado (estilo madmom) -----------------------


def log_frequencies(bands_per_octave: int, fmin: float, fmax: float, fref: float = 440.0) -> Floats:
    """Frequências espaçadas em `bands_per_octave` por oitava, ancoradas em `fref`, dentro de [fmin, fmax]."""
    left = int(np.floor(np.log2(fmin / fref) * bands_per_octave))
    right = int(np.ceil(np.log2(fmax / fref) * bands_per_octave))
    freqs = fref * 2.0 ** (np.arange(left, right) / bands_per_octave)
    return np.asarray(freqs[(freqs >= fmin) & (freqs <= fmax)], dtype=np.float64)


def filterbank(n_bins: int, sample_rate: int, frame_size: int) -> Floats:
    """Filtros triangulares (normalizados para soma 1) nas frequências logarítmicas.

    Cada frequência vira o bin de FFT mais próximo; bins repetidos (graves, onde a FFT tem pouca
    resolução) contam uma vez só. Cada trio de bins vizinhos (início, centro, fim) é um filtro.
    """
    bin_freqs = np.fft.fftfreq(frame_size, 1.0 / sample_rate)[:n_bins]
    freqs = log_frequencies(BANDS_PER_OCTAVE, FMIN, FMAX)
    idx = np.clip(np.searchsorted(bin_freqs, freqs), 1, n_bins - 1)
    closer_left = freqs - bin_freqs[idx - 1] < bin_freqs[idx] - freqs
    bins = np.unique(np.where(closer_left, idx - 1, idx))
    filters = []
    for start, center, stop in zip(bins[:-2], bins[1:-1], bins[2:], strict=True):
        if stop - start < 2:  # filtro estreito demais: vira um bin só
            center, stop = start, start + 1
        f = np.zeros(n_bins)
        rise = np.arange(start, center)
        f[rise] = (rise - start) / max(center - start, 1)
        fall = np.arange(center, stop)
        f[fall] = 1 - (fall - center) / max(stop - center, 1)
        if center - start == 0:
            f[center] = 1.0
        filters.append(f / f.sum())
    return np.asarray(np.stack(filters, axis=1), dtype=np.float64)


def features(signal: Audio, sample_rate: int = SAMPLE_RATE) -> npt.NDArray[np.float32]:
    """(quadros, bandas): magnitude da STFT (Hann, quadros centrados), filtrada e em log10(1 + x)."""
    hop = sample_rate / FPS
    n_frames = int(np.ceil(len(signal) / hop))
    padded = np.pad(signal.astype(np.float64), (FRAME_SIZE // 2, FRAME_SIZE))
    starts = (np.arange(n_frames) * hop).astype(int)
    frames = padded[starts[:, None] + np.arange(FRAME_SIZE)[None, :]] * np.hanning(FRAME_SIZE)
    magnitude = np.abs(np.fft.rfft(frames, axis=1))[:, : FRAME_SIZE // 2]
    bank = filterbank(FRAME_SIZE // 2, sample_rate, FRAME_SIZE)
    return np.log10(1.0 + magnitude @ bank).astype(np.float32)


# --- saída: picos por classe ---------------------------------------------------


def pick_peaks(activation: Floats, threshold: float, window: int = 2) -> Floats:
    """Quadros que são máximo local (±`window`) e passam do limiar → tempos em segundos.

    `window` = 2 quadros (20 ms): duas batidas da mesma peça mais perto que isso são uma só.
    """
    if not len(activation):
        return np.array([])
    padded = np.pad(activation, window, mode="constant", constant_values=-np.inf)
    neighborhood = np.lib.stride_tricks.sliding_window_view(padded, 2 * window + 1)
    local_max = activation >= neighborhood.max(axis=1)
    frames = np.flatnonzero(local_max & (activation >= threshold))
    # Platô (dois quadros iguais seguidos): fica o primeiro.
    if len(frames):
        frames = frames[np.concatenate([[True], np.diff(frames) > window])]
    return np.asarray(frames / FPS, dtype=np.float64)


class AdtofTranscriber:
    """Bateria → {classe: tempos dos ataques (s)} com o Frame_RNN do ADTOF."""

    sample_rate = SAMPLE_RATE
    classes: tuple[str, ...] = CLASSES

    def __init__(self, models_dir: Path, device: str = "cpu", thresholds: tuple[float, ...] = THRESHOLDS):
        import torch

        self._torch = torch
        self._device = device
        self.thresholds = thresholds
        weights = torch.load(
            fetch(WEIGHTS, models_dir / "adtof_frame_rnn.pth"), map_location=device, weights_only=True
        )
        self._model = build_model(torch).to(device).eval()
        self._model.load_state_dict(weights["model_weights"])

    def activations(self, signal: Audio) -> npt.NDArray[np.float32]:
        """(quadros, 5): probabilidade de ataque de cada classe a cada 10 ms."""
        torch = self._torch
        feats = features(signal)
        out = np.zeros((len(feats), len(CLASSES)), dtype=np.float32)
        step = CHUNK_FRAMES - 2 * OVERLAP_FRAMES
        with torch.no_grad():
            for start in range(0, len(feats), step):
                lo = max(0, start - OVERLAP_FRAMES)
                hi = min(len(feats), start + step + OVERLAP_FRAMES)
                x = torch.from_numpy(feats[lo:hi][None]).to(self._device)
                y = self._model(x)[0].cpu().numpy()
                out[start : min(start + step, len(feats))] = y[start - lo : start - lo + step]
        return out

    def transcribe(self, signal: Audio) -> dict[str, Floats]:
        act = self.activations(signal)
        return {
            name: pick_peaks(act[:, i].astype(np.float64), self.thresholds[i])
            for i, name in enumerate(CLASSES)
        }


def build_model(torch: Any) -> Any:
    """Frame_RNN: (lote, quadros, 84 bandas) → (lote, quadros, 5) probabilidades.

    Ordem das camadas como no Keras original: conv → ReLU → BatchNorm (eps 1e-3, o padrão do
    Keras), pooling só na frequência com o `padding="same"` do TensorFlow: 28 → 10 bins com 1 de
    folga de cada lado. O `ceil_mode` do PyTorch poria a folga só no fim e deslocaria as bandas
    (diferença de até 0,2 na saída, medida contra a referência).
    Antes da GRU, cada quadro é achatado com os canais por último (frequência × canais), como no Keras.
    """
    nn = torch.nn

    class SamePool(nn.Module):  # type: ignore[misc,name-defined]  # torch chega como Any (import tardio)
        """Max-pooling 3 na frequência com a folga dividida como no TensorFlow (antes ≤ depois)."""

        def forward(self, x: Any) -> Any:
            width = x.shape[-1]
            total = max((-(-width // 3) - 1) * 3 + 3 - width, 0)
            x = torch.nn.functional.pad(x, (total // 2, total - total // 2), value=float("-inf"))
            return torch.nn.functional.max_pool2d(x, (1, 3))

    def block(c_in: int, c_out: int) -> Any:
        return nn.Sequential(
            nn.Conv2d(c_in, c_out, 3, padding=1),
            nn.ReLU(),
            nn.BatchNorm2d(c_out, eps=1e-3),
            nn.Conv2d(c_out, c_out, 3, padding=1),
            nn.ReLU(),
            nn.BatchNorm2d(c_out, eps=1e-3),
            SamePool(),
        )

    class FrameRNN(nn.Module):  # type: ignore[misc,name-defined]  # torch chega como Any (import tardio)
        def __init__(self) -> None:
            super().__init__()
            self.cnn_blocks = nn.ModuleList([block(1, 32), block(32, 64)])
            self.gru_layers = nn.ModuleList(
                [
                    nn.GRU(640, 60, batch_first=True, bidirectional=True),
                    nn.GRU(120, 60, batch_first=True, bidirectional=True),
                    nn.GRU(120, 60, batch_first=True, bidirectional=True),
                ]
            )
            self.output_layer = nn.Linear(120, len(CLASSES))

        def forward(self, x: Any) -> Any:
            h = x[:, None]  # (lote, 1, quadros, bandas)
            for blk in self.cnn_blocks:
                h = blk(h)  # (lote, canais, quadros, bandas/9)
            b, c, t, f = h.shape
            h = h.permute(0, 2, 3, 1).reshape(b, t, f * c)  # canais por último, como no Keras
            for gru in self.gru_layers:
                h, _ = gru(h)
            return torch.sigmoid(self.output_layer(h))

    return FrameRNN()
