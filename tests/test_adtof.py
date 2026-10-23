"""Partes do ADTOF que não precisam de torch: entrada (espectrograma) e saída (picos)."""

import numpy as np

from pbq.models import adtof
from tests.test_dsp import clicks


def test_filterbank_has_84_normalized_bands():
    bank = adtof.filterbank(adtof.FRAME_SIZE // 2, adtof.SAMPLE_RATE, adtof.FRAME_SIZE)
    assert bank.shape == (1024, 84)  # o que a rede espera
    assert np.allclose(bank.sum(axis=0), 1.0)
    centers = bank.argmax(axis=0)
    assert np.all(np.diff(centers) > 0)  # graves → agudos, sem repetição


def test_log_frequencies_are_twelve_per_octave():
    f = adtof.log_frequencies(12, 20.0, 20000.0)
    assert f[0] >= 20 and f[-1] <= 20000
    assert np.allclose(f[12:] / f[:-12], 2.0)


def test_features_shape_and_timing():
    signal = clicks([0.5, 1.0], seconds=2.0, rate=adtof.SAMPLE_RATE)
    feats = adtof.features(signal)
    assert feats.shape == (200, 84) and feats.dtype == np.float32
    energy = feats.sum(axis=1)
    assert abs(int(np.argmax(energy[:75])) - 50) <= 2  # ataque em 0,5 s = quadro 50 (100 por segundo)
    assert feats.min() >= 0  # log10(1 + x)


def test_pick_peaks():
    act = np.zeros(100)
    act[[10, 11, 40, 70]] = [0.5, 0.5, 0.9, 0.1]  # platô em 10-11, pico em 40, fraco em 70
    assert list(adtof.pick_peaks(act, 0.3)) == [0.1, 0.4]
    assert list(adtof.pick_peaks(np.array([]), 0.3)) == []


def test_classes_match_thresholds():
    assert len(adtof.CLASSES) == len(adtof.THRESHOLDS) == 5
