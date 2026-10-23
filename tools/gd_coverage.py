"""Cobertura de linhas do GDScript (ADR 0005): não há ferramenta confiável para Godot 4.

    uv run python -m tools.gd_coverage            # relatório (godot/reports/gd_coverage.json)
    uv run python -m tools.gd_coverage --fail-under 80

Como funciona:
1. Copia o projeto Godot para um diretório temporário (o original nunca é tocado).
2. Em cada script medido (`core/`, `game/`), insere `GdCov.hit(id, linha)` antes de cada
   instrução executável, na mesma indentação. O número das linhas originais vai no próprio hit;
   nada se desloca no relatório.
3. Roda os testes do GdUnit4 na cópia. Um autoload grava as linhas executadas ao fechar.
4. Cruza executáveis × executadas.

"Instrução executável" (sem um parser de GDScript, por regras de indentação e de parênteses):
- só dentro de funções (corpo indentado depois de `func ...:`; inclusive em classes internas);
- só no começo de um comando: não em continuações dentro de ( [ { nem depois de `\\`;
- nunca antes de `elif`/`else` (separaria o bloco do `if`) nem nas linhas de padrão de um `match`
  (só nos corpos deles);
- funções de uma linha (`func f(): return 1`) e corpos de lambdas de várias linhas dentro de
  parênteses não são medidos; assinaturas quebradas em várias linhas, sim (o corpo é medido).
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from collections.abc import Sequence
from dataclasses import dataclass, field
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
GODOT_DIR = REPO / "godot"
MEASURED = ("core", "game")
REPORT = Path("reports") / "gd_coverage.json"
HITS_FILE = "gd_cov_hits.json"

# Início de declaração de função; a assinatura pode seguir em várias linhas (o gdformat quebra as
# longas), e essas continuações já ficam de fora por estarem dentro de parênteses.
FUNC = re.compile(r"^(\s*)(static\s+)?func\s+\w+")
BLOCK_CONTINUATIONS = ("elif ", "elif(", "else:", "else :")
STRING = re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'')

COV_CLASS = """class_name GdCov
extends RefCounted

static var hits := {}


static func hit(file_id: int, line: int) -> void:
	hits[file_id * 100000 + line] = true
"""

COV_WRITER = f"""extends Node


func _exit_tree() -> void:
	var out := FileAccess.open("user://{HITS_FILE}", FileAccess.WRITE)
	out.store_string(JSON.stringify(GdCov.hits.keys()))
	out.close()
"""


def _indent(line: str) -> int:
    return len(line) - len(line.lstrip("\t "))


def _code(line: str) -> str:
    """A linha sem strings nem comentário (para contar parênteses e achar ':' finais)."""
    no_strings = STRING.sub('""', line)
    return no_strings.split("#", 1)[0].rstrip()


def _depth_change(code: str) -> int:
    return sum(code.count(c) for c in "([{") - sum(code.count(c) for c in ")]}")


@dataclass
class Instrumented:
    text: str
    lines: list[int] = field(default_factory=list)  # linhas executáveis (1-based, do original)


def instrument(source: str, file_id: int) -> Instrumented:
    """Insere GdCov.hit antes de cada instrução executável e devolve quais linhas são essas."""
    out: list[str] = []
    executable: list[int] = []
    func_indent: int | None = None
    depth = 0
    continued = False
    match_stack: list[tuple[int, int | None]] = []  # (indentação do match, indentação dos padrões)
    lines = source.split("\n")
    for number, line in enumerate(lines, 1):
        stripped = line.strip()
        code = _code(line)
        starts_statement = depth == 0 and not continued
        if starts_statement and stripped and not stripped.startswith("#"):
            indent = _indent(line)
            while match_stack and indent <= match_stack[-1][0]:
                match_stack.pop()
            if FUNC.match(line):
                func_indent = indent
            elif func_indent is not None and indent <= func_indent:
                func_indent = None  # saiu da função (outra declaração no mesmo nível ou acima)
            elif func_indent is not None and indent > func_indent:
                is_pattern = False
                if match_stack:
                    m_indent, p_indent = match_stack[-1]
                    if p_indent is None:
                        match_stack[-1] = (m_indent, indent)
                        p_indent = indent
                    is_pattern = indent == p_indent
                if not is_pattern and not stripped.startswith(BLOCK_CONTINUATIONS):
                    prefix = line[:indent]
                    out.append(f"{prefix}GdCov.hit({file_id}, {number})")
                    executable.append(number)
                if re.match(r"^match\b.*:$", code.strip()):
                    match_stack.append((indent, None))
        out.append(line)
        depth = max(0, depth + _depth_change(code))
        continued = code.endswith("\\")
    return Instrumented("\n".join(out), executable)


@dataclass
class FileReport:
    path: str
    executable: list[int]
    hit: list[int]

    @property
    def percent(self) -> float:
        return 100.0 * len(self.hit) / len(self.executable) if self.executable else 100.0


def prepare(project: Path, measured: Sequence[str] = MEASURED) -> dict[int, tuple[str, list[int]]]:
    """Instrumenta a cópia do projeto em `project`; devolve {id: (caminho relativo, executáveis)}."""
    files: dict[int, tuple[str, list[int]]] = {}
    scripts = sorted(p for d in measured for p in (project / d).rglob("*.gd"))
    for file_id, path in enumerate(scripts, 1):
        result = instrument(path.read_text(), file_id)
        path.write_text(result.text)
        files[file_id] = (str(path.relative_to(project)), result.lines)
    cov_dir = project / "__coverage__"
    cov_dir.mkdir()
    (cov_dir / "gd_cov.gd").write_text(COV_CLASS)
    (cov_dir / "gd_cov_writer.gd").write_text(COV_WRITER)
    settings = project / "project.godot"
    text = settings.read_text()
    writer = 'GdCovWriter="*res://__coverage__/gd_cov_writer.gd"\n'
    if "[autoload]\n\n" in text:  # o projeto já tem autoloads: entra na mesma seção
        settings.write_text(text.replace("[autoload]\n\n", "[autoload]\n\n" + writer, 1))
    else:
        settings.write_text(text + "\n[autoload]\n\n" + writer)
    return files


def report(files: dict[int, tuple[str, list[int]]], hit_keys: Sequence[int]) -> list[FileReport]:
    hits: dict[int, set[int]] = {}
    for key in hit_keys:
        hits.setdefault(int(key) // 100000, set()).add(int(key) % 100000)
    return [
        FileReport(path, lines, sorted(set(lines) & hits.get(fid, set())))
        for fid, (path, lines) in sorted(files.items())
    ]


def total(reports: Sequence[FileReport]) -> float:
    executable = sum(len(r.executable) for r in reports)
    return 100.0 * sum(len(r.hit) for r in reports) / executable if executable else 100.0


def _user_dir(godot: str, project: Path) -> Path:
    """Pasta user:// do projeto copiado (o Godot diz onde fica)."""
    script = project / "__coverage__" / "print_user_dir.gd"
    script.write_text(
        'extends SceneTree\n\n\nfunc _init() -> void:\n\tprint(ProjectSettings.globalize_path("user://"))\n\tquit()\n'
    )
    out = subprocess.run(
        [godot, "--headless", "--path", str(project), "-s", str(script)],
        capture_output=True,
        text=True,
        timeout=120,
    ).stdout
    return Path(out.strip().splitlines()[-1])


def run(godot: str, source: Path = GODOT_DIR) -> list[FileReport]:
    with tempfile.TemporaryDirectory(prefix="gd_cov_") as tmp:
        project = Path(tmp) / "godot"
        shutil.copytree(source, project, ignore=shutil.ignore_patterns(".godot", "reports"))
        files = prepare(project)
        # Nome próprio para a pasta user:// da cópia (não mistura com o projeto de verdade).
        settings = project / "project.godot"
        settings.write_text(
            settings.read_text().replace(
                'config/name="Palheta & Baqueta"', 'config/name="Palheta & Baqueta (cobertura)"'
            )
        )
        user = _user_dir(godot, project)
        (user / HITS_FILE).unlink(missing_ok=True)
        subprocess.run(
            [godot, "--headless", "--path", str(project), "--import"], capture_output=True, timeout=300
        )
        subprocess.run(
            [
                godot,
                "--headless",
                "--path",
                str(project),
                "-s",
                "-d",
                "--remote-debug",
                "tcp://127.0.0.1:0",
                "res://addons/gdUnit4/bin/GdUnitCmdTool.gd",
                "-a",
                "res://tests",
                "--ignoreHeadlessMode",
                "-c",
            ],
            capture_output=True,
            timeout=600,
        )
        hits_path = user / HITS_FILE
        if not hits_path.exists():
            raise RuntimeError("os testes não gravaram a cobertura (o Godot fechou antes do autoload?)")
        return report(files, json.loads(hits_path.read_text()))


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Cobertura de linhas do GDScript (core/ e game/)")
    parser.add_argument("--godot", help="binário do Godot (padrão: scripts/godot.sh)")
    parser.add_argument("--fail-under", type=float, default=0.0)
    args = parser.parse_args(argv)
    godot = (
        args.godot
        or subprocess.run(
            [str(REPO / "scripts" / "godot.sh")], capture_output=True, text=True, check=True
        ).stdout.strip()
    )
    reports = run(godot)
    width = max(len(r.path) for r in reports)
    for r in reports:
        missing = sorted(set(r.executable) - set(r.hit))
        listed = ",".join(map(str, missing[:12])) + ("…" if len(missing) > 12 else "")
        note = f"faltam {listed}" if missing else ""
        print(f"{r.path:{width}}  {len(r.hit):4}/{len(r.executable):<4} {r.percent:5.1f}%  {note}")
    pct = total(reports)
    print(f"{'TOTAL':{width}}  {pct:5.1f}%")
    out = GODOT_DIR / REPORT
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(
        json.dumps(
            {
                "total": round(pct, 2),
                "files": [
                    {"path": r.path, "executable": r.executable, "hit": r.hit, "percent": round(r.percent, 2)}
                    for r in reports
                ],
            },
            indent=1,
        )
    )
    if pct < args.fail_under:
        print(f"cobertura de GDScript {pct:.1f}% abaixo de {args.fail_under}%", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
