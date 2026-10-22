import json
import subprocess
import sys

import pytest

from pbq import __version__
from pbq.cli import main


def test_version_prints_json(capsys, tmp_path):
    cfg = tmp_path / "c.toml"
    cfg.write_text("")
    assert main(["--config", str(cfg), "version"]) == 0
    out = json.loads(capsys.readouterr().out)
    assert out == {"name": "pbq", "version": __version__, "config": str(cfg.resolve())}


def test_command_is_required():
    with pytest.raises(SystemExit):
        main([])


def test_module_entry_point(tmp_path):
    """`python -m pbq` é como o jogo chama o backend quando não há o script `pbq` no PATH."""
    out = subprocess.run(
        [sys.executable, "-m", "pbq", "version"], cwd=tmp_path, capture_output=True, text=True, check=True
    ).stdout
    assert json.loads(out)["name"] == "pbq"
