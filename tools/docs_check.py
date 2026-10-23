"""Documentação viva: falha quando a doc diverge do repositório.

    python -m tools.docs_check          # verifica (pre-commit, CI e um teste do pytest)
    python -m tools.docs_check --fix    # regenera os trechos gerados

No kraoke a regra "atualize o AGENTS.md no mesmo commit" dependia de disciplina e envelhecia
calada. Aqui o que pode ser conferido é conferido:

1. Links relativos em Markdown apontam para arquivos (e títulos, com #âncora) que existem.
2. Caminhos citados entre crases (`pbq/cli.py`, `godot/core/judge.gd:12`) existem.
   Só valem os que começam por uma pasta do repositório (ROOTS); `data/...` e padrões com
   `<id>`, `*` ou `…` são exemplos, não arquivos.
3. Trechos gerados: entre `<!-- gen:NOME -->` e `<!-- /gen:NOME -->` o texto é produzido por
   GENERATORS[NOME] a partir do código (índice dos ADRs aqui; os do backend em
   tools/generators.py). Arquivos inteiros também podem ser gerados (FILE_GENERATORS).
   Editar à mão é inútil: o check acusa e o --fix regenera.
4. ADRs (docs/adr/NNNN-titulo.md) têm número único e sequencial, título, Status, Data e as
   seções Contexto / Decisão / Consequências; "Substituída por" aponta para um ADR existente.

O que não dá para conferir (a prosa estar certa) continua sendo regra do AGENTS.md.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from collections.abc import Callable, Iterable, Sequence
from dataclasses import dataclass
from pathlib import Path

from tools.generators import DOC_GENERATORS, FILE_GENERATORS

REPO = Path(__file__).resolve().parent.parent

# Pastas do repositório: um caminho entre crases que começa por uma delas tem que existir.
ROOTS = ("pbq", "tools", "tests", "godot", "docs", "scripts", ".github")
# Nunca varridos: dependências, dados do usuário, addons de terceiros.
SKIP_DIRS = {
    ".git",
    ".venv",
    "data",
    "node_modules",
    ".godot",
    "addons",
    ".pytest_cache",
    ".ruff_cache",
    ".mypy_cache",
    "htmlcov",
    "reports",
}
ADR_DIR = Path("docs/adr")
ADR_STATUSES = ("Proposta", "Aceita", "Descartada", "Substituída por")
ADR_SECTIONS = ("Contexto", "Decisão", "Consequências")

LINK = re.compile(r"(?<!!)\[[^\]]*\]\(([^)\s]+)\)")
CODE = re.compile(r"(?<!`)`([^`\n]+)`(?!`)")
FENCE = re.compile(r"^(```|~~~).*?^\1", re.S | re.M)
GEN = re.compile(r"(<!-- gen:([\w-]+) -->\n)(.*?)(<!-- /gen:\2 -->)", re.S)
HEADING = re.compile(r"^#{1,6}\s+(.+?)\s*#*\s*$", re.M)
ADR_FILE = re.compile(r"^(\d{4})-[a-z0-9-]+\.md$")


@dataclass(frozen=True)
class Problem:
    file: Path
    message: str

    def __str__(self) -> str:
        return f"{self.file}: {self.message}"


# --- trechos gerados -----------------------------------------------------------


@dataclass(frozen=True)
class Adr:
    number: int
    title: str
    status: str
    path: Path


def read_adrs(root: Path) -> list[Adr]:
    adrs = []
    for path in sorted((root / ADR_DIR).glob("[0-9]*.md")):
        text = path.read_text()
        title = re.search(r"^# \d{4}\. (.+)$", text, re.M)
        status = re.search(r"^- \*\*Status:\*\* (.+)$", text, re.M)
        number = ADR_FILE.match(path.name)
        adrs.append(
            Adr(
                int(number.group(1)) if number else -1,
                title.group(1).strip() if title else "",
                status.group(1).strip() if status else "",
                path.relative_to(root),
            )
        )
    return adrs


def gen_adr_index(root: Path) -> str:
    rows = ["| # | Decisão | Status |", "|---|---|---|"]
    for adr in read_adrs(root):
        # O status pode ter link relativo à pasta do ADR, que é a mesma do índice.
        rows.append(f"| {adr.number:04d} | [{adr.title}]({adr.path.name}) | {adr.status} |")
    return "\n".join(rows) + "\n"


Generator = Callable[[Path], str]
GENERATORS: dict[str, Generator] = {
    "adr-index": gen_adr_index,
    **DOC_GENERATORS,
}


# --- verificações --------------------------------------------------------------


def markdown_files(root: Path) -> list[Path]:
    """Arquivos .md versionados (ou, fora de um repositório git, todos fora de SKIP_DIRS)."""
    try:
        out = subprocess.run(
            ["git", "ls-files", "--cached", "--others", "--exclude-standard", "*.md"],
            cwd=root,
            capture_output=True,
            text=True,
            check=True,
        ).stdout
        files = [root / line for line in out.splitlines() if line]
    except (OSError, subprocess.CalledProcessError):
        files = list(root.rglob("*.md"))
    return sorted(f for f in files if f.is_file() and not SKIP_DIRS & set(f.relative_to(root).parts[:-1]))


def slug(heading: str) -> str:
    """Âncora no estilo do GitHub: minúsculas, sem pontuação, espaços viram hífens."""
    text = re.sub(r"[`*_\[\]()]", "", heading).strip().lower()
    text = re.sub(r"[^\w\- ]", "", text)
    return text.replace(" ", "-")


def anchors(path: Path) -> set[str]:
    return {slug(h) for h in HEADING.findall(strip_fences(path.read_text()))}


def strip_fences(text: str) -> str:
    """Blocos de código são exemplos: links e caminhos dentro deles não são conferidos."""
    return FENCE.sub("", text)


def check_links(root: Path, md: Path, text: str) -> Iterable[Problem]:
    for target in LINK.findall(CODE.sub("", text)):  # `[x](y)` em código é exemplo, não link
        if re.match(r"^[a-z][\w+.-]*:", target):  # http:, mailto:...
            continue
        path_part, _, anchor = target.partition("#")
        dest = (md.parent / path_part).resolve() if path_part else md
        if not dest.exists():
            yield Problem(md.relative_to(root), f"link quebrado: {target}")
        elif anchor and dest.suffix == ".md" and anchor not in anchors(dest):
            yield Problem(md.relative_to(root), f"âncora inexistente: {target}")


def check_code_paths(root: Path, md: Path, text: str) -> Iterable[Problem]:
    for span in CODE.findall(text):
        candidate = span.strip().split()[0] if span.strip() else ""
        candidate = re.sub(r":\d+(-\d+)?$", "", candidate)  # arquivo.py:12
        if "/" not in candidate or candidate.split("/")[0] not in ROOTS:
            continue
        if any(c in candidate for c in "<>*…{}$"):
            continue
        if not (root / candidate).exists() and not git_ignored(root, candidate):
            yield Problem(md.relative_to(root), f"caminho citado não existe: {candidate}")


def git_ignored(root: Path, path: str) -> bool:
    """Saída gerada (relatório, cache) que o .gitignore tira do repositório: num clone novo ela
    ainda não existe, e citá-la na doc não é um caminho quebrado."""
    try:
        return subprocess.run(["git", "check-ignore", "-q", path], cwd=root, check=False).returncode == 0
    except OSError:
        return False


def check_generated(root: Path, md: Path, text: str, fix: bool) -> tuple[str, list[Problem]]:
    problems = []

    def replace(m: re.Match[str]) -> str:
        name = m.group(2)
        gen = GENERATORS.get(name)
        if gen is None:
            problems.append(Problem(md.relative_to(root), f"gerador desconhecido: gen:{name}"))
            return m.group(0)
        fresh = gen(root)
        if fresh != m.group(3) and not fix:
            problems.append(
                Problem(
                    md.relative_to(root),
                    f"trecho gen:{name} desatualizado (rode: python -m tools.docs_check --fix)",
                )
            )
        return m.group(1) + fresh + m.group(4)

    return GEN.sub(replace, text), problems


def check_adrs(root: Path) -> Iterable[Problem]:
    adrs = read_adrs(root)
    numbers = [a.number for a in adrs]
    for adr in adrs:
        text = (root / adr.path).read_text()
        if adr.number < 0:
            yield Problem(adr.path, "nome deve ser NNNN-titulo-em-minusculas.md")
            continue
        if not adr.title:
            yield Problem(adr.path, f"primeira linha deve ser '# {adr.number:04d}. Título'")
        if not adr.status.startswith(ADR_STATUSES):
            yield Problem(adr.path, f"Status deve começar por: {', '.join(ADR_STATUSES)}")
        if adr.status.startswith("Substituída por"):
            other = re.search(r"\((\d{4}-[a-z0-9-]+\.md)\)", adr.status)
            if not other or not (root / ADR_DIR / other.group(1)).exists():
                yield Problem(adr.path, "'Substituída por' precisa de link para o ADR novo")
        if not re.search(r"^- \*\*Data:\*\* \d{4}-\d{2}-\d{2}$", text, re.M):
            yield Problem(adr.path, "falta '- **Data:** AAAA-MM-DD'")
        for section in ADR_SECTIONS:
            if not re.search(rf"^## {section}$", text, re.M):
                yield Problem(adr.path, f"falta a seção '## {section}'")
    if numbers != list(range(1, len(numbers) + 1)):
        yield Problem(ADR_DIR, f"ADRs devem ser numerados 0001, 0002... sem buracos: {numbers}")


def check_generated_files(root: Path, files: dict[Path, Generator], fix: bool) -> Iterable[Problem]:
    """Arquivos inteiros gerados (ex.: o contrato do backend em GDScript).

    Comparados em bytes: read_text() trocaria CRLF por LF, e o .chart é CRLF de propósito.
    """
    for rel, gen in files.items():
        path = root / rel
        fresh = gen(root).encode("utf-8")
        current = path.read_bytes() if path.exists() else None
        if current == fresh:
            continue
        if fix:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(fresh)
        else:
            yield Problem(rel, "arquivo gerado desatualizado (rode: python -m tools.docs_check --fix)")


def run(root: Path = REPO, fix: bool = False, files: dict[Path, Generator] | None = None) -> list[Problem]:
    """`files`: arquivos gerados a conferir (padrão: os do repositório, só quando root é ele)."""
    checked: dict[Path, Generator] = files if files is not None else (FILE_GENERATORS if root == REPO else {})
    problems: list[Problem] = list(check_adrs(root))
    problems += check_generated_files(root, checked, fix)
    for md in markdown_files(root):
        original = md.read_text()
        text, gen_problems = check_generated(root, md, original, fix)
        problems += gen_problems
        if fix and text != original:
            md.write_text(text)
        body = strip_fences(text)
        problems += check_links(root, md, body)
        problems += check_code_paths(root, md, body)
    return problems


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0] if __doc__ else None)
    parser.add_argument("--fix", action="store_true", help="regenera os trechos gerados")
    parser.add_argument("--root", type=Path, default=REPO)
    args = parser.parse_args(argv)
    problems = run(args.root, args.fix)
    for p in problems:
        print(p, file=sys.stderr)
    if problems:
        print(f"{len(problems)} problema(s) na documentação", file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
