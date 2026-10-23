"""beat_this (CPJKU, 2024; MIT) como BeatTracker.

Os pesos vêm do servidor dos autores (cloud.cp.jku.at) e ficam em data/models/, baixados por nós
e conferidos por sha256 antes de o beat_this abrir o arquivo: o checkpoint é um pickle, e
carregar um arquivo adulterado executa código. Por isso também não usamos espelhos de terceiros.
O servidor é um só e já ficou fora do ar (out/2026, HTTP 503): sem ele, a etapa cai na reserva
(ADR 0013).
"""

from __future__ import annotations

from pathlib import Path

import numpy as np

from pbq.audio import Audio
from pbq.models.download import Asset, fetch

SAMPLE_RATE = 22050  # a do modelo (ele reamostraria de qualquer jeito)
CHECKPOINT_URL = "https://cloud.cp.jku.at/public.php/dav/files/7ik4RrBKTS273gp"
# Só checkpoints com hash conferido. final0: baixado do servidor oficial em 2026-10-23, 81 MB.
CHECKPOINTS = {
    "final0": Asset(
        f"{CHECKPOINT_URL}/final0.ckpt", "8c328b45f59d8dd3dff219253ff6a8d6482be57d0133a29140e2febbf8eb8331"
    ),
}


class BeatThisTracker:
    sample_rate = SAMPLE_RATE

    def __init__(self, models_dir: Path, checkpoint: str = "final0", device: str = "cpu"):
        if checkpoint not in CHECKPOINTS:
            raise ValueError(f"checkpoint do beat_this sem hash conferido: {checkpoint!r}")
        # RuntimeError legível se o servidor estiver fora: a etapa usa a reserva.
        path = fetch(CHECKPOINTS[checkpoint], models_dir / f"beat_this-{checkpoint}.ckpt")

        from beat_this.inference import Audio2Beats

        # dbn=False: o pós-processamento padrão do beat_this, sem madmom.
        self._model = Audio2Beats(checkpoint_path=str(path), device=device, dbn=False)

    def track(self, signal: Audio) -> tuple[list[float], list[float]]:
        beats, downbeats = self._model(np.asarray(signal, dtype=np.float32), SAMPLE_RATE)
        return [float(b) for b in beats], [float(d) for d in downbeats]
