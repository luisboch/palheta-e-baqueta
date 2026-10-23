"""Pipeline real (Demucs, PANNs) numa música sintética curta. `uv run pytest -m slow --no-cov`.

Baixa os modelos na primeira vez (~400 MB) e leva cerca de 1 minuto na CPU do Deck.
"""

import json
import time
from pathlib import Path

import pytest

from pbq.manifest import Song
from pbq.pipeline import DONE, process_song
from pbq.stages import STAGES
from tests.audio import make_band

pytestmark = pytest.mark.slow

REPO = Path(__file__).resolve().parent.parent


@pytest.fixture
def real_models(config):
    """Pesos do PANNs no data/models do repositório (já baixados): não baixa 300 MB por teste."""
    config.stages["guitar_split"] = {"models_dir": str(REPO / "data" / "models")}
    return config


def test_real_pipeline_on_synthetic_band(real_models):
    config = real_models
    path = make_band(config.paths.input / "Banda - Sintética.mp3", with_guitar=True)
    song = Song.open(path, config.paths.work)
    stages = [cls(config) for cls in STAGES]
    started = time.monotonic()
    fractions = []
    assert process_song(song, stages, progress=lambda st, f: fractions.append((st, f))) == DONE
    elapsed = time.monotonic() - started

    for name in ("drums", "bass", "guitar", "piano", "vocals", "other", "electric", "acoustic"):
        assert song.path("stems", f"{name}.flac").stat().st_size > 0
    presence = json.loads(song.path("presence.json").read_text())["instruments"]
    print(f"\n{elapsed:.0f}s", json.dumps(presence, indent=1))
    assert set(presence) == {"drums", "bass", "guitar", "acoustic"}
    # O que dá para afirmar num som sintético: a bateria tem ataques fortes e regulares.
    assert presence["drums"]["present"]
    assert {st for st, _ in fractions} == {s.name for s in stages}
    assert song.meta["instruments"]["drums"] is True
