# 0024. Cada aperto de traste é julgado sozinho, lido do dispositivo a cada quadro

- **Status:** Aceita
- **Data:** 2026-10-27

## Contexto

O [ADR 0015](0015-tocar-no-traste-sem-palhetada.md) fez a nota tocar ao apertar o traste, mas
manteve a regra da palhetada: a nota simples valia pelo traste mais agudo apertado. No Steam Deck,
com L2 e R2 nos trastes, o dedo ainda no R2 quando o L1 era apertado fazia o L1 não acertar. O
anel do R2 ficava aceso e o toque no vermelho sumia, o que parecia um botão preso. O
`data/game.log` mostrou o controle mandando todos os "soltou": o jogo estava certo pela regra,
e a regra é que não servia para o controle. Antes disso, tentamos consertar um "soltar perdido"
que não existia, com leitura por eventos mais três remendos (sincronizar com o `Input`, ignorar
o repetido do gatilho, reler o dispositivo).

## Decisão

- **Cada aperto é julgado sozinho** (`Judge.press`): se a lane tem uma nota pendente na janela,
  acerta, não importa o que mais esteja apertado. Acorde: todos os trastes dele apertados; o
  traste de um acorde ainda incompleto não faz nada (montar o acorde passa por um traste de cada
  vez).
- **Aperto sem nota é erro** (overstrum: quebra a sequência), mesmo sozinho. Reverte a escolha do
  ADR 0015 de não punir; a bateria continua sem punir a batida a mais.
- **A sustentada continua enquanto todos os trastes dela estão apertados** (`Judge.holds`);
  apertar outros trastes não a solta.
- **O estado vem do dispositivo, não dos eventos.** `InputReader` lê teclado e controle a cada
  quadro, com o controle de cada ligação (o 2 não toca no jogador 1), e `FretPad` compara com o
  quadro anterior: só a descida conta (o gatilho analógico repete "apertado" e não precisa de
  filtro), e um botão não fica preso. Pausa e retomada usam `FretPad.reset`, que assume o estado
  sem contar aperto.
- A palhetada (guitarra USB, fase 8) segue com a regra do ADR 0014 (`Judge.strum`).

## Consequências

- Segurar um traste não atrapalha a próxima nota, e a nota do traste já apertado de antes toca
  ao apertar o outro.
- Apertar à frente da hora, ou "ensaiar" o dedo, passa a custar a sequência. Se isso irritar, a
  saída é punir só quando há outra nota na janela.
- Sai o código dos remendos (`sync_frets`, `_drum_down`, soltar perdido, filtro de controle por
  evento). O julgamento é por quadro: a precisão do instante é a de um quadro (16 ms a 60 FPS),
  a mesma que os eventos já tinham.
