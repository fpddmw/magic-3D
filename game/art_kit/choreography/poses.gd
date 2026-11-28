extends RefCounted

# Local anatomical rotations in degrees, mirrored for left / right limbs.
# [spine pitch, chest roll, head pitch, arm elevation, elbow pitch, knee, mantle]
const POSES := {
	"gather":
	[[0, 0, 0, 0, 0, 0, 0], [12, -8, -9, 24, -39, 15, 12], [5, -12, -16, 56, -54, 18, 21]],
	"open":
	[[5, -12, -16, 56, -54, 18, 21], [-3, -7, -20, 84, -33, 9, 18], [-7, -4, -24, 109, -17, 5, 26]],
	"loft":
	[
		[-7, -4, -24, 109, -17, 5, 26],
		[-9, -5, -27, 121, -26, 13, 37],
		[-7, -7, -21, 115, -24, 15, 34]
	],
	"release":
	[[-7, -7, -21, 115, -24, 15, 34], [11, 14, -7, 65, -58, 16, 43], [3, 9, -12, 27, -29, 8, 17]],
	"sweep":
	[[5, -18, -5, 32, -17, 8, 11], [-6, 22, -13, 89, -44, 13, 30], [7, 6, -4, 25, -23, 8, 9]],
	"stagger":
	[[1, 0, 0, 8, -7, 0, 6], [-14, 20, 10, 71, -50, 24, 43], [8, -10, 9, 27, -32, 27, 14]]
}


static func rotations(bone: String, p: Array) -> Vector3:
	var side := -1.0 if bone.ends_with("L") else 1.0
	if bone == "Spine":
		return Vector3(p[0], p[1] * .28, p[1] * .35)
	if bone == "Chest":
		return Vector3(p[0] * .32, p[1] * .9, p[1] * .28)
	if bone == "Head":
		return Vector3(p[2], -p[1] * .52, 0)
	if bone.begins_with("Shoulder"):
		return Vector3(-p[3] * .18, side * -p[3] * .13, side * p[3] * (.78 if side < 0 else 1.0))
	if bone.begins_with("Elbow"):
		return Vector3(p[4], side * p[4] * .18, side * p[3] * .13)
	if bone.begins_with("Hand"):
		return Vector3(-p[4] * .64, 0, -side * p[3] * .66)
	if bone.begins_with("Thigh"):
		return Vector3(-p[5] * .67, 0, side * p[5] * .12)
	if bone.begins_with("Knee"):
		return Vector3(p[5], 0, 0)
	if bone.begins_with("Foot"):
		return Vector3(-p[5] * .33, 0, 0)
	if bone == "Mantle":
		return Vector3(p[6] * .55, 0, p[1] * .5)
	if bone == "Hem":
		return Vector3(p[6] * .65, p[1] * .22, 0)
	return Vector3.ZERO


static func rig(actor: Node3D) -> AnimationTree:
	var skeleton := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := AnimationPlayer.new()
	actor.add_child(player)
	var library := AnimationLibrary.new()
	var root := AnimationNodeBlendTree.new()
	var selector := AnimationNodeTransition.new()
	selector.input_count = POSES.size()
	root.add_node("Pose", selector)
	root.connect_node("output", 0, "Pose")
	for index in POSES.size():
		var key: String = POSES.keys()[index]
		var clip := Animation.new()
		clip.length = 1.0
		for joint in skeleton.get_bone_count():
			var name := String(skeleton.get_bone_name(joint))
			var track := clip.add_track(Animation.TYPE_ROTATION_3D)
			clip.track_set_path(track, NodePath(String(actor.get_path_to(skeleton)) + ":" + name))
			var values: Array = POSES[key]
			for i in values.size():
				clip.rotation_track_insert_key(
					track,
					[0.0, .55, 1.0][i],
					Quaternion.from_euler(rotations(name, values[i]) * PI / 180.0)
				)
		library.add_animation(key, clip)
		var node := AnimationNodeAnimation.new()
		node.animation = key
		root.add_node(key, node)
		root.connect_node("Pose", index, key)
		selector.set_input_name(index, key)
	player.add_animation_library("", library)
	var seek := AnimationNodeTimeSeek.new()
	root.disconnect_node("output", 0)
	root.add_node("Cursor", seek)
	root.connect_node("Cursor", 0, "Pose")
	root.connect_node("output", 0, "Cursor")
	var tree := AnimationTree.new()
	actor.add_child(tree)
	tree.anim_player = tree.get_path_to(player)
	tree.tree_root = root
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.active = true
	return tree


static func sample(tree: AnimationTree, key: String, phase: float) -> void:
	tree.set("parameters/Pose/transition_request", key)
	tree.set("parameters/Cursor/seek_request", clampf(phase, 0, 1))
	tree.advance(0)
