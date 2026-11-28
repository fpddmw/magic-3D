extends RefCounted

const Stone = preload("res://art_lab/f08/stone.gd")


static func neutral(root: Node3D) -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#303238")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b8bdc2")
	env.ambient_light_energy = .64
	world.environment = env
	root.add_child(world)
	for light in [[Vector3(-45, -32, -8), 1.38], [Vector3(-24, 138, 0), .82]]:
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = light[0]
		sun.light_energy = light[1]
		root.add_child(sun)


static func box(root: Node3D, pos: Vector3, size: Vector3, tint: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = .91
	mesh.material = mat
	node.mesh = mesh
	node.position = pos
	root.add_child(node)


static func barrier(root: Node3D, cloth: MeshInstance3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 0
	root.add_child(body)
	body.global_transform = cloth.global_transform
	var shape := CollisionShape3D.new()
	shape.shape = cloth.mesh.create_trimesh_shape()
	body.add_child(shape)
	return body


static func launch(root: Node3D, cfg: Dictionary, body: StaticBody3D, veil):
	var stone := Stone.new()
	stone.mass = cfg.mass_kg
	stone.capacity_kg = cfg.capacity_kg
	stone.position = Vector3(cfg.start[0], cfg.start[1], cfg.start[2])
	stone.rotation_degrees = Vector3(-13, 18, -26)
	stone.gravity_scale = cfg.gravity_scale
	stone.constant_force = Vector3(0,0,cfg.force_z)
	stone.collision_layer = 2
	stone.collision_mask = 1 | 4
	stone.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	stone.linear_damp = .02
	stone.barrier = body
	stone.veil = veil
	root.add_child(stone)
	stone.linear_velocity = Vector3(0,0,cfg.speed_z)
	return stone


static func root_dust(root: Node3D) -> CPUParticles3D:
	var dust := CPUParticles3D.new()
	dust.emitting = false
	dust.amount = 240
	dust.lifetime = 1.05
	dust.local_coords = false
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(2.80,.015,.21)
	dust.direction = Vector3(.15,.38,1)
	dust.spread = 58
	dust.initial_velocity_min = .34
	dust.initial_velocity_max = .9
	dust.gravity = Vector3(0,-.44,0)
	dust.scale_amount_min = .10
	dust.scale_amount_max = .29
	var puff := QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	var smoke := GradientTexture2D.new()
	smoke.fill = GradientTexture2D.FILL_RADIAL
	smoke.fill_from = Vector2(.5,.5)
	smoke.fill_to = Vector2(1,.5)
	smoke.gradient = Gradient.new()
	smoke.gradient.colors = PackedColorArray([Color(1,1,1,.48),Color(1,1,1,0)])
	mat.albedo_texture = smoke
	puff.material = mat
	dust.mesh = puff
	dust.color_ramp = Gradient.new()
	dust.color_ramp.colors = PackedColorArray([Color("#99816a95"),Color("#8d807000")])
	dust.position.y = .07
	root.add_child(dust)
	return dust
