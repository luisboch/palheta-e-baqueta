# 0012. Charts de Cordas e baixo, e as 4 dificuldades

- **Status:** Aceita
- **Data:** 2026-10-22

## Contexto

Faltavam os charts dos instrumentos com altura e a regra das dificuldades. O pedido: 5 trastes
relativos pelo contorno melódico, e as dificuldades por redução do Muito difícil, sempre na grade
(Fácil: 3 trastes, tempos fortes, sem acordes; Médio: 4 trastes; Difícil: 5 trastes, acordes
simples; Muito difícil: tudo).

O `basic-pitch` (Spotify, Apache-2.0) 0.4.0 pede TensorFlow < 2.15.1, que não existe para
Python 3.12. O pacote traz o mesmo modelo em ONNX.

## Decisão

**Transcrição:** `basic-pitch` pelo modelo ONNX (`onnxruntime`). O TensorFlow é excluído no
`pyproject.toml` (`override-dependencies`). São 5 a 8 s por stem no Deck.

**Do transcrito ao chart** (`pbq/charts/pitched.py`):
- Ficam as notas dentro da extensão do instrumento (Cordas E2–E6, baixo E1–G4), com intensidade
  ≥ 0,3 e duração ≥ 60 ms.
- Notas que começam a até 40 ms umas das outras são um acorde. Cada ataque vai para a grade.
- O baixo é monofônico (só a nota mais grave). As Cordas têm acordes de até 3 notas.
- Os eventos guardam as **alturas**, não os trastes. Cada dificuldade calcula os seus.
- **Contorno:** o traste sai da posição da nota de referência (a mais grave) na extensão local
  (16 notas vizinhas, no mínimo 7 semitons). A direção é sempre respeitada: subiu, traste maior;
  desceu, menor; repetiu, o mesmo.
- Nota longa (≥ 1 batida) vira sustentada, e termina 1/16 antes do próximo ataque.

**Dificuldades** (`pbq/charts/difficulty.py`): só se tiram notas, nunca se deslocam.

| | Cordas e baixo | Bateria |
|---|---|---|
| Muito difícil | tudo; 5 trastes; acordes até 3 | tudo |
| Difícil | colcheias e tercinas; 5 trastes; acordes até 2 | colcheias e tercinas; até 2 pads + bumbo |
| Médio | batidas + contratempo quando a batida está vazia; 4 trastes; sem acordes | colcheias, mas pratos e chimbal só nas batidas; 1 pad; bumbo só nas batidas |
| Fácil | tempos fortes (1 e 3 no 4/4); 3 trastes; sem acordes | batidas; uma peça por vez (caixa > bumbo > prato) |

O Médio de Cordas e baixo fica sem acordes por escolha, já que o pedido não dizia. A bateria no
Fácil usa todas as batidas, não só os tempos fortes: com só o 1 e o 3, o Fácil perderia a caixa
do 2 e do 4, que é o que segura o groove.

**Biblioteca** (etapa `package`): um OGG por instrumento presente. O stem dos ausentes vai para o
`song.ogg` (o fundo), porque também tem som.

**Medido** (out/2026) com 5 músicas reais e batidas da librosa (o servidor do `beat_this` estava fora):

| Música | Cordas F/M/D/MD (ataques/min) | Baixo MD | Bateria F/M/D/MD |
|---|---|---|---|
| Pais e Filhos | 33 / 85 / 168 / 219 | 123 | 89 / 92 / 167 / 171 |
| Anna Júlia | 52 / 126 / 260 / 382 | 222 | 106 / 130 / 175 / 187 |
| More Than Words | 17 / 82 / 148 / 191 | ausente | ausente |

O Médio da bateria saía quase igual ao Difícil (164 × 167 em "Pais e Filhos") até os pratos e o
chimbal ficarem só nas batidas.

## Consequências

- **Ninguém jogou ainda:** os números mostram que a progressão funciona, mas não se o chart é
  gostoso de tocar. Isso se ajusta na fase 6, com a pista funcionando. As regras estão isoladas em
  funções puras, então mudar é barato, e subir a `version` da etapa `chart` refaz só ela.
- A transcrição de Cordas mistura violão base e solo quando tocam juntos (ADR 0010).
- O Fácil de bateria pode ficar monótono em músicas quase sem caixa (só bumbo em "Ainda Ontem").
