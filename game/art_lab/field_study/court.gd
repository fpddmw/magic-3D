extends Node3D

const Compiler = preload("res://art_lab/field_study/recipe.gd")
const Instance = preload("res://art_lab/field_study/instance.gd")
const Art = preload("res://art_lab/field_study/field_stage.gd")
const Stage = preload("res://art_lab/scenes/stage.gd")
const Masonry = preload("res://art_lab/field_study/masonry.gd")
const FILES = [
	"res://art_lab/field_study/recipes/infall.json",
	"res://art_lab/field_study/recipes/sand_court.json",
	"res://art_lab/field_study/recipes/clear_passage.json"
]
var host
var session = Instance.new()
var art
var set_piece: Stage
var compiled: Dictionary
var commands: Array = []
var camera: Camera3D
var actor: Node3D
var rig: Skeleton3D
var score_clock := 0.
var pose_weight := 0.
var recoil := 0.
var index := 0
var stones: Array = []
var prior: RigidBody3D
var prior_id := 0
var prior_receipt := false
var exclusions: Array[RID] = []
var old_mix: AudioBusLayout
var report
var guide: Label
var hud_enabled := true
var no_ornament := false
var alt_space := false
var options: Dictionary = {}
var test_case := ""


func open(arena, opts: Dictionary) -> void:
	host = arena
	options = opts
	camera = host.camera
	test_case = opts.get("case", "")
	alt_space = test_case in ["outdoor", "empty"]
	index = 2 if test_case == "passage" else (1 if test_case == "transfer" else 0)
	old_mix = AudioServer.generate_bus_layout()
	AudioServer.set_bus_layout(Art.Layout)
	if host.ruin_stage:
		set_piece = host.ruin_stage
	else:
		set_piece = Stage.new()
		host.hall.hide()
		for body in host.hall.find_children("*", "StaticBody3D", true, false):
			body.collision_layer = 0
	for n in host.get_children():
		if n is DirectionalLight3D:
			n.hide()
		if n is WorldEnvironment:
			n.environment = null
	for b in get_tree().get_nodes_in_group("world_body"):
		if b.has_meta("control"):
			continue
		b.hide()
		b.freeze = true
		b.collision_layer = 0
		b.collision_mask = 0
	if host.rain:
		host.rain.hide()
		host.rain.emitting = false
	for node in get_tree().get_nodes_in_group("hall_audio"):
		node.stop()
	if not set_piece.is_inside_tree():
		add_child(set_piece)
	set_piece.set_space(alt_space)
	host.player.name = "Caster"
	host.player.position = Vector3(-.2, .08, 5.5)
	host.pitch = -.23
	host.yaw = 0.
	if host.player.artist:
		host.player.artist.hide()
		host.player.grip.hide()
		host.player.figure.show()
	for piece in host.player.figure.get_children():
		if piece is Node3D:
			piece.hide()
	actor = preload("res://assets/models/astronomer.glb").instantiate()
	host.player.figure.add_child(actor)
	actor.rotation.y = PI
	preload("res://art_kit/choreography/astronomer.gd").dress(actor)
	rig = actor.find_children("*", "Skeleton3D", true, false)[0]
	host.place_camera()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	guide = Label.new()
	canvas.add_child(guide)
	guide.add_theme_font_size_override("font_size", 20)
	guide.add_theme_constant_override("outline_size", 4)
	guide.position = Vector2(55, 52)
	host.info.get_parent().visible = false
	if test_case != "empty":
		stone("Shale", Vector3(-.86, .22, 2.03), 1.0, Vector3(.43, .21, .31), 71, Color("#a99a83"))
		stone("Basalt", Vector3(2.15, .34, 1.38), 4.0, Vector3(.56, .36, .48), 32, Color("#777c76"))
		stone(
			"Keystone", Vector3(.40, .27, -.16), 2.0, Vector3(.52, .27, .37), 121, Color("#ac9f77")
		)
		stone("Flake", Vector3(-.35, .13, .86), .45, Vector3(.27, .13, .20), 15, Color("#b2ad9c"))
		stone(
			"FarStone", Vector3(-4.8, .3, -2.15), 1.4, Vector3(.48, .24, .39), 421, Color("#81796a")
		)
		stone(
			"Drum", Vector3(-3.15, .432, 2.89), 2.5, Vector3(.42, .21, .42), 213, Color("#c0ae8d")
		)
		Masonry.drum(stones.back())
		stones[0].linear_velocity = Vector3(.68, 0, .18)
		stones[0].angular_velocity = Vector3(.5, 0, -1.6)
	load_score(index)
	if not test_case.is_empty():
		report = preload("res://art_lab/field_study/review.gd").new()
		report.begin(self, opts)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func stone(
	label: String, p: Vector3, kg: float, extent: Vector3, seed_value: int, dye: Color
) -> void:
	var b = host.world.make_body(label, p, kg, extent * 2., host.hall.mats.stone, {})
	Masonry.skin(b, extent, seed_value, dye)
	stones.append(b)


func capture_contacts(b: RigidBody3D) -> void:
	if not b.body_entered.is_connected(_heard.bind(b)):
		b.body_entered.connect(_heard.bind(b))


func _heard(other: Node, body: RigidBody3D) -> void:
	session.contact(body, other)


func load_score(which: int) -> void:
	if session.phase != "idle":
		return
	var result := Compiler.compile_recipe(FILES[which])
	if result.is_empty():
		return
	if art:
		art.stop_audio()
		art.free()
	index = which
	compiled = result
	session.setup(host, compiled)
	art = Art.new()
	add_child(art)
	art.setup(compiled, alt_space)
	for b in stones:
		capture_contacts(b)
	if prior:
		capture_contacts(prior)
	no_ornament = test_case == "silent"
	art.muted_layers = no_ornament


func earlier_cast() -> void:
	if is_instance_valid(prior):
		return
	for entry in host.catalog:
		if not entry.path.ends_with("/cast_stone.json"):
			continue
		var previous = host.cast_entry(entry)
		if not previous or previous.bodies.is_empty():
			return
		prior = previous.bodies.values()[0]
		prior_id = prior.get_instance_id()
		previous.input_event("release")
		for e in previous.events:
			if e.event == "handoff_world" and e.body == prior:
				prior_receipt = true
		Masonry.skin(prior, Vector3(.41, .31, .37), 713, Color("#a6a999"))
		capture_contacts(prior)
		return


func terrain(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(p.x, p.y + 4., p.z), Vector3(p.x, p.y - 12., p.z), 1, exclusions
	)
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	return h.position.y if not h.is_empty() else -12.


func aim_target() -> Dictionary:
	var start := camera.global_position
	var q := PhysicsRayQueryParameters3D.create(start, start + host.aim() * 28., 1, exclusions)
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	if h.is_empty():
		return {"point": session.center, "valid": false}
	var p: Vector3 = h.position + h.normal * 1.48
	var valid: bool = host.cast_origin().distance_to(p) <= session.plan.Contracts.reach_m
	return {"point": p, "valid": valid}


func clip_descent(start: Vector3, wanted: Vector3, clearance: float) -> Vector3:
	if start.is_equal_approx(wanted):
		return start
	var q := PhysicsRayQueryParameters3D.create(
		start, wanted + Vector3.DOWN * clearance, 1, exclusions
	)
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	if h.is_empty():
		return wanted
	return Vector3(start.x, clampf(h.position.y + clearance, wanted.y, start.y), start.z)


func input_event(e: InputEvent) -> void:
	if (
		e is InputEventMouseMotion
		and (
			Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless"
		)
	):
		host.yaw -= e.relative.x * .002
		host.pitch = clampf(host.pitch - e.relative.y * .002, -.8, .55)
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_RIGHT:
		commands.append("hold" if e.pressed else "release")
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_SPACE:
				commands.append("interrupt")
			KEY_G:
				earlier_cast()
			KEY_TAB:
				load_score((index + 1) % FILES.size())
			KEY_O:
				if session.phase == "idle":
					alt_space = not alt_space
					set_piece.set_space(alt_space)
					for k in art.voices:
						if k != "foundation":
							art.voices[k].bus = "OpenSky" if alt_space else "Vault"
			KEY_H:
				hud_enabled = not hud_enabled
			KEY_V:
				art.muted_layers = not art.muted_layers
			KEY_B:
				commands.append("source_lost")
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://scenes/main.tscn")


func step(dt: float) -> void:
	if compiled.is_empty():
		return
	exclusions.clear()
	exclusions.append(host.player.get_rid())
	for b in get_tree().get_nodes_in_group("world_body"):
		exclusions.append(b.get_rid())
	host.place_camera()
	if report:
		report.inputs(self)
	var target := aim_target()
	session.step(dt, commands, target, clip_descent)
	art.update(session, dt, terrain)
	animate(dt)
	if report:
		report.observe(self, commands, target)
	commands.clear()
	guide.visible = hud_enabled
	guide.text = (
		"%s     %s\n右键蓄势 / 松手交付     空格打断     Tab 换谱     O 换场     G 投石留形     H 隐藏"
		% [
			compiled.title,
			{"idle": "就绪", "prepare": "选定落点   %.0f%%" % (100. * session.funded), "active": "牵引"}[
				session.phase
			]
		]
	)


func animate(dt: float) -> void:
	score_clock += dt
	for e in session.events:
		if e.kind == "commit" and art.finish_pose == "unload":
			recoil = 1.
	var target: float = (
		session.funded if session.phase == "prepare" and art.finish_pose == "brace" else 0.
	)
	pose_weight = lerpf(pose_weight, target, 1. - exp(-dt * (7. if target > 0. else 4.5)))
	recoil = maxf(0., recoil - dt * 2.4)
	var release := sin(PI * recoil)
	var movement: float = minf(
		1., Vector2(host.player.velocity.x, host.player.velocity.z).length() / 2.
	)
	if session.phase != "idle" and movement < .1:
		host.player.facing = Vector3(-sin(host.yaw), 0, -cos(host.yaw))
	for i in rig.get_bone_count():
		var joint := String(rig.get_bone_name(i))
		var side: float = -1. if joint.ends_with("L") else 1.
		var v := Vector3.ZERO
		match joint:
			"Spine":
				v = Vector3(9., -14., -8.) * pose_weight + Vector3(-4., 22., 4.) * release
			"Chest":
				v = Vector3(-7., -16., 3.) * pose_weight + Vector3(4., 18., -6.) * release
			"Head":
				v = Vector3(4., 15., 3.) * pose_weight
			"Mantle", "Hem":
				v = Vector3(
					5. + 9. * pose_weight + 12. * release, 3. * sin(score_clock), -5. * pose_weight
				)
		if joint.begins_with("Shoulder"):
			v = (
				Vector3(-21., -side * 13., side * (52. if side < 0 else 74.)) * pose_weight
				+ Vector3(-20., side * 6., side * 40.) * release
			)
		elif joint.begins_with("Elbow"):
			v.x = -14. - 49. * pose_weight - 27. * release
		elif joint.begins_with("Hand"):
			v = Vector3(12., 0., side * (-23. * pose_weight - 18. * release))
		elif joint.begins_with("Thigh"):
			v = Vector3(
				-13. * pose_weight + side * 17. * movement * sin(score_clock * 8.),
				0,
				side * 4. * pose_weight
			)
		elif joint.begins_with("Knee"):
			v.x = 19. * pose_weight + maxf(0., -side * sin(score_clock * 8.)) * 17. * movement
		elif joint.begins_with("Foot"):
			v.x = -6. * pose_weight
		rig.set_bone_pose_rotation(i, Quaternion.from_euler(v * PI / 180.))


func _exit_tree() -> void:
	if is_instance_valid(art):
		art.stop_audio()
	if old_mix:
		AudioServer.set_bus_layout(old_mix)
