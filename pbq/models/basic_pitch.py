"""basic-pitch (Spotify, 2022; Apache-2.0) como PitchTranscriber, pelo modelo ONNX do pacote.

O pacote pede TensorFlow < 2.15.1, que não existe para Python 3.12: o pyproject impede a
instalação do TensorFlow, e o basic-pitch escolhe sozinho o modelo ONNX (onnxruntime).
"""

from __future__ import annotations

import logging
import warnings
from pathlib import Path

# Ajustes do basic-pitch (os padrões do pacote, explícitos): limiar de ataque e de nota ativa,
# nota mínima de ~58 ms; "melodia trick" junta notas quebradas por vibrato.
ONSET_THRESHOLD = 0.5
FRAME_THRESHOLD = 0.3
MIN_NOTE_MS = 58.0


class BasicPitchTranscriber:
    def __init__(self) -> None:
        # O import avisa (logging e warnings) que TensorFlow e TFLite não estão instalados: esperado.
        logging.disable(logging.WARNING)
        try:
            with warnings.catch_warnings():
                warnings.simplefilter("ignore")
                from basic_pitch import ICASSP_2022_MODEL_PATH
                from basic_pitch.inference import Model, predict
        finally:
            logging.disable(logging.NOTSET)
        self._predict = predict
        self._model = Model(ICASSP_2022_MODEL_PATH)

    def transcribe(self, path: Path) -> list[tuple[float, float, int, float]]:
        _, _, notes = self._predict(
            str(path),
            self._model,
            onset_threshold=ONSET_THRESHOLD,
            frame_threshold=FRAME_THRESHOLD,
            minimum_note_length=MIN_NOTE_MS,
        )
        return [(float(n[0]), float(n[1]), int(n[2]), float(n[3])) for n in notes]
