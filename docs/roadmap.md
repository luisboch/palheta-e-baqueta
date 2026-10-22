# Roadmap

Uma fase só fecha com testes passando, cobertura medida e commit. Ao fechar, atualize esta
tabela (regra 5 da [doc viva](adr/0001-documentacao-viva-verificada.md)).

| # | Fase | Status | Cobertura Python | GDScript |
|---|---|---|---|---|
| 1 | Estrutura, tooling, CI, testes "hello" | ✅ concluída | ver abaixo | sem medição ([ADR 0005](adr/0005-testes-e-cobertura.md)) |
| 2 | Importação via pendrive (do kraoke) e cache | ⏳ próxima | | |
| 3 | Separação de stems e instrumento ausente | | | |
| 4 | Mapa de batidas e chart de bateria | | | |
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
