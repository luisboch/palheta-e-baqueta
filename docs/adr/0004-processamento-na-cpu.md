# 0004. Processamento na CPU; GPU só no jogo, por enquanto

- **Status:** Aceita
- **Data:** 2026-10-22

## Contexto

O jogo roda acelerado pela GPU de qualquer jeito: o Godot usa Vulkan (RADV) no Deck. Para a
importação (separação e transcrição), o kraoke investigou a GPU do Deck (AMD Van Gogh,
gfx1033) em set/2026:

- **ROCm**: sem suporte oficial à gfx1033. Com `HSA_OVERRIDE_GFX_VERSION=10.3.0`, o Demucs não
  terminou 60 s de áudio em 25 min (a CPU leva 30 s), e há relatos de resultados errados.
- **Vulkan**: o PyTorch não tem backend utilizável. O [audio.cpp](https://github.com/0xShug0/audio.cpp)
  (ggml, com Vulkan) tem HTDemucs, mas não foi testado.

## Decisão

- Todo o processamento roda na **CPU**, com `nice` 19 e threads limitadas. O jogo pausa o
  worker durante a partida.
- Cada modelo fica atrás de uma interface, com `device` na config (`cpu`, ou `cuda` num PC com
  NVIDIA). Trocar o motor de uma etapa, por exemplo para um CLI Vulkan, não mexe no resto.
- Não tentar ROCm de novo sem suporte oficial à gfx1033.

## Consequências

- São alguns minutos por música no Deck (a medir na fase 3). Quem tiver um PC com GPU processa
  lá e leva pela "Salvar/Importar biblioteca".
- Experimento em aberto: medir o audio.cpp (Vulkan) com `htdemucs_6s` no Deck. Se compensar,
  vira um ADR que substitui este para a etapa `separate`.
