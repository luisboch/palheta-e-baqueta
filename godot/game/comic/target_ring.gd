## O anel em volta do alvo de uma lane, na linha de acerto: aceso, com uma faixa de luz correndo
## pela lane, enquanto o traste está apertado; no acerto, uma onda de choque e faíscas na cor da
## lane. Só desenha: quem decide é a Highway.
class_name TargetRing
extends Node3D

const IDLE_GLOW := 0.5  ## brilho do aro parado
const PRESSED_GLOW := 3.5  ## brilho do aro com o traste apertado
const LANE_ALPHA := 0.18  ## faixa de luz na lane com o traste apertado
const WAVE_TIME := 0.25  ## s da onda de choque
const WAVE_SCALE := 2.6  ## a onda cresce até este tamanho, sumindo

var _rim_material := StandardMaterial3D.new()
var _lane_material := StandardMaterial3D.new()
var _wave_material := StandardMaterial3D.new()
var _spark_material := StandardMaterial3D.new()

@onready var _rim: MeshInstance3D = $Rim
@onready var _lane: MeshInstance3D = $Lane
@onready var _wave: MeshInstance3D = $Wave
@onready var _sparks: CPUParticles3D = $Sparks


func _ready() -> void:
	_rim_material.albedo_color = Comic.INK
	_rim_material.emission_enabled = true
	for mat: StandardMaterial3D in [_lane_material, _wave_material, _spark_material]:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_lane_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_spark_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_spark_material.vertex_color_use_as_albedo = true
	_rim.material_override = _rim_material
	_lane.material_override = _lane_material
	_wave.material_override = _wave_material
	(_sparks.mesh as QuadMesh).material = _spark_material
	set_color(Comic.CREAM)
	set_pressed(false)


func set_color(color: Color) -> void:
	_rim_material.emission = color
	_lane_material.albedo_color = Color(color, LANE_ALPHA)
	_wave_material.albedo_color = color
	_sparks.color = color.lightened(0.3)


func set_pressed(on: bool) -> void:
	_rim_material.emission_energy_multiplier = PRESSED_GLOW if on else IDLE_GLOW
	_lane.visible = on


## O acerto: onda de choque e faíscas.
func hit() -> void:
	_wave.visible = true
	_wave.scale = Vector3.ONE
	_wave_material.albedo_color.a = 1.0
	var tween := create_tween().set_parallel()
	tween.tween_property(_wave, "scale", Vector3.ONE * WAVE_SCALE, WAVE_TIME).set_ease(
		Tween.EASE_OUT
	)
	tween.tween_property(_wave_material, "albedo_color:a", 0.0, WAVE_TIME)
	tween.chain().tween_callback(_wave.hide)
	_sparks.restart()
