# 0023. Modelos 3D construídos por script no Blender

- **Status:** Aceita
- **Data:** 2026-10-24

## Contexto

O cenário dos menus ([ADR 0022](0022-menus-3d-em-quadrinho.md)) precisa de modelos: emblema,
guitarra, baixo, bateria, palco, globo espelhado, refletor, pendrive, disco e uma cidade. O
projeto tem identidade própria (nada de arte de outros jogos), não tem artista, e tudo o que entra
no git precisa ser reproduzível e revisável. Pacotes CC0 prontos foram cogitados e deixados de
lado: estilos misturados e licenças a registrar, para formas que um script resolve.

## Decisão

- **Os modelos saem de um script** (`art/build_models.py`), rodado pelo Blender sem janela
  (`scripts/build_models.sh`, Blender na versão de `scripts/versions.env`). Nenhum `.blend` é
  guardado: mudar um modelo é um diff de código.
- **O jogo usa os `.glb` exportados**, que vão para o git (`godot/game/models/`): quem não tem
  Blender, a CI e o `.deb` não precisam dele.
- **Formas low-poly e cor chapada.** O material de cada peça tem o nome de uma cor da paleta; o
  Godot troca pelo shader toon da mesma cor (`godot/game/comic/comic.gd`). Nomes especiais:
  `screen` (a tela do palco, que recebe a capa), `glow_<cor>` (brilha) e `mirror` (facetas do
  globo).
- Peças de um modelo viram uma malha só (menos chamadas de desenho), exceto as que o jogo mexe:
  a tela do palco e a cabeça do refletor.

## Consequências

- Dá para refazer tudo com um comando, e o diff mostra o que mudou em cada modelo.
- Esculpir à mão não cabe: formas orgânicas (personagens) pediriam outro caminho.
- O Blender exportando um `.glb` diferente entre versões muda arquivos sem mudar o script; por
  isso a versão fica fixada.
