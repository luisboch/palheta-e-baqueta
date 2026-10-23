# 0008. Contrato backend ↔ jogo gerado a partir do Python

- **Status:** Aceita
- **Data:** 2026-10-22

## Contexto

Eventos do worker e mensagens do CLI têm tipos e campos que os dois lados precisam conhecer.
Escritos à mão em Python e em GDScript, eles divergiriam sem ninguém perceber até um evento
sumir da tela.

## Decisão

- A fonte é o Python: `EVENT_TYPES` (`pbq/events.py`), `MESSAGE_TYPES` (`pbq/protocol.py`) e
  `FORMAT_VERSION` (`pbq/library.py`). `emit` e `write` recusam o que estiver fora deles.
- `godot/core/backend_protocol.gd` é **gerado** dessas constantes (`tools/generators.py`) e
  conferido pelo `tools/docs_check.py` como qualquer trecho gerado: desatualizado, o commit falha.
- O jogo valida cada linha contra ele e ignora o que não reconhece.
- As tabelas de `docs/backend-protocol.md` saem das mesmas constantes.

## Consequências

- Mudar um evento é mudar uma linha no Python e rodar `--fix`; documentação e GDScript seguem.
- O arquivo gerado é versionado (o Godot precisa dele sem rodar Python), e editá-lo à mão é inútil.
