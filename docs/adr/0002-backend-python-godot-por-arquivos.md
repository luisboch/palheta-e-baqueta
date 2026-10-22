# 0002. Backend Python e jogo Godot conversando por arquivos

- **Status:** Aceita
- **Data:** 2026-10-22

## Contexto

A separação por IA e a transcrição pedem Python (torch, Demucs etc.) e levam minutos por
música. O jogo precisa de 3D, áudio com baixa latência e controles, e o Godot 4 dá isso com a
GPU do Deck (Vulkan). O kraoke já resolveu a convivência entre processamento pesado e interface
com dois processos que só trocam arquivos, e isso aguentou bem o uso real.

## Decisão

- **Backend** (`pbq`): pipeline de etapas retomável e worker, no mesmo modelo do kraoke (estado
  em `data/work/<id>/song.json`, escrita atômica, `<id>` = hash do MP3 como cache).
- **Contrato**: `data/library/` (versionado, documentado em docs/library-format.md a partir da
  fase 2) e `data/events.jsonl` (worker → jogo).
- **Ações pedidas pelo jogo** (pendrive, e no futuro excluir ou reprocessar) são comandos
  curtos do CLI `pbq`, que respondem em JSON (uma linha por evento de progresso) no stdout.
  O Godot usa `OS.execute_with_pipe`. A lógica do pendrive do kraoke (Python, já testada) é
  reaproveitada, em vez de ser reescrita em GDScript.
- O jogo inicia o worker e o pausa (SIGSTOP/SIGCONT) durante a partida. O worker morre junto
  com o jogo (`PR_SET_PDEATHSIG`).
- Sem socket, fila ou banco.

## Consequências

- Os dois lados são testáveis isoladamente: o backend com fakes, e o jogo com bibliotecas de
  teste em disco.
- Uma comunicação nova é um arquivo novo ou um comando novo do CLI, documentado.
- O jogo depende de achar o `pbq` (o `.venv` do projeto). O caminho vai para os ajustes do jogo.
