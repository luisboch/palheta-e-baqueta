# Palheta & Baqueta

Jogo de ritmo para até 2 jogadores, com Cordas (violão e guitarra), baixo e bateria, feito para o Steam
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

### Jogar (fase 6: antes dos menus)

```bash
GODOT=$(scripts/godot.sh)
$GODOT --path godot -- --song data/library/<id> --instrument strings --difficulty Hard
```

- `--instrument`: `strings` (Cordas), `bass` ou `drums`; `--difficulty`: `Easy`, `Medium`, `Hard`
  ou `Expert`. Sem `--song`, abre a música de `data/library/` com mais instrumentos; sem escolha,
  Cordas no Difícil (o que existir mais perto disso). É o que o F5 do editor abre.
- Teclado: trastes `1`–`5` (ou `A S D F G`); a nota toca ao apertar o traste, sem palhetada
  ([ADR 0015](docs/adr/0015-tocar-no-traste-sem-palhetada.md)). Bateria: bumbo `Espaço`, pads
  `H J K L`. Controle: trastes A B Y X LB. `Esc` sai.
- No modo desktop do Deck, o Steam converte os controles em teclado e mouse e o jogo não vê o
  controle: use um teclado ou rode pelo Steam (o atalho para o modo jogo vem na fase 9).
- A música toca do começo ao fim; o instrumento escolhido baixa 18 dB a cada erro e volta no
  acerto. Numa música só de Cordas (como uma de violão e voz), errar deixa quase só a voz.
- `--autoplay 1`: o jogo toca sozinho (para ver um chart sem tocar).
As etapas de IA precisam dos extras: `uv sync --extra dev --extra ai` (torch CPU e Demucs;
~1,5 GB). O modelo baixa no primeiro uso (~80 MB). O jogo chega na fase 6.

## Testes

```bash
scripts/test.sh                     # tudo que é rápido: Python (cobertura ≥ 80%) + GDScript
scripts/test.sh python -k config    # só Python, com argumentos do pytest
scripts/test.sh godot               # só GDScript (GdUnit4, headless)
scripts/test.sh coverage            # cobertura do GDScript (≥ 80%)
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

## Licenças e créditos

O Palheta & Baqueta é um projeto **não comercial**: a transcrição de bateria usa os pesos do
ADTOF, sob CC BY-NC-SA 4.0 ([ADR 0011](docs/adr/0011-batidas-e-bateria.md)). A licença do
código do projeto ainda não foi definida.

| Componente | Uso | Licença |
|---|---|---|
| [Demucs](https://github.com/adefossez/demucs) (`htdemucs_6s`) | separação em stems | MIT |
| [beat_this](https://github.com/CPJKU/beat_this) | batidas e compassos | MIT (código e pesos) |
| [basic-pitch](https://github.com/spotify/basic-pitch) (modelo ONNX) | notas de Cordas e baixo | Apache-2.0 |
| [librosa](https://librosa.org) | reserva das batidas | ISC |
| [ADTOF](https://github.com/MZehren/ADTOF), Zehren, Alunno e Bientinesi (ISMIR 2021; *Signals* 2023) | pesos da transcrição de bateria | CC BY-NC-SA 4.0 |
| [ADTOF-pytorch](https://github.com/xavriley/ADTOF-pytorch) | conversão dos pesos do ADTOF para PyTorch | pesos derivados do ADTOF (CC BY-NC-SA 4.0) |

A rede do ADTOF em `pbq/models/adtof.py` é implementação própria; só os pesos vêm de fora.
