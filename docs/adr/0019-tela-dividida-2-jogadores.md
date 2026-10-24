# 0019. Tela dividida para 2 jogadores

- **Status:** Aceita
- **Data:** 2026-10-23

## Contexto

Com uma câmera só, as duas pistas lado a lado ([ADR 0017](0017-modos-banda-e-duelo.md))
convergem para o centro da tela: o ponto de fuga do jogador 1 fica à direita da pista dele e o
do jogador 2, à esquerda. As notas chegam tortas, de dentro para fora, e fica difícil ler a pista.

## Decisão

- Com 2 jogadores, a tela se divide ao meio (P1 à esquerda, P2 à direita). Cada metade é uma
  `SubViewport` com a sua câmera, centrada na própria pista; as duas veem o mesmo mundo 3D.
- As pistas ficam longe uma da outra no mundo (`HIGHWAY_2P_OFFSET` em `godot/game/play.gd`),
  para a câmera de um não enxergar a pista do outro, sem precisar de camadas de visibilidade.
- O fundo no ritmo continua numa `CanvasLayer` atrás e aparece pelo fundo transparente das
  metades (a câmera de cada metade usa um `Environment` com fundo transparente, porque o
  "Canvas" de uma `SubViewport` é o canvas vazio dela). O HUD fica por cima, na tela inteira.
- No solo nada muda: uma câmera, na tela inteira.

## Consequências

- Cada jogador vê a sua pista de frente, como no solo.
- A cena 3D é desenhada duas vezes por quadro. Se o Deck perder quadros com 2 jogadores, rever
  (por exemplo, metades com resolução menor).
- Cada metade é mais estreita que a tela, por isso a câmera de 2 jogadores fica mais alta e mais
  longe (`CAM_2P_POS`).
