"""Download de pesos de modelos: atômico, conferido por sha256, uma vez só.

Os pesos não vão para o git nem vêm do uv. Ficam em `data/models/` (ou no cache do próprio
pacote, como o Demucs no Hugging Face). Sem internet, a etapa falha com erro legível e a música
fica na fila até haver conexão.
"""

from __future__ import annotations

import hashlib
import urllib.request
from pathlib import Path
from typing import NamedTuple

from pbq.fsutil import tmp_path

CHUNK = 1 << 20


class Asset(NamedTuple):
    url: str
    sha256: str


def sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(CHUNK), b""):
            h.update(chunk)
    return h.hexdigest()


def fetch(asset: Asset, dest: Path) -> Path:
    """Garante `dest` com o conteúdo de `asset`, baixando se faltar ou estiver diferente."""
    if dest.exists() and sha256_of(dest) == asset.sha256:
        return dest
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = tmp_path(dest)
    try:
        with urllib.request.urlopen(asset.url, timeout=60) as response, tmp.open("wb") as out:
            for chunk in iter(lambda: response.read(CHUNK), b""):
                out.write(chunk)
        got = sha256_of(tmp)
        if got != asset.sha256:
            raise RuntimeError(f"download de {dest.name} veio diferente (sha256 {got[:12]}…)")
        tmp.replace(dest)
    except OSError as e:
        raise RuntimeError(f"não consegui baixar {dest.name}: {e}") from e
    finally:
        tmp.unlink(missing_ok=True)
    return dest
