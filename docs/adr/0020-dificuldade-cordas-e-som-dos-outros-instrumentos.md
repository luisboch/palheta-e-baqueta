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

## Nota (2026-10-23): a bateria entra na mesma escala

Jogando bateria, o Difícil e o Muito difícil também pesavam: o Muito difícil era "tudo" e o
Difícil quase igual a ele (≈ 97% dos ataques). A bateria passou a seguir a regra das Cordas:
Muito difícil = colcheias e tercinas; Difícil = só colcheias, com chimbal e pratos só nas
batidas. `version` da etapa `chart` foi para 4. No controle, a bateria usa os botões das
Cordas (os 4 pads em L2 L1 R1 R2, o bumbo em X), e os pads antigos (B Y X A, LB) saíram.

## Nota (2026-10-23): escala por parcela, igual para todos os instrumentos

As regras por grade (só colcheias etc.) davam densidades diferentes por música e instrumento.
Agora há uma **referência** (100%): colcheias e tercinas da transcrição, que é o que o Muito
difícil era. Nenhum nível usa a referência inteira: **Muito difícil = 80%**, **Difícil = 70%**
(`EXPERT_SHARE` e `HARD_SHARE` em `pbq/charts/difficulty.py`). Sai primeiro o ataque de pulso
mais fraco (tercina, depois contratempo) e, no último pulso a caber, um subconjunto espaçado
por igual. O Difícil é sempre um subconjunto do Muito difícil. Em ataques/min, médias de 6 a 7
músicas, referência → Muito difícil → Difícil: Cordas 182 → 145 → 127, baixo 115 → 92 → 80,
bateria 174 → 139 → 122. Fácil e Médio seguem as regras de grade; Médio e Difícil do baixo e
Fácil e Médio da bateria ficaram próximos (71 × 80; 92 × 103).
`version` da etapa `chart` foi para 5.
