import pytest

from pbq.charts import difficulty, drums
from pbq.charts.difficulty import (
    EASY,
    EXPERT,
    HARD,
    MEDIUM,
    drum_track,
    pitched_track,
    select_ticks,
    strong_beats,
)
from pbq.charts.model import Note
from pbq.charts.pitched import BASS, STRINGS, Event, RawNote, chord_lanes, contour_lanes, events, to_notes
from pbq.charts.tempo import RESOLUTION as R
from pbq.charts.tempo import Tempo, TempoMap, TimeSignature

TM = TempoMap([Tempo(0, 60000)])  # 1 batida = 1 s: tempo (s) × R = tick


# --- eventos ---------------------------------------------------------------------


def test_events_filter_group_and_quantize():
    raw = [
        RawNote(0.00, 0.20, 52, 0.8),
        RawNote(0.01, 0.20, 56, 0.7),
        RawNote(0.02, 0.2, 59, 0.6),  # acorde
        RawNote(0.03, 0.2, 64, 0.6),  # 4ª nota do acorde: Cordas guardam só 3
        RawNote(0.51, 0.70, 55, 0.9),  # colcheia, levemente atrasada
        RawNote(1.00, 1.03, 50, 0.9),  # curta demais (30 ms)
        RawNote(1.25, 1.40, 50, 0.1),  # fraca demais
        RawNote(1.50, 1.70, 20, 0.9),  # grave demais para Cordas
    ]
    assert events(raw, TM, STRINGS) == [Event(0, (52, 56, 59)), Event(R // 2, (55,))]


def test_events_merge_same_tick_and_bass_keeps_root():
    raw = [RawNote(0.0, 0.2, 40, 0.9), RawNote(0.1, 0.2, 52, 0.9)]  # grupos diferentes, mesmo tick
    assert events(raw, TM, BASS) == [Event(0, (40,))]
    assert events(raw, TM, STRINGS) == [Event(0, (40, 52))]


def test_events_sustain_only_long_notes_and_stops_before_next():
    raw = [RawNote(0.0, 1.5, 50, 0.9), RawNote(2.0, 2.3, 52, 0.9), RawNote(3.0, 6.0, 54, 0.9)]
    evts = events(raw, TM, STRINGS)
    assert [e.length for e in evts] == [round(1.5 * R), 0, 3 * R]
    capped = events([RawNote(0.0, 3.0, 50, 0.9), RawNote(2.0, 2.2, 52, 0.9)], TM, STRINGS)
    assert capped[0].length == 2 * R - R // 4  # acaba 1/16 antes da próxima
    short = events([RawNote(0.0, 3.0, 50, 0.9), RawNote(0.6, 0.8, 52, 0.9)], TM, STRINGS)
    assert short[0].length == 0  # cortada para 0,35 batida: vira nota curta


# --- contorno -----------------------------------------------------------------------


def test_contour_keeps_direction():
    roots = [60, 62, 64, 65, 67, 65, 64, 62, 60, 60]
    lanes = contour_lanes(roots, 5)
    for i in range(1, len(roots)):
        if roots[i] > roots[i - 1]:
            assert lanes[i] > lanes[i - 1] or lanes[i] == 4
        elif roots[i] < roots[i - 1]:
            assert lanes[i] < lanes[i - 1] or lanes[i] == 0
        else:
            assert lanes[i] == lanes[i - 1]
    assert lanes[0] == 0 and max(lanes) == 4


def test_contour_small_range_stays_in_the_middle():
    assert contour_lanes([60, 61, 60, 61], 5) == [2, 3, 2, 3]
    assert contour_lanes([], 5) == []
    assert set(contour_lanes([40, 80, 40, 80], 3)) == {0, 2}


def test_chords_and_notes():
    assert chord_lanes(1, 3, 5) == [1, 2, 3]
    assert chord_lanes(4, 2, 5) == [3, 4]  # encostado à direita: recua
    assert chord_lanes(0, 4, 3) == [0, 1, 2]
    evts = [Event(0, (50, 54, 57), 96), Event(R, (55,))]
    # 50 → 55 é um salto pequeno: fica no meio do braço (extensão mínima de 7 semitons)
    assert to_notes(evts, 5, 2) == [Note(0, 1, 96), Note(0, 2, 96), Note(R, 3, 0)]


# --- dificuldades -------------------------------------------------------------------

FOUR_FOUR = [TimeSignature(0, 4)]


def test_strong_beats():
    assert strong_beats(FOUR_FOUR, 8 * R, R) == {0, 2 * R, 4 * R, 6 * R, 8 * R}
    assert strong_beats([TimeSignature(0, 3), TimeSignature(3 * R, 4)], 7 * R, R) == {0, 3 * R, 5 * R, 7 * R}


def test_select_ticks_per_difficulty():
    ticks = [0, R // 4, R // 2, R + R // 2, 2 * R + R // 3, 3 * R]
    # Muito difícil: sem semicolcheias (R // 4); Difícil: nem tercinas
    assert select_ticks(ticks, EXPERT, R, FOUR_FOUR) == {0, R // 2, R + R // 2, 2 * R + R // 3, 3 * R}
    assert select_ticks(ticks, HARD, R, FOUR_FOUR) == {0, R // 2, R + R // 2, 3 * R}
    # Médio: batidas + contratempo só quando a batida está vazia (a da batida 1 estava)
    assert select_ticks(ticks, MEDIUM, R, FOUR_FOUR) == {0, R + R // 2, 3 * R}
    assert select_ticks(ticks, EASY, R, FOUR_FOUR) == {0}
    assert select_ticks([], EASY, R, FOUR_FOUR) == set()


def test_pitched_track_fewer_lanes_and_chords():
    evts = [Event(i * R, (48 + 2 * i, 52 + 2 * i, 55 + 2 * i)) for i in range(8)]
    expert = pitched_track(evts, EXPERT, R, FOUR_FOUR)
    easy = pitched_track(evts, EASY, R, FOUR_FOUR)
    medium = pitched_track(evts, MEDIUM, R, FOUR_FOUR)
    assert len(expert) == 24 and max(n.lane for n in expert) == 4
    assert [n.tick for n in easy] == [0, 2 * R, 4 * R, 6 * R] and max(n.lane for n in easy) <= 2
    assert len(medium) == 8 and max(n.lane for n in medium) <= 3
    assert {
        len([n for n in pitched_track(evts, HARD, R, FOUR_FOUR) if n.tick == t]) for t in range(0, 8 * R, R)
    } == {2}


def test_drum_track_reductions():
    k, r, y, g = drums.KICK, drums.RED, drums.YELLOW, drums.GREEN
    expert = [
        Note(0, k),
        Note(0, y),
        Note(0, 66),
        Note(0, g),
        Note(0, 68),
        Note(R // 4, y),
        Note(R // 4, 66),
        Note(R // 2, k),
        Note(R // 2, r),
        Note(R, r),
        Note(R, k),
    ]
    top = drum_track(expert, EXPERT, R)
    assert top == sorted(n for n in expert if n.tick != R // 4)  # só a semicolcheia sai
    hard = drum_track(expert, HARD, R)
    assert Note(R // 4, y) not in hard and Note(0, 68) in hard and Note(0, 66) in hard
    assert [n for n in hard if n.tick == R // 2] == [Note(R // 2, k), Note(R // 2, r)]
    hat_hard = drum_track([Note(R // 2, y), Note(R // 2, 66), Note(R, y), Note(R, 66)], HARD, R)
    assert hat_hard == [Note(R, y), Note(R, 66)]  # chimbal só na batida, como no Médio
    assert drum_track([Note(R // 3, r)], HARD, R) == []  # tercina só no Muito difícil
    assert drum_track([Note(R // 3, r)], EXPERT, R) == [Note(R // 3, r)]
    medium = drum_track(expert, MEDIUM, R)
    assert [n for n in medium if n.tick == 0] == [Note(0, k), Note(0, g), Note(0, 68)]  # 1 pad: o prato
    assert [n for n in medium if n.tick == R // 2] == [Note(R // 2, r)]  # bumbo fora da batida sai
    offbeat_hat = drum_track([Note(R // 2, y), Note(R // 2, 66), Note(R, y), Note(R, 66)], MEDIUM, R)
    assert offbeat_hat == [Note(R, y), Note(R, 66)]  # chimbal só na batida
    easy = drum_track(expert, EASY, R)
    assert easy == [Note(0, k), Note(R, r)]  # uma peça por batida: bumbo antes do prato


def test_difficulty_names_cover_all():
    assert set(difficulty.PITCHED) == {EASY, MEDIUM, HARD, EXPERT}
    with pytest.raises(KeyError):
        pitched_track([], "Impossível", R, FOUR_FOUR)
