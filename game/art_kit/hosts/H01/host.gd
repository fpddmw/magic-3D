extends RigidBody3D
const HERE = "res://art_kit/hosts/H01/"
const MASK = preload("res://art_kit/families/F03_arc_blade/textures/erosion_mask.png")
var kind: Dictionary
var surface: MeshInstance3D
var overlay := ShaderMaterial.new()
var dust := GPUParticles3D.new()
var voice := AudioStreamPlayer3D.new()
var tone: AudioStream
var control_state := "world"
var controller: WeakRef
var play_stress_audio := true
var show_contact_dust := true
var unloading := -1.
var last_load := 0.
var contact_count := 0
var lift_y := 0.
var lifted := false
var support_hit: Dictionary
var ground_marks := 0
var clock := 0.
var last_sound := -2.
var impact_speed := 0.


func build(definition: Dictionary) -> void:
	kind = definition
	mass = kind.mass_kg
	var art = load(HERE + "models/" + kind.id + ".glb").instantiate()
	add_child(art)
	surface = art.find_children("*", "MeshInstance3D", true, false)[0]
	surface.layers = 4
	var collider := CollisionShape3D.new()
	collider.shape = surface.mesh.create_convex_shape(true, true)
	add_child(collider)
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 8
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = .69
	physics_material_override.bounce = .12
	overlay.shader = preload(HERE + "stress.gdshader")
	overlay.set_shader_parameter("vein", MASK)
	# Only overlay the material while a world force is actively loading this host.
	linear_damp = .12
	angular_damp = .36
	add_child(voice)
	voice.unit_size = 5.
	tone = (
		preload(HERE + "oak_strain.wav")
		if kind.medium == "timber"
		else preload(HERE + "S09_stone_drag.wav")
	)
	voice.stream = tone
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(.22, .025, .21)
	pm.direction = Vector3.UP
	pm.spread = 71.
	pm.initial_velocity_min = .38
	pm.initial_velocity_max = 1.3
	pm.gravity = Vector3(0, -1.8, 0)
	pm.scale_min = .24
	pm.scale_max = 1.35
	var quad := QuadMesh.new()
	quad.size = Vector2(.39, .39)
	var shader := ShaderMaterial.new()
	shader.shader = preload(HERE + "dust.gdshader")
	shader.set_shader_parameter("grains", MASK)
	quad.material = shader
	dust.emitting = false
	dust.one_shot = true
	dust.explosiveness = .87
	dust.amount = 20
	dust.lifetime = .64
	dust.process_material = pm
	dust.draw_pass_1 = quad
	dust.top_level = true
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dust)
	body_entered.connect(on_contact)


func sound(db: float, pitch: float) -> void:
	if not play_stress_audio or DisplayServer.get_name() == "headless" or clock - last_sound < .35:
		return
	last_sound = clock
	voice.pitch_scale = pitch
	voice.volume_db = db
	voice.play()


func dust_at(point: Vector3) -> void:
	dust.global_position = point + Vector3.UP * .03
	dust.restart()
	dust.emitting = true


func mark_ground(hit: Dictionary) -> void:
	var floor_body = instance_from_id(hit.collider_id) as StaticBody3D
	if not floor_body:
		return
	var normal: Vector3 = hit.normal
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE * clampf(.57 + mass * .025, .65, 1.5)
	var material := ShaderMaterial.new()
	material.shader = preload(HERE + "ground_fissure.gdshader")
	mesh.material = material
	var mark := MeshInstance3D.new()
	mark.mesh = mesh
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	floor_body.add_child(mark)
	mark.global_transform = Transform3D(
		Basis(Quaternion(Vector3.UP, normal)) * Basis(Vector3.UP, rotation.y),
		hit.position + normal * .006
	)
	var tail := mark.create_tween()
	tail.tween_interval(.92)
	tail.tween_property(mark, "transparency", 1., 1.25)
	tail.tween_callback(mark.queue_free)
	ground_marks += 1


func take_control(owner_ref: RefCounted, expression: Dictionary) -> void:
	show_contact_dust = expression.get("lift_dust", "") == "X03"
	play_stress_audio = expression.get("stone_audio", "") == "S09"
	controller = weakref(owner_ref)
	unloading = -1.
	control_state = "held"
	lifted = false
	lift_y = global_position.y
	var ray := PhysicsRayQueryParameters3D.create(
		global_position, global_position + Vector3.DOWN * 2.
	)
	ray.exclude = [get_rid()]
	support_hit = get_world_3d().direct_space_state.intersect_ray(ray)
	if not support_hit.is_empty() and not get_colliding_bodies().has(support_hit.collider):
		support_hit.clear()
	surface.material_overlay = overlay
	sleeping = false
	sound(-13., clampf(1.25 - mass * .012, .68, 1.22))


func load_surface(ratio: float) -> void:
	last_load = clampf(ratio, 0., 1.)
	overlay.set_shader_parameter("load_ratio", last_load)
	overlay.set_shader_parameter("art_clock", clock)
	if not lifted and global_position.y - lift_y > .09:
		lifted = true
		if show_contact_dust and not support_hit.is_empty():
			dust_at(support_hit.position)
			mark_ground(support_hit)
			support_hit.clear()


func handoff(next: String) -> void:
	controller = null
	control_state = next
	unloading = 0.
	# A few grains shed from the actual departing surface, retaining its position in space.
	var rim: Vector3 = surface.mesh.get_aabb().get_endpoint(0) * .50
	if show_contact_dust:
		dust_at(to_global(rim))


func _physics_process(dt: float) -> void:
	clock += dt
	if unloading >= 0.:
		unloading += dt
		overlay.set_shader_parameter(
			"load_ratio", last_load * (1. - smoothstep(0., .27, unloading))
		)
		if unloading >= .27:
			surface.material_overlay = null
			unloading = -1.
	impact_speed = maxf(linear_velocity.length(), impact_speed * exp(-dt * 8.))


func on_contact(_other: Node) -> void:
	if control_state in ["dispatched", "released"] and impact_speed > 1.25:
		contact_count += 1
		sound(-8., clampf(1.23 - mass * .011, .73, 1.3))
