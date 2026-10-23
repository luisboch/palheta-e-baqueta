import json

from pbq.library import FORMAT_VERSION, ready_ids, write_index


def test_index_lists_complete_songs_only(config):
    lib = config.paths.library
    for sid, data in (("b", {"id": "b", "title": "B", "extra": 1}), ("a", {"id": "a", "artist": "X"})):
        (lib / sid).mkdir(parents=True)
        (lib / sid / "song.json").write_text(json.dumps(data))
    (lib / "c").mkdir()  # sem song.json: incompleta
    (lib / "d").mkdir()
    (lib / "d" / "song.json").write_text("{metade")  # sendo copiada
    write_index(config)
    index = json.loads((lib / "index.json").read_text())
    assert index["version"] == FORMAT_VERSION
    assert index["songs"] == [
        {"id": "a", "title": None, "artist": "X", "duration": None, "instruments": None},
        {"id": "b", "title": "B", "artist": None, "duration": None, "instruments": None},
    ]
    assert ready_ids(lib) == {"a", "b", "d"}
    assert ready_ids(None) == set() and ready_ids(lib / "nao") == set()
