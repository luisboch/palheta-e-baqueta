"""PANNs CNN14 (AudioSet, 527 classes) como GuitarTimbre.

Usado só pelas classes de guitarra do AudioSet. O pacote `panns_inference` baixa, ao ser
importado, o CSV de rótulos para ~/panns_data com `wget` (e quebra sem internet). Por isso
garantimos o CSV antes do import, por download conferido, e passamos os pesos por caminho nosso.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import numpy.typing as npt

from pbq.models.download import Asset, fetch

SAMPLE_RATE = 32000  # a do CNN14
BATCH = 16  # janelas por inferência: limita a memória (~1 GB) no Deck
CHECKPOINT = Asset(
    "https://zenodo.org/record/3987831/files/Cnn14_mAP%3D0.431.pth?download=1",
    "0dc499e40e9761ef5ea061ffc77697697f277f6a960894903df3ada000e34b31",
)
LABELS = Asset(
    "http://storage.googleapis.com/us_audioset/youtube_corpus/v1/csv/class_labels_indices.csv",
    "cdd1049833c4b86127c2773ac0d14a2754b6a6d0d1798002ed5c66e699708429",
)
LABELS_PATH = Path.home() / "panns_data" / "class_labels_indices.csv"  # fixo no panns_inference

# Índices no AudioSet: a distorção é a marca mais confiável da guitarra elétrica.
ACOUSTIC_GUITAR = 143
ELECTRIC_GUITAR = 141
DISTORTION = 517


class PannsGuitarTimbre:
    sample_rate = SAMPLE_RATE

    def __init__(self, models_dir: Path, device: str = "cpu"):
        fetch(LABELS, LABELS_PATH)
        checkpoint = fetch(CHECKPOINT, models_dir / "Cnn14_mAP=0.431.pth")
        import torch
        from panns_inference.models import Cnn14

        self._torch = torch
        self._device = device
        model = Cnn14(
            sample_rate=SAMPLE_RATE,
            window_size=1024,
            hop_size=320,
            mel_bins=64,
            fmin=50,
            fmax=14000,
            classes_num=527,
        )
        model.load_state_dict(torch.load(checkpoint, map_location=device)["model"])
        self._model = model.to(device).eval()

    def scores(self, windows: npt.NDArray[np.float32]) -> npt.NDArray[np.float64]:
        torch = self._torch
        out = []
        with torch.no_grad():
            for i in range(0, len(windows), BATCH):
                batch = torch.from_numpy(np.ascontiguousarray(windows[i : i + BATCH])).to(self._device)
                probs = self._model(batch, None)["clipwise_output"].cpu().numpy()
                electric = np.maximum(probs[:, ELECTRIC_GUITAR], probs[:, DISTORTION])
                out.append(np.stack([probs[:, ACOUSTIC_GUITAR], electric], axis=1))
        return np.concatenate(out).astype(np.float64) if out else np.zeros((0, 2))
