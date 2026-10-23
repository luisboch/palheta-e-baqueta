# Decisões de arquitetura (ADRs)

Um arquivo por decisão com trade-off: `NNNN-titulo-em-minusculas.md`, numerados em sequência.

- **Proposta**: decidida no papel, à espera de validação (ex.: um modelo ainda não testado no Deck).
- **Aceita**: em vigor. Não se reescreve, a não ser para corrigir o status ou acrescentar uma nota datada.
- **`Substituída por [NNNN](NNNN-titulo.md)`**: mudou de ideia; o ADR novo explica o porquê.
- **Descartada**: avaliada e rejeitada (fica para ninguém tentar de novo às cegas).

O índice abaixo é gerado (`python -m tools.docs_check --fix`) e conferido no pre-commit.

<!-- gen:adr-index -->
| # | Decisão | Status |
|---|---|---|
| 0001 | [Documentação viva e verificada](0001-documentacao-viva-verificada.md) | Aceita |
| 0002 | [Backend Python e jogo Godot conversando por arquivos](0002-backend-python-godot-por-arquivos.md) | Aceita |
| 0003 | [Pendrive só pelo menu, na pasta palheta/](0003-pendrive-pelo-menu.md) | Aceita |
| 0004 | [Processamento na CPU; GPU só no jogo, por enquanto](0004-processamento-na-cpu.md) | Aceita |
| 0005 | [Testes e cobertura (Python ≥ 80%; GDScript sem ferramenta confiável)](0005-testes-e-cobertura.md) | Aceita |
| 0006 | [Modelos de IA do pipeline](0006-modelos-de-ia.md) | Proposta |
| 0007 | [Formato de chart compatível com o Clone Hero](0007-formato-de-chart.md) | Proposta |
| 0008 | [Contrato backend ↔ jogo gerado a partir do Python](0008-contrato-gerado-do-python.md) | Aceita |
<!-- /gen:adr-index -->

## Modelo

```markdown
# NNNN. Título curto

- **Status:** Proposta
- **Data:** AAAA-MM-DD

## Contexto

O problema e as forças em jogo.

## Decisão

O que foi escolhido.

## Consequências

O que fica mais fácil, o que fica mais difícil, e quando rever.
```
