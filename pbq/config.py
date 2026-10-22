"""Carrega config.toml (veja config.example.toml).

Igual ao kraoke: sem config.toml, vale o config.example.toml versionado; o código lê cada
ajuste com default (`opts.get("chave", padrão)`), então uma chave nova não quebra configs antigas.
"""

from __future__ import annotations

import tomllib
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

Section = dict[str, Any]


@dataclass
class Paths:
    input: Path = Path("data/input")
    work: Path = Path("data/work")
    library: Path = Path("data/library")
    state: Path = Path("data")  # events.jsonl, lock do worker, settings do jogo


@dataclass
class Config:
    paths: Paths = field(default_factory=Paths)
    stages: dict[str, Section] = field(default_factory=dict)
    sections: dict[str, Section] = field(default_factory=dict)  # [watch], [drive], ...
    source: Path | None = None  # arquivo de onde veio (repassado ao worker)

    def stage(self, name: str) -> Section:
        return self.stages.get(name, {})

    def section(self, name: str) -> Section:
        return self.sections.get(name, {})


def load_config(path: Path | None = None) -> Config:
    if path is None:
        path = Path("config.toml")
        if not path.exists():
            path = Path("config.example.toml")
    if not path.exists():
        return Config()

    data = tomllib.loads(path.read_text())
    paths = Paths(**{k: Path(v) for k, v in data.get("paths", {}).items()})
    sections = {k: v for k, v in data.items() if k not in ("paths", "stages") and isinstance(v, dict)}
    return Config(paths=paths, stages=data.get("stages", {}), sections=sections, source=path.resolve())
