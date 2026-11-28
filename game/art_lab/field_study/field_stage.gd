extends Node3D

const Domain = preload("res://art_kit/geometry/ribbon_mesh.gd")
const SHADER = preload("res://art_kit/materials/field_folds.gdshader")
const FLOW = preload("res://assets/textures/observatory/flow.png")
const Layout = preload("res://art_kit/audio/observatory_buses.tres")
var spec: Dictionary
var plan_hash: String
var bands: Array = []
var marks := MeshInstance3D.new()
var wake := MeshInstance3D.new()
var mark_mesh := ImmediateMesh.new()
var wake_mesh := ImmediateMesh.new()
var ink := StandardMaterial3D.new()
var trail_ink := StandardMaterial3D.new()
var voices: Dictionary = {}
var visible_strength := 0.
var after := 0.
var elapsed := 0.
var clock := 0.
var ground_height := 0.
var stage_events: Array = []
var consumed := 0
var muted_layers := false
var finish_pose := ""
var last_contact_point := Vector3.ZERO


func colour(c: Array) -> Color:
	return Color(c[0], c[1], c[2])


func setup(compiled: Dictionary, outside: bool) -> void:
	spec = compiled.stage
	plan_hash = compiled.digest
	var mesh := Domain.strip(100, 40)
	for sector in spec.sectors:
		var strip := MeshInstance3D.new()
		strip.mesh = mesh
		var m := ShaderMaterial.new()
		m.shader = SHADER
		var values = {
			"flow": FLOW,
			"pigment": colour(spec.color),
			"glint": colour(spec.edge),
			"length_m": sector[1],
			"height_m": sector[2] * spec.rise_m,
			"sector_width": sector[3],
			"inner_m": spec.inner_m,
			"bank": deg_to_rad(spec.bank_deg),
			"fan": deg_to_rad(spec.fan_deg),
			"skew": sin(deg_to_rad(sector[0])),
			"flow_speed": spec.flow_m_s,
			"phase_delay": spec.front_s,
			"fold_duration": spec.fold_s,
			"fibers": float(spec.ribs),
			"flow_sign": 1.0 if compiled.world.Relations.direction == "radial_in" else -1.0,
			"grain": 1.0 if spec.surface == "ochre_grain" else 0.0
		}
		for k in values:
			m.set_shader_parameter(k, values[k])
		strip.rotation.y = deg_to_rad(sector[0])
		strip.material_override = m
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(strip)
		bands.append(strip)
		var glitter := MultiMeshInstance3D.new()
		var particles := MultiMesh.new()
		particles.transform_format = MultiMesh.TRANSFORM_3D
		particles.use_custom_data = true
		particles.mesh = Domain.strip(3, 1)
		particles.instance_count = int(spec.ribs) * 14
		var rng := RandomNumberGenerator.new()
		rng.seed = 734 + roundi(sector[0])
		for i in particles.instance_count:
			particles.set_instance_transform(i, Transform3D.IDENTITY)
			particles.set_instance_custom_data(
				i, Color(rng.randf(), rng.randf(), rng.randf(), rng.randf())
			)
		glitter.multimesh = particles
		glitter.custom_aabb = AABB(Vector3(-5, -4, -5), Vector3(10, 8, 10))
		var particle_mat := ShaderMaterial.new()
		particle_mat.shader = preload("res://art_kit/particles/convergent_grain.gdshader")
		for uniform_name in [
			"pigment",
			"length_m",
			"height_m",
			"sector_width",
			"inner_m",
			"bank",
			"fan",
			"skew",
			"flow_speed",
			"phase_delay",
			"fold_duration",
			"grain",
			"flow_sign"
		]:
			particle_mat.set_shader_parameter(uniform_name, values[uniform_name])
		glitter.rotation.y = strip.rotation.y
		glitter.material_override = particle_mat
		glitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(glitter)
		bands.append(glitter)
	for pair in [[marks, mark_mesh, ink], [wake, wake_mesh, trail_ink]]:
		pair[0].mesh = pair[1]
		pair[2].shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pair[2].transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pair[2].vertex_color_use_as_albedo = true
		pair[2].cull_mode = BaseMaterial3D.CULL_DISABLED
		pair[0].top_level = true
		add_child(pair[0])
	for stem in spec.sound:
		var v := AudioStreamPlayer3D.new()
		v.stream = load("res://assets/audio/observatory/" + stem + ".wav")
		v.bus = "Foundation" if stem == "foundation" else ("OpenSky" if outside else "Vault")
		v.unit_size = 7.
		v.max_db = -3.
		v.volume_db = -5. if stem != "breath" else -9.
		add_child(v)
		v.top_level = (stem == "stone_contact")
		voices[stem] = v


func play_voice(stem: String) -> void:
	if DisplayServer.get_name() != "headless":
		voices[stem].play()


func update(s, dt: float, ground: Callable) -> void:
	clock += dt
	stage_events.clear()
	for e in s.events:
		if e.seq <= consumed:
			continue
		consumed = e.seq
		stage_events.append(e.kind)
		match e.kind:
			"enter.prepare":
				after = 0.
				elapsed = 0.
				visible_strength = 0.
				play_voice("foundation")
				play_voice("breath")
			"commit":
				elapsed = 0.
				finish_pose = spec.body[1]
				play_voice("release")
			"exit.prepare", "exit.active":
				after = spec.tail_s
				voices.foundation.stop()
				voices.breath.stop()
			"contact":
				last_contact_point = e.point
				voices.stone_contact.global_position = e.point
				play_voice("stone_contact")
	if s.phase != "idle":
		global_position = s.center
		ground_height = float(ground.call(s.center))
	if s.phase == "prepare":
		visible_strength = spec.preview_alpha * (.23 + .77 * s.funded)
		finish_pose = spec.body[0]
	elif s.phase == "active":
		visible_strength = lerpf(
			visible_strength, .28 + .72 * s.funded * s.allocation_scale, 1. - exp(-dt * 19.)
		)
		elapsed += dt
	else:
		after = maxf(0., after - dt)
		visible_strength *= exp(-dt * 7.) if after > 0. else 0.
	var anchored := ground_height - global_position.y + .035
	var local_base: float = anchored if spec.projection == "ground" else anchored * .62
	for strip in bands:
		strip.visible = visible_strength > .001 and not muted_layers
		var m: ShaderMaterial = strip.material_override
		m.set_shader_parameter("elapsed", elapsed)
		m.set_shader_parameter("ground_y", local_base)
		m.set_shader_parameter("drift", clock)
		m.set_shader_parameter("strength", visible_strength)
	mark_mesh.clear_surfaces()
	if s.phase == "active":
		draw_extent(s.center, s.plan.Subjects.radius_m, ground)
	wake_mesh.clear_surfaces()
	if (s.phase == "active" or after > 0.) and s.history.size() > 1 and not muted_layers:
		wake_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, trail_ink)
		for i in s.history.size():
			var u: float = float(i) / (s.history.size() - 1)
			var c := colour(spec.edge)
			c.a = u * spec.history_alpha * visible_strength * .55
			wake_mesh.surface_set_color(c)
			var p: Vector3 = s.history[i]
			var half: Vector3 = Vector3.RIGHT * (.003 + .011 * u) * visible_strength
			wake_mesh.surface_add_vertex(p - half)
			wake_mesh.surface_add_vertex(p + half)
		wake_mesh.surface_end()


func draw_extent(c: Vector3, r: float, ground: Callable) -> void:
	# Intersect the sphere with the local terrain. Sparse marks stay depth-tested.
	var started := false
	for arc in 5:
		for step_index in 7:
			var angle := float(arc) * TAU / 5. + .19 * sin(arc * 3.1) + float(step_index) * .025
			var d := Vector3(sin(angle), 0, cos(angle))
			var h: float = ground.call(c + d * r)
			var rad := sqrt(maxf(0., r * r - (h - c.y) * (h - c.y)))
			if rad < .01:
				continue
			var p := c + d * rad
			p.y = ground.call(p) + .025
			var side := Vector3(d.z, 0, -d.x) * .047
			var taper := sin(PI * (step_index + .5) / 7.)
			if not started:
				mark_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, ink)
				started = true
			mark_mesh.surface_set_color(Color(.58, .54, .45, .12 + .24 * taper))
			for v in [p - side, p + side, p - d * .023 * taper]:
				mark_mesh.surface_add_vertex(v)
	if started:
		mark_mesh.surface_end()


func stop_audio() -> void:
	for v in voices.values():
		v.stop()
		v.stream = null
