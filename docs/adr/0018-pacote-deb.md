# 0018. Distribuição em .deb, só Linux, com o backend instalado pelo uv

- **Status:** Aceita
- **Data:** 2026-10-23

## Contexto

Até aqui o jogo só rodava a partir do repositório (`scripts/setup.sh`). Para instalar sem clonar
nada, é preciso um pacote. O backend de IA (torch, Demucs) passa de 2 GB e o `uv.lock` só
resolve para Linux; o jogo controla o worker com `env`, `kill` e `/proc`, que não existem no
Windows.

## Decisão

- **Só Linux por enquanto**: um `.deb` para amd64. Nada de `.exe` até o backend e o controle do
  worker rodarem no Windows.
- **O pacote leva o jogo exportado, o código do backend e o uv** (versão fixada em
  `scripts/versions.env`, conferida por sha256), em `/opt/palheta-e-baqueta`. Não leva o `.venv`:
  o pacote fica pequeno e o torch vem da mesma fonte e versão do desenvolvimento (`uv.lock`).
- **Lançador** (`scripts/deb/palheta-e-baqueta`, em `/usr/bin`): usa uma pasta gravável do
  usuário, `$PALHETA_HOME` (padrão `~/.local/share/palheta-e-baqueta`), com o código do backend,
  `data/` e o `.venv`. Na primeira execução de cada versão, roda `uv sync --frozen --extra ai`
  ali (com uma janela de espera do zenity, se houver). O jogo lê a mesma variável
  (`godot/game/app.gd`); sem ela, continua usando a raiz do repositório.
- **CI** (`.github/workflows/package.yml`): todo push na main gera o `.deb` como artefato; uma
  tag `v*` cria a release com ele. O pacote é instalado e o jogo exportado é aberto e fechado
  na própria CI.

## Consequências

- A primeira abertura depois de instalar ou atualizar demora (download de alguns GB) e precisa
  de internet. Sem rede, o jogo abre e toca o que já está na biblioteca, mas não processa músicas.
- Não roda no Steam Deck (SteamOS não é Debian): lá continua o caminho de
  `scripts/steamdeck/install.sh`.
- Windows fica para quando o backend for portado; aí este ADR é substituído.
