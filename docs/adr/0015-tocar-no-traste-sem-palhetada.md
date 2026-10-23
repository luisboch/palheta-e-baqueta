# 0015. Teclado e controle tocam no traste, sem palhetada

- **Status:** Aceita
- **Data:** 2026-10-23

## Contexto

O [ADR 0014](0014-regras-de-jogo.md) pôs a nota de Cordas e baixo na palhetada, como numa
guitarra de plástico. No primeiro teste de verdade, no teclado (`A S D F G`), nenhuma nota tocou:
apertar o traste só o "segurava", e a palhetada (`↓`/`Enter`) numa tecla separada não é o gesto
natural de quem toca no teclado ou no controle.

## Decisão

- Com teclado e controle comum, **a nota toca ao apertar o traste** (`InputProfile.FRET_TAPS`).
  Os trastes pressionados no instante contam como na palhetada: nota simples pelo mais agudo
  (ancoragem vale), acorde com os trastes exatos. O acorde toca quando o último traste dele desce.
- Traste apertado sem nota que bata **não pune** (`Judge.tap`): montar um acorde passa por
  combinações erradas, e isso não pode quebrar a sequência.
- Nesse modo a palhetada é ignorada: depois de um acerto no traste, ela cairia sem nota e viraria
  overstrum.
- A guitarra USB (fase 8) volta à palhetada, que é o gesto do instrumento. A escolha vai para o
  perfil de entrada.

## Consequências

- Dá para jogar no teclado e no controle do Deck sem aprender a palhetada.
- Sem punição por traste errado, apertar trastes a esmo acerta mais do que deveria. Se isso
  estragar o jogo, a saída é punir o traste errado só quando há nota na janela.
