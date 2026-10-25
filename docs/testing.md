# Testes

## Python

- `pytest` + `pytest-cov`, com `--cov-fail-under=80` no `pyproject.toml`: rodar `pytest` já
  aplica o limiar. Mede `pbq/` e `tools/`, com cobertura de ramos.
- **Modelos de IA atrás de interfaces.** Cada etapa recebe o modelo por um `Protocol`. Os testes
  usam fakes determinísticos, sem torch, sem GPU e sem download.
- **Adaptadores reais** (`pbq/models/demucs.py`) só rodam por inteiro nos testes `slow`. Nos rápidos, testa-se a matemática deles (ex.: o progresso do Demucs) sem torch.
- **`@pytest.mark.slow`**: o pipeline real numa música curta e sintética. Fica fora do padrão
  (`-m "not slow"`) e da CI rápida. Para rodar: `uv run pytest -m slow --no-cov`.
- **Fixtures de áudio** são geradas na hora por `tests/audio.py` (senoide via ffmpeg + tags ID3
  e capa via mutagen), curtas e sem direito autoral. Nunca use música de verdade em teste.
- **Etapas falsas** para pipeline e worker ficam em `tests/fakes.py`; a config de teste
  (`tests/conftest.py`) aponta tudo para um `tmp_path`, inclusive as montagens de pendrive.
- A `data/` real nunca é usada: todo teste monta a sua config num `tmp_path`.

## GDScript

- GdUnit4 (versão em `scripts/versions.env`, instalado pelo `scripts/setup.sh`), headless:
  `scripts/test.sh godot`.
- Só `godot/core/` (lógica pura) é testado em unidade. Cenas, só quando houver lógica que não
  dê para tirar delas.
- **Cobertura**: `scripts/test.sh coverage`, com o instrumentador próprio (`tools/gd_coverage.py`):
  copia o projeto, insere um contador antes de cada instrução de `core/` e `game/`, roda o GdUnit4
  e cruza as linhas. Limiar de 80%, também na CI ([ADR 0005](adr/0005-testes-e-cobertura.md)).
  O relatório fica em `godot/reports/gd_coverage.json`.
- **Cenas**: `godot/tests/game/` monta a cena da partida com o chart de exemplo, sem áudio, e joga
  em autoplay até o fim.
- **Telas dos menus**: `godot/tests/game/menus_test.gd` abre cada tela sozinha (sem cenário) e a
  casca inteira, com uma biblioteca de mentira num diretório temporário.
- **Ver uma tela no cenário**: `godot res://game/shell.tscn -- --screen <cena> [--players 2]
  [--song <id>]` (ver `godot/game/shell.gd`). Para não usar a `data/` real, aponte
  `PALHETA_HOME` para uma pasta com `data/library/` de mentira.
- **Ver o jogo sem tela**: `--write-movie quadros.png --fixed-fps 30 --quit-after N` com
  `-- --song <pasta> --autoplay 1` grava quadros em PNG (precisa de GPU, não roda headless).
