# 0016. Menus e navegação

- **Status:** Aceita
- **Data:** 2026-10-23

## Contexto

A fase 9 tira a linha de comando do caminho: no Deck, tudo tem de ser feito com o controle. O
dono do projeto quer ver e ajustar as telas no editor do Godot, então elas não podem nascer de
código.

## Decisão

- **Uma cena por tela, montada com nós** (menu, escolha de música, pendrive, partida). O código só
  preenche e liga sinais. Linhas de lista (músicas, pendrives) são cópias de um botão-modelo que
  fica na cena: muda o modelo no editor, muda a lista.
- **Um tema** (`godot/game/theme.tres`) com o foco bem visível (borda âmbar), porque com
  controle o foco é o cursor.
- **Fluxo:** menu → Jogar → música (o foco na lista já mostra os detalhes) → instrumento →
  dificuldade → partida → resultado (Jogar de novo / Escolher outra música). `Esc`/B volta uma
  tela; na partida, volta para a escolha de música. Ainda não há pausa.
- **Instrumento ausente** (ADR 0009) aparece desabilitado, com o aviso "X não toca nesta música".
  A escolha de instrumento e dificuldade segue `InstrumentRules.choose` (Cordas no Difícil, ou o
  mais perto disso) e fica lembrada entre músicas.
- **Backend:** o menu inicia o worker; a partida o pausa (`SIGSTOP`) e o retoma ao sair, para a
  separação de stems não disputar a CPU com o áudio. Comandos do menu (`pbq drive …`,
  `pbq edit`) rodam numa thread com o andamento na tela.
- **Editar nome** chama `pbq edit`, que corrige todos os arquivos da música e guarda a correção
  para reprocessamentos.

## Consequências

- Mudar o visual não exige mexer em código. O preço é escrever os `.tscn` com cuidado (ou pelo
  editor) e manter `unique_name_in_owner` nos nós que o script usa.
- Sair no meio da música perde a partida; uma pausa de verdade fica para depois.
- A tela de controles (mapeamento e palhetada liga/desliga, ADR 0015) entra na fase 8.
