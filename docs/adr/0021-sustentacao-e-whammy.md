# 0021. Nota sustentada que pontua, whammy nos analógicos e o instrumento do jogador num player próprio

- **Status:** Aceita
- **Data:** 2026-10-24

## Contexto

Até aqui a nota sustentada era só desenho: o ataque contava e a cauda sumia junto com a nota
(ADR 0014: "a sustentação ainda não pontua"). No gênero, segurar os trastes até o fim da cauda
rende pontos, e a alavanca (whammy) faz a cauda tremer e o instrumento desafinar. O controle do
Steam Deck não tem alavanca, mas tem dois analógicos livres na maior parte do tempo.

O som era o obstáculo: todos os stems tocam num `AudioStreamSynchronized`, e efeito de áudio só
existe por bus, o que mudaria a música inteira.

## Decisão

**Sustentação** (`godot/core/play_session.gd`, `godot/core/scoring.gd`):
- Depois do ataque, a nota fica "segurada" enquanto os trastes baterem com ela (as mesmas regras
  do ataque: acorde exato, nota simples pelo traste mais agudo). Pontua 25 por batida segurada
  (`SUSTAIN_POINTS_PER_BEAT`), vezes o multiplicador, contada do tempo da nota.
- Soltar antes do fim não é erro nem quebra a sequência: só para de somar, e o resto da cauda
  apaga na pista. Apertar de novo não volta a segurar.
- Na pista (`godot/game/highway.gd`), a nota segurada some e a cauda vira uma fita acesa que vai
  sendo consumida na linha de acerto.

**Whammy** (`godot/core/whammy.gd`):
- Qualquer um dos dois analógicos do controle do jogador (no Deck o polegar direito também toca
  o X; o esquerdo fica livre sem palhetada, ADR 0015); no teclado, `Shift` (P1) e `6` do teclado
  numérico (P2). Zona morta de 20%, suavizado.
- Só vale segurando uma sustentada: +50% nos pontos da sustentação no máximo (`WHAMMY_BONUS`),
  a fita ondula proporcional ao curso, e o instrumento do jogador desce até um tom.

**Som** (`godot/game/play.gd`, `godot/default_bus_layout.tres`):
- O instrumento de cada jogador sai do `AudioStreamSynchronized` para um `AudioStreamPlayer`
  próprio, nos buses `Player1`/`Player2`, cada um com um `AudioEffectPitchShift` (ligado só
  enquanto o whammy dobra o som, porque ele colore um pouco até em 1,0). Os buses mandam para o
  `Music`, então o fundo continua reagindo ao instrumento.
- O fundo e os outros instrumentos continuam sincronizados entre si. Com os 2 jogadores no mesmo
  instrumento, um player só, com o maior volume e o maior whammy dos dois.

## Consequências

- Os players dão `play()` no mesmo quadro: entram no mesmo bloco do mixer e, com a mesma taxa de
  amostragem, não se separam. Conferido gravando a partida (Movie Maker): o pico do instrumento
  desceu de 440 para ~400 Hz com o whammy e o resto não mudou. Se o stem algum dia escorregar
  (procurar posição, recomeçar no meio), é aqui que se olha primeiro.
- Pausar solta os trastes (ADR 0014), então pausar no meio de uma sustentada a perde.
- 25 pontos por batida, +50% e um tom são palpites do gênero: ajustar jogando.
- A bateria não tem sustentação, então nada disto muda nela.
