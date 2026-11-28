extends Node3D

const Stage = preload("res://art_lab/scenes/stage.gd")
const Actor = preload("res://assets/models/astronomer.glb")
const B03 = preload("res://art_kit/families/F08_open_veil/B03_dual_open.tres")
const Setup = preload("res://art_lab/f08/lab_setup.gd")
const Veil = preload("res://art_kit/families/F08_open_veil/F08_open_veil.tscn")
const FAMILY := "res://art_kit/families/F08_open_veil/"
var veil = Veil.instantiate()
var camera := Camera3D.new()
var body: StaticBody3D
var stone
var dust: CPUParticles3D
var rig := AnimationPlayer.new()
var skeleton: Skeleton3D
var recipe: Dictionary
var recipe_path := "res://art_lab/f08/recipes/v1_load.json"
var output := ""
var tick := 0
var clip_index := -1
var b03_index := 0
var trace: Array = []
var handoffs: Array = []
var peak_load := 0.0
var last_ratio := 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--recipe="):
			recipe_path = arg.trim_prefix("--recipe=")
		if arg.begins_with("--observations="):
			output = arg.trim_prefix("--observations=")
	recipe = JSON.parse_string(FileAccess.get_file_as_string(recipe_path))
	add_child(Stage.new())
	var actor: Node3D = Actor.instantiate()
	actor.position = Vector3(-3.37,0,1.42)
	actor.rotation.y = .52
	add_child(actor)
	preload("res://art_kit/choreography/astronomer.gd").dress(actor)
	skeleton = actor.find_children("*", "Skeleton3D", true, false)[0]
	actor.add_child(rig)
	rig.root_node = rig.get_path_to(skeleton)
	rig.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var library := AnimationLibrary.new()
	library.add_animation("B03",B03)
	rig.add_animation_library("",library)
	rig.play("B03")
	add_child(veil)
	veil.position.y = recipe.anchor_y_m
	veil.set_process(false)
	veil.configure(recipe.pack, recipe.form)
	body = Setup.barrier(self, veil.cloth)
	body.get_child(0).disabled = int(recipe.collision.layer) == 0
	dust = Setup.root_dust(self)
	add_child(camera)
	camera.fov = 35
	camera.position = Vector3(3.45,2.12,7.7)
	camera.look_at(Vector3(-.40,1.37,0))
	camera.current = true


func _physics_process(delta: float) -> void:
	var t := float(tick) / Engine.physics_ticks_per_second
	if clip_index+1 < recipe.clips.size() and t >= float(recipe.clips[clip_index+1].at):
		clip_index += 1
		var event: Dictionary = recipe.clips[clip_index]
		var curve: Curve = null if event.curve == "" else load(FAMILY+event.curve)
		var previous: Vector4 = veil.pose
		veil.enter(event.clip, event.duration, curve)
		handoffs.append({"t":t,"clip":event.clip,"entry":pose_array(veil.pose),
			"jump":previous.distance_to(veil.pose) if clip_index else 0.0})
	body.collision_layer = int(recipe.collision.layer) if t >= recipe.collision.active_from and t <= recipe.collision.active_to else 0
	if stone == null and not recipe.stone.is_empty() and t >= recipe.stone.at:
		stone = Setup.launch(self, recipe.stone, body, veil)
	if not recipe.dust_window.is_empty():
		dust.emitting = t >= recipe.dust_window[0] and t < recipe.dust_window[1]
	if b03_index+1 < recipe.b03.size() and t >= recipe.b03[b03_index+1].at:
		b03_index += 1
	var gesture: Dictionary = recipe.b03[b03_index]
	var gesture_phase := smoothstep(0,gesture.duration,t-float(gesture.at))
	rig.seek(lerpf(gesture.from_s, gesture.to_s, gesture_phase), true)
	var angle := lerpf(.19,.71,smoothstep(2.35,5.35,t))
	var frame_center := Vector3(-.52,1.47,0)
	camera.position = frame_center + Vector3(0,.94,8.53).rotated(Vector3.UP,angle)
	camera.look_at(frame_center)
	veil.advance(delta)
	peak_load = maxf(peak_load,veil.load_ratio)
	if not output.is_empty() and (tick % 3 == 0 or last_ratio != veil.load_ratio):
		var row := {"tick":tick,"clip":veil.active_clip,"load_ratio":veil.load_ratio,"flex":veil.flex,
			"dust":dust.emitting,"gesture":gesture.pose,"collision_layer":body.collision_layer,"pose":pose_array(veil.pose),
			"hand_span_m":skeleton.get_bone_global_pose(skeleton.find_bone("HandL")).origin.distance_to(
				skeleton.get_bone_global_pose(skeleton.find_bone("HandR")).origin)}
		if stone:
			row.merge({"stone_xyz":vec3(stone.position),"velocity":vec3(stone.linear_velocity),"contact_ticks":stone.contact_ticks})
			if veil.load_ratio > 0:
				row.merge({"contact_xyz":vec3(stone.last_point),"normal":vec3(stone.last_normal),"impulse":vec3(stone.last_impulse)})
		trace.append(row)
	last_ratio = veil.load_ratio
	tick += 1
	if t >= recipe.seconds:
		if not output.is_empty():
			var log_file := FileAccess.open(output, FileAccess.WRITE)
			log_file.store_string(JSON.stringify({"recipe":recipe_path,"engine":Engine.get_version_info().string,
				"device":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),
				"physics":ProjectSettings.get_setting("physics/3d/physics_engine"),"peak_load":peak_load,
				"contact_ticks":stone.contact_ticks if stone else 0,"handoffs":handoffs,"samples":trace},"\t"))
		get_tree().quit()


func pose_array(v: Vector4) -> Array:
	return [v.x,v.y,v.z,v.w]


func vec3(v: Vector3) -> Array:
	return [v.x,v.y,v.z]
