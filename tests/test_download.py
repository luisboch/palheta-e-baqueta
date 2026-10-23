import hashlib

import pytest

from pbq.models import download
from pbq.models.download import Asset, fetch


def asset_for(tmp_path, content=b"pesos do modelo"):
    src = tmp_path / "origem.bin"
    src.write_bytes(content)
    return Asset(src.as_uri(), hashlib.sha256(content).hexdigest())


def test_fetch_once_and_verify(tmp_path, monkeypatch):
    asset = asset_for(tmp_path)
    dest = tmp_path / "models" / "m.pth"
    assert fetch(asset, dest).read_bytes() == b"pesos do modelo"
    monkeypatch.setattr(download.urllib.request, "urlopen", lambda *a, **k: pytest.fail("baixou de novo"))
    assert fetch(asset, dest) == dest  # já está certo: não baixa


def test_wrong_hash_leaves_nothing(tmp_path):
    asset = asset_for(tmp_path)._replace(sha256="0" * 64)
    with pytest.raises(RuntimeError, match="veio diferente"):
        fetch(asset, tmp_path / "models" / "m.pth")
    assert list((tmp_path / "models").iterdir()) == []


def test_offline_is_readable(tmp_path):
    asset = Asset((tmp_path / "nao-existe").as_uri(), "0" * 64)
    with pytest.raises(RuntimeError, match=r"não consegui baixar m\.pth"):
        fetch(asset, tmp_path / "m.pth")
