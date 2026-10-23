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

## Pipeline

Etapas implementadas (gerado de `pbq/stages/__init__.py`):

<!-- gen:stages -->
| # | Etapa | Versão | Requer | Obrigatória | O que faz |
|---|---|---|---|---|---|
| 1 | `ingest` | 1 | — | sim | metadados (artista, música, duração) e capa |
| 2 | `separate` | 1 | `ingest` | sim | stems por instrumento (Demucs htdemucs_6s) |
| 3 | `presence` | 2 | `separate` | sim | quais instrumentos tocam (energia e ataques); ausentes ficam bloqueados |
| 4 | `beats` | 1 | `ingest` | sim | batidas, tempos fortes e energia por batida (beat_this) |
| 5 | `drums_chart` | 1 | `separate`, `beats`, `presence` | sim | chart de bateria Muito difícil (ADTOF), na grade de batidas |
| 6 | `chart` | 1 | `beats`, `drums_chart` | sim | notes.chart (Clone Hero): mapa de tempo, compassos e trilhas |
<!-- /gen:stages -->

Planejadas (fase 5):

| Etapa | Saída | Ferramenta (ver [ADR 0006](adr/0006-modelos-de-ia.md)) |
|---|---|---|
| `pitched_chart` | notas de Cordas e baixo (Muito difícil) | transcrição de altura |
| `difficulty` | Fácil, Médio e Difícil, por redução | regras puras |
| `package` | `data/library/<id>/` | ffmpeg |

O núcleo dos charts (`pbq/charts/`) não depende de modelos: mapa de tempo a partir das batidas
(`pbq/charts/tempo.py`), encaixe na grade (`pbq/charts/quantize.py`), lanes da bateria
(`pbq/charts/drums.py`) e o formato `.chart` (`pbq/charts/chart_file.py`).
Batidas e bateria: [ADR 0011](adr/0011-batidas-e-bateria.md).
Medidas e limiares das etapas de áudio: [ADR 0009](adr/0009-separacao-violao-e-presenca-medidos.md).
Os modelos ficam atrás das interfaces de `pbq/models/__init__.py`; o adaptador real
(`pbq/models/demucs.py`) importa torch só ao ser construído. Instrumentos jogáveis: bateria,
baixo e Cordas (violão + guitarra, [ADR 0010](adr/0010-cordas-um-instrumento.md)).

O formato de saída é compatível com o Clone Hero ([ADR 0007](adr/0007-formato-de-chart.md)).

## Godot

- `godot/core/`: lógica pura (`RefCounted`). Inclui o parser de chart, o mapa de tempo, o
  relógio da música, o julgamento de acertos, a pontuação, as regras de seleção de
  instrumento e os perfis de entrada. Tudo testado com GdUnit4.
- godot/game (a partir da fase 6): cenas e nós (pista 3D, notas, fundo, menus). Só desenham e encaminham entrada
  para o `core`.
