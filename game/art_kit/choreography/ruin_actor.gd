extends Node3D
## Root motion stays visual. The hand socket is sampled after posing and sole alignment.
const ASTRONOMER = preload("res://assets/models/astronomer.glb")
const DRESS = preload("res://art_kit/choreography/astronomer.gd")
const POSES = preload("res://art_kit/choreography/poses.gd")
# Spine, twist, head, shoulder, elbow, knees, cloak. Four anatomical beats per action.
const BEATS = {
	"B02":
	[
		[4, -8, -2, 13, -18, 12, 3],
		[22, -32, 11, 51, -67, 39, 13],
		[17, -38, 5, 72, -83, 46, 20],
		[-8, 27, -10, 91, -22, 14, 34]
	],
	"B07":
	[
		[6, -20, 3, 30, -32, 12, 8],
		[11, -42, -8, 72, -54, 28, 17],
		[-8, 32, -13, 101, -18, 13, 32],
		[8, 49, 1, 57, -35, 20, 25]
	],
	"B08":
	[
		[2, 0, 4, 17, -20, 10, 4],
		[15, -9, 6, 46, -64, 30, 9],
		[3, 4, -6, 66, -42, 23, 14],
		[-11, 12, -11, 85, -10, 12, 24]
	],
	"B05":
	[
		[6, 0, 6, 12, -16, 16, 3],
		[26, -8, 18, 25, -71, 54, 12],
		[8, -5, -12, 61, -65, 37, 20],
		[-12, 7, -19, 99, -38, 18, 28]
	]
}
var artist: Node3D
var skeleton: Skeleton3D
var rest_ankle: float


func _ready() -> void:
	artist = ASTRONOMER.instantiate()
	add_child(artist)
	artist.rotation.y = PI
	DRESS.dress(artist)
	skeleton = artist.find_children("*", "Skeleton3D", true, false)[0]
	rest_ankle = minf(joint("FootL").y, joint("FootR").y) - global_position.y
	pose("B07", 0., 0.)


func joint(label: String) -> Vector3:
	return skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone(label)).origin)


func pose(intent: String, phase: float, strength := 1.) -> void:
	var f := clampf(phase, 0., 1.) * 3.
	var a := mini(2, floori(f))
	var mix_weight := smoothstep(0., 1., f - a)
	var values: Array = []
	for j in 7:
		values.append(lerpf(BEATS[intent][a][j], BEATS[intent][a + 1][j], mix_weight) * strength)
	artist.position = Vector3.ZERO
	for i in skeleton.get_bone_count():
		var label := String(skeleton.get_bone_name(i))
		var deg := POSES.rotations(label, values)
		var side := 1. if label.ends_with("L") else -1.
		if label.begins_with("Thigh"):
			deg.x += side * (12. + absf(values[1]) * .44) * strength
			deg.z += side * (6. + values[5] * .13) * strength
		if label.begins_with("Shoulder"):
			deg.x -= values[3] * (.73 if intent in ["B08", "B05"] else .41)
			deg.y += side * values[1] * (1.1 if intent == "B07" else .52)
		skeleton.set_bone_pose_rotation(i, Quaternion.from_euler(deg * PI / 180.))
	skeleton.force_update_all_bone_transforms()
	var ankle := minf(joint("FootL").y, joint("FootR").y) - global_position.y
	artist.position = Vector3(values[1] * .002, rest_ankle - ankle - .04, -values[0] * .003)
