# 0017. Dois jogadores: Banda e Duelo

- **Status:** Aceita
- **Data:** 2026-10-23

## Contexto

A fase 8 pôs duas pistas lado a lado, cada uma com a própria `PlaySession` e o próprio
`Scoring`. Faltava decidir o que a tela mostra e quem ganha. As regras abaixo mudam a sensação
do jogo e vão ser ajustadas jogando; ficam em lógica pura (`godot/core/match_result.gd`).

## Decisão

- **Dois modos**, escolhidos ao começar a partida: **Banda** (`coop`, tocam juntos) e **Duelo**
  (`versus`, um contra o outro). Segundo instrumento sem modo vira Banda.
- **Pontuação individual igual à do solo** ([ADR 0014](0014-regras-de-jogo.md)): cada um com o
  próprio multiplicador. Assim o jogador não é punido pelo erro do outro e o placar continua
  comparável com o solo.
- **Banda**: placar único no centro de cima, com a soma dos pontos e o multiplicador da Banda,
  que é a média dos dois, arredondada para baixo (só chega a 4× com os dois em 4×). É só
  mostrado: não multiplica nada de novo.
- **Estrelas da Banda** (1 a 5) pela precisão somada (acertos ÷ notas tocadas pelos dois):
  2 estrelas a partir de 65%, 3 de 78%, 4 de 88%, 5 de 95%. Precisão, e não pontos, porque não
  depende do tamanho da música nem da dificuldade. O resultado mostra a parte dos pontos de cada um.
- **Duelo**: pontos de P1 e P2 lado a lado com quem está na frente; vence quem fizer mais pontos,
  pontos iguais é empate. Pontos (e não acertos) porque premiam a precisão e a sequência, e
  porque quem escolhe uma dificuldade maior tem mais notas para pontuar, o que é justo num duelo.
- **Sequência de cada um sobre a própria pista** (um `Label3D` da `Highway`, logo abaixo da linha
  de acerto), com o instrumento e a dificuldade, em vez de um placar por canto da tela.

## Consequências

- Mudar uma faixa de estrelas ou o critério de vitória é uma linha e um teste.
- No Duelo, dificuldades diferentes dão vantagem a quem escolheu a maior; se isso incomodar
  jogando, a saída é comparar pontos sobre o máximo possível de cada chart.
- Rever as faixas de estrelas depois de jogar com pessoas (ainda não foi jogado a dois no Deck).
