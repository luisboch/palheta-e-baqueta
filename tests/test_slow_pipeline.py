"""Pipeline real (Demucs, beat_this, ADTOF, basic-pitch) numa música sintética curta.

    uv run pytest -m slow --no-cov

Baixa os modelos na primeira vez (~100 MB) e leva uns 20 s na CPU do Deck. Sem o servidor dos
pesos do beat_this (ADR 0011), o teste é pulado com o motivo.
"""

import json
import time
from pathlib import Path

import pytest

from pbq.charts.chart_file import parse_chart
from pbq.manifest import Song
from pbq.pipeline import DONE, process_song
from pbq.stages import STAGES
from tests.audio import make_band

pytestmark = pytest.mark.slow

REPO = Path(__file__).resolve().parent.parent


@pytest.fixture
def stages(config):
    # Pesos do ADTOF no data/models do repositório: não baixa de novo a cada teste.
    config.stages["drums_chart"] = {"models_dir": str(REPO / "data" / "models")}
    built = [cls(config) for cls in STAGES]
    beats = next(s for s in built if s.name == "beats")
    try:
        beats.tracker()
    except RuntimeError as e:
        pytest.skip(f"beat_this indisponível: {e}")
    return built


def test_real_pipeline_on_synthetic_band(config, stages):
    path = make_band(config.paths.input / "Banda - Sintética.mp3", with_guitar=True)
    song = Song.open(path, config.paths.work)
    started = time.monotonic()
    fractions = []
    assert process_song(song, stages, progress=lambda st, f: fractions.append((st, f))) == DONE
    elapsed = time.monotonic() - started

    for name in ("drums", "bass", "guitar", "piano", "vocals", "other"):
        assert song.path("stems", f"{name}.flac").stat().st_size > 0
    presence = json.loads(song.path("presence.json").read_text())["instruments"]
    beatmap = json.loads(song.path("beatmap.json").read_text())
    chart = parse_chart(song.path("notes.chart").read_text())
    print(f"\n{elapsed:.0f}s  bpm={beatmap['bpm']}  notas={ {k: len(v) for k, v in chart.tracks.items()} }")
    assert set(presence) == {"drums", "bass", "strings"}
    assert {st for st, _ in fractions} == {s.name for s in stages}
    # O que dá para afirmar num som sintético: bateria presente, andamento de 120 e bumbo no chart.
    assert presence["drums"]["present"]
    assert abs(beatmap["bpm"] - 120) < 3
    assert any(n.lane == 0 for n in chart.tracks["ExpertDrums"])
    library = json.loads((config.paths.library / song.id / "song.json").read_text())
    assert library["instruments"]["drums"] is True and library["files"]["drums"] == "drums.ogg"
