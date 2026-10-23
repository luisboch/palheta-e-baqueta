"""Etapas falsas para testar pipeline e worker sem modelos nem áudio."""

import json

from pbq.manifest import Song
from pbq.stages.base import Progress, Stage, no_progress


class Touch(Stage):
    name = "touch"
    summary = "etapa de teste"

    def outputs(self, song: Song):
        return [song.path("touched")]

    def run(self, song: Song, progress: Progress = no_progress) -> None:
        for i in range(1, 4):
            progress(i / 4)
        song.path("touched").parent.mkdir(parents=True, exist_ok=True)
        song.path("touched").write_text("x")


class Publish(Stage):
    """Faz o papel do package: a música fica "completa" quando esta etapa está feita."""

    name = "publish"
    requires = ("touch",)

    def outputs(self, song: Song):
        return [self.config.paths.library / song.id / "song.json"]

    def run(self, song: Song, progress: Progress = no_progress) -> None:
        out = self.config.paths.library / song.id
        out.mkdir(parents=True, exist_ok=True)
        (out / "song.json").write_text(json.dumps({"id": song.id, "title": song.label}))


class Boom(Stage):
    name = "boom"

    def run(self, song: Song, progress: Progress = no_progress) -> None:
        raise RuntimeError("falhou de propósito")


class Optional(Stage):
    name = "optional"
    required = False

    def run(self, song: Song, progress: Progress = no_progress) -> None:
        raise RuntimeError("opcional falhou")


class FakeSeparator:
    """StemSeparator falso: cada stem é um tom sintético (ou silêncio, se pedido)."""

    sample_rate = 44100
    stems = ("drums", "bass", "guitar", "piano", "vocals", "other")

    def __init__(self, seconds: float = 2.0, silent: tuple[str, ...] = ()):
        self.seconds = seconds
        self.silent = silent
        self.calls = 0

    def separate(self, path, progress):
        import numpy as np

        self.calls += 1
        progress(0.5)
        n = int(self.seconds * self.sample_rate)
        t = np.arange(n) / self.sample_rate
        out = {}
        for i, name in enumerate(self.stems):
            tone = 0.0 if name in self.silent else 0.2 * np.sin(2 * np.pi * (110 * (i + 1)) * t)
            out[name] = np.stack([tone * np.ones(n), tone * np.ones(n)]).astype(np.float32)
        progress(1.0)
        return out


class FakeTracker:
    """BeatTracker falso: batidas regulares (120 BPM) e tempo forte a cada 4."""

    sample_rate = 22050

    def __init__(self, bpm: float = 120.0, start: float = 0.5):
        self.bpm = bpm
        self.start = start

    def track(self, signal):
        seconds = len(signal) / self.sample_rate
        step = 60 / self.bpm
        beats = []
        t = self.start
        while t < seconds:
            beats.append(round(t, 4))
            t += step
        return beats, beats[::4]


class FakeTranscriber:
    """DrumTranscriber falso: bumbo nas batidas 1 e 3, caixa na 2 e 4, chimbal em colcheias (120 BPM)."""

    sample_rate = 44100
    classes = ("kick", "snare", "tom", "hihat", "cymbal")

    def __init__(self, start: float = 0.5, beats: int = 8):
        self.start = start
        self.beats = beats
        self.calls = 0

    def transcribe(self, signal):
        import numpy as np

        self.calls += 1
        b = self.start + 0.5 * np.arange(self.beats)
        return {
            "kick": b[::2] + 0.01,
            "snare": b[1::2] - 0.005,
            "tom": np.array([]),
            "hihat": np.concatenate([b, b + 0.25]),
            "cymbal": b[:1],
        }


class FakePitch:
    """PitchTranscriber falso: escala subindo em semínimas (120 BPM, a partir de 0,5 s)."""

    def __init__(self, base: int = 52, n: int = 8, chord: bool = False):
        self.base = base
        self.n = n
        self.chord = chord
        self.calls = []

    def transcribe(self, path):
        self.calls.append(path.name)
        notes = []
        for i in range(self.n):
            t = 0.5 + 0.5 * i
            notes.append((t, t + 0.3, self.base + 2 * i, 0.8))
            if self.chord:
                notes.append((t + 0.01, t + 0.3, self.base + 2 * i + 7, 0.7))
        return notes
