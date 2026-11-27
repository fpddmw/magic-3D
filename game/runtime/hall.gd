extends Node3D

const Architecture = preload("res://runtime/architecture.gd")
const Law = preload("res://world_law/hall_world.gd")
const Director = preload("res://art_kit/director.gd")
const Actor = preload("res://runtime/player.gd")
const Cast = preload("res://runtime/cast.gd")
var registry: Dictionary
var tariff: Dictionary
var catalog: Array = []
var selected := 0
var casts: Array = []
var serial := 0
var mana := 300.
var world
var director
var player
var hall
var camera: Camera3D
var info: Label
var yaw := 0.
var pitch := -.13
var enemy: RigidBody3D
var enemy_clock := 0.
var testing := false
var status := ""
var charge_bar: ProgressBar
var latest_cast
var rain: GPUParticles3D


func data(path: String):
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _ready() -> void:
	testing = (
		"--hall-test" in OS.get_cmdline_user_args() or "--hall-bench" in OS.get_cmdline_user_args()
	)
	registry = data("res://data/magic_v0_3/registry.json")
	tariff = data("res://data/magic_v0_3/tariff.json")
	for entry in data("res://data/magic_v0_3/catalog.json"):
		if FileAccess.get_sha256(entry.path) != entry.sha256:
			push_error("Recipe digest mismatch: " + entry.path)
			continue
		entry.recipe = data(entry.path)
		entry.display_name = entry.recipe.name
		for subject in entry.recipe.Subjects:
			var ref = subject.get("spatial", {}).get("reference", {})
			if ref.get("anchor") == "aim_point":
				entry.display_name += " · " + ("随瞄点" if ref.bind == "live" else "固定瞄点")
				break
		catalog.append(entry)
		if entry.path.ends_with("/pressure_wind.json"):
			selected = catalog.size() - 1
	hall = Architecture.new()
	add_child(hall)
	director = Director.new()
	director.kit = registry.artkit
	add_child(director)
	director.prepare(registry.art)
	world = Law.new()
	world.units = tariff.world_units
	world.max_bodies = registry.engine_gates.global_dynamic_bodies
	world.director = director
	world.target_limit = registry.limits.targets
	world.material_contact.connect(
		func(body):
			for c in casts:
				for handle in c.bodies:
					if c.bodies[handle] == body and c.holds.has(handle):
						c.observe(c.holds[handle], "contact")
	)
	add_child(world)
	environment()
	player = Actor.new()
	player.arena = self
	player.position = Vector3(0, .12, 7)
	add_child(player)
	world.slots.caster = player
	camera = Camera3D.new()
	camera.fov = 61
	add_child(camera)
	place_camera()
	director.prime_surfaces(camera.global_position + aim() * 2.)
	var pillar = world.make_body(
		"CrackedPier",
		Vector3(1.55, 1.4, 1.5),
		11,
		Vector3(.78, 2.8, .84),
		hall.mats.trim,
		{"integrity": 8., "fracturable": true}
	)
	pillar.freeze = true
	enemy = world.make_body(
		"Sentinel",
		Vector3(-1.6, .95, 1.0),
		4.,
		Vector3(.76, 1.80, .56),
		hall.mats.bronze,
		{"poise": 18.}
	)
	enemy.lock_rotation = true
	enemy.get_child(0).visible = false
	var knight = Node3D.new()
	knight.position.y = -.9
	enemy.add_child(knight)
	preload("res://art_kit/vestment.gd").harness(player, knight, true)
	var helm = CylinderMesh.new()
	helm.top_radius = .08
	helm.bottom_radius = .37
	helm.height = .57
	player.mesh(enemy, helm, Vector3(0, .81, 0), Color("#827b69"))
	var stone = world.make_body(
		"LooseStone",
		Vector3(.2, .51, 3.45),
		1.5,
		Vector3(.88, .78, .72),
		hall.mats.stone,
		{"thermal_path": "contact"}
	)
	var lamp = world.make_body(
		"Votive",
		Vector3(3.7, .55, 3.),
		8.,
		Vector3(.6, 1., .6),
		hall.mats.bronze,
		{"mana": 45., "linked": true, "disturbance": true, "sight": true}
	)
	lamp.freeze = true
	world.slots.merge({"target": stone, "observed_site": lamp, "lamp": lamp, "self": player})
	var last = null
	for i in range(4):
		var b = world.make_body(
			"Channel" + str(i),
			Vector3(-3.4, .18, 4. - i * 1.15),
			1.,
			Vector3(.85, .28, 1.14),
			hall.mats.dark,
			{"phase": "liquid", "conductive": true}
		)
		b.freeze = true
		phase(b, "liquid")
		if last:
			for k in ["material", "electric", "thermal"]:
				world.edges.append({"a": last, "b": b, "kind": k, "length_m": 1.15, "intact": true})
		else:
			world.slots.spring = b
		last = b
	ui()
	if "--aim-study" in OS.get_cmdline_user_args():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		call_deferred("run_aim_study")
	elif not testing:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif "--hall-test" in OS.get_cmdline_user_args():
		call_deferred("run_checks")
	else:
		call_deferred("benchmark")


func environment() -> void:
	var we = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#475c70")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b8c8db")
	env.ambient_light_energy = .40
	env.fog_enabled = true
	env.fog_light_color = Color("#374858")
	env.fog_density = .011
	env.glow_enabled = true
	we.environment = env
	add_child(we)
	var moon = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-51, -28, -21)
	moon.light_color = Color("#c7ddf5")
	moon.light_energy = 1.32
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 38.0
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(moon)
	rain = GPUParticles3D.new()
	rain.amount = 750
	rain.lifetime = 1.4
	rain.position = Vector3(0, 12, -2)
	rain.visibility_aabb = AABB(Vector3(-7, -16, -19), Vector3(14, 20, 37))
	var pm = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(5.4, 1, 16)
	pm.direction = Vector3(.08, -1, 0)
	pm.spread = 3.
	pm.initial_velocity_min = 10.
	pm.initial_velocity_max = 14.
	rain.process_material = pm
	var streak = BoxMesh.new()
	streak.size = Vector3(.011, .26, .011)
	var rain_mat = StandardMaterial3D.new()
	rain_mat.albedo_color = Color("#798e9d")
	streak.material = rain_mat
	rain.draw_pass_1 = streak
	add_child(rain)
	if DisplayServer.get_name() != "headless":
		var bed = AudioStreamPlayer.new()
		bed.stream = director.sound("rain", true)
		bed.volume_db = -17.
		add_child(bed)
		bed.add_to_group("hall_audio")
		bed.play()


func spawn_material(p: Vector3, factor: float, radius: float):
	return world.make_body(
		"WorkedStone",
		p,
		factor,
		Vector3.ONE * clampf(radius * 2., .2, 2.),
		hall.mats.stone,
		{"phase": "solid", "integrity": 10., "fracturable": true}
	)


func phase(b: RigidBody3D, value: String) -> void:
	b.set_meta("phase", value)
	# These finite water patches carry loads only in the solid phase.
	if not b.has_meta("solid_collision"):
		b.set_meta("solid_collision", Vector2i(b.collision_layer, b.collision_mask))
	var solid: Vector2i = b.get_meta("solid_collision")
	b.collision_layer = solid.x if value == "solid" else 0
	b.collision_mask = solid.y if value == "solid" else 0
	b.get_child(0).material_override = hall.mats.trim if value == "solid" else hall.mats.dark


func fracture(b: RigidBody3D, count: int) -> void:
	if b.get_meta("broken", false) or count < 2:
		return
	if get_tree().get_nodes_in_group("world_body").size() + count - 1 > world.max_bodies:
		return
	var size: Vector3 = b.get_child(1).shape.size
	var original = b.global_transform
	var v = b.linear_velocity
	var spin = b.angular_velocity
	b.mass /= count
	size.x /= count
	b.get_child(1).shape.size = size
	b.get_child(0).mesh.size = size
	b.freeze = false
	b.set_meta("broken", true)
	var center = original.origin
	for i in count:
		var offset = original.basis.x * size.x * (i - (count - 1) * .5)
		var piece = (
			b
			if i == 0
			else world.make_body(
				"Fragment",
				center + offset,
				b.mass,
				size,
				b.get_child(0).material_override,
				{"broken": true}
			)
		)
		piece.global_transform = Transform3D(original.basis, center + offset)
		piece.linear_velocity = v + spin.cross(offset)
		piece.angular_velocity = spin


func aim() -> Vector3:
	return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch)).normalized()


func cast_origin() -> Vector3:
	return player.global_position + Vector3.UP * 1.20 + Vector3(-sin(yaw), 0, -cos(yaw)) * .87


func aim_point() -> Vector3:
	var from = camera.global_position
	var ray = PhysicsRayQueryParameters3D.create(from, from + aim() * 30.)
	ray.exclude = [player.get_rid()]
	var hit = get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.get("position", cast_origin() + aim() * 8.)


func pick_target() -> void:
	var best = null
	var score = .83
	for b in get_tree().get_nodes_in_group("world_body"):
		var d = b.global_position - camera.global_position
		if d.length() > 30:
			continue
		var s = aim().dot(d.normalized())
		if s > score:
			best = b
			score = s
	world.slots.target = best


func place_camera() -> void:
	var arm = Vector3(1.25, 1.92, 4.0).rotated(Vector3.UP, yaw)
	camera.position = player.position + arm
	camera.look_at(camera.position + aim())
	if director.last_impact > 0 and director.clock_s - director.last_impact < .13:
		camera.h_offset = .03 * sin((director.clock_s - director.last_impact) * 80)
	else:
		camera.h_offset = 0.


func cast_entry(entry: Dictionary):
	if casts.size() >= registry.limits.entry:
		return null
	for other in casts:
		for pid in other.active:
			if other.contracts[other.nodes[pid].contract].focus == "exclusive":
				return null
	var c = Cast.new()
	serial += 1
	if not c.setup(self, entry.recipe, entry.quote, serial):
		status = "供给不足"
		return null
	casts.append(c)
	latest_cast = c
	return c


func mobility() -> float:
	var limit = 1.
	for c in casts:
		for pid in c.active:
			var rule = c.contracts[c.nodes[pid].contract].mobility
			limit = minf(limit, 0. if rule == "rooted" else (.42 if rule == "slow_walk" else 1.))
	return limit


func send_event(kind: String) -> void:
	for c in casts:
		c.input_event(kind)


func _unhandled_input(e: InputEvent) -> void:
	if testing:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_Q:
				selected = posmod(selected - 1, catalog.size())
			KEY_E:
				selected = posmod(selected + 1, catalog.size())
			KEY_R:
				if casts.is_empty() and player.position.distance_to(Vector3(0, 0, 7)) < 2.:
					mana = 300.
			KEY_F:
				for edge in world.edges:
					if edge.a.position.distance_to(player.position) < 2.5:
						edge.intact = not edge.intact
			KEY_SPACE:
				player.command("roll")
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * .002
		pitch = clampf(pitch - e.relative.y * .002, -.8, .58)
	if e is InputEventMouseButton:
		if e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if e.button_index == MOUSE_BUTTON_RIGHT:
			if e.pressed:
				pick_target()
				cast_entry(catalog[selected])
			elif latest_cast:
				latest_cast.input_event("release")
		if e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			player.command("swing")


func ui() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)
	info = Label.new()
	info.position = Vector2(32, 20)
	info.add_theme_font_size_override("font_size", 21)
	info.add_theme_color_override("font_color", Color("#e1dac4"))
	info.add_theme_constant_override("outline_size", 4)
	canvas.add_child(info)
	charge_bar = ProgressBar.new()
	charge_bar.position = Vector2(32, 83)
	charge_bar.size = Vector2(238, 6)
	charge_bar.show_percentage = false
	canvas.add_child(charge_bar)
	var dot = Label.new()
	dot.text = "·"
	dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	canvas.add_child(dot)


func _physics_process(dt: float) -> void:
	if not player:
		return
	for c in casts.duplicate():
		c.step(dt)
		if c.active.is_empty():
			casts.erase(c)
	if (not testing or "--hall-bench" in OS.get_cmdline_user_args()) and is_instance_valid(enemy):
		var delta: Vector3 = player.position - enemy.position
		delta.y = 0.
		enemy_clock += dt
		if float(enemy.get_meta("poise")) <= 0:
			if enemy_clock > 2.2:
				enemy.set_meta("poise", 18.)
				enemy_clock = 0.
		elif delta.length() < 8. * world.transmission(enemy.position, player.position + Vector3.UP):
			if delta.length() > 1.65:
				enemy.apply_central_force(delta.normalized() * 6.)
			elif enemy_clock > 2.:
				player.struck(23., delta.normalized())
				director.play_at("stone_strain", enemy.position, .5)
				enemy_clock = 0.
			enemy.get_child(2).rotation.z = (
				.24 if enemy_clock > 1.5 and delta.length() < 2.3 else 0.
			)
	place_camera()
	info.text = (
		"%s   ·   %d / %d\n魔力 %.0f    耐力 %.0f    韧性 %.0f    %s"
		% [
			catalog[selected].display_name,
			selected + 1,
			catalog.size(),
			mana,
			player.stamina,
			player.poise,
			status
		]
	)
	charge_bar.value = (
		100. * latest_cast.ratio() if latest_cast and not latest_cast.active.is_empty() else 0.
	)


func run_aim_study() -> void:
	await preload("res://runtime/aim_checks.gd").new().run(self)


func run_checks() -> void:
	await preload("res://runtime/acceptance.gd").new().run(self)


func benchmark() -> void:
	await preload("res://runtime/acceptance.gd").new().bench(self)


func shutdown_audio() -> void:
	for child in get_tree().get_nodes_in_group("hall_audio"):
		child.stop()
		child.stream = null
	director.audio_cache.clear()


func _exit_tree() -> void:
	if is_instance_valid(director):
		shutdown_audio()
