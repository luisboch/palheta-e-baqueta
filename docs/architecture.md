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
| 4 | `beats` | 2 | `ingest` | sim | batidas, tempos fortes e energia por batida (beat_this; reserva: librosa) |
| 5 | `drums_chart` | 1 | `separate`, `beats`, `presence` | sim | chart de bateria Muito difícil (ADTOF), na grade de batidas |
| 6 | `pitched_chart` | 2 | `separate`, `beats`, `presence` | sim | Cordas e baixo Muito difícil (basic-pitch), na grade de batidas |
| 7 | `chart` | 6 | `beats`, `drums_chart`, `pitched_chart` | sim | notes.chart (Clone Hero): mapa de tempo, compassos e as 4 dificuldades |
| 8 | `package` | 1 | `presence`, `chart` | sim | pasta da música na biblioteca (stems em OGG, chart, mapa de batidas, song.json) |
<!-- /gen:stages -->

O núcleo dos charts (`pbq/charts/`) não depende de modelos: mapa de tempo a partir das batidas
(`pbq/charts/tempo.py`), encaixe na grade (`pbq/charts/quantize.py`), lanes da bateria
(`pbq/charts/drums.py`), contorno de Cordas e baixo (`pbq/charts/pitched.py`), as 4 dificuldades
(`pbq/charts/difficulty.py`) e o formato `.chart` (`pbq/charts/chart_file.py`).
Batidas e bateria: [ADR 0011](adr/0011-batidas-e-bateria.md). Cordas, baixo e dificuldades:
[ADR 0012](adr/0012-charts-de-cordas-baixo-e-dificuldades.md).
Medidas e limiares das etapas de áudio: [ADR 0009](adr/0009-separacao-violao-e-presenca-medidos.md).
Os modelos ficam atrás das interfaces de `pbq/models/__init__.py`; o adaptador real
(`pbq/models/demucs.py`) importa torch só ao ser construído. Instrumentos jogáveis: bateria,
baixo e Cordas (violão + guitarra, [ADR 0010](adr/0010-cordas-um-instrumento.md)).

O formato de saída é compatível com o Clone Hero ([ADR 0007](adr/0007-formato-de-chart.md)).

## Godot

- `godot/core/`: lógica pura (`RefCounted`). Inclui o parser de chart, o mapa de tempo, o
  relógio da música, o julgamento de acertos, a pontuação, o placar de 2 jogadores
  (`godot/core/match_result.gd`), as regras de seleção de instrumento e os perfis de entrada. Tudo testado com GdUnit4.
- **Telas** (`godot/game/`, uma cena por tela, montada com nós no editor; regras em
  [ADR 0016](adr/0016-menus-e-navegacao.md)): menu principal (`godot/game/main_menu.tscn`), modo de 2
  jogadores (`godot/game/mode_select.tscn`), escolha de música (`godot/game/song_select.tscn`),
  instrumento e dificuldade de cada jogador, com o "PRONTO" (`godot/game/instrument_select.tscn`),
  Gerenciar músicas (`godot/game/manage.tscn`: o painel do pendrive, `godot/game/drive.tscn`, e a
  biblioteca com "Editar nome") e a partida. A ordem das telas e o "voltar" ficam em lógica
  pura (`godot/core/menu_flow.gd`), assim como o cursor de cada jogador
  (`godot/core/player_pick.gd`) e a cor das luzes do palco tirada da capa
  (`godot/core/cover_color.gd`). O visual
  dos menus vem de um tema só, de quadrinho (`godot/game/theme.tres`, fonte Bangers). Linhas de
  lista (músicas, pendrives) são cópias de um botão-modelo que está na cena.
- **A casca dos menus** (`godot/game/shell.tscn` + `godot/game/shell.gd`, a cena principal;
  [ADR 0022](adr/0022-menus-3d-em-quadrinho.md)): um cenário 3D de cidade de quadrinho com uma
  estação por tela (`godot/game/comic/station.gd`: onde a câmera para e as cores do céu). As
  telas abrem por cima dela; trocar de tela voa com a câmera em vez de trocar de cena. O visual
  de quadrinho vem de shaders em `godot/game/comic/`: sombra em faixas com retícula nos modelos
  (`toon.gdshader`, aplicado por `godot/game/comic/comic.gd`), contorno de tinta num passe só
  (`ink.gdshader`) e o céu de explosão (`comic_sky.gdshader`). O foco dos botões é desenhado por
  `godot/game/comic/focus_fx.gd`. Estações com comportamento: o modo
  (`godot/game/comic/mode_station.gd`), o palco com a capa no telão e os refletores
  (`godot/game/comic/stage_station.gd`, `godot/game/comic/lamp.tscn`) e os instrumentos com a luz
  na cor de cada jogador (`godot/game/comic/instrument_station.gd`).
- **Modelos 3D** (`godot/game/models/*.glb`): exportados por `art/build_models.py`, rodado no
  Blender por `scripts/build_models.sh` ([ADR 0023](adr/0023-modelos-3d-por-script-no-blender.md)).
- **Autoload `App`** (`godot/game/app.gd`): caminhos de `data/` (na raiz do repositório, ou em
  `$PALHETA_HOME` no jogo instalado pelo `.deb`, [ADR 0018](adr/0018-pacote-deb.md)), a escolha do jogador, a troca de
  tela (pela casca, ou carregando a casca já na tela pedida quando vem da partida), o worker (iniciado pelo menu, pausado durante a partida) e os comandos `pbq`, rodados
  por `godot/game/backend_job.gd` numa thread. Nos testes ele fica inerte: sem worker, sem
  comandos e sem trocar de cena.
- **A partida** (`godot/game/play.tscn` + `godot/game/play.gd`). A parte
  fixa (câmera, luz, pista, lanes, linha de acerto, alvos, placar) são nós da cena, editáveis no editor;
  só as notas nascem em tempo de jogo. Pista 3D
  (`godot/game/highway.gd`), placar (`godot/game/hud.gd`), áudio sincronizado e entrada. Só desenham e
  encaminham entrada para o `core` (`godot/core/play_session.gd` junta juiz, pontuação e relógio).
  Regras de jogo: [ADR 0014](adr/0014-regras-de-jogo.md). Visual de quadrinho
  ([ADR 0022](adr/0022-menus-3d-em-quadrinho.md)): atrás de cada pista, o palco dos menus com a capa no
  telão (`godot/game/comic/stage_backdrop.gd`), que segue as batidas; um anel em cada alvo
  (`godot/game/comic/target_ring.tscn`), bordas que acendem com o multiplicador, o medidor de
  energia no placar (`godot/game/comic/power_meter.gd`) e o contorno só de silhuetas. Com 2 jogadores, a tela se divide ao meio,
  cada metade com a sua pista (a segunda é cópia da primeira) e a sua câmera
  ([ADR 0019](adr/0019-tela-dividida-2-jogadores.md)), e o placar da Banda ou do Duelo
  ([ADR 0017](adr/0017-modos-banda-e-duelo.md)).
- **Fundo no ritmo** (`godot/game/background.gd` + `godot/game/background.gdshader`): uma
  `CanvasLayer` atrás da pista (o `Environment` usa o fundo "Canvas"). Recebe as batidas do
  `beatmap.json` (`godot/core/beat_grid.gd`: pulso, fase da batida, compasso) e os níveis de
  graves, médios e agudos (`godot/core/spectrum_bands.gd`), lidos de um
  `AudioEffectSpectrumAnalyzer` no bus `Music` (`godot/default_bus_layout.tres`). Cada faixa é
  medida contra o próprio pico recente, porque o volume muda muito entre músicas. As mesmas
  batidas desenham linhas na pista (compasso mais forte) e fazem a linha de acerto pulsar.
