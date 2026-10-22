from pathlib import Path

from pbq.config import Config, load_config


def test_missing_file_gives_defaults(tmp_path):
    cfg = load_config(tmp_path / "nao-existe.toml")
    assert cfg == Config()
    assert cfg.stage("separate") == {}
    assert cfg.section("watch") == {}


def test_reads_paths_stages_and_sections(tmp_path):
    path = tmp_path / "c.toml"
    path.write_text(
        "solto = 1\n"  # chave de topo que não é seção: ignorada
        '[paths]\ninput = "x/in"\n'
        '[stages.separate]\nmodel = "htdemucs_6s"\n'
        "[watch]\ninterval = 3\n"
    )
    cfg = load_config(path)
    assert cfg.paths.input == Path("x/in")
    assert cfg.paths.work == Path("data/work")
    assert cfg.stage("separate") == {"model": "htdemucs_6s"}
    assert cfg.section("watch") == {"interval": 3}
    assert cfg.source == path.resolve()


def test_default_lookup_falls_back_to_example(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    assert load_config().source is None
    (tmp_path / "config.example.toml").write_text("[watch]\ninterval = 9\n")
    assert load_config().section("watch") == {"interval": 9}
    (tmp_path / "config.toml").write_text("[watch]\ninterval = 1\n")
    assert load_config().section("watch") == {"interval": 1}
