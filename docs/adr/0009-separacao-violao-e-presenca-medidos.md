# 0009. Separação, violão × guitarra e presença: medidos no Deck

- **Status:** Aceita
- **Data:** 2026-10-22

> **2026-10-22:** a divisão violão × guitarra foi retirada no [ADR 0010](0010-cordas-um-instrumento.md)
> (um instrumento Cordas). As medidas de separação e de presença continuam valendo.

## Contexto

O [ADR 0006](0006-modelos-de-ia.md) propôs o Demucs `htdemucs_6s` e o PANNs CNN14 sem medição.
Na fase 3 eles rodaram no Steam Deck (CPU, 4 threads, `nice` 19) com quatro músicas reais de
estilos diferentes: rock com violão e guitarra ("Pais e Filhos"), rock com guitarra
distorcida ("Anna Júlia"), sertanejo com violão ("Ainda Ontem Chorei de Saudade") e pop
("Black Magic").

## Decisão

**Separação: Demucs 4.1.0 `htdemucs_6s`, torch 2.8.0 CPU.**
- Tempo: 132 s para 5:08 de música (~0,43× o tempo real) e 80–93 s para músicas de 3:30, mais 3 a 22 s para carregar o modelo.
- A versão 4.1 lê áudio pelo `sphn` e baixa os pesos do Hugging Face, sem torchaudio.
- Os 6 stems em FLAC ocupam ~230 MB por música em `data/work`.

**Violão × guitarra: PANNs CNN14, janelas de 2 s a cada 1 s, mediana de 5 decisões.**
- Evidência de violão: a classe *Acoustic guitar*. De elétrica: a maior entre *Electric guitar* e *Distortion*.
- Tempo: 10–18 s por música, mais 3–16 s para carregar.

| Música | Violão | Guitarra elétrica | Resultado |
|---|---|---|---|
| Pais e Filhos | 206 s, confiança 0,66 | 92 s, 0,69 | alterna nos trechos esperados |
| Anna Júlia | 21 s, 0,13 (falso) | 191 s, 0,31 | violão devolvido à guitarra |
| Ainda Ontem | 191 s, 0,76 | 0 s | só violão |
| Black Magic | 4 s, 0,12 | 136 s, 0,49 | violão devolvido à guitarra |

- **A confiança só barra o violão.** A guitarra elétrica tem confiança baixa quando o som é
  limpo ou comprimido (0,31 em "Anna Júlia", que só tem elétrica). Barrar a guitarra por isso
  seria errado. Violão abaixo de `min_acoustic_confidence` (0,4) volta inteiro para a guitarra:
  melhor um violão indisponível do que notas de guitarra no instrumento errado.

**Presença: fração audível + ataques por minuto, sem a confiança.**
- O stem é "audível" num quadro quando está até 18 dB abaixo da mixagem e acima de -50 dBFS.
- Para estar presente, precisa tocar em ≥ 15% da música e ter ≥ 30 ataques por minuto.
- O limiar de ataque é de 1 dB médio por banda (`onset_delta`): com 3 dB, a guitarra distorcida
  de "Anna Júlia" dava 12 ataques por minuto, contra ~216 reais.
- Detector de ataques próprio, em numpy (`pbq/dsp.py`): fluxo espectral em dB por 40 bandas,
  janela de 1024 e hop de 256 a 22 kHz. Ataques saem ~10 ms adiantados; com janela de 2048, ~30 ms.

## Consequências

- Com o processamento todo, são cerca de 2 a 3 minutos de CPU por música no Deck até aqui. Faltam
  batidas e transcrição (fases 4 e 5).
- **Calibrado com só 4 músicas.** Ainda falta um caso real de instrumento ausente com
  vazamento (ex.: música sem bateria). O caso sintético passa (vazamento a -30 dB fica "quiet").
  "Black Magic" passou com guitarra no limite (ativa em 16% da música, a -22 dB), e isso precisa ser
  conferido de ouvido.
- Os limiares estão em `config.example.toml`, com o motivo: recalibrar é mudar a config, sem
  código. Mudar o algoritmo pede subir a `version` da etapa (o cache refaz só ela e as
  seguintes).
