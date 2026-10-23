# 0011. Batidas com beat_this e bateria com ADTOF (projeto não comercial)

- **Status:** Aceita
- **Data:** 2026-10-22

> **2026-10-23:** o servidor dos pesos voltou. O checkpoint `final0` agora é baixado pelo
> backend para `data/models/` e conferido por sha256 antes de abrir (é um pickle); as músicas
> feitas pela reserva foram refeitas com o beat_this.

## Contexto

O [ADR 0006](0006-modelos-de-ia.md) propunha o `beat_this` para batidas e o ADTOF para bateria.
A fase 4 conferiu licenças e compatibilidade:

- **beat_this** (CPJKU): código e pesos MIT, no PyPI (1.1.0), PyTorch.
- **ADTOF** (Zehren et al.): melhor transcrição de bateria aberta (F ≈ 0,88), com as 5 peças que
  viram as lanes do jogo. O original é TensorFlow/Keras e usa madmom, frágil no Python 3.12.
  **Os pesos são CC BY-NC-SA 4.0.** Existe um port para PyTorch (ADTOF-pytorch) com os pesos
  convertidos, mas o código dele não declara licença.
- Alternativas: um detector próprio por bandas (livre, mas bem pior em tons e pratos) e o
  Omnizart (MIT, mas TensorFlow e madmom).

## Decisão

- **Projeto não comercial** (decisão do dono do projeto, 2026-10-22), por causa dos pesos do ADTOF.
  Atribuição e licença ficam no README.
- **ADTOF com implementação própria** (`pbq/models/adtof.py`), escrita a partir da arquitetura
  dos artigos e da estrutura dos pesos, sem copiar código do port. Os pesos convertidos vêm de um
  commit fixo do port e são conferidos por sha256.
  - **Verificação:** o port serviu só de oráculo, rodando num clone fora do repositório, em 30 s de
    bateria real. Batidas detectadas por peça: idênticas nas 5 classes. Diferença média nas
    ativações: 0,001.
  - O resto da diferença é o max-pooling `padding="same"` (28 → 10 bins). Aqui ele segue o
    TensorFlow, com 1 bin de folga de cada lado. O port diverge do Keras nessa mesma camada, como
    o README dele mostra.
  - A entrada é um espectrograma log-filtrado em numpy, no estilo do madmom, sem madmom.
  - Tempo no Deck: 4 a 7 s por música.
- **beat_this** (`final0`, sem o DBN do madmom) na mixagem completa. A grade dos charts sai das
  batidas: 192 ticks por batida, o andamento muda a cada batida e os compassos vêm dos tempos fortes.
- **Lanes da bateria** (pro drums do Clone Hero): bumbo 0, caixa 1, chimbal 2 com marca de
  prato, tons 3, pratos 4 com marca de prato. No máximo 2 pads por instante (duas mãos), com
  prioridade caixa > prato > chimbal > tom.

## Consequências

- O projeto não pode ser vendido nem distribuído com fins comerciais enquanto usar os pesos do ADTOF.
- Os pesos do `beat_this` só existem no servidor dos autores, que estava fora do ar (HTTP 503) na
  fase 4. Sem ele, a etapa `beats` falha com erro legível e a música espera. Espelhos de terceiros não
  são usados: o checkpoint é um pickle, e carregar um arquivo adulterado executa código.
- O ADTOF junta todos os tons numa classe só (tudo vai para o azul) e todos os pratos noutra.
  Distribuir tons e pratos entre as cores (por altura) fica para depois, se o jogo pedir.
