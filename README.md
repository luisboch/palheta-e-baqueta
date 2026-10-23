# Palheta & Baqueta

Jogo de ritmo para até 2 jogadores, com guitarra, violão, baixo e bateria, feito para o Steam
Deck. Você traz os seus MP3s num pendrive. O backend separa os instrumentos com IA e gera as
notas em 4 dificuldades (Fácil, Médio, Difícil e Muito difícil). O jogo, em Godot 4, toca a
música com uma pista 3D por jogador.

> Em construção: o andamento por fase está em [docs/roadmap.md](docs/roadmap.md).

## Arquitetura

```
pendrive/palheta/*.mp3 ─(menu do jogo)─► data/input ─► worker (Python) ─► data/library/<id>/ ─► jogo (Godot)
                                                          │ data/events.jsonl (fila, progresso)      ▲
                                                          └──────────────────────────────────────────┘
```

- **Backend** (`pbq/`, Python): importação, separação de stems, transcrição, charts e cache.
  Roda como um worker em segundo plano, em prioridade baixa.
- **Jogo** (`godot/`, Godot 4): só lê a biblioteca e os eventos, e roda o jogo.
- Os dois conversam **só por arquivos**. Detalhes em [docs/architecture.md](docs/architecture.md)
  e decisões em [docs/adr/](docs/adr/README.md).

## Instalação

Requisitos:
- [uv](https://docs.astral.sh/uv/) (`curl -LsSf https://astral.sh/uv/install.sh | sh`);
- `ffmpeg` com libvorbis;
- git;
- Godot na versão de `scripts/versions.env`. O script procura em `$GODOT_BIN`, em
  `~/Applications/Godot_v<versão>-stable_linux.x86_64` e no `PATH`.

```bash
scripts/setup.sh     # .venv com Python fixado, GdUnit4, importação do projeto Godot, pre-commit
```

O `uv` baixa sozinho o Python de `.python-version` (3.12), sem depender do Python do sistema.

## Uso

```bash
cp config.example.toml config.toml   # opcional: só para mudar algum ajuste
uv run pbq process                   # processa agora o que estiver em data/input
uv run pbq status                    # estado de cada música, por etapa
uv run pbq watch                     # worker em segundo plano (o jogo inicia sozinho)
uv run pbq drive list                # pendrives montados (o menu do jogo usa os comandos drive)
```

Todos os comandos e o que o jogo lê estão em [docs/backend-protocol.md](docs/backend-protocol.md).
Por enquanto só a etapa `ingest` existe; o jogo chega na fase 6 (ver o roadmap).

## Testes

```bash
scripts/test.sh                     # tudo que é rápido: Python (cobertura ≥ 80%) + GDScript
scripts/test.sh python -k config    # só Python, com argumentos do pytest
scripts/test.sh godot               # só GDScript (GdUnit4, headless)
uv run pytest -m slow --no-cov      # modelos de IA reais (minutos)
uv run pre-commit run --all-files   # ruff, mypy, gdformat, gdlint, documentação viva
```

Estratégia de testes e cobertura: [docs/testing.md](docs/testing.md).

## Estrutura

```
pbq/            backend Python (CLI `pbq`)
tools/          ferramentas de desenvolvimento (documentação viva)
tests/          testes Python
godot/core/     lógica do jogo em classes puras (testáveis)
godot/tests/    testes GdUnit4
scripts/        setup, testes, versões fixadas
docs/           arquitetura, ADRs, roadmap, testes, armadilhas
```

Para quem vai mexer no código, as regras ficam em [AGENTS.md](AGENTS.md).
