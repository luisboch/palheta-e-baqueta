# 0014. Regras de jogo: janela de acerto, palhetada, pontuação e stem

- **Status:** Aceita
- **Data:** 2026-10-22

## Contexto

A fase 6 pôs a partida de pé (`godot/core/judge.gd`, `godot/core/scoring.gd`,
`godot/core/stem_mix.gd`, `godot/core/song_clock.gd`). Cada regra abaixo é um número ou um
comportamento que muda a sensação do jogo e que vai ser ajustado jogando.

## Decisão

- **Janelas** (± em volta da nota): Perfeito 45 ms, Bom 90 ms, Ok 135 ms. Fora disso, não acertou.
- **Cordas e baixo:** a nota é tocada na palhetada (para cima ou para baixo).
  - Nota simples: vale o traste mais agudo pressionado. Segurar os de baixo é permitido
    ("ancoragem", como no gênero).
  - Acorde: os trastes têm de ser exatamente os do acorde.
  - Palhetada sem nota que bata (sem nota, ou trastes errados) é *overstrum*: zera a sequência e
    abaixa o stem, mas a nota continua lá até sair da janela.
  - Sem hammer-on/pull-off por enquanto: toda nota pede palhetada.
- **Bateria:** cada peça é julgada sozinha. Batida a mais não pune, porque bateristas enfeitam.
- **Pontuação:** 100, 75 ou 50 pontos por Perfeito, Bom ou Ok, vezes o multiplicador. O
  multiplicador começa em 1× e sobe 1 a cada 10 acertos seguidos, até 4×. Erro ou overstrum zera.
  A sustentação ainda não pontua.
- **Stem do jogador:** abaixa para -18 dB a 60 dB/s no erro e volta no acerto. Os stems tocam
  juntos num `AudioStreamSynchronized`: o fundo (`song.ogg`) mais o do instrumento escolhido.
- **Relógio:** posição de reprodução + `AudioServer.get_time_since_last_mix()` −
  `get_output_latency()` − calibração. Suavizado (corrige 10% do desvio por quadro) e nunca volta
  para trás. Desvio acima de 100 ms é salto de verdade e é aplicado na hora.
- **Contagem de 2 s** antes do áudio, para ver as primeiras notas chegando.
- **Identidade própria:** a paleta das lanes é turquesa, coral, âmbar, azul e violeta, não a de
  outros jogos do gênero.

## Consequências

- Tudo isso está em classes puras com testes. Mudar um número é uma linha e um teste.
- Ainda não foi jogado por uma pessoa: as janelas e o multiplicador podem precisar de ajuste. A
  calibração de atraso (fase 8) é o que torna as janelas justas com fone Bluetooth ou TV.
