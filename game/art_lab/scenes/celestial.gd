extends Node3D

const Transport = preload("res://art_kit/deformation/transport.gd")
const Domain = preload("res://art_kit/geometry/ribbon_mesh.gd")
const RELIEF = preload("res://assets/textures/observatory/lunar_relief.png")
const NORMAL = preload("res://assets/textures/observatory/lunar_normal.png")
const FLOW = preload("res://assets/textures/observatory/flow.png")
const GLINT = preload("res://assets/textures/observatory/glint.png")
const RELEASE := 3.85
const MAX_RADIUS := .83
const END := 7.8
var core: MeshInstance3D
var shell: MeshInstance3D
var streamers := Node3D.new()
var motes := GPUParticles3D.new()
var corona := OmniLight3D.new()
var core_mat := ShaderMaterial.new()
var shell_mat := ShaderMaterial.new()
var dust_mat := ShaderMaterial.new()
var curves: Array[ShaderMaterial] = []
var mask := [true, true, true, true]
var launched := false
var released_at := Vector3.ZERO
var inherited_velocity := Vector3.ZERO
var flight_position := Vector3.ZERO
var flight_velocity := Vector3.ZERO
var flight_step := 0
var contact_time := -1.
var contact_position := Vector3.ZERO
var interrupt_time := -1.
var interrupt_origin := Vector3.ZERO
var sphere_query := PhysicsShapeQueryParameters3D.new()
var radius := .01
var phase_offset := 0.


func globe(mat: ShaderMaterial, segments: int) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.
	mesh.height = 2.
	mesh.radial_segments = segments
	mesh.rings = segments / 2
	var skin := MeshInstance3D.new()
	skin.mesh = mesh
	skin.layers = 2
	skin.material_override = mat
	skin.custom_aabb = AABB(Vector3(-1.3, -1.3, -1.3), Vector3.ONE * 2.6)
	skin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(skin)
	return skin


func _ready() -> void:
	core_mat.shader = preload("res://art_kit/materials/lunar_surface.gdshader")
	core_mat.set_shader_parameter("geology", RELIEF)
	core_mat.set_shader_parameter("relief", NORMAL)
	core = globe(core_mat, 128)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	shell_mat.shader = preload("res://art_kit/materials/optical_shell.gdshader")
	shell_mat.set_shader_parameter("turbulence", FLOW)
	shell_mat.render_priority = 0
	shell = globe(shell_mat, 80)
	add_child(streamers)
	var domain: ArrayMesh = Domain.strip()
	for j in 3:
		var band := MeshInstance3D.new()
		band.mesh = domain
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://art_kit/materials/swept_light.gdshader")
		mat.set_shader_parameter("flow", FLOW)
		mat.set_shader_parameter(
			"silver", [Vector3(.49, .70, .95), Vector3(.77, .70, .49), Vector3(.57, .67, .79)][j]
		)
		mat.render_priority = j + 1
		band.material_override = mat
		band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		streamers.add_child(band)
		curves.append(mat)
	dust_mat.shader = preload("res://art_kit/particles/circumstellar.gdshader")
	var spark := ShaderMaterial.new()
	spark.shader = preload("res://art_kit/particles/starlight.gdshader")
	spark.set_shader_parameter("sprite", GLINT)
	spark.render_priority = 5
	var quad := QuadMesh.new()
	quad.material = spark
	motes.amount = 1600
	motes.lifetime = 12.
	motes.explosiveness = 1.
	motes.fixed_fps = 0
	motes.local_coords = false
	motes.use_fixed_seed = true
	motes.seed = 194
	motes.visibility_aabb = AABB(Vector3(-15, -12, -16), Vector3(30, 26, 32))
	motes.process_material = dust_mat
	motes.draw_pass_1 = quad
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(motes)
	motes.emitting = true
	corona.light_color = Color("#9bbbe1")
	corona.omni_range = 4.2
	add_child(corona)
	var collider := SphereShape3D.new()
	collider.radius = MAX_RADIUS
	sphere_query.shape = collider
	sphere_query.collision_mask = 1


func reset_motion() -> void:
	launched = false
	contact_time = -1.
	flight_step = 0
	interrupt_time = -1.


func interrupt(t: float) -> void:
	if t < RELEASE and interrupt_time < 0.:
		interrupt_time = t
		interrupt_origin = global_position


func release(anchor: Vector3, velocity: Vector3, direction: Vector3) -> void:
	if launched or interrupt_time >= 0.:
		return
	launched = true
	released_at = anchor
	inherited_velocity = velocity
	flight_position = anchor
	flight_velocity = velocity + direction.normalized() * 2.5 + Vector3.UP * .32


func advance_flight(t: float) -> void:
	var wanted := maxi(0, roundi((t - RELEASE) * 60.))
	while flight_step < wanted and contact_time < 0.:
		var gravity := Vector3.DOWN * 1.48
		var motion := flight_velocity / 60. + gravity / (2. * 3600.)
		sphere_query.transform = Transform3D(Basis.IDENTITY, flight_position)
		sphere_query.motion = motion
		var fractions := get_world_3d().direct_space_state.cast_motion(sphere_query)
		var fraction := fractions[0] if fractions.size() == 2 else 1.
		flight_position += motion * fraction
		flight_velocity += gravity * fraction / 60.
		flight_step += 1
		if fraction < 1.:
			contact_time = RELEASE + (flight_step - 1 + fraction) / 60.
			sphere_query.transform = Transform3D(
				Basis.IDENTITY, flight_position + motion * (fractions[1] - fraction + .004)
			)
			sphere_query.motion = Vector3.ZERO
			var hit := get_world_3d().direct_space_state.get_rest_info(sphere_query)
			contact_position = hit.get("point", flight_position + Vector3.DOWN * MAX_RADIUS)


func bands(t: float, growth: float, strength: float) -> void:
	for j in curves.size():
		var pts := PackedVector3Array()
		for i in Transport.COUNT:
			var s := float(i) / (Transport.COUNT - 1)
			var lag: float = Transport.settle(t - .42 - s * (.57 + .1 * j) - j * .17, 2.2)
			var theta := s * (4.85 - j * .43) + j * 1.97 + t * (.34 - .075 * j) + phase_offset
			var r := (.29 + .89 * lag) * (1.03 + .14 * sin(s * 5.2 + t * .48 + j)) * (1. + .09 * j)
			var vertical := (
				(
					.48 * cos(theta + j * .8)
					+ .38 * sin(theta - j * 1.35)
					+ .15 * sin(theta * 2. + s * 2. - t * .4)
				)
				* r
			)
			pts.append(
				Vector3(
					cos(theta) * r,
					vertical + .36 * sin(s * PI + j * 1.2) * (1. - lag),
					sin(theta) * r
				)
			)
		var mat: ShaderMaterial = curves[j]
		mat.set_shader_parameter("spine", pts)
		mat.set_shader_parameter("frames", Transport.frames(pts))
		mat.set_shader_parameter("width", [.42, .16, .24][j] * (.24 + .76 * growth))
		mat.set_shader_parameter("reveal", clampf((t - .48 - j * .2) * .58, 0, 1.15))
		mat.set_shader_parameter("intensity", strength * [.91, .46, .49][j])
		mat.set_shader_parameter("phase", t)


func display(t: float, anchor: Vector3) -> void:
	if launched:
		advance_flight(t)
	var clock := minf(t, interrupt_time) if interrupt_time >= 0. else t
	var grow := smoothstep(.22, 2.94, clock)
	var fade := 0.
	if interrupt_time >= 0.:
		fade = smoothstep(interrupt_time, interrupt_time + .44, t)
	elif contact_time >= 0.:
		fade = smoothstep(contact_time, contact_time + .82, t)
	else:
		fade = smoothstep(7.08, 7.65, t)
	global_position = (
		flight_position if launched else (interrupt_origin if interrupt_time >= 0. else anchor)
	)
	radius = lerpf(.10, MAX_RADIUS, grow)
	core.visible = mask[0] and t > .22 and fade < .998
	core.rotation = Vector3(.13, phase_offset + t * .13, .18)
	core_mat.set_shader_parameter("radius", radius)
	core_mat.set_shader_parameter("assembly", smoothstep(.23, 2.37, clock))
	core_mat.set_shader_parameter("withdrawal", fade)
	shell.visible = mask[1] and t > .25 and fade < .998
	shell_mat.set_shader_parameter("inner_radius", radius * .996)
	shell_mat.set_shader_parameter("outer_radius", radius * (1.09 + .041 * grow))
	shell_mat.set_shader_parameter("strength", grow * (1. - fade))
	shell_mat.set_shader_parameter("phase", t)
	streamers.visible = mask[2] and t > .4 and fade < .999
	bands(clock, grow, 1. - fade)
	motes.visible = mask[3] and t > .45 and fade < .999
	dust_mat.set_shader_parameter("center", global_position)
	var wake := PackedVector3Array()
	for i in 8:
		var age := minf(maxf(0, t - RELEASE), float(i) * .075) if launched else 0.
		wake.append(global_position - flight_velocity * age)
	dust_mat.set_shader_parameter("wake", wake)
	dust_mat.set_shader_parameter("strength", grow * (1. - fade))
	dust_mat.set_shader_parameter("radius", radius * 1.26)
	dust_mat.set_shader_parameter("epoch", t)
	corona.light_energy = 1.4 * grow * (1. - fade) if mask.any(func(v): return v) else 0.
