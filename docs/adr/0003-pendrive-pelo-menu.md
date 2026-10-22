# 0003. Pendrive só pelo menu, na pasta palheta/

- **Status:** Aceita
- **Data:** 2026-10-22

## Contexto

O pedido inicial falava em detectar o pendrive e importar. O kraoke já tinha aprendido que
importar sozinho ao conectar causa surpresas: música excluída que volta, ou cópia pesada no meio
de uma música. Um pendrive pode ter as pastas do kraoke e deste jogo ao mesmo tempo.

## Decisão

- Conectar não faz nada. O usuário escolhe no menu: **Processar músicas** (MP3s novos →
  `data/input`), **Importar músicas** (prontas, de `palheta/library/`) e **Salvar biblioteca**.
- No pendrive: `<raiz>/palheta/*.mp3` (e subpastas) e `<raiz>/palheta/library/<id>/`. A pasta é
  configurável (`[drive] folder`).
- O pendrive só é escrito por "Salvar biblioteca", sempre de forma incremental, sem apagar nada.

## Consequências

- O mesmo pendrive serve ao kraoke e a este jogo sem conflito.
- Ninguém é surpreendido por cópias. Em troca, o usuário precisa abrir o menu.
