extends Node3D

const Veil = preload("res://art_kit/families/F08_open_veil/F08_open_veil.tscn")
const Setup = preload("res://art_lab/f08/lab_setup.gd")
const ANGLES = [0, 90, 180, 34]
const CUTS = [.25,.55,.85]
const CLIPS = ["F08-01","F08-02","F08-04","F08-05","F08-06"]
var veil = Veil.instantiate()
var camera := Camera3D.new()
var landmarks := Node3D.new()
var output := ""
var checks: Array = []
var geometry: Array = []
var failed := false


func _ready() -> void:
	Setup.neutral(self)
	add_child(landmarks)
	for x in [-2.25, -.86, .81, 2.2]:
		for i in 3:
			Setup.box(landmarks,Vector3(x+i*.07,1.55,-1.38),Vector3(.065,3.1,.10),
				[Color("#635f5a"),Color("#aaa69e"),Color("#787772")][i])
	Setup.box(landmarks, Vector3(0,.67,-1.4), Vector3(6.0,.045,.12), Color("#999385"))
	add_child(veil)
	veil.set_process(false)
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	frame(12)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			output = arg.trim_prefix("--shots=")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		call_deferred("review")


func frame(degrees: float, focus := Vector3(0,1.64,0), size := 4.0) -> void:
	camera.size = size
	camera.position = focus + Vector3(0,.56,8).rotated(Vector3.UP,deg_to_rad(degrees))
	camera.look_at(focus)


func shot(file: String) -> void:
	for i in 2:
		await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	picture.convert(Image.FORMAT_RGB8)
	picture.resize(960,540,Image.INTERPOLATE_LANCZOS)
	if picture.save_png(output.path_join(file+".png")) != OK:
		failed = true


func review() -> void:
	var gray := StandardMaterial3D.new()
	gray.albedo_color = Color("#a3a3a3")
	gray.roughness = .84
	landmarks.visible = false
	for cut in ["ArcVeil","FlatVeil"]:
		veil.configure("P19",cut)
		var mesh: ArrayMesh = veil.cloth.mesh
		var arrays := mesh.surface_get_arrays(0)
		var names := []
		for i in mesh.get_blend_shape_count():
			names.append(str(mesh.get_blend_shape_name(i)))
		geometry.append({"form":cut,"vertices":arrays[Mesh.ARRAY_VERTEX].size(),
			"uv0_count":arrays[Mesh.ARRAY_TEX_UV].size(),"uv1_count":arrays[Mesh.ARRAY_TEX_UV2].size(),
			"keys":names,"local_bounds":str(mesh.get_aabb())})
		veil.cloth.material_override = gray
		for angle in ANGLES:
			frame(angle)
			await shot("gray_%s_%s" % [cut,angle])
		veil.cloth.material_override = veil.material
	landmarks.visible = true
	frame(12)
	for pack in ["P19","P04","P03"]:
		veil.configure(pack,"ArcVeil")
		await shot(pack)
		if pack == "P04":
			frame(12,Vector3(.73,1.14,0),1.47)
			await shot("P04_detail")
			frame(12)
	landmarks.visible = false
	veil.configure("P19","ArcVeil")
	for clip in ["F08-01","F08-02","F08-05","F08-06"]:
		await interruptions(clip)
	# Use a laterally guided physical specimen for repeatable local load.
	# Pause on a real manifold. All loaded stills sample this one solver state.
	veil.enter("F08-04",1,null,true)
	var body := Setup.barrier(self,veil.cloth)
	body.collision_layer = 4
	var cfg := {"mass_kg":7,"capacity_kg":10,"start":[.70,1.18,1.45],"gravity_scale":0,
		"force_z":-7.0,"speed_z":-2.80}
	var stone = Setup.launch(self,cfg,body,veil)
	stone.axis_lock_linear_x = true
	stone.axis_lock_linear_y = true
	stone.lock_rotation = true
	for i in 180:
		await get_tree().physics_frame
		if stone.measured > 0:
			break
	if not is_equal_approx(stone.measured,.7):
		push_error("Calibration specimen did not contact the membrane")
		get_tree().quit(1)
		return
	get_tree().paused = true
	landmarks.visible = true
	await shot("P19_load")
	frame(12,stone.last_point,1.90)
	await shot("X13_detail")
	frame(12)
	landmarks.visible = false
	await interruptions("F08-04",stone)
	var measured: float = stone.measured
	var hit: Vector3 = stone.last_point
	veil.configure("P03","ArcVeil")
	veil.set_contact(hit,measured)
	if veil.load_ratio != 0 or veil.flex != 0:
		failed = true
	var out := FileAccess.open(output.path_join("bench.json"),FileAccess.WRITE)
	out.store_string(JSON.stringify({"engine":Engine.get_version_info().string,
		"renderer":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name(),
		"measured_load":measured,"measured_contact":[hit.x,hit.y,hit.z],"P03_stale_receipt":veil.load_ratio,
		"geometry":geometry,"cuts":checks,"passed":not failed},"\t"))
	out.close()
	get_tree().paused = false
	get_tree().quit(1 if failed else 0)


func interruptions(clip: String, specimen = null) -> void:
	for cut in CUTS:
		var prefix := "%s_%02d" % [clip, roundi(cut*100)]
		for ending in ["F08-05","F08-06"]:
			# Rewind the visual experiment to the same initial clock on each fork.
			veil.art_clock = 0.0
			veil.contact_age = 0.0
			if specimen:
				specimen.visible = true
				veil.set_contact(specimen.last_point,specimen.measured)
			veil.enter(clip,1,null,true)
			veil.advance(cut)
			if ending == "F08-05":
				await shot(prefix+"_entry")
			var before: Vector4 = veil.pose
			var erosion: float = veil.erosion
			var flex: float = veil.flex
			var clock: float = veil.art_clock
			veil.enter(ending,1)
			var delta := maxf(before.distance_to(veil.pose),maxf(absf(veil.erosion-erosion),absf(veil.flex-flex)))
			if delta > .00001 or veil.art_clock != clock:
				failed = true
			# The two outgoing previews release the sampled receipt after measuring
			# the instantaneous handoff. The physics specimen remains paused.
			if specimen:
				veil.set_contact(Vector3.ZERO,0.0)
				specimen.visible = false
			veil.advance(.42)
			checks.append({"clip":clip,"cut":cut,"into":ending,"max_entry_jump":delta,
				"pose_before":[before.x,before.y,before.z,before.w],"source_flex":flex,"source_load":specimen.measured if specimen else 0.0,
				"pose_after_420ms":[veil.pose.x,veil.pose.y,veil.pose.z,veil.pose.w],
				"art_clock_delta":veil.art_clock-clock,"load_ratio":veil.load_ratio})
			await shot(prefix+"_"+ending)
