# 0025. Apertos também pelos eventos; o estado do dispositivo continua dizendo o que está apertado

- **Status:** Aceita
- **Data:** 2026-10-31

## Contexto

O [ADR 0024](0024-cada-aperto-e-julgado-sozinho.md) passou a ler só o estado do dispositivo a cada
quadro: o aperto era o que desceu desde o quadro anterior. No `data/game.log` de 2026-10-30 o
gamescope fixou o jogo em 30 FPS (ciclo de 33 ms). Um toque rápido no L1 ou no R1 cabe nesse
intervalo: aperta e solta entre dois quadros, o estado lido diz "solto" nas duas leituras e o
aperto some. O jogador vê "apertei e não contou". Soltar e apertar de novo dentro do mesmo quadro
também sumia.

## Decisão

- **O aperto vem de duas fontes, somadas:** o que desceu desde o quadro anterior (estado) e os
  eventos de aperto do quadro, guardados em `_input` da partida (`InputReader.pressed_by`, com o
  device de cada ligação, e o gatilho contando só quando cruza a metade do curso descendo).
- **O que está apertado continua vindo só do estado** (`FretPad.held`): um "soltou" perdido não
  prende botão, como no ADR 0024.
- O toque que já soltou conta como apertado para o juiz naquele quadro (`PlaySession.fret_input`)
  e não deixa o anel aceso.

## Consequências

- Nenhum toque se perde, a qualquer FPS. O instante do julgamento continua sendo o do quadro.
- Duas fontes para o mesmo aperto: o FretPad junta sem repetir (o evento e a descida do mesmo
  aperto contam uma vez).
- Se o próprio dispositivo atrasar o evento (o aperto só chega junto com o do botão seguinte),
  nada aqui resolve: aí a causa está antes do jogo (controle, driver ou Steam Input).
