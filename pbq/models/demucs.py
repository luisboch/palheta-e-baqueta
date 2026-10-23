"""Demucs (htdemucs_6s) como StemSeparator."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import numpy as np

from pbq.audio import Audio
from pbq.models import Progress

# Os 6 stems do htdemucs_6s. O piano é o mais fraco do modelo; vai para o "resto" do jogo.
STEMS_6S = ("drums", "bass", "guitar", "piano", "vocals", "other")


class DemucsSeparator:
    def __init__(self, model: str = "htdemucs_6s", device: str = "cpu", shifts: int = 1):
        # Import tardio: torch leva segundos para carregar e só esta etapa precisa dele.
        from demucs.api import Separator

        self._shifts = shifts
        self._progress: Progress = lambda f: None
        self._separator = Separator(model=model, device=device, shifts=shifts, callback=self._on_chunk)
        self.sample_rate: int = self._separator.samplerate
        self.stems: tuple[str, ...] = tuple(self._separator.model.sources)

    def _on_chunk(self, info: dict[str, Any]) -> None:
        """Callback do Demucs a cada trecho: posição dentro de modelo × shift × áudio."""
        if info.get("state") != "end":
            return
        models = info.get("models", 1)
        done = (info["model_idx_in_bag"] * self._shifts + info["shift_idx"]) * info["audio_length"]
        done += info["segment_offset"]
        self._progress(done / (models * self._shifts * info["audio_length"]))

    def separate(self, path: Path, progress: Progress) -> dict[str, Audio]:
        self._progress = progress
        _, stems = self._separator.separate_audio_file(path)
        return {name: np.asarray(wav.numpy(), dtype=np.float32) for name, wav in stems.items()}
