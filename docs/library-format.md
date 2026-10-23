# Formato da biblioteca (contrato backend → jogo)

O jogo só lê `data/library/`. Qualquer mudança incompatível aqui deve incrementar a versão
(`FORMAT_VERSION` em `pbq/library.py`) no mesmo commit; o jogo recebe a mesma constante pelo
arquivo gerado `godot/core/backend_protocol.gd`.

<!-- gen:format-version -->
Versão atual do formato: **1**.
<!-- /gen:format-version -->

```
library/
├── index.json
└── <id>/              <id> = 12 primeiros hex do sha1 do MP3 original
    ├── song.json      escrito por último: pasta sem ele está incompleta
    └── …              stems, notes.chart, beatmap.json, capa (definidos nas fases 3 a 5)
```

## index.json

Resumo para montar o menu sem abrir cada pasta. Regenerado pelo backend a cada música pronta
ou importada, a partir dos `song.json`.

<!-- gen:index-example -->
```json
{
  "version": 1,
  "songs": [
    {
      "id": "…",
      "title": "…",
      "artist": "…",
      "duration": "…",
      "instruments": "…"
    }
  ]
}
```
<!-- /gen:index-example -->

## <id>/song.json

Por enquanto só o que o pendrive precisa (os campos de stems, presença dos instrumentos e
charts entram nas fases 3 a 5, cada um documentado aqui quando existir):

```json
{
  "version": 1,
  "id": "3f2a9c1b7e00",
  "title": "…",
  "artist": "…",
  "duration": 214.3,
  "files": {"chart": "notes.chart", "cover": null}
}
```

- `instruments` (a partir da fase 4, com o `package`): `{id: true|false}`, se o instrumento toca
  na música (etapa `presence`). O jogo não deixa escolher um instrumento `false`. Ids:

<!-- gen:instruments -->
| Id | Stem tocado |
|---|---|
| `drums` | `stems/drums.flac` |
| `bass` | `stems/bass.flac` |
| `strings` | `stems/guitar.flac` |
<!-- /gen:instruments -->

- `files.*`: nomes de arquivo relativos à pasta da música; `null` = não existe. "Salvar no
  pendrive" e "Importar" copiam exatamente estes arquivos, mais o `song.json`.

## No pendrive

`<pendrive>/palheta/library/<id>/` tem a mesma pasta. Importar recusa `version` maior que a
nossa e pasta cujo nome não bate com o `id` ([ADR 0003](adr/0003-pendrive-pelo-menu.md)).
O `index.json` não vai para o pendrive: quem importa regenera o seu.

## <id>/beatmap.json

A grade de batidas, também usada pelo fundo animado do jogo. Tempos em segundos, a partir do
início do áudio.

```json
{
  "version": 1,
  "beats": [0.52, 1.03, 1.55],
  "downbeats": [0.52, 2.58],
  "bpm": 116.4,
  "energy": [0.61, 0.44, 1.0]
}
```

- `beats`: cada batida detectada. No `notes.chart`, a batida *i* fica no tick
  `(introdução + i) × 192`.
- `downbeats`: os tempos fortes (primeira batida de cada compasso), um subconjunto de `beats`.
- `bpm`: o andamento mediano, só para exibir. O mapa de tempo de verdade está no `[SyncTrack]`.
- `energy`: energia da mixagem em cada batida, de 0 a 1, onde 1 é a batida mais forte da música.
