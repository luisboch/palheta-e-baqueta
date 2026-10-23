"""Etapa ingest com MP3s sintéticos de verdade (ffmpeg + tags ID3)."""

from pbq.manifest import Song
from pbq.pipeline import DONE, process_song
from pbq.stages.ingest import Ingest
from tests.audio import make_mp3


def ingest(config, path):
    song = Song.open(path, config.paths.work)
    assert process_song(song, [Ingest(config)]) == DONE
    return song


def test_video_title_and_cover(config):
    path = make_mp3(
        config.paths.input / "x.mp3",
        seconds=1.5,
        cover=True,
        tags={"title": "Fulano & Beltrano - Canção (Ao Vivo)", "artist": "Canal Qualquer", "album": "Disco"},
    )
    song = ingest(config, path)
    assert song.meta["artist"] == "Fulano & Beltrano"
    assert song.meta["title"] == "Canção"
    assert song.meta["live"] is True
    assert song.meta["album"] == "Disco"
    assert 1.4 < song.meta["duration"] < 1.7
    assert song.meta["cover"] is True and song.path("cover.jpg").stat().st_size > 0


def test_youtube_music_description_wins(config):
    description = "Provided to YouTube by Gravadora\n\nCanção do Mar · Artista Certo · Outro\n\nDisco"
    path = make_mp3(config.paths.input / "y.mp3", tags={"title": "Canção do Mar", "description": description})
    song = ingest(config, path)
    assert (song.meta["artist"], song.meta["title"]) == ("Artista Certo", "Canção do Mar")
    assert song.meta["cover"] is False and not song.path("cover.jpg").exists()


def test_without_tags_uses_file_name(config):
    path = make_mp3(config.paths.input / "Artista - Música.mp3")
    song = ingest(config, path)
    assert (song.meta["artist"], song.meta["title"]) == ("Artista", "Música")
    assert song.meta["album"] is None
