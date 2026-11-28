@tool
extends Node3D

const HERE = "res://art_kit/families/F03_arc_blade/"
const SHADER = preload(HERE + "arc_blade.gdshader")
const FLOW = preload(HERE + "textures/energy_flow.png")
const MASK = preload(HERE + "textures/erosion_mask.png")
const AIR = preload("res://assets/audio/observatory/release.wav")
const CHARGE = preload("res://assets/audio/observatory/foundation.wav")
const CONTACT = preload("res://assets/audio/observatory/stone_contact.wav")
@export_enum("narrow_edge","wide_crescent") var form := "narrow_edge"
@export_enum("P01","P04","P15") var palette := "P01"
@export_range(.2,7.,.05,"suffix:m") var width_m := 3.8
@export_range(45.,160.,1.,"degrees") var span_deg := 134.
@export_range(0.,3.,.01) var flow_speed := 1.
@export_range(0.,3.,.01) var edge_gain := 1.3
@export_range(0.,2.,.01) var density := 1.
@export_range(0.,.08,.001) var distortion := .031
var inspector_state: Array = []
var cfg: Dictionary
var skin := ShaderMaterial.new()
var blade: MeshInstance3D
var opening: Curve
var hold: Curve
var art_clock := 0.
var exit_clock := -1.
var flash_clock := -1.
var ending := ""
var erosion_at_exit := -.035
var retract_at_exit := 0.
var shape_indices := {}
var camera_weight := 0.
var pressure := 0.
var travel := false
var reveal := 0.

# A placed instance opens directly as a live silver blade in any 3D scene.
# An owner can then supply a recipe, socket transform and committed physics events.
func _ready() -> void:
	apply_inspector_values()


func apply_inspector_values() -> void:
	inspector_state = [form,palette,width_m,span_deg,flow_speed,edge_gain,density,distortion]
	configure({"curve_id":"C01","form":form,"palette":palette,"distortion":distortion,
		"edge_gain":edge_gain,"flow_speed":flow_speed,"density":density,"weight":0.,"env_weight":0.,"air_db":-4.,
		"air_pitch":1.,"tail_s":.75},width_m*.5,inverse_lerp(45.,160.,span_deg))
	prepare(1.,0.)

func configure(profile: Dictionary, radius: float, arc_mix: float) -> void:
	cfg = profile
	opening = load("res://art_kit/curves/" + cfg.curve_id + ".tres")
	hold = load("res://art_kit/curves/C05.tres")
	blade = $Carrier.get_node(cfg.form)
	for node in $Carrier.get_children():
		node.visible = node == blade
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blade.scale = Vector3.ONE * radius
	blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in blade.get_blend_shape_count():
		shape_indices[blade.mesh.get_blend_shape_name(i)] = i
	skin.shader = SHADER
	blade.material_override = skin
	skin.set_shader_parameter("gray_preview",cfg.palette=="Gray")
	skin.set_shader_parameter("flow_map", FLOW)
	skin.set_shader_parameter("erosion_map", MASK)
	skin.set_shader_parameter("optical_pack", 0 if cfg.palette=="P01" else (2 if cfg.palette=="P15" else 1))
	skin.set_shader_parameter("distortion",cfg.distortion)
	skin.set_shader_parameter("edge_gain", cfg.edge_gain)
	skin.set_shader_parameter("flow_speed", cfg.flow_speed)
	skin.set_shader_parameter("mist_density",cfg.get("density",1.))
	skin.set_shader_parameter("central_gather",cfg.get("formation","edge_draw")=="gather_in_place")
	blade.set_blend_shape_value(shape_indices.arc_open, arc_mix)
	skin.set_shader_parameter("erosion",-.035)
	prepare(0., 0.)
	if cfg.weight > .65:
		voice(CHARGE, -6., .88)

func voice(clip: AudioStream, db: float, pitch: float) -> void:
	if Engine.is_editor_hint() or DisplayServer.get_name() == "headless":
		return
	$Voice.stream = clip
	$Voice.volume_db = db
	$Voice.pitch_scale = pitch
	$Voice.play()

func prepare(fraction: float, apex: float) -> void:
	reveal = opening.sample_baked(clampf(fraction,0.,1.))
	skin.set_shader_parameter("reveal", reveal*1.035)
	blade.set_blend_shape_value(shape_indices.unfold_root_to_tip, 1.-reveal)
	blade.set_blend_shape_value(shape_indices.sweep_bend, reveal*.52)
	camera_weight = smoothstep(.65,.95,cfg.weight)*reveal
	pressure = cfg.env_weight * (reveal + .18*hold.sample_baked(apex))

func launch() -> void:
	travel = true
	reveal = 1.
	camera_weight = 0.
	pressure = 0.
	blade.set_blend_shape_value(shape_indices.sweep_bend, 0.)
	blade.set_blend_shape_value(shape_indices.unfold_root_to_tip, 0.)
	skin.set_shader_parameter("reveal", 1.035)
	$Wake.emitting = cfg.palette == "P01"
	voice(AIR, cfg.air_db, cfg.air_pitch)

func contact(point: Vector3, normal: Vector3, along: float) -> void:
	$Contact.global_position = point + normal*.012
	$Contact.global_basis = Basis(Quaternion(Vector3.UP, normal.normalized()))
	$Contact.restart()
	$Contact.emitting = true
	flash_clock = 0.
	skin.set_shader_parameter("contact_u",along)
	if Engine.is_editor_hint() or DisplayServer.get_name() == "headless":
		return
	$Contact/Stone.stream = CONTACT
	$Contact/Stone.volume_db = -2.
	$Contact/Stone.play()

func finish(reason: String) -> void:
	if exit_clock >= 0.:
		return
	ending = reason
	erosion_at_exit = skin.get_shader_parameter("erosion")
	retract_at_exit = blade.get_blend_shape_value(shape_indices.edge_retract)
	exit_clock = 0.
	camera_weight = 0.
	pressure = 0.
	$Wake.emitting = false
	if not travel:
		$Voice.stop()

func _process(dt: float) -> void:
	if Engine.is_editor_hint() and inspector_state != [form,palette,width_m,span_deg,flow_speed,edge_gain,density,distortion]:
		apply_inspector_values()
	if not blade:
		return
	art_clock += dt
	skin.set_shader_parameter("art_clock", art_clock)
	if flash_clock >= 0.:
		flash_clock += dt
		$Contact/Flash.light_energy = 4.5 * exp(-flash_clock*27.)
	if exit_clock < 0.:
		return
	exit_clock += dt
	var t := clampf(exit_clock/cfg.tail_s, 0., 1.)
	sample_tail(t)
	if t >= 1.:
		blade.visible = false
		if not $Contact/Stone.playing and not $Voice.playing and not $Contact.emitting:
			queue_free()

func sample_tail(t: float) -> void:
	if ending == "released":
		var retract := lerpf(retract_at_exit,1.,smoothstep(0.,1.,t))
		skin.set_shader_parameter("retreat", retract)
		blade.set_blend_shape_value(shape_indices.edge_retract, retract)
	else:
		var erosion := lerpf(erosion_at_exit, 1.05, pow(t,.80 if ending=="interrupted" else 1.15))
		skin.set_shader_parameter("erosion",erosion)
