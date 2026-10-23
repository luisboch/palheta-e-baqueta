from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np
import numpy.typing as npt

from pbq import audio, dsp
from pbq.config import Config
from pbq.fsutil import write_json
from pbq.manifest import Song
from pbq.models import GuitarTimbre
from pbq.stages.base import Progress, Stage, no_progress
from pbq.stages.separate import STEM_DIR

ACOUSTIC, ELECTRIC = "acoustic", "electric"
REPORT = "guitar_split.json"

Floats = npt.NDArray[np.float64]


@dataclass(frozen=True)
class SplitOptions:
    window: float = 2.0  # s de contexto que o classificador ouve por decisão
    hop: float = 1.0  # s entre decisões: a resolução da divisão
    active_db: float = -40.0  # janela abaixo disso (dBFS) é guitarra calada: não decide nada
    smooth: int = 5  # mediana sobre N decisões: troca de instrumento dura segundos, não 1 s
    fade: float = 0.05  # s de transição entre os dois stems: corte seco estala
    # Abaixo disso o violão não é confiável e tudo volta para a guitarra (o padrão): em Anna Júlia
    # (só elétrica) os falsos trechos de violão tinham 0,13; em Pais e Filhos o violão real, 0,66.
    min_acoustic_confidence: float = 0.4

    @classmethod
    def from_opts(cls, opts: dict[str, Any]) -> SplitOptions:
        return cls(**{k: type(getattr(cls, k))(v) for k, v in opts.items() if k in cls.__dataclass_fields__})


def decide(scores: Floats, active: npt.NDArray[np.bool_], smooth: int) -> tuple[list[str | None], Floats]:
    """Rótulo por bloco a partir das evidências [violão, elétrica] de cada janela.

    Retorna (rótulos, s), em que s = violão / (violão + elétrica), suavizado pela mediana das
    janelas ativas vizinhas. Blocos inativos ficam None (e s = nan).
    """
    total = scores.sum(axis=1)
    raw = np.where(active & (total > 0), scores[:, 0] / np.maximum(total, 1e-9), np.nan)
    half = smooth // 2
    s = np.full(len(raw), np.nan)
    for i in np.flatnonzero(active):
        near = raw[max(0, i - half) : i + half + 1]
        near = near[~np.isnan(near)]
        if len(near):
            s[i] = float(np.median(near))
    labels: list[str | None] = [None if np.isnan(x) else (ACOUSTIC if x >= 0.5 else ELECTRIC) for x in s]
    return labels, s


def fill_gaps(labels: list[str | None]) -> list[str]:
    """Blocos calados herdam o rótulo do bloco ativo mais próximo (o fim da nota vai junto)."""
    active = [i for i, label in enumerate(labels) if label]
    if not active:
        return [ELECTRIC] * len(labels)
    filled = []
    for i in range(len(labels)):
        nearest = min(active, key=lambda j: (abs(j - i), j))
        filled.append(labels[nearest] or ELECTRIC)
    return filled


def acoustic_mask(labels: list[str], hop_samples: int, length: int, fade_samples: int) -> Floats:
    """Ganho do violão por amostra (1 = violão, 0 = elétrica), com rampas de `fade_samples`."""
    blocks = np.array([1.0 if label == ACOUSTIC else 0.0 for label in labels])
    mask = np.repeat(blocks, hop_samples)[:length]
    if len(mask) < length:
        mask = np.pad(mask, (0, length - len(mask)), mode="edge" if len(mask) else "constant")
    if fade_samples > 1:
        kernel = np.ones(fade_samples) / fade_samples
        mask = np.convolve(np.pad(mask, fade_samples // 2, mode="edge"), kernel, mode="same")
        mask = mask[fade_samples // 2 : fade_samples // 2 + length]
    return np.asarray(np.clip(mask, 0.0, 1.0), dtype=np.float64)


def segments(labels: list[str | None], s: Floats, hop: float) -> list[dict[str, Any]]:
    """Blocos consecutivos com o mesmo rótulo, para o relatório (e para depuração à mão)."""
    out: list[dict[str, Any]] = []
    for i, label in enumerate(labels):
        if out and out[-1]["label"] == label:
            out[-1]["end"] = round((i + 1) * hop, 2)
            out[-1]["_s"].append(s[i])
        else:
            out.append(
                {"start": round(i * hop, 2), "end": round((i + 1) * hop, 2), "label": label, "_s": [s[i]]}
            )
    for seg in out:
        values = [v for v in seg.pop("_s") if not np.isnan(v)]
        seg["acoustic_score"] = round(float(np.mean(values)), 3) if values else None
    return out


def summary(labels: list[str | None], s: Floats, hop: float) -> dict[str, dict[str, float]]:
    """Segundos e confiança média (|2s - 1|, de 0 a 1) de cada lado."""
    result = {}
    for side in (ACOUSTIC, ELECTRIC):
        idx = [i for i, label in enumerate(labels) if label == side]
        confidence = float(np.mean(np.abs(2 * s[idx] - 1))) if idx else 0.0
        result[side] = {"seconds": round(len(idx) * hop, 2), "confidence": round(confidence, 3)}
    return result


def _panns(opts: dict[str, Any]) -> GuitarTimbre:
    from pbq.models.panns import PannsGuitarTimbre

    return PannsGuitarTimbre(
        models_dir=Path(opts.get("models_dir", "data/models")), device=str(opts.get("device", "cpu"))
    )


CLASSIFIERS: dict[str, Callable[[dict[str, Any]], GuitarTimbre]] = {"panns": _panns}


class GuitarSplit(Stage):
    """Divide o stem de guitarra em guitarra elétrica e violão, por trechos.

    O Demucs põe os dois no mesmo stem. Um classificador de timbre ouve janelas do stem e cada
    trecho vai inteiro para um dos lados (limitações no ADR 0006: os dois juntos vão para o
    dominante; guitarra limpa pode passar por violão).

    Entrada: stems/guitar.flac
    Saída:   stems/electric.flac, stems/acoustic.flac, guitar_split.json (trechos e confiança)
    Violão com confiança baixa volta inteiro para a guitarra (`merged_into_electric` no relatório):
    melhor um violão indisponível do que notas de guitarra no instrumento errado.

    Config:  classifier (panns), device, window, hop, active_db, smooth, fade, min_acoustic_confidence
    """

    name = "guitar_split"
    summary = "guitarra elétrica × violão, por trechos (classificador de timbre)"
    requires = ("separate",)

    def __init__(self, config: Config, timbre: GuitarTimbre | None = None):
        super().__init__(config)
        self._timbre = timbre

    def outputs(self, song: Song) -> list[Path]:
        return [
            song.path(STEM_DIR, f"{ELECTRIC}.flac"),
            song.path(STEM_DIR, f"{ACOUSTIC}.flac"),
            song.path(REPORT),
        ]

    def timbre(self) -> GuitarTimbre:
        if self._timbre is None:
            name = str(self.opts.get("classifier", "panns"))
            if name not in CLASSIFIERS:
                raise ValueError(f"classifier inválido: {name!r} (use {', '.join(CLASSIFIERS)})")
            opts = {"models_dir": str(self.config.paths.state / "models"), **self.opts}
            self._timbre = CLASSIFIERS[name](opts)
        return self._timbre

    def run(self, song: Song, progress: Progress = no_progress) -> None:
        opts = SplitOptions.from_opts(self.opts)
        timbre = self.timbre()
        stem_path = song.path(STEM_DIR, "guitar.flac")

        # Janelas centradas em cada bloco de `hop`, ouvidas na taxa do classificador.
        sr = timbre.sample_rate
        signal = audio.mono(audio.decode(stem_path, sr, channels=1))
        hop, win = int(opts.hop * sr), int(opts.window * sr)
        blocks = max(1, int(np.ceil(len(signal) / hop)))
        pad = (win - hop) // 2
        padded = np.pad(signal, (pad, pad + win))
        windows = np.stack([padded[i * hop : i * hop + win] for i in range(blocks)])
        active = dsp.to_db(np.sqrt(np.mean(windows.astype(np.float64) ** 2, axis=1))) >= opts.active_db
        progress(0.1)
        scores = np.zeros((blocks, 2))
        if active.any():
            scores[active] = timbre.scores(windows[active])
        progress(0.8)

        labels, s = decide(scores, active, opts.smooth)
        sides = summary(labels, s, opts.hop)
        merged = (
            sides[ACOUSTIC]["seconds"] > 0 and sides[ACOUSTIC]["confidence"] < opts.min_acoustic_confidence
        )
        report = {
            "window": opts.window,
            "hop": opts.hop,
            **sides,
            "merged_into_electric": merged,
            "segments": segments(labels, s, opts.hop),
        }
        if merged:
            labels = [ELECTRIC if label == ACOUSTIC else label for label in labels]

        # Os stems saem na taxa original do stem de guitarra (a do separador).
        rate = audio.sample_rate(stem_path)
        full = audio.decode(stem_path, rate)
        mask = acoustic_mask(fill_gaps(labels), int(opts.hop * rate), full.shape[1], int(opts.fade * rate))
        audio.write(song.path(STEM_DIR, f"{ACOUSTIC}.flac"), (full * mask).astype(np.float32), rate)
        audio.write(song.path(STEM_DIR, f"{ELECTRIC}.flac"), (full * (1 - mask)).astype(np.float32), rate)
        write_json(song.path(REPORT), report)
        progress(1.0)
