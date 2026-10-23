# 0010. Violão e guitarra num instrumento só: Cordas

- **Status:** Aceita
- **Data:** 2026-10-22

## Contexto

O pedido inicial tinha violão e guitarra como instrumentos separados, e a fase 3 implementou a
divisão com um classificador de timbre ([ADR 0009](0009-separacao-violao-e-presenca-medidos.md)).
Na prática:

- Em 2 das 4 músicas medidas, o violão voltou para a guitarra por confiança baixa.
- Quando violão e guitarra tocam **ao mesmo tempo**, a divisão não ajuda: o Demucs entrega os
  dois no mesmo stem, e o classificador manda cada trecho inteiro para um lado. Não há modelo de
  separação utilizável que distinga os dois.
- Quando eles **alternam**, um chart só já segue quem estiver tocando.

## Decisão

- Um instrumento **Cordas** (id `strings`), com notas redondas, tocando o stem `guitar` inteiro
  (violão + guitarra elétrica).
- Sai a etapa `guitar_split`, junto com o PANNs e o extra `classify`. A `presence` (versão 2)
  mede o stem `guitar` direto.
- Instrumentos do jogo: bateria (`drums`), baixo (`bass`) e Cordas (`strings`). A lista é parte
  do contrato gerado (`godot/core/backend_protocol.gd`).
- Para 2 jogadores, os dois podem escolher o mesmo instrumento, cada um com a sua pista e a
  sua dificuldade.

## Consequências

- O pipeline fica 15 a 30 s mais rápido por música e dispensa ~330 MB de pesos.
- Música com violão base e guitarra solo juntos dá um chart de Cordas mais cheio, com as duas
  partes misturadas. A divisão também não resolvia esse caso.
- Perde-se o visual próprio do violão. Se valer a pena no polimento, as notas de trechos de
  violão podem ganhar outro material na mesma pista, o que traria o classificador de volta só
  para o visual. Seria um ADR novo.
