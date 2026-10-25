## Visual de quadrinho dos modelos 3D: troca os materiais importados dos .glb (cor chapada, ver
## art/build_models.py) pelo shader toon, com a mesma cor. Os materiais saem de um cache por nome:
## o cenário inteiro usa uma dúzia deles.
class_name Comic
extends RefCounted

const TOON := preload("res://game/comic/toon.gdshader")
const GLOW_PREFIX := "glow_"  ## brilha sozinho (lentes, faixas de luz)
const MIRROR := "mirror"  ## as facetas do globo espelhado
const SCREEN := "screen"  ## a tela do palco: quem usa põe o material dela (a capa)
const GLOW_ENERGY := 1.5  ## emissão das peças "glow_": passa do limiar do brilho (glow) do ambiente

## Paleta de quadrinho (a mesma do art/build_models.py), para o que é desenhado em código.
const RED := Color("e63946")
const YELLOW := Color("ffd23f")
const BLUE := Color("2764d9")
const CYAN := Color("3bceac")
const ORANGE := Color("ff8c42")
const PURPLE := Color("7b2cbf")
const CREAM := Color("fff3d6")
const INK := Color("1a1a1f")

static var _cache := {}


## Aplica o material toon em todas as malhas abaixo de `root` (inclusive).
static func toonify(root: Node) -> void:
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for node: MeshInstance3D in meshes:
		if node.mesh == null:
			continue
		for i in node.mesh.get_surface_count():
			var source := node.get_active_material(i)
			if source != null and source.resource_name != SCREEN:
				node.set_surface_override_material(i, material_for(source))


## Material toon com a cor (e o brilho, pelo nome) do material importado.
static func material_for(source: Material) -> Material:
	var key := source.resource_name
	if key != "" and _cache.has(key):
		return _cache[key]
	var color := Color.WHITE
	if source is BaseMaterial3D:
		color = (source as BaseMaterial3D).albedo_color
	var mat := ShaderMaterial.new()
	mat.shader = TOON
	mat.set_shader_parameter("albedo", color)
	if key.begins_with(GLOW_PREFIX):
		mat.set_shader_parameter("emission", color * GLOW_ENERGY)
	if key == MIRROR:
		mat.set_shader_parameter("sparkle", 1.0)
	if key != "":
		_cache[key] = mat
	return mat
