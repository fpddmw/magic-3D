extends Node3D

const PACKS = {
	"P19": [Color("#d1c3aa"), Color("#e2cda7"), .59, .0, .0, .32, true],
	"P04": [Color("#799796"), Color("#9cbabf"), .87, .037, .0, .095, true],
	"P03": [Color("#242331"), Color("#686477"), .87, .0, .95, .068, false],
}
const START = {
	"F08-01": Vector4(1, 0, 0, 0), "F08-02": Vector4(0, 1, 0, 0),
	"F08-04": Vector4.ZERO, "F08-05": Vector4.ZERO, "F08-06": Vector4.ZERO
}
const TARGET = {
	"F08-01": Vector4.ZERO, "F08-02": Vector4.ZERO, "F08-04": Vector4.ZERO,
	"F08-05": Vector4(0, 0, 1, 0), "F08-06": Vector4(0, 0, 0, 1)
}
const SHAPES = ["unfold_from_line", "rise_from_ground", "fracture_open", "retract_to_root"]
@export var base_material: ShaderMaterial
@onready var player: AnimationPlayer = $AnimationPlayer
var material: ShaderMaterial
var cloth: MeshInstance3D
var cuts: Array[MeshInstance3D] = []
var active_clip := ""
var duration := 1.0
var elapsed := 0.0
var art_clock := 0.0
var time_curve: Curve
var progress := 0.0
var handling := 1.0
var entry_handling := 1.0
var grip := 1.0
var pose := Vector4.ZERO
var destination := Vector4.ZERO
var origin := Vector4.ZERO
var erosion := 0.0
var origin_erosion := 0.0
var end_erosion := 0.0
var load_ratio := 0.0
var contact_local := Vector3.ZERO
var contact_age := 0.0
var accepts_load := true
var flex := 0.0


func _ready() -> void:
	cuts.assign($Carrier.find_children("*", "MeshInstance3D", true, false))
	material = base_material.duplicate()
	for cut in cuts:
		cut.material_override = material
		cut.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	configure("P19", "ArcVeil")


func configure(pack: String, form: String) -> void:
	var p: Array = PACKS[pack]
	for i in 6:
		material.set_shader_parameter(["silk_dye","selvage","density","distortion","absorption","edge_gain"][i], p[i])
	accepts_load = p[6]
	for cut in cuts:
		cut.visible = cut.name == form
		if cut.visible:
			cloth = cut
	set_contact(Vector3.ZERO, 0.0)
	_apply_pose()


func enter(clip: String, seconds: float, curve: Curve = null, fresh := false) -> void:
	if fresh or active_clip.is_empty():
		pose = START[clip]
		erosion = 0.0
	entry_handling = 1.0 if fresh else grip
	origin = pose
	destination = TARGET[clip]
	if clip == "F08-05":
		destination = origin
		var visible_span := 1.0 - maxf(origin.x, maxf(origin.y, origin.w))
		destination.z += (1.0-origin.z) * visible_span
	elif clip == "F08-06":
		destination.x = origin.x
	origin_erosion = erosion
	end_erosion = erosion if clip == "F08-06" else (0.94 if clip == "F08-05" else 0.0)
	active_clip = clip
	duration = maxf(seconds, .001)
	time_curve = curve
	elapsed = 0.0
	player.play(clip)
	sample_phase(0.0)


func sample_phase(unit_time: float) -> void:
	var t := clampf(unit_time, 0, 1)
	if time_curve:
		t = clampf(time_curve.sample_baked(t), 0, 1)
	player.seek(t, true)
	grip = lerpf(entry_handling, handling, smoothstep(0, .2, t))
	pose = origin.lerp(destination, progress)
	erosion = lerpf(origin_erosion, end_erosion, progress)
	_apply_pose()


func advance(delta: float) -> void:
	art_clock += delta
	contact_age += delta
	material.set_shader_parameter("art_clock", art_clock)
	elapsed += delta
	if not active_clip.is_empty():
		sample_phase(elapsed / duration)


func _process(delta: float) -> void:
	advance(delta)


# Feed once per physics tick; zero clears the receipt immediately. No clip
# changes a collision layer or produces a receipt. P03 rejects even stale input.
func set_contact(world_point: Vector3, ratio: float) -> void:
	var next := clampf(ratio, 0, 1) if accepts_load else 0.0
	if load_ratio <= 0.0 and next > 0.0:
		contact_age = 0.0
	if next > 0.0:
		contact_local = to_local(world_point)
	load_ratio = next
	material.set_shader_parameter("load_ratio", load_ratio)
	material.set_shader_parameter("contact_local", contact_local)
	_apply_flex()


func _apply_flex() -> void:
	var spring := .61 + .39*exp(-3.8*contact_age)*cos(13.0*contact_age)
	flex = load_ratio * spring * grip
	cloth.set_blend_shape_value(cloth.find_blend_shape_by_name("load_bulge"), flex)
	material.set_shader_parameter("flex", flex)


func _apply_pose() -> void:
	for i in SHAPES.size():
		cloth.set_blend_shape_value(cloth.find_blend_shape_by_name(SHAPES[i]), pose[i])
	material.set_shader_parameter("erosion_threshold", erosion)
	material.set_shader_parameter("closure", pose.w)
	_apply_flex()
