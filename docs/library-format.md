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

- `files.*`: nomes de arquivo relativos à pasta da música; `null` = não existe. "Salvar no
  pendrive" e "Importar" copiam exatamente estes arquivos, mais o `song.json`.

## No pendrive

`<pendrive>/palheta/library/<id>/` tem a mesma pasta. Importar recusa `version` maior que a
nossa e pasta cujo nome não bate com o `id` ([ADR 0003](adr/0003-pendrive-pelo-menu.md)).
O `index.json` não vai para o pendrive: quem importa regenera o seu.
