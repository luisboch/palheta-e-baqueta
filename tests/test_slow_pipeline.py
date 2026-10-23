"""Pipeline real (Demucs) numa música sintética curta. `uv run pytest -m slow --no-cov`.

Baixa o modelo na primeira vez (~80 MB) e leva uns 15 s na CPU do Deck.
"""

import json
import time

import pytest

from pbq.manifest import Song
from pbq.pipeline import DONE, process_song
from pbq.stages import STAGES
from tests.audio import make_band

pytestmark = pytest.mark.slow


def test_real_pipeline_on_synthetic_band(config):
    path = make_band(config.paths.input / "Banda - Sintética.mp3", with_guitar=True)
    song = Song.open(path, config.paths.work)
    stages = [cls(config) for cls in STAGES]
    started = time.monotonic()
    fractions = []
    assert process_song(song, stages, progress=lambda st, f: fractions.append((st, f))) == DONE
    elapsed = time.monotonic() - started

    for name in ("drums", "bass", "guitar", "piano", "vocals", "other"):
        assert song.path("stems", f"{name}.flac").stat().st_size > 0
    presence = json.loads(song.path("presence.json").read_text())["instruments"]
    print(f"\n{elapsed:.0f}s", json.dumps(presence, indent=1))
    assert set(presence) == {"drums", "bass", "strings"}
    # O que dá para afirmar num som sintético: a bateria tem ataques fortes e regulares.
    assert presence["drums"]["present"]
    assert {st for st, _ in fractions} == {s.name for s in stages}
    assert song.meta["instruments"]["drums"] is True
