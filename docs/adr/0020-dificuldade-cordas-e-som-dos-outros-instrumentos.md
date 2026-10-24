# 0020. Cordas e baixo menos densos no Difícil e no Muito difícil; os outros instrumentos continuam tocando

- **Status:** Aceita
- **Data:** 2026-10-23

## Contexto

Jogando Free Bird: o Difícil de Cordas parecia o Muito difícil (colcheias e tercinas de tudo
que o modelo transcreve), e ao tocar o baixo sumiam a guitarra e a bateria, porque o
`song.ogg` só leva o que não é instrumento presente (ADR 0012).

## Decisão

**Cordas e baixo** (a bateria não mudou; `pbq/charts/difficulty.py`, ajusta a tabela do ADR 0012):
- Muito difícil: colcheias e tercinas, ou seja, o que era o Difícil. Cai só a semicolcheia, que
  o transcritor costuma inventar. Acordes até 3.
- Difícil: só colcheias (sem tercinas), entre o Médio e o Muito difícil. Acordes até 2.
- Médio e Fácil: iguais.
- A `version` da etapa `chart` subiu para 3, então o worker refaz os charts (sem rodar o modelo).

**Som:** o jogo carrega o `song.ogg` e o áudio de **todos** os instrumentos presentes. O
instrumento de quem joga continua abaixando no erro (ADR 0014); os que ninguém toca ficam
3 dB abaixo (`OTHERS_DB` em `godot/game/play.gd`) para destacar o do jogador.

## Consequências

- A velocidade de rolagem da pista é a mesma em todas as dificuldades; o que muda é a densidade.
- Os 3 dB dos outros instrumentos são palpite: ajustar jogando.
