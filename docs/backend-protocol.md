# Protocolo backend ↔ jogo

Os dois lados só trocam arquivos e linhas JSON ([ADR 0002](adr/0002-backend-python-godot-por-arquivos.md)).
As tabelas abaixo são geradas do código, e o jogo valida tudo contra
`godot/core/backend_protocol.gd`, gerado das mesmas fontes ([ADR 0008](adr/0008-contrato-gerado-do-python.md)).

## Arquivos em data/

| Arquivo | Quem escreve | Quem lê | Para quê |
|---|---|---|---|
| `library/` | backend | jogo | músicas prontas ([formato](library-format.md)) |
| `events.jsonl` | worker | jogo (`godot/core/event_reader.gd`) | notificações; o jogo lê a partir do fim |
| `queue.json` | worker | jogo | retrato da fila: `pending` [{id, label}], `current` {id, label, stage, fraction} ou `null` |
| `.worker.lock` | worker | jogo | PID do worker (SIGSTOP/SIGCONT durante a partida) |
| `work/` | backend | backend | estado por música e caches de hash (`.scan-cache.json`, `.drive-cache.json`) |

## Eventos (data/events.jsonl)

Uma linha por evento, sempre com `type` e `at` (ISO 8601, UTC), mais os campos:

<!-- gen:events -->
| Tipo | Campos | Quando |
|---|---|---|
| `queued` | `id`, `label` | música nova encontrada em data/input |
| `progress` | `id`, `label`, `stage`, `fraction` | andamento da música em processamento (no máximo ~1 por segundo) |
| `ready` | `id`, `label` | música pronta na biblioteca |
| `failed` | `id`, `label`, `stage`, `error` | etapa obrigatória falhou |
| `queue` | `pending` | músicas na fila, contando a atual |
<!-- /gen:events -->

## Comandos

<!-- gen:cli -->
| Comando | O que faz |
|---|---|
| `pbq version` | versão do backend (JSON; o jogo confere a compatibilidade) |
| `pbq watch [--die-with-parent]` | worker: processa em segundo plano o que chega em data/input |
| `pbq process [--song SONG] [--force]` | processa agora as músicas pendentes (terminal) |
| `pbq status` | estado de cada música (terminal) |
| `pbq drive list` | pendrives montados |
| `pbq drive process [--mount MOUNT]` | copia os MP3s novos de palheta/ para data/input |
| `pbq drive import [--mount MOUNT]` | traz as músicas prontas de palheta/library/ |
| `pbq drive export [--mount MOUNT]` | salva a biblioteca em palheta/library/ (incremental) |
| `pbq edit [--title TITLE] [--artist ARTIST]` | corrige título e artista de uma música pronta (JSON-lines) |
<!-- /gen:cli -->

O jogo inicia o worker com `pbq watch --die-with-parent`: o worker morre junto se o jogo
morrer, mesmo por SIGKILL ou congelado.

## Mensagens dos comandos (stdout, JSON-lines)

Os comandos chamados pelo jogo (`version`, `drive …`) escrevem só estas linhas no stdout;
logs vão para o stderr. Código de saída diferente de 0 vem sempre com uma linha `error`.

<!-- gen:messages -->
| Tipo | Campos | Quando |
|---|---|---|
| `version` | `name`, `version`, `config` | resposta de `pbq version` |
| `drives` | `drives` | pendrives montados: [{path, name, has_folder}] |
| `progress` | `phase`, `done`, `total`, `fraction` | andamento; phase = reading (lendo/analisando) ou copying |
| `done` | `count`, `errors` | fim com sucesso: quantas músicas, erros por arquivo |
| `error` | `message` | falhou (sem espaço, pendrive removido...); saída ≠ 0 |
<!-- /gen:messages -->

Exemplo, `pbq drive process --mount /run/media/deck/PEN`:

```
{"type": "progress", "phase": "reading", "done": 1, "total": 12, "fraction": 0.083}
…
{"type": "progress", "phase": "copying", "done": 3, "total": 3, "fraction": 1.0}
{"type": "done", "count": 3, "errors": []}
```

- `pbq edit <id> --title … --artist …` responde `done` (`count` 1) ou `error`. Reescreve o nome em
  `song.json`, `notes.chart`, `song.ini` e `index.json`, e guarda a correção no estado da música
  (`meta["edited"]`), que o `ingest` respeita se a música for reprocessada.
- `reading`: `done`/`total` contam MP3s lidos (hash); `copying`: músicas copiadas, e a fração
  conta bytes.
- No máximo uma linha de progresso a cada 0,2 s, mais a última.
- O cache de hash dos MP3s do pendrive fica em disco (cada comando é um processo novo; no
  kraoke ficava na memória do app), por (caminho, tamanho, mtime).
- Números chegam ao jogo como `float` (é o JSON do Godot): use `int()` nos campos de contagem.
