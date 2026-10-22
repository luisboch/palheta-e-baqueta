# Arquitetura

O desenho geral, que vale para todas as fases. O porquê de cada escolha está nos
[ADRs](adr/README.md). O que já existe está no [roadmap](roadmap.md).

## Processos

```
                       ┌──────────────────── pbq watch (worker, nice 19) ────────────────────┐
     data/input ──────►│ scan ──► pipeline (etapas) ──► data/library/<id>/                    │
          ▲            └───────────────────────┬──────────────────────────────────────────────┘
          │                                    │ data/events.jsonl: queued, progress, ready, failed, queue
┌─────────┴────────────────────────────────────▼──────────────────────── jogo (Godot) ───────┐
│ lê data/library (index.json + song.json, stems, notes.chart, beatmap.json)                │
│ inicia o worker ao abrir; pausa (SIGSTOP) durante a partida; o worker morre junto          │
│ menu do pendrive → `pbq drive …` (subprocesso curto, progresso em JSON-lines no stdout)    │
│ ajustes do jogo (calibração, controles): data/settings.json                                │
└────────────────────────────────────────────────────────────────────────────────────────────┘
```

- **Worker** (`pbq watch`): como no kraoke. Procura MP3s estáveis em `data/input`, roda as
  etapas pendentes e emite eventos. Um lock (`flock` em `data/.worker.lock`) garante um worker só,
  e o PID gravado nele é o que o jogo usa para pausar e retomar.
- **Jogo**: nunca escreve na biblioteca. O que muda o estado do backend passa pelo CLI `pbq`
  (ex.: o pendrive), e o jogo só lê o que o CLI responde.
- **Pendrive** ([ADR 0003](adr/0003-pendrive-pelo-menu.md)): `<pendrive>/palheta/*.mp3` para
  processar e `<pendrive>/palheta/library/<id>/` para músicas prontas (salvar e importar).

## Pipeline (planejado)

| # | Etapa | Saída | Ferramenta (ver [ADR 0006](adr/0006-modelos-de-ia.md)) |
|---|---|---|---|
| 1 | `ingest` | metadados, capa | mutagen, ffmpeg |
| 2 | `separate` | stems: drums, bass, guitar, vocals, piano, other | Demucs `htdemucs_6s` |
| 3 | `guitar_split` | guitarra elétrica × violão, por trechos | classificador de timbre |
| 4 | `presence` | quais instrumentos tocam (os ausentes ficam bloqueados) | RMS, onsets |
| 5 | `beats` | batidas, compassos, mapa de tempo | beat tracker |
| 6 | `drums_chart` | notas de bateria (Muito difícil) | transcrição de bateria |
| 7 | `pitched_chart` | notas de guitarra, violão e baixo (Muito difícil) | transcrição de altura |
| 8 | `difficulty` | Fácil, Médio e Difícil, por redução | regras puras |
| 9 | `package` | `data/library/<id>/` | ffmpeg |

O formato de saída é compatível com o Clone Hero ([ADR 0007](adr/0007-formato-de-chart.md)).

## Godot

- `godot/core/`: lógica pura (`RefCounted`). Inclui o parser de chart, o mapa de tempo, o
  relógio da música, o julgamento de acertos, a pontuação, as regras de seleção de
  instrumento e os perfis de entrada. Tudo testado com GdUnit4.
- godot/game (a partir da fase 6): cenas e nós (pista 3D, notas, fundo, menus). Só desenham e encaminham entrada
  para o `core`.
