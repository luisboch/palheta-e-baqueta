# Roadmap

Uma fase só fecha com testes passando, cobertura medida e commit. Ao fechar, atualize esta
tabela (regra 5 da [doc viva](adr/0001-documentacao-viva-verificada.md)).

| # | Fase | Status | Cobertura Python | GDScript |
|---|---|---|---|---|
| 1 | Estrutura, tooling, CI, testes "hello" | ✅ concluída | ver abaixo | sem medição ([ADR 0005](adr/0005-testes-e-cobertura.md)) |
| 2 | Importação via pendrive (do kraoke) e cache | ✅ concluída | 99% | sem medição |
| 3 | Separação de stems e instrumento ausente | ✅ concluída | 97,7% | sem medição |
| 4 | Mapa de batidas e chart de bateria | ⏳ próxima | | |
| 5 | Charts de guitarra, violão e baixo; 4 dificuldades | | | |
| 6 | Godot: parser de chart, pista de 1 jogador, julgamento | | | |
| 7 | Visual: notas quadradas e redondas, fundo no ritmo | | | |
| 8 | 2 jogadores, controles USB, calibração | | | |
| 9 | Menus, seleção (bloqueando ausentes), resultados | | | |

## Fase 1

- Repositório, `.gitignore`, uv com Python 3.12 e versões fixadas, `scripts/setup.sh` e
  `scripts/test.sh`.
- ruff, mypy (strict), gdformat, gdlint e a documentação viva no pre-commit; CI no GitHub Actions.
- CLI `pbq version`, `pbq/config.py` (o mesmo modelo do kraoke) e `godot/core/app_info.gd`.
- Cobertura Python ao fechar: 98% (limiar de 80%).

## Fase 2

- Portado do kraoke, tipado: manifesto (`<id>` = hash do MP3 como cache), scanner, pipeline,
  worker com lock e eventos, pendrive (`pbq/drive.py`, pasta `palheta/`) e salvar/importar
  biblioteca (`pbq/backup.py`), parser de títulos.
- Novo em relação ao kraoke: `version` por etapa (subir refaz a etapa e as que dependem dela),
  eventos `progress` e `data/queue.json` para a barra de andamento, CLI `pbq drive …` em
  JSON-lines, cache de hash do pendrive em disco, `--die-with-parent` no worker.
- Contrato backend ↔ jogo gerado do Python ([ADR 0008](adr/0008-contrato-gerado-do-python.md)),
  com `EventReader` e `BackendMessage` no Godot.
- Primeira etapa real: `ingest` (metadados e capa), testada com MP3 sintético.
- Cobertura Python ao fechar: 99,4%. GDScript: 13 testes, cobertura não medida.

## Fase 3

- Etapas `separate` (Demucs `htdemucs_6s`), `guitar_split` (PANNs: guitarra × violão) e
  `presence` (instrumentos ausentes), com os modelos atrás de `Protocol`s e fakes nos testes.
- Medido no Deck com 4 músicas reais ([ADR 0009](adr/0009-separacao-violao-e-presenca-medidos.md)):
  separação ~0,43× o tempo da música, divisão de guitarra em 10–18 s.
- Detector de ataques próprio em numpy (`pbq/dsp.py`), que a fase 4 vai reaproveitar.
- Teste `slow` com os modelos reais numa banda sintética (13 s).
- Cobertura Python ao fechar: 97,7% (rodando sem torch, como na CI). GDScript: sem mudanças.
