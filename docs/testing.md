# Testes

## Python

- `pytest` + `pytest-cov`, com `--cov-fail-under=80` no `pyproject.toml`: rodar `pytest` já
  aplica o limiar. Mede `pbq/` e `tools/`, com cobertura de ramos.
- **Modelos de IA atrás de interfaces.** Cada etapa recebe o modelo por um `Protocol`. Os testes
  usam fakes determinísticos, sem torch, sem GPU e sem download.
- **`@pytest.mark.slow`**: o pipeline real numa música curta e sintética. Fica fora do padrão
  (`-m "not slow"`) e da CI rápida. Para rodar: `uv run pytest -m slow --no-cov`.
- **Fixtures de áudio** são geradas por script (senoides, cliques, ruído filtrado), curtas e
  sem direito autoral. Nunca use música de verdade em teste.
- A `data/` real nunca é usada: todo teste monta a sua config num `tmp_path`.

## GDScript

- GdUnit4 (versão em `scripts/versions.env`, instalado pelo `scripts/setup.sh`), headless:
  `scripts/test.sh godot`.
- Só `godot/core/` (lógica pura) é testado em unidade. Cenas, só quando houver lógica que não
  dê para tirar delas.
- **Cobertura**: não há ferramenta confiável para Godot 4 ([ADR 0005](adr/0005-testes-e-cobertura.md)).
