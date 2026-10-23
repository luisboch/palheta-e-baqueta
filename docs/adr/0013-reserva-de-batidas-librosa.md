# 0013. librosa como reserva das batidas, com refazer automático

- **Status:** Aceita
- **Data:** 2026-10-22

## Contexto

Os pesos do `beat_this` só existem no servidor dos autores, que ficou horas fora do ar
([ADR 0011](0011-batidas-e-bateria.md)). Sem batidas não há grade, e sem grade não há chart: o
pipeline inteiro parava. A librosa (ISC) já vinha instalada como dependência do `basic-pitch`, e
o ADR 0006 a listava como reserva.

## Decisão

- A etapa `beats` (versão 2) tenta o rastreador principal (`tracker = "beat_this"`). Se ele não
  carregar, usa a reserva (`fallback = "librosa"`; `""` desliga a reserva).
- O `beatmap.json` registra quem gerou as batidas (`"tracker"`).
- Depois de uma falha, o principal só é tentado de novo após 30 minutos por instância da etapa: o
  worker passa por todas as músicas a cada volta e não pode martelar o servidor.
- **Refazer automático:** grade da reserva não conta como "feita" quando o principal carrega. O
  worker passou a conferir **todas** as etapas da música (antes, só a última). Uma etapa refeita
  refaz as que dependem dela, então charts e biblioteca se atualizam sozinhos.
- Tempos fortes na librosa: ela não os detecta. Supõe-se compasso de 4, com a fase de maior grave
  (o bumbo costuma cair no 1).

## Consequências

- Com o servidor fora, as músicas saem jogáveis, mas com uma grade pior: a librosa às vezes dobra
  ou corta pela metade o andamento, e o compasso pode sair errado em 3/4 ou 6/8.
- Quando o servidor volta, cada música feita pela reserva é reprocessada a partir de `beats`
  (alguns segundos a mais, sem nova separação) e reaparece como "pronta".
- O worker confere uma etapa a mais por música a cada volta: são checagens de arquivo, baratas.
