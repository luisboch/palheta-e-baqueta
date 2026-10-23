"""Linha de comando do backend (`pbq`).

Comandos chamados pelo jogo (version, drive ...) respondem só em JSON-lines no stdout
(pbq/protocol.py); logs vão para o stderr. A tabela de comandos de docs/backend-protocol.md
é gerada deste parser.
"""

from __future__ import annotations

import argparse
import logging
import sys
import time
from collections.abc import Callable, Sequence
from pathlib import Path

from pbq import __version__, backup, drive, protocol
from pbq.config import Config, load_config
from pbq.library import write_index
from pbq.pipeline import process_song
from pbq.proc import die_with_parent
from pbq.scan import Scanner
from pbq.stages import STAGES
from pbq.worker import Worker

log = logging.getLogger("pbq")

PROGRESS_INTERVAL = 0.2  # segundos entre linhas de progresso do pendrive (o jogo redesenha a barra)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="pbq", description="Palheta & Baqueta: backend")
    parser.add_argument("--config", type=Path, help="config.toml (padrão: ./config.toml ou o exemplo)")
    sub = parser.add_subparsers(dest="command", required=True, metavar="comando")

    sub.add_parser("version", help="versão do backend (JSON; o jogo confere a compatibilidade)")

    watch = sub.add_parser("watch", help="worker: processa em segundo plano o que chega em data/input")
    watch.add_argument(
        "--die-with-parent",
        action="store_true",
        help="morre junto com o processo pai (o jogo inicia o worker assim)",
    )

    process = sub.add_parser("process", help="processa agora as músicas pendentes (terminal)")
    process.add_argument("--song", action="append", help="só ids que começam assim (repetível)")
    process.add_argument("--force", action="store_true", help="refaz todas as etapas")

    sub.add_parser("status", help="estado de cada música (terminal)")

    drv = sub.add_parser("drive", help="pendrive (chamado pelo menu do jogo; JSON-lines)")
    drv_sub = drv.add_subparsers(dest="action", required=True, metavar="ação")
    drv_sub.add_parser("list", help="pendrives montados")
    for name, text in (
        ("process", "copia os MP3s novos de palheta/ para data/input"),
        ("import", "traz as músicas prontas de palheta/library/"),
        ("export", "salva a biblioteca em palheta/library/ (incremental)"),
    ):
        action = drv_sub.add_parser(name, help=text)
        action.add_argument("--mount", type=Path, required=True, help="montagem do pendrive")
    return parser


def cmd_version(config: Config, args: argparse.Namespace) -> int:
    protocol.write(
        "version", name="pbq", version=__version__, config=str(config.source) if config.source else None
    )
    return 0


def cmd_watch(config: Config, args: argparse.Namespace) -> int:
    if args.die_with_parent:
        die_with_parent()
    Worker(config).run_forever()
    return 1  # run_forever só volta se outro worker já tem o lock


def cmd_process(config: Config, args: argparse.Namespace) -> int:
    worker = Worker(config)
    if not worker.acquire_lock():
        log.error("o worker está rodando: ele já processa a fila")
        return 1
    stages = [cls(config) for cls in STAGES]
    scanner = Scanner(config)
    scanner.scan()
    songs = scanner.scan()  # a segunda volta entrega os arquivos estáveis
    if args.song:
        songs = [s for s in songs if s.id.startswith(tuple(args.song))]
    failed = 0
    for song in songs:
        log.info("== %s [%s]", song.label, song.id)
        failed += process_song(song, stages, force=args.force) == "failed"
    write_index(config)  # como o worker: a biblioteca vista pelo jogo inclui as recém-prontas
    return 1 if failed else 0


def cmd_status(config: Config, args: argparse.Namespace) -> int:
    scanner = Scanner(config)
    scanner.scan()
    stages = [cls(config) for cls in STAGES]
    for song in scanner.scan():
        marks = []
        for s in stages:
            state = "ok" if s.is_done(song) else song.stages.get(s.name, {}).get("status", "-")
            marks.append(f"{s.name}:{state}")
        print(f"{song.id}  {song.label[:50]:50}  {' '.join(marks)}")
    return 0


DriveAction = Callable[[Config, Path, drive.Progress], tuple[int, list[str]]]


def _drive_process(config: Config, mount: Path, progress: drive.Progress) -> tuple[int, list[str]]:
    result = drive.process_new(config, mount, progress)
    return len(result.copied), result.errors


DRIVE_ACTIONS: dict[str, DriveAction] = {
    "process": _drive_process,
    "import": lambda c, m, p: (backup.import_library(c, m, p), []),
    "export": lambda c, m, p: (backup.export_library(c, m, p), []),
}


def cmd_drive(config: Config, args: argparse.Namespace) -> int:
    if args.action == "list":
        protocol.write(
            "drives",
            drives=[
                {"path": str(m), "name": m.name, "has_folder": drive.drive_dir(config, m) is not None}
                for m in drive.mounts(config)
            ],
        )
        return 0

    last = 0.0

    def on_change(p: drive.Progress) -> None:
        nonlocal last
        t = time.monotonic()
        if p.done == p.total or t - last >= PROGRESS_INTERVAL:
            last = t
            protocol.write("progress", **p.as_dict())

    try:
        count, errors = DRIVE_ACTIONS[args.action](config, args.mount, drive.Progress(on_change=on_change))
    except OSError as e:  # sem espaço, pendrive removido, somente leitura...
        protocol.write("error", message=str(e))
        return 1
    protocol.write("done", count=count, errors=errors)
    return 0


Command = Callable[[Config, argparse.Namespace], int]
COMMANDS: dict[str, Command] = {
    "version": cmd_version,
    "watch": cmd_watch,
    "process": cmd_process,
    "status": cmd_status,
    "drive": cmd_drive,
}


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    logging.basicConfig(
        level=logging.INFO, stream=sys.stderr, format="%(asctime)s %(message)s", datefmt="%H:%M:%S"
    )
    return COMMANDS[args.command](load_config(args.config), args)
