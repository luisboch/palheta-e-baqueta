# 0007. Formato de chart compatível com o Clone Hero

- **Status:** Proposta
- **Data:** 2026-10-22

## Contexto

O jogo precisa das notas em 4 dificuldades por instrumento, do mapa de tempo e dos stems. Um
formato próprio seria mais simples de ler, mas o formato do Clone Hero é conhecido, documentado
pela comunidade e abre a pasta em outros jogos e editores (Moonscraper) para conferir e corrigir.

## Decisão

Cada `data/library/<id>/` é uma pasta de música do Clone Hero, mais os nossos arquivos:

- `notes.chart` (texto): `[Song]` e `[SyncTrack]` (tempo e compasso, de `beats`), e as trilhas
  `Easy|Medium|Hard|Expert` × `Single` (Cordas: violão + guitarra, [ADR 0010](0010-cordas-um-instrumento.md)),
  `DoubleBass` (baixo) e `Drums` (bateria).
- `song.ini` e os áudios com os nomes do Clone Hero: `guitar.ogg` (Cordas), `bass.ogg`,
  `drums.ogg`, `song.ogg` (o resto) e `vocals.ogg`.
- `beatmap.json` (nosso): batidas, downbeats, BPM e energia por batida, para o fundo animado.
- `song.json` (nosso): `version`, presença de cada instrumento e confiança, como no kraoke.

Mapeamento: Fácil, Médio, Difícil e Muito difícil correspondem a Easy, Medium, Hard e Expert.

## Consequências

- O parser do jogo lê um subconjunto do `.chart`. Ele é testado contra os charts que o próprio
  pipeline gera.
- Outros jogos tocam nossas músicas sem nenhuma convenção extra.
