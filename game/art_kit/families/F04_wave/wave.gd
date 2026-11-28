extends Node3D
const ARC = "res://art_kit/families/F03_arc_blade/"
const FLOW = preload(ARC + "textures/energy_flow.png")
const MASK = preload(ARC + "textures/erosion_mask.png")
var skin := ShaderMaterial.new()
var dust := ShaderMaterial.new()
var art_clock := 0.
var threshold := -.035
var at_cut := -.035
var fall := 0.
var fall_at_cut := 0.
var tail := -1.
var dust_level := 0.
var dust_at_cut := 0.
var ground_feedback := false
@onready var lip: MeshInstance3D = $Carrier/Breaker
@onready var skirt: MeshInstance3D = $Carrier/DustFoot


func _ready() -> void:
	skin.shader = preload(ARC + "arc_blade.gdshader")
	for pair in [
		["flow_map", FLOW],
		["erosion_map", MASK],
		["closed_front", true],
		["retreat", 0.],
		["edge_gain", 1.85],
		["reveal", 1.05]
	]:
		skin.set_shader_parameter(pair[0], pair[1])
	dust.shader = preload("res://art_kit/families/F04_wave/dust.gdshader")
	dust.set_shader_parameter("grains", FLOW)
	skirt.material_override = dust
	for mesh in [lip, skirt]:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	configure("P15", true)
	realized(.2, 0., 0.)


func configure(pack: String, ground: bool) -> void:
	ground_feedback = ground
	lip.material_override = skin
	skin.set_shader_parameter("gray_preview", pack == "Gray")
	skin.set_shader_parameter("optical_pack", {"P01": 0, "P04": 1, "P15": 2, "Gray": 0}[pack])
	skin.set_shader_parameter("distortion", .057)
	skin.set_shader_parameter("flow_speed", 2.6 if pack == "P15" else .85)


func realized(radius: float, opening: float, dust_weight: float) -> void:
	$Carrier.scale = Vector3(radius, minf(2.5, radius), radius)
	lip.set_blend_shape_value(0, 1. - opening)
	skirt.set_blend_shape_value(0, 1. - opening)
	dust_level = dust_weight
	skirt.visible = ground_feedback and dust_level > .001
	dust.set_shader_parameter("strength", dust_level)


func finish(_reason: String) -> void:
	at_cut = threshold
	fall_at_cut = fall
	dust_at_cut = dust_level
	tail = 0.


func sample_tail(t: float) -> void:
	threshold = lerpf(at_cut, 1.055, t)
	fall = lerpf(fall_at_cut, 1., smoothstep(0., 1., t))
	skin.set_shader_parameter("erosion", threshold)
	lip.set_blend_shape_value(1, fall)
	skirt.set_blend_shape_value(1, fall)
	dust.set_shader_parameter("strength", dust_at_cut * (1. - t))


func _process(dt: float) -> void:
	art_clock += dt
	skin.set_shader_parameter("art_clock", art_clock)
	dust.set_shader_parameter("art_clock", art_clock)
	if tail >= 0.:
		tail += dt
		sample_tail(minf(1., tail / .88))
		if tail >= .88:
			queue_free()


func inspect_state(index: int, p: float, pack: String) -> void:
	configure(pack, false)
	threshold = -.035
	fall = 0.
	tail = -1.
	skin.set_shader_parameter("erosion", threshold)
	skin.set_shader_parameter("art_clock", p)
	lip.set_blend_shape_value(1, 0.)
	match index:
		0:
			realized(lerpf(1.28, .32, p), .15 * p, 0.)
		1:
			realized(lerpf(.32, 2.08, p), p, 0.)
		2:
			realized(2.08, 1., 0.)
			finish("completed")
			sample_tail(p)
			tail = -1.
