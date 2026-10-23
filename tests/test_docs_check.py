"""Documentação viva (tools/docs_check.py)."""

from pathlib import Path

import pytest

from tools import docs_check
from tools.docs_check import REPO, run, slug

ADR = """# {n:04d}. {title}

- **Status:** {status}
- **Data:** 2026-10-22

## Contexto

x

## Decisão

y

## Consequências

z
"""


def write(root: Path, rel: str, text: str) -> Path:
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    return path


def adr(root: Path, n: int, title: str = "Algo", status: str = "Aceita") -> Path:
    return write(root, f"docs/adr/{n:04d}-algo-{n}.md", ADR.format(n=n, title=title, status=status))


def messages(root: Path, fix: bool = False) -> list[str]:
    return [str(p) for p in run(root, fix)]


@pytest.fixture
def root(tmp_path):
    # Fora de um repositório git: markdown_files cai no rglob.
    return tmp_path


def test_repository_docs_are_consistent():
    """A própria documentação do projeto passa no check (o mesmo do pre-commit e da CI)."""
    assert messages(REPO) == []


def test_clean_tree_has_no_problems(root):
    write(root, "README.md", "# Oi\n\nVeja [a seção](#oi) e [o outro](docs/b.md#título-b).\n")
    write(root, "docs/b.md", "# Título B\n")
    assert messages(root) == []


def test_broken_links_and_anchors(root):
    write(
        root,
        "README.md",
        "[x](docs/nao.md) [y](docs/b.md#nada) [z](https://exemplo.com/nao)\n"
        "![img](nao.png) `[em código](nao.md)`\n",
    )
    write(root, "docs/b.md", "# B\n")
    assert messages(root) == [
        "README.md: link quebrado: docs/nao.md",
        "README.md: âncora inexistente: docs/b.md#nada",
    ]


def test_code_paths(root):
    write(root, "pbq/cli.py", "")
    write(
        root,
        "README.md",
        "`pbq/cli.py:3` `pbq/sumiu.py` `data/input/x.mp3` `pbq/stages/<etapa>.py` "
        "`song.json` `uv run pbq` `godot/core/*.gd`\n"
        "```\n`pbq/no-bloco.py` [x](nao.md)\n```\n",
    )
    assert messages(root) == ["README.md: caminho citado não existe: pbq/sumiu.py"]


def test_generated_block_is_checked_and_fixed(root):
    adr(root, 1, "Primeira")
    index = write(
        root, "docs/adr/README.md", "# ADRs\n\n<!-- gen:adr-index -->\nvelho\n<!-- /gen:adr-index -->\n"
    )
    assert messages(root) == [
        "docs/adr/README.md: trecho gen:adr-index desatualizado (rode: python -m tools.docs_check --fix)"
    ]
    assert messages(root, fix=True) == []
    assert "| 0001 | [Primeira](0001-algo-1.md) | Aceita |" in index.read_text()
    assert messages(root) == []


def test_unknown_generator(root):
    write(root, "a.md", "<!-- gen:nada -->\n<!-- /gen:nada -->\n")
    assert messages(root) == ["a.md: gerador desconhecido: gen:nada"]


def test_adr_rules(root):
    adr(root, 1, status="Talvez")
    adr(root, 3, status="Substituída por nada")
    write(root, "docs/adr/0004-ruim.md", "sem nada\n")
    write(root, "docs/adr/9-x.md", "")
    found = messages(root)
    assert (
        "docs/adr/0001-algo-1.md: Status deve começar por: Proposta, Aceita, Descartada, Substituída por"
        in found
    )
    assert "docs/adr/0003-algo-3.md: 'Substituída por' precisa de link para o ADR novo" in found
    assert "docs/adr/0004-ruim.md: primeira linha deve ser '# 0004. Título'" in found
    assert "docs/adr/0004-ruim.md: falta '- **Data:** AAAA-MM-DD'" in found
    assert "docs/adr/0004-ruim.md: falta a seção '## Contexto'" in found
    assert "docs/adr/9-x.md: nome deve ser NNNN-titulo-em-minusculas.md" in found
    assert any("sem buracos" in m for m in found)


def test_superseded_with_valid_link(root):
    adr(root, 1, status="Substituída por [0002](0002-algo-2.md)")
    adr(root, 2)
    assert messages(root) == []


def test_slug_like_github():
    assert slug("Decisões & `código` (v2)") == "decisões--código-v2"


def test_main_exit_code(root, capsys):
    assert docs_check.main(["--root", str(root)]) == 0
    write(root, "a.md", "[x](nao.md)\n")
    assert docs_check.main(["--root", str(root)]) == 1
    assert "1 problema(s)" in capsys.readouterr().err


def test_git_listing_ignores_untracked_ignored_dirs(tmp_path):
    import subprocess

    subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
    write(tmp_path, ".gitignore", "ignorado/\n")
    write(tmp_path, "a.md", "ok\n")
    write(tmp_path, "ignorado/b.md", "[x](nao.md)\n")
    write(tmp_path, "godot/addons/lib/c.md", "[x](nao.md)\n")
    assert docs_check.markdown_files(tmp_path) == [tmp_path / "a.md"]


def test_generated_files_are_checked_and_fixed(root):
    files = {Path("godot/core/gerado.gd"): lambda r: "conteúdo novo\n"}
    assert messages_with(root, files) == [
        "godot/core/gerado.gd: arquivo gerado desatualizado (rode: python -m tools.docs_check --fix)"
    ]
    assert [str(p) for p in run(root, fix=True, files=files)] == []
    assert (root / "godot/core/gerado.gd").read_text() == "conteúdo novo\n"
    assert messages_with(root, files) == []


def messages_with(root, files):
    return [str(p) for p in run(root, files=files)]


def test_repository_generated_contract_is_fresh():
    """O contrato em GDScript bate com o Python (o mesmo check do pre-commit)."""
    from tools.generators import FILE_GENERATORS

    for rel, gen in FILE_GENERATORS.items():
        assert (REPO / rel).read_text() == gen(REPO), rel
