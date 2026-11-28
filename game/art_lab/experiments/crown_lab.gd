extends Node3D
const HOST = preload("res://art_kit/hosts/H01/host.gd")
const CONTROL = preload("res://world_law/host_array.gd")
const ACTOR = preload("res://art_kit/choreography/ruin_actor.gd")
const RECIPE = "res://art_kit/families/F10_array/b1.json"
const LIBRARY = "res://art_kit/hosts/H01/hosts.json"
@export var neutral := false
var cfg: Dictionary
var catalog: Array
var hosts: Array = []
var witnesses: Array = []
var control
var artist
var cam := Camera3D.new()
var anchor := Vector3(0, 0, 2.8)
var count := 8
var fixture := "stone"
var balance := {"mana": 300.}
var capture_dir := ""
var record := false
var age := 0.
var recorded_tick := 0
var free_camera := 0.
var released_at := -1.
var sent := 0
var account_start := 0.
var hint := Label.new()
var model_index := -1
var model_prop
var studio_busy := false
var max_rise := 0.
var max_accel := 0.
var settled := 0
var result_written := false


func _ready() -> void:
	cfg = JSON.parse_string(FileAccess.get_file_as_string(RECIPE))
	catalog = JSON.parse_string(FileAccess.get_file_as_string(LIBRARY))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture="):
			fixture = arg.trim_prefix("--fixture=")
		if arg.begins_with("--members="):
			count = clampi(int(arg.trim_prefix("--members=")), 1, 40)
		if arg.begins_with("--plates="):
			capture_dir = arg.trim_prefix("--plates=")
		if arg == "--record":
			record = true
	if neutral:
		build_studio()
	else:
		add_child(preload("res://art_lab/scenes/stage.gd").new())
		artist = ACTOR.new()
		add_child(artist)
		artist.position = anchor
		# A high, cool clerestory bounce exposes the facets against the dark nave.
		var bounce := DirectionalLight3D.new()
		bounce.rotation_degrees = Vector3(-48, 27, -10)
		bounce.light_color = Color("#d0d9df")
		bounce.light_energy = .86
		bounce.light_cull_mask = 4
		add_child(bounce)
		var edge_light := DirectionalLight3D.new()
		edge_light.rotation_degrees = Vector3(-20, 153, 0)
		edge_light.light_color = Color("#e5cfaa")
		edge_light.light_energy = .40
		edge_light.light_cull_mask = 4
		add_child(edge_light)
	add_child(cam)
	cam.fov = 56.
	cam.current = true
	var hud := CanvasLayer.new()
	add_child(hud)
	hud.add_child(hint)
	hint.position = Vector2(22, 22)
	hint.text = "Space  lift     F  dispatch     X  interrupt     Drag  orbit     R  reset"
	if neutral:
		hint.text += "     [ / ]  inspect host     Tab  VFX viewer"
	hint.visible = not record and capture_dir.is_empty()
	if not capture_dir.is_empty():
		studio_busy = true
		DirAccess.make_dir_recursive_absolute(capture_dir)
		call_deferred("studio_catalog")
	else:
		populate()
		camera_pose()
	print(
		"B1 RUN ",
		JSON.stringify(
			{
				"fixture": fixture,
				"members": count,
				"recipe_sha256": FileAccess.get_sha256(RECIPE),
				"engine": Engine.get_version_info().string,
				"physics": ProjectSettings.get_setting("physics/3d/physics_engine")
			}
		)
	)


func build_studio() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#303339")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b9c1c6")
	env.ambient_light_energy = .68
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-47, -38, 12)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	var floor_body := StaticBody3D.new()
	add_child(floor_body)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(34, .2, 34)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#494c51")
	floor_body.position.y = -.1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	floor_body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	col.shape = shape
	floor_body.add_child(col)


func camera_pose() -> void:
	var arm := Vector3(4.4, 3.95, 7.5)
	if count > 12:
		arm = Vector3(1.9, 5.45, 10.6)
	cam.position = anchor + arm.rotated(Vector3.UP, free_camera)
	cam.look_at(anchor + Vector3(0, 1.25, -.68))


func populate() -> void:
	for i in count:
		var choices: Array = [0, 7, 2, 5, 8, 1, 4, 3, 6] if fixture == "stone" else [9, 10]
		var b = HOST.new()
		b.name = "Host_%02d" % i
		add_child(b)
		b.build(catalog[choices[i % choices.size()]])
		var angle := TAU * i * .618034 + .21
		var r := 1.48 + sqrt((i + .25) / count) * (3.9 if count > 12 else 2.25)
		b.position = anchor + Vector3(cos(angle) * r, .67, sin(angle) * r)
		b.rotation = Vector3(.13 * (i % 3), i * .96, .17 * (i % 2))
		hosts.append(b)


func begin() -> void:
	if (control and control.active) or hosts.is_empty():
		return
	sent = 0
	released_at = -1.
	max_accel = 0.
	max_rise = 0.
	witnesses.clear()
	account_start = balance.mana
	for b in hosts:
		witnesses.append(
			{
				"id": b.get_instance_id(),
				"material": b.surface.mesh.surface_get_material(0),
				"start_y": b.global_position.y,
				"peak": 0.,
				"released_y": -INF,
				"vy": 0.,
				"first_rise_s": -1.
			}
		)
	control = CONTROL.new()
	control.begin(hosts, anchor, cfg, count, balance)
	print("B1 PICK_ORDER ", JSON.stringify(control.order))


func dispatch_one() -> void:
	if not control:
		return
	var spot := anchor + Vector3(-2.8 + sent * 1.23, .28, -5.4 - .35 * (sent % 2))
	if control.dispatch(spot):
		sent += 1


func drop() -> void:
	if not control or not control.active:
		return
	control.interrupt()
	released_at = age
	for i in hosts.size():
		if hosts[i].control_state == "released":
			witnesses[i].released_y = hosts[i].position.y


func _physics_process(dt: float) -> void:
	if studio_busy or model_index >= 0 or hosts.is_empty():
		return
	age += dt
	recorded_tick += 1
	if record:
		if recorded_tick == 57:
			begin()
		if recorded_tick in [404, 434, 466]:
			dispatch_one()
		if recorded_tick == 492:
			drop()
	if control:
		control.step(dt)
		if artist:
			var strength := (
				smoothstep(0., .3, control.elapsed)
				if control.active
				else 1. - smoothstep(0., .65, age - released_at)
			)
			var phase := minf(1., control.elapsed / 2.6)
			if sent > 0 and control.active:
				phase -= .24 * exp(-maxf(0., control.elapsed - control.last_dispatch) * 5.)
			artist.rotation.y = .20 * sin(control.elapsed * .73) * strength
			artist.pose(cfg.Expression.pose, phase, strength)
		for i in hosts.size():
			var b = hosts[i]
			var w: Dictionary = witnesses[i]
			var rise: float = b.position.y - w.start_y
			w.peak = maxf(w.peak, rise)
			max_rise = maxf(max_rise, rise)
			if rise > .15 and w.first_rise_s < 0.:
				w.first_rise_s = snappedf(control.elapsed, .001)
			if b.control_state == "held":
				max_accel = maxf(max_accel, (b.linear_velocity.y - w.vy) / dt)
			w.vy = b.linear_velocity.y
	if not capture_dir.is_empty() and recorded_tick in [82, 129, 187, 285, 383, 452, 503, 552, 625]:
		write_frame(capture_dir + "/live_%03d.png" % recorded_tick)
	if record and recorded_tick >= 654 and not result_written:
		conclude()


func conclude() -> void:
	result_written = true
	var ids_ok := true
	var releases := 0
	var fallen := 0
	var material_ok := true
	var impacts := 0
	var fissures := 0
	var thrown_hits := 0
	var risen := 0
	var heights: Array = []
	for i in hosts.size():
		var b = hosts[i]
		var w: Dictionary = witnesses[i]
		ids_ok = ids_ok and b.get_instance_id() == w.id
		material_ok = (
			material_ok
			and b.surface.mesh.surface_get_material(0) == w.material
			and b.surface.material_overlay == null
		)
		if w.peak > .20:
			risen += 1
		if b.control_state == "released":
			releases += 1
			if b.position.y < w.released_y - .26:
				fallen += 1
		if b.control_state == "dispatched" and b.contact_count > 0:
			thrown_hits += 1
		impacts += b.contact_count
		fissures += b.ground_marks
		heights.append(
			{
				"host": b.name,
				"id": b.kind.id,
				"kg": b.mass,
				"rise_m": snappedf(w.peak, .01),
				"first_rise_s": w.first_rise_s
			}
		)
	var empty_slots: bool = control.slots.all(func(s): return s == null)
	print("B1 SLOTS ", JSON.stringify(control.changes))
	print("B1 HOSTS ", JSON.stringify(heights))
	var ok: bool = (
		ids_ok
		and material_ok
		and empty_slots
		and sent == 3
		and thrown_hits == sent
		and fallen == releases
		and risen == count
	)
	print(
		"B1 RESULT ",
		JSON.stringify(
			{
				"ok": ok,
				"count": count,
				"lifted": risen,
				"dispatched": sent,
				"thrown_with_contact": thrown_hits,
				"released": releases,
				"fell": fallen,
				"contact_events": impacts,
				"support_marks": fissures,
				"identity_retained": ids_ok,
				"base_material_retained": material_ok,
				"all_slots_empty": empty_slots,
				"peak_applied_up_m_s2": control.peak_acceleration,
				"peak_observed_up_m_s2": max_accel,
				"max_rise_m": max_rise,
				"control_impulse_Ns": control.force_spent,
				"mana_spent": account_start - balance.mana
			}
		)
	)
	for b in hosts:
		b.voice.stop()
		b.voice.stream = null
	get_tree().quit(0 if ok else 1)


func write_frame(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(640, 360, Image.INTERPOLATE_LANCZOS)
	img.save_png(path)


func show_model(i: int) -> void:
	if model_prop:
		remove_child(model_prop)
		model_prop.queue_free()
	model_index = posmod(i, catalog.size())
	model_prop = load(HOST.HERE + "models/" + catalog[model_index].id + ".glb").instantiate()
	add_child(model_prop)
	model_prop.rotation.y = .43
	var mesh: MeshInstance3D = model_prop.find_children("*", "MeshInstance3D", true, false)[0]
	var bounds = mesh.get_aabb()
	model_prop.position = anchor + Vector3.UP * (-bounds.position.y)
	var center: Vector3 = model_prop.position + Vector3.UP * bounds.get_center().y
	var arm := Vector3(1.2, .83, 1.65).normalized() * maxf(.9, bounds.size.length() * .94)
	cam.position = center + arm
	cam.look_at(center)
	if not record:
		hint.text = catalog[model_index].id + "     [ / ]  previous / next     R  physics"


func studio_catalog() -> void:
	for i in catalog.size():
		show_model(i)
		await RenderingServer.frame_post_draw
		await write_frame(capture_dir + "/host_%02d.png" % i)
	model_prop.queue_free()
	model_prop = null
	model_index = -1
	populate()
	camera_pose()
	studio_busy = false
	record = true


func _unhandled_input(e: InputEvent) -> void:
	if record or studio_busy:
		return
	if (
		e is InputEventMouseMotion
		and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		and model_index < 0
	):
		free_camera -= e.relative.x * .009
		camera_pose()
	if not e is InputEventKey or not e.pressed or e.echo:
		return
	match e.keycode:
		KEY_SPACE:
			begin()
		KEY_F:
			dispatch_one()
		KEY_X:
			drop()
		KEY_R:
			get_tree().reload_current_scene()
		KEY_TAB:
			get_tree().change_scene_to_file("res://art_lab/asset_viewer/AssetViewer.tscn")
		KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
			if neutral and not control:
				for b in hosts:
					b.hide()
				show_model(model_index + (1 if e.keycode == KEY_BRACKETRIGHT else -1))
