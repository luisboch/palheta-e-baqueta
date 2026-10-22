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
