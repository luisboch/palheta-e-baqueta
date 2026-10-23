# 0006. Modelos de IA do pipeline

- **Status:** Proposta
- **Data:** 2026-10-22

> **2026-10-22:** separação e violão × guitarra medidos e aceitos no
> [ADR 0009](0009-separacao-violao-e-presenca-medidos.md). Batidas, bateria e cordas seguem como proposta.

## Contexto

Precisamos de stems por instrumento, batidas e transcrição de bateria e de instrumentos com
altura, tudo rodando na CPU do Deck ([ADR 0004](0004-processamento-na-cpu.md)) em Python 3.12.

## Decisão

Candidatos, a validar nas fases 3 a 5. Cada validação atualiza este ADR (ou o substitui):

| Tarefa | Escolha | Alternativas e por que não |
|---|---|---|
| Separação | Demucs `htdemucs_6s` (drums, bass, guitar, piano, vocals, other) | `htdemucs` não tem guitarra; os RoFormers só separam a voz |
| Guitarra × violão | PANNs CNN14 (AudioSet: *Acoustic guitar*, *Electric guitar*, *Distortion*), em janelas de 1 s suavizadas no tempo | o Demucs não separa os dois; um classificador próprio exigiria um dataset |
| Batidas | `beat_this` (CPJKU, 2024, PyTorch) | o madmom está sem manutenção e é frágil no Python 3.12; o `librosa` fica de reserva |
| Bateria | ADTOF (5 classes: bumbo, caixa, tom, chimbal, prato), de preferência o port para PyTorch | o Omnizart está abandonado (Python ≤ 3.8, TensorFlow) |
| Cordas | `basic-pitch` (Spotify), com backend ONNX | sem TensorFlow; é polifônico, o que permite acordes |

Ausência de instrumento: limiares sobre a energia RMS do stem em relação à mixagem, onsets por
minuto e fração de tempo ativo. Ficam na config, e são calibrados com músicas reais.

**Limitações conhecidas do violão × guitarra**: trechos com os dois juntos vão para o
dominante. Guitarra limpa pode passar por violão. Nylon e vazamento de outros stems confundem.
Com confiança baixa, o violão fica **indisponível** em vez de errado.

## Consequências

- Cada modelo entra atrás de um `Protocol`: trocar um não mexe no resto, e os testes usam fakes.
- Riscos a verificar antes de aceitar: compatibilidade do ADTOF e do `basic-pitch` com o
  Python 3.12, o tempo total por música no Deck e o disco ocupado pelos modelos.
