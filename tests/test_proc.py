import signal

import pytest

from pbq import proc


class FakeLibc:
    def __init__(self):
        self.calls = []

    def prctl(self, *args):
        self.calls.append(args)


def test_die_with_parent_sets_pdeathsig(monkeypatch):
    libc = FakeLibc()
    monkeypatch.setattr(proc.ctypes, "CDLL", lambda name: libc)
    monkeypatch.setattr(proc.os, "getppid", lambda: 42)
    proc.die_with_parent()
    assert libc.calls == [(proc.PR_SET_PDEATHSIG, signal.SIGKILL)]


def test_die_with_parent_exits_if_parent_already_died(monkeypatch):
    parents = iter([42, 1])
    monkeypatch.setattr(proc.ctypes, "CDLL", lambda name: FakeLibc())
    monkeypatch.setattr(proc.os, "getppid", lambda: next(parents))

    def exit_(code):
        raise SystemExit(code)

    monkeypatch.setattr(proc.os, "_exit", exit_)
    with pytest.raises(SystemExit):
        proc.die_with_parent()
