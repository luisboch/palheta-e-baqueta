import json

from pbq.manifest import Song, song_id
from pbq.pipeline import CANCELLED, DONE, FAILED, process_song
from tests.fakes import Boom, Optional, Publish, Touch


def song(config, content=b"mp3"):
    path = config.paths.input / "a.mp3"
    path.write_bytes(content)
    return Song.open(path, config.paths.work)


def test_runs_pending_stages_in_order_and_reports_progress(config):
    s = song(config)
    seen = []
    stages = [Touch(config), Publish(config)]
    assert process_song(s, stages, progress=lambda st, f: seen.append((st, f))) == DONE
    assert seen == [
        ("touch", 0.0),
        ("touch", 0.25),
        ("touch", 0.5),
        ("touch", 0.75),
        ("touch", 1.0),
        ("publish", 0.0),
        ("publish", 1.0),
    ]
    saved = json.loads(s.path("song.json").read_text())
    assert saved["stages"]["touch"]["status"] == "done" and saved["stages"]["touch"]["version"] == 1

    seen.clear()
    assert process_song(s, stages, progress=lambda st, f: seen.append(st)) == DONE
    assert seen == []  # cache: nada a refazer


def test_version_bump_reruns_stage_and_dependents(config):
    s = song(config)
    process_song(s, [Touch(config), Publish(config)])

    class TouchV2(Touch):
        version = 2

    ran = []
    process_song(s, [TouchV2(config), Publish(config)], progress=lambda st, f: ran.append(st))
    assert sorted(set(ran)) == ["publish", "touch"]
    assert s.stages["touch"]["version"] == 2


def test_missing_output_reruns(config):
    s = song(config)
    process_song(s, [Touch(config)])
    s.path("touched").unlink()
    assert not Touch(config).is_done(s)
    process_song(s, [Touch(config)])
    assert s.path("touched").exists()


def test_required_failure_stops(config):
    s = song(config)
    assert process_song(s, [Boom(config), Touch(config)]) == FAILED
    assert s.stages["boom"]["error"] == "RuntimeError: falhou de propósito"
    assert "touch" not in s.stages


def test_optional_failure_continues(config):
    s = song(config)
    assert process_song(s, [Optional(config), Touch(config)]) == DONE
    assert s.stages["optional"]["status"] == "failed"
    assert s.stage_done("touch")


def test_waits_for_requirements(config):
    s = song(config)
    assert process_song(s, [Publish(config)]) == DONE  # touch nunca rodou
    assert "publish" not in s.stages


def test_cancel_between_stages(config):
    s = song(config)
    assert process_song(s, [Touch(config)], cancelled=lambda: True) == CANCELLED


def test_force_reruns(config):
    s = song(config)
    process_song(s, [Touch(config)])
    ran = []
    process_song(s, [Touch(config)], force=True, progress=lambda st, f: ran.append(st))
    assert ran


def test_progress_is_clamped(config):
    class Wild(Touch):
        def run(self, song, progress=lambda f: None):
            progress(-1)
            progress(7)

    seen = []
    process_song(song(config), [Wild(config)], progress=lambda st, f: seen.append(f))
    assert seen == [0.0, 0.0, 1.0, 1.0]


def test_manifest_reopen_keeps_state_and_updates_source(config):
    s = song(config)
    s.mark("touch", "done", 1)
    s.save()
    moved = config.paths.input / "sub" / "b.mp3"
    moved.parent.mkdir()
    (config.paths.input / "a.mp3").rename(moved)
    again = Song.open(moved, config.paths.work)
    assert again.id == s.id == song_id(moved)
    assert again.stage_done("touch") and again.source == str(moved.resolve())
    assert again.label == "b"
    again.meta.update(title="Música", artist=None)
    assert again.label == "? - Música"
