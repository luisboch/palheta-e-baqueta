import pytest

from pbq import fsutil
from pbq.ffmpeg import ffmpeg, ffmpeg_to


def test_write_and_read_json(tmp_path):
    path = tmp_path / "a" / "b.json"
    fsutil.write_json(path, {"x": "ç"})
    assert fsutil.read_json(path, None) == {"x": "ç"}
    assert not list(path.parent.glob(".tmp.*"))
    path.write_text("{quebrado")
    assert fsutil.read_json(path, []) == []
    assert fsutil.read_json(tmp_path / "nao", {}) == {}


def test_copy_atomic_cleans_up_on_error(tmp_path, monkeypatch):
    src = tmp_path / "src"
    src.write_bytes(b"x" * 10)
    fsutil.copy_atomic(src, tmp_path / "d" / "dst")
    assert (tmp_path / "d" / "dst").read_bytes() == b"x" * 10

    def broken(a, b):
        b.write_bytes(b"metade")
        raise OSError("disco cheio")

    monkeypatch.setattr(fsutil.shutil, "copyfile", broken)
    with pytest.raises(OSError):
        fsutil.copy_atomic(src, tmp_path / "d" / "outro")
    assert sorted(p.name for p in (tmp_path / "d").iterdir()) == ["dst"]


def test_mp3s_free_name_and_size(tmp_path):
    for name in ("a.mp3", "b.MP3", ".oculto.mp3", "c.txt", "sub/d.mp3"):
        (tmp_path / name).parent.mkdir(exist_ok=True)
        (tmp_path / name).write_bytes(b"x")
    assert [p.name for p in fsutil.mp3s(tmp_path)] == ["a.mp3", "b.MP3", "d.mp3"]
    assert fsutil.free_name(tmp_path / "a.mp3").name == "a (2).mp3"
    (tmp_path / "a (2).mp3").write_bytes(b"x")
    assert fsutil.free_name(tmp_path / "a.mp3").name == "a (3).mp3"
    assert fsutil.size(tmp_path / "a.mp3") == 1 and fsutil.size(tmp_path / "nao") == 0


def test_ffmpeg_errors_are_readable(tmp_path):
    with pytest.raises(RuntimeError, match="ffmpeg falhou"):
        ffmpeg("-i", tmp_path / "nao-existe.mp3", tmp_path / "x.wav")
    with pytest.raises(RuntimeError):
        ffmpeg_to(tmp_path / "y.wav", "-i", tmp_path / "nao-existe.mp3")
    assert list(tmp_path.iterdir()) == []  # nenhum temporário largado
