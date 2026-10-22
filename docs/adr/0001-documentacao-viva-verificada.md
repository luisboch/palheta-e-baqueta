# 0001. Documentação viva e verificada

- **Status:** Aceita
- **Data:** 2026-10-22

## Contexto

No kraoke, a doc viva era uma regra de disciplina: "atualize o AGENTS.md no mesmo commit". Na
prática, o AGENTS.md virou depósito de tudo: regras, decisões, armadilhas e relatórios de
investigação. Tabelas iam sendo copiadas entre README e o docs/app.md do kraoke, e nada avisava quando um
arquivo citado mudava de nome ou uma lista saía de sincronia com o código.

## Decisão

- **Cada fato num lugar só**, com o mapa no AGENTS.md: o AGENTS.md tem regras e ponteiros; a
  arquitetura, os ADRs, o roadmap, os testes e as armadilhas têm cada um o seu arquivo.
- **Decisões em ADRs** imutáveis, com status (`Proposta`, `Aceita`, `Substituída por`,
  `Descartada`). Mudar de ideia é escrever um ADR novo, e o histórico do porquê fica preservado.
- **O que é verificável é verificado** por `tools/docs_check.py`: links e âncoras, caminhos
  citados entre crases, formato e numeração dos ADRs, e trechos gerados
  (`<!-- gen:nome -->`) que precisam bater com o código. O check roda no pre-commit, na CI e
  como teste do pytest, e por isso uma doc quebrada impede o commit.
- **Gerar em vez de copiar**: listas derivadas do código (índice de ADRs agora; etapas, eventos,
  chaves de config e versão do formato depois) são trechos gerados. Cada fase acrescenta o seu
  gerador quando cria a lista.

## Consequências

- Renomear um arquivo citado ou esquecer o índice dos ADRs quebra o commit, não o leitor.
- A prosa continua dependendo de quem escreve. O check não sabe se uma explicação está certa,
  só que ela não aponta para o vazio.
- Um gerador novo custa algumas linhas e um teste. É o preço de não manter a lista à mão.
