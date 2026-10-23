# Armadilhas

Uma linha por armadilha: data, o que acontece e o porquê. Regra 4 da
[doc viva](adr/0001-documentacao-viva-verificada.md).

- **2026-10-22 · GDScript:** `JSON.parse_string` registra `ERROR` no log quando o texto é
  inválido, e isso polui a saída dos testes. Para validar entrada, use `JSON.new().parse()`,
  que devolve o código de erro em silêncio.
- **2026-10-22 · GdUnit4:** os dois `ERROR: ... 127.0.0.1:0` no início dos testes são
  intencionais. O runner aponta o depurador para a porta 0 para não cair no prompt interativo
  `debug>` quando há erro de parse.
- **2026-10-22 · GPU do Deck:** o ROCm não funciona na gfx1033 (já investigado no kraoke, set/2026);
  ver [ADR 0004](adr/0004-processamento-na-cpu.md).
- **2026-10-22 · Godot:** classe nova com `class_name` dá "Identifier not declared" nos testes
  headless até o cache global (`.godot/global_script_class_cache.cfg`) ser refeito. Por isso o
  `scripts/test.sh` roda `--import` antes do GdUnit4.
- **2026-10-22 · Godot:** o `JSON` do Godot devolve todo número como `float` (`"pending": 3` →
  `3.0`). Campos inteiros do backend (`pending`, `done`, `count`...) precisam de `int()` no jogo.
- **2026-10-22 · uv:** o lock resolve para todas as plataformas, e no macOS Intel o Demucs exige
  numpy < 2. Por isso `[tool.uv] environments` limita o lock a Linux.
- **2026-10-22 · SteamOS:** não existe `/usr/bin/time`. Meça o tempo dentro do script.
- **2026-10-22 · ataques:** guitarra distorcida tem ataques de só ~1–2 dB, e um limiar pensado
  para bateria (3 dB) "esconde" a palhetada inteira. Ver
  [ADR 0009](adr/0009-separacao-violao-e-presenca-medidos.md).
- **2026-10-22 · beat_this:** os pesos só existem no servidor da JKU (cloud.cp.jku.at), que
  ficou fora do ar (HTTP 503) por horas. Os espelhos no Hugging Face são de terceiros e o
  checkpoint é pickle: não usar ([ADR 0011](adr/0011-batidas-e-bateria.md)).
- **2026-10-22 · PyTorch × Keras:** `MaxPool2d(ceil_mode=True)` não equivale a
  `padding="same"` do Keras. O TensorFlow divide a folga entre os dois lados, e o `ceil_mode` põe
  tudo no fim, o que desloca as bandas (erro de até 0,2 na saída do ADTOF). Ver `pbq/models/adtof.py`.
- **2026-10-22 · ADTOF:** o Frame_RNN espera 84 bandas (12 por oitava, 20 Hz–20 kHz, janela 2048 a
  44,1 kHz). Com outra taxa ou janela, o número de bandas muda e os pesos não servem.
- **2026-10-22 · basic-pitch:** a 0.4.0 pede `tensorflow < 2.15.1`, que não existe para Python 3.12.
  O `override-dependencies` do `pyproject.toml` impede a instalação do TensorFlow, e o pacote usa o
  modelo ONNX sozinho.
- **2026-10-22 · resampy:** a versão que o basic-pitch fixa (< 0.4.3) importa `pkg_resources`,
  que saiu do setuptools 81. Por isso o setuptools fica fixado em 80.9.0 no extra `pitch`.
