import numpy as np
import pytest

from pbq.charts import drums
from pbq.charts.chart_file import parse_chart, write_chart
from pbq.charts.model import Chart, Note, track_name
from pbq.charts.quantize import quantize
from pbq.charts.tempo import RESOLUTION, Tempo, TempoMap, TimeSignature, time_signatures

R = RESOLUTION


def steady(bpm=120.0, n=16, start=0.5):
    return [start + i * 60 / bpm for i in range(n)]


# --- mapa de tempo -----------------------------------------------------------


def test_from_beats_steady_tempo_with_intro():
    beats = steady(120, start=0.5)  # 1ª batida em 0,5 s = 1 batida de introdução
    tm = TempoMap.from_beats(beats)
    assert tm.lead_beats == 1
    assert [t.milli_bpm for t in tm.tempos] == [120000]  # marcas iguais somem
    for i, b in enumerate(beats):
        assert tm.tick(b) == pytest.approx((i + 1) * R)
        assert tm.time((i + 1) * R) == pytest.approx(b)


def test_from_beats_follows_tempo_changes():
    beats = [0.0, 0.5, 1.0, 1.4, 1.8, 2.2]  # 120 → 150 BPM
    tm = TempoMap.from_beats(beats)
    assert tm.lead_beats == 0
    assert [(t.tick, t.milli_bpm) for t in tm.tempos] == [(0, 120000), (2 * R, 150000)]
    assert tm.time(3 * R) == pytest.approx(1.4)
    assert tm.tick(1.6) == pytest.approx(3.5 * R)


def test_intro_shorter_than_half_a_beat_still_gets_one_beat():
    tm = TempoMap.from_beats([0.1, 0.6, 1.1])
    assert tm.lead_beats == 1 and tm.tempos[0].milli_bpm == 600000
    assert tm.tick(0.6) == pytest.approx(2 * R)


def test_rounded_bpm_does_not_drift():
    rng = np.random.default_rng(1)
    beats = np.cumsum(0.5 + rng.normal(0, 0.005, 600))  # 600 batidas com jitter de 5 ms
    tm = TempoMap.from_beats(beats.tolist())
    err = max(abs(tm.time((tm.lead_beats + i) * R) - b) for i, b in enumerate(beats))
    assert err < 0.002


def test_tempo_map_validation():
    with pytest.raises(ValueError, match="tick 0"):
        TempoMap([Tempo(10, 120000)])
    with pytest.raises(ValueError, match="ao menos 2"):
        TempoMap.from_beats([1.0])


def test_time_signatures_with_anacrusis_and_change():
    beats = steady(120, n=20, start=0.0)
    # anacruse de 1 batida, compassos de 4, depois de 3 a partir da batida 13
    downbeats = [beats[i] for i in (1, 5, 9, 13, 16, 19)]
    assert time_signatures(beats, downbeats) == [
        TimeSignature(0, 1),
        TimeSignature(R, 4),
        TimeSignature(13 * R, 3),
    ]


def test_time_signatures_aligned_and_fallback():
    beats = steady(120, n=12, start=0.0)
    assert time_signatures(beats, [beats[0], beats[4], beats[8]]) == [TimeSignature(0, 4)]
    assert time_signatures(beats, [beats[0]]) == [TimeSignature(0, 4)]
    assert time_signatures(beats, [], lead_beats=2) == [TimeSignature(0, 4)]


def test_time_signatures_with_lead_beats():
    beats = steady(120, n=12, start=1.0)  # 2 batidas de introdução
    downbeats = [beats[i] for i in (0, 4, 8)]
    assert time_signatures(beats, downbeats, lead_beats=2) == [TimeSignature(0, 2), TimeSignature(2 * R, 4)]


# --- quantização -------------------------------------------------------------


def test_quantize_to_sixteenths_and_triplets():
    tm = TempoMap([Tempo(0, 60000)])  # 1 batida = 1 s
    assert quantize(0.26, tm) == R // 4  # perto da semicolcheia
    assert quantize(0.335, tm) == R // 3  # tercina clara
    assert quantize(0.30, tm) == R // 4  # no meio do caminho: fica a semicolcheia
    assert quantize(0.30, tm, subdivisions=(4,)) == R // 4
    assert quantize(-0.01, tm) == 0


# --- .chart ------------------------------------------------------------------


def sample_chart():
    return Chart(
        name='Música "Boa"',
        artist="Fulano",
        tempos=[Tempo(0, 120000), Tempo(4 * R, 90500)],
        time_signatures=[TimeSignature(0, 4), TimeSignature(8 * R, 3)],
        tracks={
            "ExpertDrums": [Note(R, 0), Note(R, 2), Note(R, 66), Note(0, 1)],
            "ExpertSingle": [Note(2 * R, 3, 96)],
        },
        streams={"MusicStream": "song.ogg", "DrumStream": "drums.ogg"},
    )


def test_chart_roundtrip():
    text = write_chart(sample_chart())
    assert "\r\n" in text and "  Name = \"Música 'Boa'\"" in text
    assert "  0 = TS 4\r\n  0 = B 120000" in text  # TS antes de B no mesmo tick
    back = parse_chart(text)
    assert back.name == "Música 'Boa'" and back.artist == "Fulano" and back.resolution == R
    assert back.tempos == sample_chart().tempos
    assert back.time_signatures == sample_chart().time_signatures
    assert back.tracks["ExpertDrums"] == sorted(sample_chart().tracks["ExpertDrums"])
    assert back.tracks["ExpertSingle"] == [Note(2 * R, 3, 96)]
    assert back.streams == {"MusicStream": "song.ogg", "DrumStream": "drums.ogg"}


def test_parse_tolerates_bom_events_and_unknown_lines():
    text = (
        "﻿[Song]\n{\n  Resolution = 480\n}\n[SyncTrack]\n{\n  0 = B 100000\n  0 = A 5\n}\n"
        '[Events]\n{\n  0 = E "section Intro"\n}\n[ExpertDrums]\n{\n  480 = N 1 0\n  480 = S 2 10\n'
        "  960 = N 0\n}\nlixo fora de seção\n"
    )
    chart = parse_chart(text)
    assert chart.resolution == 480 and chart.tempos == [Tempo(0, 100000)]
    assert chart.tracks["ExpertDrums"] == [Note(480, 1), Note(960, 0)]
    assert "Events" not in chart.tracks


def test_track_names():
    assert track_name("drums", "Expert") == "ExpertDrums"
    assert track_name("strings", "Easy") == "EasySingle"
    assert track_name("bass", "Hard") == "HardDoubleBass"


# --- bateria -----------------------------------------------------------------


def test_drum_notes_lanes_cymbals_and_grid():
    tm = TempoMap([Tempo(0, 60000)])
    hits = {"kick": [0.0, 1.01], "snare": [0.5], "hihat": [0.0, 0.26], "tom": [], "cymbal": [1.0]}
    assert drums.drum_notes(hits, tm) == [
        Note(0, drums.KICK),
        Note(0, drums.YELLOW),
        Note(0, 66),
        Note(R // 4, drums.YELLOW),
        Note(R // 4, 66),
        Note(R // 2, drums.RED),
        Note(R, drums.KICK),
        Note(R, drums.GREEN),
        Note(R, 68),
    ]


def test_drum_notes_two_hands_and_dedupe():
    tm = TempoMap([Tempo(0, 60000)])
    hits = {"kick": [0.0, 0.004], "snare": [0.0], "hihat": [0.0], "tom": [0.0], "cymbal": [0.0]}
    notes = drums.drum_notes(hits, tm)
    lanes = sorted(n.lane for n in notes)
    assert lanes == [drums.KICK, drums.RED, drums.GREEN, 68]  # caixa e prato; chimbal e tom saem
