"""beat_this (CPJKU, 2024; MIT) como BeatTracker.

Os pesos vêm do servidor dos autores (cloud.cp.jku.at) e ficam no cache do torch.hub. O
servidor é um só e já esteve fora do ar (out/2026, HTTP 503): sem ele, a etapa falha com erro
legível e a música espera na fila. Espelhos de terceiros não são usados: o checkpoint é um
pickle, e carregar um arquivo adulterado executa código.
"""

from __future__ import annotations

import numpy as np

from pbq.audio import Audio

SAMPLE_RATE = 22050  # a do modelo (ele reamostraria de qualquer jeito)


class BeatThisTracker:
    sample_rate = SAMPLE_RATE

    def __init__(self, checkpoint: str = "final0", device: str = "cpu"):
        from beat_this.inference import Audio2Beats

        try:
            # dbn=False: o pós-processamento padrão do beat_this, sem madmom.
            self._model = Audio2Beats(checkpoint_path=checkpoint, device=device, dbn=False)
        except ValueError as e:
            raise RuntimeError(
                f"não consegui carregar o beat_this ({checkpoint}): servidor dos pesos "
                "fora do ar ou sem internet"
            ) from e

    def track(self, signal: Audio) -> tuple[list[float], list[float]]:
        beats, downbeats = self._model(np.asarray(signal, dtype=np.float32), SAMPLE_RATE)
        return [float(b) for b in beats], [float(d) for d in downbeats]
