extends RefCounted


static func mesh(seed_value: int, extent: Vector3) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rings: Array = []
	var count := 9
	var angles := []
	for i in count:
		angles.append(TAU * (i + rng.randf_range(-.16, .16)) / count)
	for level in range(4):
		var row := []
		for a in angles:
			var r: float = [.67, 1., .91, .57][level] * rng.randf_range(.87, 1.08)
			var y: float = [-.82, -.41, .44, .89][level] + rng.randf_range(-.09, .09)
			row.append(Vector3(cos(a) * r + .13 * y, y, sin(a) * r - .12 * y) * extent)
		rings.append(row)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var j := (i + 1) % count
		for k in 3:
			face(surface, rings[k][i], rings[k + 1][j], rings[k + 1][i])
			face(surface, rings[k][i], rings[k][j], rings[k + 1][j])
		face(surface, Vector3.DOWN * extent.y * .85, rings[0][j], rings[0][i])
		face(surface, Vector3.UP * extent.y * .90, rings[3][i], rings[3][j])
	surface.generate_tangents()
	return surface.commit()


static func face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (c - a).cross(b - a).normalized()
	if normal.dot((a + b + c) / 3.) < 0:
		var swap := b
		b = c
		c = swap
		normal = -normal
	for p in [a, b, c]:
		st.set_normal(normal)
		st.set_uv(Vector2(p.x + p.y * .34, p.z + p.y * .68))
		st.add_vertex(p)


static func skin(body: RigidBody3D, extent: Vector3, seed_value: int, tint: Color) -> void:
	var m := mesh(seed_value, extent)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://art_kit/materials/cleaved_stone.gdshader")
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("rock", preload("res://art_kit/slate.jpg"))
	mat.set_shader_parameter(
		"relief", preload("res://assets/textures/observatory/crystal_normal.png")
	)
	body.get_child(0).mesh = m
	body.get_child(0).material_override = mat
	body.get_child(1).shape = m.create_convex_shape(true, false)
	var physical := PhysicsMaterial.new()
	physical.friction = .22
	physical.bounce = .13
	body.physics_material_override = physical
	body.linear_damp = .025
	body.angular_damp = .04


# A fallen fluted column drum. The continuous rim can roll past the field before release.
static func drum(body: RigidBody3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile := [
		[0.01, -.22],
		[.28, -.22],
		[.31, -.20],
		[.38, -.20],
		[.42, -.16],
		[.42, -.12],
		[.38, -.10],
		[.36, .10],
		[.42, .13],
		[.42, .17],
		[.38, .20],
		[.28, .20],
		[.01, .20]
	]
	for k in range(profile.size() - 1):
		for i in 96:
			var vertices := []
			for ix in [i, i + 1]:
				for band in [k, k + 1]:
					var theta: float = TAU * ix / 96.
					var rad: float = profile[band][0]
					if band in [6, 7]:
						rad -= .026 * pow(.5 + .5 * cos(theta * 16.), 2.)
					vertices.append(Vector3(cos(theta) * rad, profile[band][1], sin(theta) * rad))
			face(st, vertices[0], vertices[1], vertices[2])
			face(st, vertices[2], vertices[1], vertices[3])
	st.generate_tangents()
	body.get_child(0).mesh = st.commit()
	var shape := CylinderShape3D.new()
	shape.radius = .42
	shape.height = .42
	body.get_child(1).shape = shape
	body.rotation.x = PI / 2.
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = .018
	body.angular_damp = .014
	body.linear_velocity = Vector3(1.23, 0., 0.)
	body.angular_velocity = Vector3(0., 0., -1.23 / .42)
