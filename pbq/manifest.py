"""Estado de cada música no pipeline, salvo em data/work/<id>/song.json.

O `<id>` é o hash do conteúdo do MP3 e é o cache do projeto: a mesma música (renomeada,
movida, vinda de outro pendrive) cai na mesma pasta de trabalho e não é reprocessada.
Cada etapa grava a sua `version`: subir a versão de uma etapa (ex.: gerador de charts novo)
refaz só ela e as que vêm depois, para todas as músicas.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import asdict, dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from pbq.fsutil import write_json

MANIFEST = "song.json"
ID_LENGTH = 12  # hex do sha1; colisão improvável para uma biblioteca pessoal


def song_id(path: Path) -> str:
    """Id estável derivado do conteúdo: renomear ou mover o MP3 não muda o id."""
    h = hashlib.sha1()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()[:ID_LENGTH]


def now() -> str:
    return datetime.now(UTC).isoformat(timespec="seconds")


@dataclass
class Song:
    id: str
    source: str
    work_dir: Path
    meta: dict[str, Any] = field(default_factory=dict)
    stages: dict[str, dict[str, Any]] = field(default_factory=dict)

    def path(self, *parts: str) -> Path:
        return self.work_dir.joinpath(*parts)

    @property
    def label(self) -> str:
        if self.meta.get("title"):
            return f"{self.meta.get('artist') or '?'} - {self.meta['title']}"
        return Path(self.source).stem

    def stage_done(self, name: str, version: int | None = None) -> bool:
        entry = self.stages.get(name, {})
        return entry.get("status") == "done" and (version is None or entry.get("version") == version)

    def mark(self, name: str, status: str, version: int, error: str | None = None) -> None:
        entry: dict[str, Any] = {"status": status, "version": version, "at": now()}
        if error:
            entry["error"] = error
        self.stages[name] = entry

    def save(self) -> None:
        data = asdict(self)
        data["work_dir"] = str(self.work_dir)
        write_json(self.path(MANIFEST), data)

    @classmethod
    def load(cls, work_dir: Path) -> Song:
        data = json.loads((work_dir / MANIFEST).read_text())
        data["work_dir"] = work_dir
        return cls(**data)

    @classmethod
    def open(cls, mp3: Path, work_root: Path, sid: str | None = None) -> Song:
        """Carrega o estado existente ou cria um novo para o MP3 (sid: id já calculado)."""
        sid = sid or song_id(mp3)
        work_dir = work_root / sid
        if (work_dir / MANIFEST).exists():
            # Não grava aqui: o worker pode estar atualizando este manifesto agora.
            song = cls.load(work_dir)
            song.source = str(mp3.resolve())
        else:
            song = cls(id=sid, source=str(mp3.resolve()), work_dir=work_dir)
            song.save()
        return song
