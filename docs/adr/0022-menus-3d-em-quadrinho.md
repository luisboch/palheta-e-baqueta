# 0022. Menus num cenário 3D, com visual de quadrinho de herói

- **Status:** Aceita
- **Data:** 2026-10-24

## Contexto

Os menus da fase 9 ([ADR 0016](0016-menus-e-navegacao.md)) eram painéis escuros sobre o fundo
animado, e a escolha de música juntava tudo numa tela só: modo, instrumento e dificuldade dos
dois jogadores. O dono do projeto pediu um jogo com mais cara de jogo: explorar o 3D do Godot,
transições animadas, efeito ao selecionar (sem exagero) e uma identidade de desenho animado ou
super-herói, sem copiar o tema de outros jogos de ritmo. Escolheu o **quadrinho de herói**, e os
2 jogadores escolhendo o instrumento ao mesmo tempo, cada um com o seu "PRONTO".

## Decisão

- **Um cenário 3D só para todos os menus** (`godot/game/shell.tscn`, "a casca"): uma cidade de
  quadrinho com uma **estação** por tela (emblema, palco, instrumentos, pendrive). Trocar de tela
  não troca de cena: a câmera voa em arco até a estação da tela nova, a tela velha sai deslizando
  e a nova "estoura" para o tamanho normal. O `change_scene` destruiria o cenário e cortaria a
  transição. A partida continua uma cena à parte; a casca mergulha a câmera e escurece antes.
- **As telas continuam cenas de `Control` montadas no editor** (o que valia no ADR 0016), abertas
  por cima do cenário. Uma tela que declara `var world` recebe a casca para mexer no cenário;
  rodando sozinha (testes, F6) ela funciona sem cenário.
- **Visual de quadrinho por shader, não por textura** (`godot/game/comic/`):
  - modelos com sombra em faixas e retícula de impressão na passagem (`toon.gdshader`);
  - contorno de tinta num passe só, na tela inteira, pela profundidade e pelas normais
    (`ink.gdshader`), em vez de um casco invertido por objeto, que abre buracos nas quinas;
  - céu de "explosão" (raios girando, retícula nas bordas, pulso num ritmo calmo) com as cores de
    cada estação (`comic_sky.gdshader`).
- **Tema de HQ** (`godot/game/theme.tres`): painéis creme com borda de tinta grossa e sombra dura
  deslocada, botões inclinados e a fonte Bangers (OFL). O botão em foco ganha o fundo amarelo e
  solta linhas de ação uma vez (`godot/game/comic/focus_fx.gd`): com controle, o foco é o cursor.
- **Fluxo:** menu (1 Jogador, 2 Jogadores, Gerenciar músicas, Sair) → com 2 jogadores, o modo
  (Banda ou Duelo) → a música → o instrumento e a dificuldade (com 2 jogadores, cada um no seu
  controle, até os dois darem "PRONTO") → a partida.

## Consequências

- As telas ganham movimento sem perder o que o ADR 0016 garantia: ajustar o visual no editor e
  testar as telas sem o cenário.
- O contorno por pós-processamento exige o Forward+ (textura de normais), que o projeto já usa.
  Objetos transparentes (cones de luz, textos 3D) não ganham contorno.
- A cena 3D dos menus custa GPU que antes não custava. Nada de sombras nem neblina volumétrica;
  medir no Deck, e se perder quadros, reduzir a cidade ou desligar o contorno nos menus.
- Rodando uma tela sozinha no editor, não há fundo: para ver a tela no lugar dela, abra a casca
  com `--screen` (ver `godot/game/shell.gd`).
