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
    thin,
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


def test_thin_keeps_the_strongest_pulses_and_spreads_the_rest():
    ticks = [0, R, 2 * R, R // 2, 3 * R // 2, 5 * R // 2, 7 * R // 2, R // 3, R // 4]
    assert thin(ticks, 1.0, R) == set(ticks)
    assert thin(ticks, 0.0, R) == set()
    assert thin(ticks, 3 / 9, R) == {0, R, 2 * R}  # batidas primeiro
    five = thin(ticks, 5 / 9, R)
    assert (
        {0, R, 2 * R} < five
        and len(five) == 5
        and len(five & {R // 2, 3 * R // 2, 5 * R // 2, 7 * R // 2}) == 2
    )
    assert R // 3 not in thin(ticks, 8 / 9, R) or R // 4 not in thin(
        ticks, 8 / 9, R
    )  # o mais fraco sai antes
    assert thin(ticks, 8 / 9, R) == set(ticks) - {R // 4}


def test_select_ticks_per_difficulty():
    # referência: colcheias e tercinas (10 ataques); a semicolcheia R // 4 nunca entra
    beats = [i * R for i in range(5)]
    eighths = [i * R + R // 2 for i in range(4)]
    ticks = beats + eighths + [R // 3, R // 4]
    reference = set(beats + eighths + [R // 3])
    expert = select_ticks(ticks, EXPERT, R, FOUR_FOUR)
    hard = select_ticks(ticks, HARD, R, FOUR_FOUR)
    assert len(expert) == 8 and len(hard) == 7  # 80% e 70% da referência
    assert expert <= reference and hard <= reference
    assert set(beats) <= hard  # as batidas ficam
    assert R // 3 not in hard  # a tercina é o pulso mais fraco: sai primeiro
    # Médio: batidas + contratempo só quando a batida está vazia (a da batida 1 estava)
    medium_ticks = [0, R // 4, R // 2, R + R // 2, 2 * R + R // 3, 3 * R]
    assert select_ticks(medium_ticks, MEDIUM, R, FOUR_FOUR) == {0, R + R // 2, 3 * R}
    assert select_ticks(medium_ticks, EASY, R, FOUR_FOUR) == {0}
    assert select_ticks([], EASY, R, FOUR_FOUR) == set()


def test_pitched_track_fewer_lanes_and_chords():
    evts = [Event(i * R, (48 + 2 * i, 52 + 2 * i, 55 + 2 * i)) for i in range(8)]
    expert = pitched_track(evts, EXPERT, R, FOUR_FOUR)
    easy = pitched_track(evts, EASY, R, FOUR_FOUR)
    medium = pitched_track(evts, MEDIUM, R, FOUR_FOUR)
    assert len(expert) == 18 and max(n.lane for n in expert) == 4  # 6 de 8 ataques (80%) × 3 notas
    assert [n.tick for n in easy] == [0, 2 * R, 4 * R, 6 * R] and max(n.lane for n in easy) <= 2
    assert len(medium) == 8 and max(n.lane for n in medium) <= 3
    hard = pitched_track(evts, HARD, R, FOUR_FOUR)
    assert {len([n for n in hard if n.tick == t]) for t in {n.tick for n in hard}} == {2}  # acordes de até 2


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
    # 10 ataques (batidas e colcheias) na referência: Muito difícil fica com 8, Difícil com 7
    grid = [Note(i * R // 2, r) for i in range(10)] + [Note(R // 4, y), Note(R // 4, 66)]
    top = drum_track(grid, EXPERT, R)
    hard = drum_track(grid, HARD, R)
    assert len({n.tick for n in top}) == 8 and len({n.tick for n in hard}) == 7
    assert R // 4 not in {n.tick for n in top}  # semicolcheia nunca entra
    assert {n.tick for n in hard} <= {n.tick for n in top}
    assert all(i * R in {n.tick for n in hard} for i in range(5))  # as batidas ficam
    flagged = drum_track([Note(0, y), Note(0, 66), Note(0, k)], EXPERT, R)
    assert flagged == [Note(0, k), Note(0, y), Note(0, 66)]  # o prato leva a marca junto
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
