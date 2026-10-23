# Roadmap

Uma fase só fecha com testes passando, cobertura medida e commit. Ao fechar, atualize esta
tabela (regra 5 da [doc viva](adr/0001-documentacao-viva-verificada.md)).

| # | Fase | Status | Cobertura Python | GDScript |
|---|---|---|---|---|
| 1 | Estrutura, tooling, CI, testes "hello" | ✅ concluída | ver abaixo | sem medição na época ([ADR 0005](adr/0005-testes-e-cobertura.md)) |
| 2 | Importação via pendrive (do kraoke) e cache | ✅ concluída | 99% | sem medição |
| 3 | Separação de stems e instrumento ausente | ✅ concluída | 97,7% | sem medição |
| 4 | Mapa de batidas e chart de bateria | ✅ concluída | 96,4% | sem medição |
| 5 | Charts de Cordas e baixo; 4 dificuldades | ✅ concluída | 96,8% | sem medição |
| 6 | Godot: parser de chart, pista de 1 jogador, julgamento | ✅ concluída | ver abaixo | 91,2% |
| 7 | Visual: notas quadradas e redondas, fundo no ritmo | ✅ concluída | 95,5% | 93,2% |
| 8 | 2 jogadores, controles USB, calibração | | | |
| 9 | Menus, seleção (bloqueando ausentes), resultados | ✅ concluída (MVP) | 95,5% | 90,9% |

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
- Depois do fechamento: violão e guitarra mesclados num instrumento só, **Cordas**
  ([ADR 0010](adr/0010-cordas-um-instrumento.md)). Sai a `guitar_split` (PANNs).

## Fase 4

- Núcleo de charts em Python puro (`pbq/charts/`): mapa de tempo a partir das batidas, grade de
  semicolcheias e tercinas, `.chart` do Clone Hero (escrita e leitura), lanes da bateria.
- Etapas `beats` (beat_this), `drums_chart` (ADTOF) e `chart` (`notes.chart`).
- ADTOF com implementação própria, conferida contra o port: mesmas batidas nas 5 peças
  ([ADR 0011](adr/0011-batidas-e-bateria.md)). 4 a 7 s por música no Deck.
- **Projeto não comercial** por causa dos pesos do ADTOF (CC BY-NC-SA 4.0); créditos no README.
- **Pendente:** o servidor dos pesos do beat_this (JKU) ficou fora do ar (HTTP 503) durante toda a
  fase. A etapa `beats` foi testada só com fake, e o teste `slow` do pipeline inteiro é pulado.
  Quando o servidor voltar: rodar `uv run pytest -m slow --no-cov` e as 4 músicas reais.
- **2026-10-23:** o servidor voltou. Pesos baixados por nós e conferidos por sha256
  (`pbq/models/beat_this.py`), testes `slow` passando com o modelo real (inclusive o do pipeline
  inteiro), e as duas músicas da biblioteca refeitas sozinhas a partir de `beats`, em 1,5 min no
  total (sem nova separação). BPM pela librosa → beat_this: 92,3 → 90,9 e 89,1 → 90,9.
- Cobertura Python: 96,4% (sem torch, como na CI). GDScript: sem mudanças.

## Fase 5

- Etapa `pitched_chart` (basic-pitch ONNX): Cordas e baixo Muito difícil, com alturas guardadas e
  trastes por contorno.
- As 4 dificuldades dos 3 instrumentos, por redução (etapa `chart`, versão 2).
- Etapa `package`: a pasta da música na biblioteca (OGG por instrumento presente, `song.ogg` com o
  resto, `notes.chart`, `song.ini`, `beatmap.json`, `song.json`).
  ([ADR 0012](adr/0012-charts-de-cordas-baixo-e-dificuldades.md)).
- Pipeline real nas 5 músicas, com batidas da librosa só no benchmark: 14 a 44 s por música nestas
  etapas, mais ~2 min da separação.
- Ainda pendente da fase 4: as batidas reais com beat_this (servidor fora do ar).
- Cobertura Python ao fechar: 96,8% (sem torch, como na CI). GDScript: sem mudanças.
- Depois do fechamento: librosa como reserva das batidas, com refazer automático quando o
  beat_this voltar ([ADR 0013](adr/0013-reserva-de-batidas-librosa.md)).

## Fase 6

- Lógica de jogo em classes puras (`godot/core/`), testadas com GdUnit4: parser do `.chart` (contra um
  chart gerado pelo pipeline), mapa de tempo, notas jogáveis, relógio sincronizado com o áudio,
  julgamento, pontuação, regras de seleção de instrumento, volume do stem, carregamento da música e
  perfil de entrada ([ADR 0014](adr/0014-regras-de-jogo.md)).
- Partida de 1 jogador (`godot/game/`): pista 3D com notas redondas (Cordas, baixo) e quadradas (bateria),
  placar, stems sincronizados, teclado e controle; `--autoplay` para depuração. Conferida em quadros
  renderizados com músicas reais.
- **Cobertura de GDScript medida pela primeira vez**: instrumentador próprio (`tools/gd_coverage.py`),
  91,2%, com o limiar de 80% na CI.
- Cobertura Python: 95,4%; GDScript: 43 testes, 91,2%.
- Depois do fechamento, no primeiro teste jogado: teclado e controle tocam a nota no traste, sem
  palhetada ([ADR 0015](adr/0015-tocar-no-traste-sem-palhetada.md)); o F5 do editor abre a música
  com mais instrumentos, em Cordas no Difícil.

## Fase 7

- Fundo animado em shader (`godot/game/background.gdshader`), atrás da pista: anel a cada
  batida, cor nova a cada compasso (a paleta das lanes), horizonte pelos graves, raios pelos
  médios, estrelas pelos agudos. Discreto, para as notas continuarem legíveis.
- Batidas do `beatmap.json` em lógica pura (`godot/core/beat_grid.gd`); sem beatmap, saem do mapa
  de tempo. Níveis do som por um `AudioEffectSpectrumAnalyzer` no bus `Music`, normalizados pelo
  pico recente de cada faixa (`godot/core/spectrum_bands.gd`): medido no Deck, o espectro fica entre
  -85 e -25 dB e varia muito entre músicas.
- Na pista: linhas de batida correndo com as notas (compasso mais forte), linha de acerto
  pulsando no tempo e o alvo "estourando" no acerto.
- 60 FPS estáveis no Deck (modo desktop, partida real com áudio).
- Cobertura Python: 95,5%; GDScript: 50 testes, 93,2%.

## Fase 9

Feita antes da 8, para fechar o MVP de 1 jogador: dá para jogar no Deck sem linha de comando.

- Telas montadas com nós no editor ([ADR 0016](adr/0016-menus-e-navegacao.md)): menu principal
  com o andamento da fila, escolha de música (instrumento ausente desabilitado, dificuldade sem
  notas desabilitada, capa, editar nome), pendrive (listar, trazer MP3s, importar, salvar) e
  resultado ao fim da partida. Tema único (`godot/game/theme.tres`) e o fundo animado também nos menus.
- `pbq edit` corrige título e artista em todos os arquivos da música e sobrevive a reprocessamento.
- Autoload `App`: inicia o worker com o menu, pausa durante a partida, roda comandos `pbq` numa
  thread. Nos testes fica inerte (sem worker, comandos ou troca de cena).
- Conferido: as três telas renderizadas com a biblioteca real; o worker sobe com o menu e morre
  com o jogo; `pbq drive list` de verdade pela ponte.
- Depois: pausa na partida (`Esc`/Start, e ao perder o foco) e atalho para o modo jogo
  (`scripts/steamdeck/install.sh`, lançador testado com o PATH mínimo do modo jogo).
- A seguir: fase 8 (2 jogadores, controles USB, calibração, tela de controles com a palhetada).
- Cobertura Python: 95,5%; GDScript: 64 testes, 90,9%.
