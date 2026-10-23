"""Instrumentador de cobertura do GDScript (tools/gd_coverage.py)."""

import json
import shutil
import subprocess

import pytest

from tools import gd_coverage as gc

SAMPLE = """class_name Exemplo
extends RefCounted

const X := {"a": (1, 2)}
var y := [
\t1,
]


func f(a: int) -> int:
\t# comentário (com parêntese
\tvar total := a + \\
\t\t2
\tif a > 1:
\t\treturn compute(
\t\t\ta,
\t\t)
\telif a < 0:
\t\tpass
\telse:
\t\ttotal += 1
\tmatch a:
\t\t1:
\t\t\treturn 1
\t\t2, 3:
\t\t\treturn "x(:"
\treturn total


static func g() -> void: pass


class Interna:
\tfunc h() -> void:
\t\tprint("oi")


func longa(
\ta: int, b: int
) -> int:
\treturn a + b
"""


def lines_of(text: str) -> dict[int, str]:
    return {i: line for i, line in enumerate(text.split("\n"), 1)}


def test_executable_lines():
    result = gc.instrument(SAMPLE, 7)
    src = lines_of(SAMPLE)
    marked = {n: src[n].strip() for n in result.lines}
    assert marked == {
        12: "var total := a + \\",
        14: "if a > 1:",
        15: "return compute(",
        19: "pass",
        21: "total += 1",
        22: "match a:",
        24: "return 1",
        26: 'return "x(:"',
        27: "return total",
        35: 'print("oi")',
        41: "return a + b",
    }


def test_instrumented_text_keeps_original_lines_in_order():
    result = gc.instrument(SAMPLE, 7)
    cleaned = [line for line in result.text.split("\n") if "GdCov.hit(" not in line]
    assert cleaned == SAMPLE.split("\n")
    out = result.text.split("\n")
    i = out.index("\t\tpass")
    assert out[i - 1] == "\t\tGdCov.hit(7, 19)"  # mesma indentação do comando
    assert "\tGdCov.hit(7, 18)" not in result.text  # nunca antes de elif/else


def test_report_and_total():
    files = {1: ("core/a.gd", [3, 4, 5]), 2: ("core/b.gd", [])}
    reports = gc.report(files, [100003, 100005, 999999])
    assert [(r.path, r.hit, round(r.percent)) for r in reports] == [
        ("core/a.gd", [3, 5], 67),
        ("core/b.gd", [], 100),
    ]
    assert round(gc.total(reports)) == 67
    assert gc.total([]) == 100.0


def test_prepare_instruments_a_copy(tmp_path):
    project = tmp_path / "godot"
    (project / "core").mkdir(parents=True)
    (project / "tests").mkdir()
    (project / "core" / "a.gd").write_text("func f() -> void:\n\tpass\n")
    (project / "tests" / "a_test.gd").write_text("func test() -> void:\n\tpass\n")
    (project / "project.godot").write_text('[application]\nconfig/name="X"\n')
    files = gc.prepare(project, measured=("core",))
    assert files == {1: ("core/a.gd", [2])}
    assert "GdCov.hit(1, 2)" in (project / "core" / "a.gd").read_text()
    assert "GdCov" not in (project / "tests" / "a_test.gd").read_text()  # testes não são medidos
    assert "GdCovWriter" in (project / "project.godot").read_text()
    assert (project / "__coverage__" / "gd_cov.gd").exists()


@pytest.mark.slow
def test_real_run_on_the_project():
    """Roda o GdUnit4 no projeto instrumentado (uns 30 s): a cobertura sai e é plausível."""
    godot = subprocess.run(
        [str(gc.REPO / "scripts" / "godot.sh")], capture_output=True, text=True
    ).stdout.strip()
    if not godot or not shutil.which(godot):
        pytest.skip("Godot não encontrado")
    reports = gc.run(godot)
    by_path = {r.path: r for r in reports}
    assert by_path["core/judge.gd"].percent > 80
    assert 0 < gc.total(reports) <= 100
    json.dumps([r.path for r in reports])
