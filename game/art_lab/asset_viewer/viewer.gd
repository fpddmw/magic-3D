extends Node3D

const ARC = preload("res://art_kit/families/F03_arc_blade/F03_arc_blade.tscn")
const PACKS = ["Gray", "P01", "P04", "P15"]
const ARC_STATES = [
	"01  Edge draw", "02  Gather", "03  Sweep", "04  Travel", "05  Erode", "06  Retract"
]
var family := "F03"
var states: Array = ARC_STATES
var model
var cam := Camera3D.new()
var panel := CanvasLayer.new()
var slider := HSlider.new()
var clock := .67
var state := 0
var pack := 1
var yaw := .12
var elevation := .65
var interrupt_time := -1.
var playing := false
var capturing := false
var view_center := Vector3(0, .16, -.27)


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#27292c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c3c5c7")
	env.ambient_light_energy = .64
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-43, -32, 10)
	add_child(light)
	add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.10
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--plates="):
			output = arg.trim_prefix("--plates=")
		if arg.begins_with("--family="):
			family = arg.trim_prefix("--family=")
	spawn_model()
	build_ui()
	orbit()
	if output != "":
		capturing = true
		panel.hide()
		call_deferred("plates", output)


func spawn_model() -> void:
	if model:
		remove_child(model)
		model.queue_free()
	if family == "F03":
		model = ARC.instantiate()
		states = ARC_STATES
	else:
		model = load("res://art_kit/families/F04_wave/F04_wave.tscn").instantiate()
		states = ["01  Compress", "02  Overturn", "05  Settle"]
	add_child(model)
	model.set_process(false)
	sample(clock)


func orbit() -> void:
	cam.position = (
		view_center
		+ Vector3(sin(yaw) * cos(elevation), sin(elevation), cos(yaw) * cos(elevation)) * 7.
	)
	cam.look_at(view_center)


func sample(p: float) -> void:
	clock = clampf(p, 0., 1.)
	interrupt_time = -1.
	model.position = Vector3.ZERO
	model.rotation = Vector3.ZERO
	if family != "F03":
		model.inspect_state(state, clock, PACKS[pack])
		return
	var cfg: Dictionary = model.cfg.duplicate()
	cfg.merge(
		{
			"form": "wide_crescent",
			"palette": PACKS[pack],
			"distortion": .074,
			"weight": 0.,
			"edge_gain": 1.6,
			"formation": "gather_in_place" if state == 1 else "edge_draw"
		},
		true
	)
	model.configure(cfg, 2., .94)
	model.rotation_degrees.z = 24.
	model.blade.visible = true
	model.skin.set_shader_parameter("art_clock", clock * 1.7)
	model.exit_clock = -1.
	model.skin.set_shader_parameter("retreat", 0.)
	model.blade.set_blend_shape_value(model.shape_indices.edge_retract, 0.)
	model.prepare(clock if state < 2 else 1., 0.)
	if state == 2:
		model.rotation.y = lerpf(-.56, .49, clock)
		model.blade.set_blend_shape_value(model.shape_indices.sweep_bend, sin(PI * clock))
	elif state == 3:
		model.position.z = lerpf(.8, -.9, clock)
	elif state >= 4:
		model.finish("released" if state == 5 else "completed")
		model.sample_tail(clock)
		model.exit_clock = -1.


func interrupt_at(p: float) -> void:
	if not is_equal_approx(p, clock) or interrupt_time >= 0.:
		sample(p)
	playing = false
	model.finish("released" if (family == "F03" and state in [1, 5]) else "interrupted")
	interrupt_time = 0.


func _process(dt: float) -> void:
	if capturing:
		return
	if interrupt_time >= 0.:
		interrupt_time = minf(1., interrupt_time + dt)
		model.sample_tail(interrupt_time)
	elif playing:
		sample(fmod(clock + dt * .5, 1.))
		slider.set_value_no_signal(clock)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		yaw -= event.relative.x * .009
		elevation = clampf(elevation + event.relative.y * .008, -1.45, 1.45)
		orbit()


func button(row: Container, caption: String, action: Callable) -> void:
	var control := Button.new()
	control.text = caption
	control.pressed.connect(action)
	row.add_child(control)


func build_ui() -> void:
	add_child(panel)
	var box := VBoxContainer.new()
	box.position = Vector2(18, 16)
	panel.add_child(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	var families := OptionButton.new()
	for id in ["F03", "F04"]:
		if id == "F03" or ResourceLoader.exists("res://art_kit/families/F04_wave/F04_wave.tscn"):
			families.add_item(id)
	row.add_child(families)
	families.select(0 if family == "F03" else 1)
	button(
		row,
		"H01 / F10",
		func(): get_tree().change_scene_to_file("res://art_lab/asset_viewer/HostViewer.tscn")
	)
	var anim := OptionButton.new()
	for label in states:
		anim.add_item(label)
	row.add_child(anim)
	families.item_selected.connect(
		func(i):
			family = families.get_item_text(i)
			state = 0
			spawn_model()
			anim.clear()
			for label in states:
				anim.add_item(label)
	)
	anim.item_selected.connect(
		func(i):
			state = i
			sample(clock)
	)
	for i in PACKS.size():
		button(
			row,
			PACKS[i],
			func():
				pack = i
				sample(clock)
		)
	var transport := HBoxContainer.new()
	box.add_child(transport)
	button(
		transport,
		"Play / pause",
		func():
			playing = not playing
			interrupt_time = -1.
	)
	slider.min_value = 0.
	slider.max_value = 1.
	slider.step = .001
	slider.value = clock
	slider.custom_minimum_size.x = 240
	transport.add_child(slider)
	slider.value_changed.connect(
		func(p):
			playing = false
			sample(p)
	)
	for p in [.25, .55, .85]:
		button(
			transport,
			"Cut %d%%" % roundi(p * 100),
			func():
				slider.set_value_no_signal(p)
				interrupt_at(p)
		)
	var views := HBoxContainer.new()
	box.add_child(views)
	for pair in [["Front", 0.], ["Side", PI / 2], ["Back", PI]]:
		button(
			views,
			pair[0],
			func():
				yaw = pair[1]
				elevation = .32
				orbit()
		)


func snapshot(dir: String, key: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var im := get_viewport().get_texture().get_image()
	im.resize(540, 304, Image.INTERPOLATE_LANCZOS)
	assert(im.save_png(dir + "/" + key + ".png") == OK)


func sample_signature() -> Array:
	var mesh: MeshInstance3D = model.blade if family == "F03" else model.lip
	var result: Array = [model.transform, mesh.global_transform]
	for i in mesh.get_blend_shape_count():
		result.append(snappedf(mesh.get_blend_shape_value(i), .00001))
	for key in ["reveal", "retreat", "erosion"]:
		result.append(snappedf(model.skin.get_shader_parameter(key), .00001))
	return result


func plates(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	state = 3 if family == "F03" else 1
	for i in 6:
		pack = 0 if i < 3 else i - 2
		yaw = [.0, PI / 2, PI, .18, .18, .18][i]
		elevation = .24 if i < 3 else .73
		orbit()
		sample(.60)
		await snapshot(dir, "mode_%d" % i)
	pack = 1
	yaw = .14
	elevation = .64
	orbit()
	for i in states.size():
		state = i
		for j in 3:
			var p: float = [.25, .55, .85][j]
			sample(p)
			await snapshot(dir, "s%d_%d_before" % [i, j])
			var before := sample_signature()
			interrupt_at(p)
			model.sample_tail(0.)
			if before != sample_signature():
				push_error("Discontinuous cut " + str([family, i, p]))
				get_tree().quit(1)
				return
			model.sample_tail(.33)
			await snapshot(dir, "s%d_%d_after" % [i, j])
	print("VIEWER ", family, " independent states=", states.size(), " cut points=.25/.55/.85")
	get_tree().quit()
