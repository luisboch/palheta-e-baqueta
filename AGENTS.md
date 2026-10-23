# AGENTS.md — regras para quem mexe no Palheta & Baqueta (agentes e pessoas)

Jogo de ritmo para até 2 jogadores (Cordas, baixo e bateria) em **Godot 4**, alimentado por um backend
**Python** que transforma MP3s em músicas jogáveis: stems separados por IA, charts em 4
dificuldades e mapa de batidas. O alvo é o **Steam Deck no modo jogo**.

Este arquivo tem só **regras e ponteiros**. Os fatos ficam em `docs/`, cada um num lugar só.

## Mapa da documentação

| Pergunta | Onde |
|---|---|
| Como instalar, rodar, testar | [README.md](README.md) |
| Como as peças se encaixam (processos, arquivos, fluxo) | [docs/architecture.md](docs/architecture.md) |
| Arquivos e mensagens entre backend e jogo | [docs/backend-protocol.md](docs/backend-protocol.md) |
| O que a biblioteca contém (contrato versionado) | [docs/library-format.md](docs/library-format.md) |
| Por que foi decidido assim | [docs/adr/](docs/adr/README.md): um ADR por decisão |
| O que já foi feito e o que vem | [docs/roadmap.md](docs/roadmap.md) |
| Testes, cobertura, fixtures | [docs/testing.md](docs/testing.md) |
| O que já custou tempo e vai custar de novo | [docs/pitfalls.md](docs/pitfalls.md) |
| Cada ajuste e o motivo do valor | `config.example.toml` (comentado) |

## Documentação viva

A doc é parte do código: uma mudança só está pronta quando a doc correspondente também está.
As regras de [ADR 0001](docs/adr/0001-documentacao-viva-verificada.md):

1. **Mesmo commit.** Mudou comportamento, contrato, comando ou decisão? Atualize o documento do
   mapa acima no mesmo commit. Doc desatualizada se corrige, não se contorna.
2. **Fato derivável do código não se copia à mão.** Ele vira trecho gerado
   (`<!-- gen:nome -->`, produzido por `tools/docs_check.py`) ou é conferido pelo check.
   Se você está prestes a copiar uma lista do código para a doc, escreva um gerador.
3. **Decisão com trade-off = ADR novo** (um arquivo `NNNN-titulo.md` em `docs/adr/`, modelo em
   [docs/adr/README.md](docs/adr/README.md)). ADR aceito não se reescreve: mudou de ideia,
   escreva outro e marque o antigo como "Substituída por". Experimento pendente é "Proposta".
4. **Armadilha descoberta** (algo que custou tempo) vira uma linha em `docs/pitfalls.md`, com
   data e porquê. Não espalhe armadilhas pelo AGENTS.md (no kraoke, isso o fez crescer sem
   parar).
5. **Fim de fase**: atualizar `docs/roadmap.md` (status, cobertura medida, próximo passo).
6. **O check roda sempre**: `uv run python -m tools.docs_check` no pre-commit, na CI e como
   teste do pytest. Ele confere links, caminhos citados, trechos gerados e o formato dos ADRs.
   `--fix` regenera os trechos gerados.
7. Se uma tarefa pedir algo que contradiga um ADR ou uma regra daqui, **pergunte antes**.

## Linha arquitetural (detalhes em docs/architecture.md)

- **Dois mundos que só conversam por arquivos** ([ADR 0002](docs/adr/0002-backend-python-godot-por-arquivos.md)):
  o backend escreve `data/library/` (contrato versionado) e `data/events.jsonl`; o Godot lê.
  O Godot chama o CLI `pbq` para ações pontuais (pendrive) e lê JSON do stdout. Nada de socket.
- **Pipeline de etapas retomável**, como no kraoke: uma etapa por arquivo, estado em
  `data/work/<id>/song.json`, escrita atômica (`.tmp.` + `replace`), `<id>` = hash do MP3 (é o
  cache: renomear não reprocessa).
- **Modelos de IA atrás de interfaces** (`Protocol`), importados só dentro de `run()`. Testes
  usam fakes; o modelo real só nos testes `slow`.
- **Godot: lógica pura em `godot/core/`** (`RefCounted`, sem nós), testada com GdUnit4. Nós e
  cenas (godot/game, a partir da fase 6) só desenham e encaminham entrada.
- **Pendrive só pelo menu** ([ADR 0003](docs/adr/0003-pendrive-pelo-menu.md)): conectar não faz nada.
- **Nada de música no git**: MP3s, stems e charts gerados ficam em `data/`. Fixtures de áudio
  são sintéticas, geradas por script.
- **Identidade própria**: nada de nome, logo ou arte de Guitar Hero/Rock Band.

## Convenções

- **Idioma**: identificadores em inglês; comentários, docstrings, logs, UI, docs e commits em português.
- **Comentários** explicam o *porquê*. Docstring de etapa: Entrada / Saída / Config.
- **Commits**: Conventional Commits (`feat:`, `fix:`, `test:`, `docs:`, `chore:`, `ci:`,
  `refactor:`), curtos, em português, pequenos e frequentes. Teste junto com a funcionalidade.
- **Dependências**: `uv` com versões fixadas no `uv.lock`; extras por etapa (a CI rápida não
  instala torch). Ferramentas fora do uv (Godot, GdUnit4) fixadas em `scripts/versions.env`.
- **Sem constantes mágicas**: ajustável vai para `config.example.toml` com o motivo; o resto vira
  constante nomeada e comentada no topo do módulo.
- **Ferramentas externas** (ffmpeg) via `subprocess` com erro legível; nunca `shell=True`.

## Verificação

```bash
scripts/test.sh                        # Python (cobertura ≥ 80%) + GDScript
uv run pre-commit run --all-files      # ruff, mypy, gdformat, gdlint, documentação viva
```

- **Nunca** rodar worker ou testes contra a `data/` real: use um diretório temporário.
