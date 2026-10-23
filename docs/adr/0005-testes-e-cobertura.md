# 0005. Testes e cobertura (Python ≥ 80%; GDScript sem ferramenta confiável)

- **Status:** Aceita
- **Data:** 2026-10-22

> **2026-10-22:** o instrumentador existe (`tools/gd_coverage.py`, com testes) e mede `core/` e
> `game/`: 91% na fase 6. O limiar de 80% passou a valer para GDScript também (`scripts/test.sh
> coverage`, na CI). Limitações: funções de uma linha e corpos de lambdas de várias linhas dentro de
> parênteses não são medidos.

## Contexto

O pedido exige no mínimo 80% de cobertura. Do lado Python, `pytest-cov` resolve. Do lado
GDScript, em out/2026:

- GdUnit4 e GUT não medem cobertura.
- [godot-code-coverage](https://github.com/jamie-pate/godot-code-coverage) instrumenta scripts,
  mas declara suporte só ao Godot 3.5.
- O [gdmutant](https://pypi.org/project/gdmutant/) (Godot 4.3+) faz teste de mutação, não
  cobertura.

## Decisão

- **Python**: `--cov-fail-under=80` no `pyproject.toml`, com cobertura de ramos, sobre `pbq/` e
  `tools/`. Os adaptadores de modelos reais são finos, e o resto é testado com fakes.
- **GDScript**: GdUnit4 (versão fixada), headless, na CI. A lógica fica em `godot/core/` (classes
  puras), o que torna os testes possíveis e baratos.
- **Cobertura de GDScript**: na fase 6, quando o `core/` tiver lógica real, escrever um
  instrumentador próprio em Python (`tools/`). Ele copiaria `godot/core/` instrumentado,
  inserindo uma chamada de contagem antes de cada instrução executável, rodaria os testes
  sobre a cópia e geraria o relatório. Se ficar confiável, o limiar de 80% passa a valer também
  para GDScript. Se não ficar, o relatório é só informativo e isso se registra aqui.

## Consequências

- Até a fase 6 não há número de cobertura para GDScript, e o roadmap mostra isso.
- O instrumentador próprio é código a manter. Ele só vale se for pequeno e testado.
