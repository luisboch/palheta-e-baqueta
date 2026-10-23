from pathlib import Path

import pytest

from pbq.config import Config, Paths


def make_config(root: Path) -> Config:
    """Config apontando para um diretório temporário: os testes nunca tocam a data/ real."""
    cfg = Config(
        paths=Paths(input=root / "in", work=root / "work", library=root / "lib", state=root),
        sections={"drive": {"roots": [str(root / "media")]}},
    )
    cfg.paths.input.mkdir(parents=True)
    return cfg


@pytest.fixture
def config(tmp_path: Path) -> Config:
    return make_config(tmp_path / "pc")
