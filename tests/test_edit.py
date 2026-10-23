import json

import pytest

from pbq.edit import edit_song
from pbq.manifest import Song
from pbq.pipeline import process_song
from pbq.stages.ingest import Ingest
from tests.audio import make_mp3
from tests.test_backup import packaged
from tests.test_cli import cfg_file, run  # noqa: F401 (fixture)

CHART = '[Song]\r\n{\r\n  Name = "Legião Urbana"\r\n  Artist = "Pais e Filhos"\r\n  Resolution = 192\r\n}\r\n'
INI = "[song]\nname = Legião Urbana\nartist = Pais e Filhos\nalbum = \n"


def test_edit_rewrites_every_file_that_shows_the_name(config):
    folder = packaged(config, "aaa", "Legião Urbana")
    (folder / "notes.chart").write_bytes(CHART.encode())
    (folder / "song.ini").write_text(INI)
    edit_song(config, "aaa", ' Pais e "Filhos" ', "Legião Urbana")

    chart = (folder / "notes.chart").read_bytes().decode()
    assert "Name = \"Pais e 'Filhos'\"\r\n" in chart and 'Artist = "Legião Urbana"\r\n' in chart
    assert "Resolution = 192\r\n" in chart  # o resto, e o CRLF, ficam como estavam
    assert (folder / "song.ini").read_text() == (
        '[song]\nname = Pais e "Filhos"\nartist = Legião Urbana\nalbum = \n'
    )
    song = json.loads((folder / "song.json").read_text())
    assert (song["title"], song["artist"], song["duration"]) == ('Pais e "Filhos"', "Legião Urbana", 60)
    index = json.loads((config.paths.library / "index.json").read_text())
    assert index["songs"][0]["title"] == 'Pais e "Filhos"'


def test_empty_artist_and_errors(config):
    packaged(config, "aaa")
    edit_song(config, "aaa", "Só título", "  ")
    assert json.loads((config.paths.library / "aaa" / "song.json").read_text())["artist"] is None
    with pytest.raises(ValueError):
        edit_song(config, "aaa", "  ", "x")
    with pytest.raises(LookupError):
        edit_song(config, "zzz", "Título", "x")


def test_edit_survives_reprocessing(config):
    path = make_mp3(config.paths.input / "Legião Urbana - Pais e Filhos.mp3")
    song = Song.open(path, config.paths.work)
    process_song(song, [Ingest(config)])
    packaged(config, song.id, "Pais e Filhos")
    edit_song(config, song.id, "Pais e Filhos", "Legião Urbana")
    song = Song.load(config.paths.work / song.id)
    process_song(song, [Ingest(config)], force=True)
    assert (song.meta["title"], song.meta["artist"]) == ("Pais e Filhos", "Legião Urbana")


def test_edit_command_answers_in_json(config, cfg_file, capsys):  # noqa: F811
    packaged(config, "aaa")
    code, lines = run(cfg_file, capsys, "edit", "aaa", "--title", "Nova", "--artist", "Alguém")
    assert (code, lines) == (0, [{"type": "done", "count": 1, "errors": []}])
    code, lines = run(cfg_file, capsys, "edit", "zzz", "--title", "Nova")
    assert code == 1 and lines[0]["type"] == "error"
