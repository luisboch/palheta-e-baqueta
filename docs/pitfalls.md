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
- **2026-10-22 · gdlint:** variáveis de classe têm de vir antes das funções
  (`class-definitions-order`), inclusive as públicas que você queira pôr perto da função que as usa.
- **2026-10-22 · Godot headless:** `--headless` não renderiza. Para ver o jogo sem estar na frente
  da tela, use o Movie Maker (`--write-movie f.png --fixed-fps 30 --quit-after N`): ele grava os
  quadros em PNG, mas precisa de GPU e abre uma janela.
- **2026-10-22 · .chart e git:** o `.chart` é CRLF (como o Moonscraper escreve). `*.chart -text` no
  `.gitattributes` impede o git de converter, e o docs_check compara os arquivos gerados em bytes
  (o `read_text()` do Python converteria CRLF em LF).
- **2026-10-22 · Godot, cenas:** malhas e materiais de uma `PackedScene` são compartilhados entre
  todas as instâncias. Mudar `mesh.size` numa partida muda na próxima. Faça `duplicate()` antes
  (ver `setup()` em `godot/game/highway.gd`).
- **2026-10-22 · Godot, editor:** nó criado só em `_ready()` não aparece no editor (o script não roda
  lá). O que deve ser visto e ajustado no editor tem de ser nó da cena.
- **2026-10-22 · MP3 baixado da internet:** alguns trazem o link do vídeo na tag de título. O
  `ingest` ignora título que é URL e usa o nome do arquivo.
- **2026-10-23 · Deck em modo desktop:** o Steam converte os botões em teclado e mouse e o
  Godot não vê controle nenhum (`Input.get_connected_joypads()` vazio). Teste com teclado ou
  rode o jogo pelo Steam.
- **2026-10-23 · `override.cfg` não muda os argumentos do F5:** o editor ignora esse arquivo. O
  padrão do F5 (música e dificuldade) fica no próprio `godot/game/play.gd`.
- **2026-10-23 · `OS.execute_with_pipe` não tem diretório de trabalho:** os caminhos do
  `config.toml` são relativos à raiz do repositório. O jogo roda `env -C <repo> .venv/bin/pbq …`
  (`godot/game/app.gd`).
- **2026-10-23 · Lock do worker fica com o PID depois que ele sai:** `kill -STOP` nesse número
  pararia outro programa que o herdou. O jogo só pausa se `/proc/<pid>/cmdline` for um `pbq watch`.
- **2026-10-23 · Testes do GdUnit4:** `create_temp_dir("x")` devolve a mesma pasta em todos os
  testes (sobra lixo do anterior: use um nome único), e `change_scene_to_file` num teste troca a
  cena do executor. Por isso `App.live` é falso nos testes e `goto()` só registra.
- **2026-10-23 · Modo jogo do Deck:** o PATH não tem o Homebrew nem `~/.local/bin`, e não há
  terminal. O lançador (`scripts/steamdeck/palheta.sh`) acerta o PATH antes de abrir o jogo (o
  worker herda) e manda a saída para `data/game.log`. O mesmo problema já tinha custado tempo no
  kraoke.
- **2026-10-23 · CI ≠ Deck:** o pre-commit passava no Deck e falhava no primeiro run da CI. O
  mypy achava o `torch` no `.venv` local (na CI ele não é instalado), um caminho gerado citado
  na doc só existia aqui, e o `gdformat` em lotes paralelos falha com "File exists"
  (`require_serial` no `.pre-commit-config.yaml`).
- **2026-10-23 · Godot 4 não liga os menus ao controle:** `ui_accept` e `ui_cancel` padrão só
  têm teclas (o `ui_up/down` tem o direcional, então a navegação engana). O A não apertava
  nenhum botão no Bazzite. `InputProfile.DEFAULTS` acrescenta A/B e o autoload `App` aplica.
