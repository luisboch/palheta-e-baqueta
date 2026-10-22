"""Linha de comando do backend (`pbq`). Cada fase acrescenta seus comandos aqui."""

from __future__ import annotations

import argparse
import json
from collections.abc import Sequence
from pathlib import Path

from pbq import __version__
from pbq.config import load_config


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="pbq", description="Palheta & Baqueta: backend")
    parser.add_argument("--config", type=Path, help="config.toml (padrão: ./config.toml ou o exemplo)")
    sub = parser.add_subparsers(dest="command", required=True)
    # O Godot confere a versão do backend ao abrir: saída em JSON, como todo comando que ele chama.
    sub.add_parser("version", help="versão do backend (JSON)")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    config = load_config(args.config)
    if args.command == "version":
        print(
            json.dumps(
                {
                    "name": "pbq",
                    "version": __version__,
                    "config": str(config.source) if config.source else None,
                }
            )
        )
    return 0
