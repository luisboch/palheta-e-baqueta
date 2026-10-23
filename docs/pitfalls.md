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
