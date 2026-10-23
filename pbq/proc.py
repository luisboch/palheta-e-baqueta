"""Ciclo de vida do worker como filho do jogo."""

from __future__ import annotations

import ctypes
import os
import signal

PR_SET_PDEATHSIG = 1


def die_with_parent() -> None:
    """O kernel mata este processo quando o pai (o jogo) morrer, inclusive por SIGKILL.

    Chamado pelo próprio worker (`pbq watch --die-with-parent`): o Godot não tem preexec_fn.
    SIGKILL (e não SIGTERM) porque funciona mesmo com o worker congelado (SIGSTOP durante a
    partida); as escritas do pipeline são atômicas, então não corrompe nada.
    """
    parent = os.getppid()
    ctypes.CDLL(None).prctl(PR_SET_PDEATHSIG, signal.SIGKILL)
    if os.getppid() != parent:  # o pai morreu antes do prctl
        os._exit(0)
