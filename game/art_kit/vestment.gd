extends RefCounted


# Revolved cloth with an open front, alternating pleats and individually torn hems.
static func fabric(
	parent: Node3D, length: float, radius: float, shoulder: float, tint: Color, full: bool
) -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = .91
	st.set_material(mat)
	var span = TAU if full else PI * 1.56
	for i in 40:
		for j in 7:
			for corner in [
				Vector2i(0, 0),
				Vector2i(1, 0),
				Vector2i(0, 1),
				Vector2i(0, 1),
				Vector2i(1, 0),
				Vector2i(1, 1)
			]:
				var u = float(i + corner.x) / 40.
				var v = float(j + corner.y) / 7.
				var theta = (u - .5) * span
				var fold = cos(theta * 13. + v * .9)
				var r = radius * (.65 + .39 * v) + fold * (.014 + .039 * v)
				var hem = (.045 + .18 * abs(sin(theta * 7. + 1.) * cos(theta * 12.))) * pow(v, 6.)
				var trim = (i in [1, 38] or j == 5) and not full
				var color = Color("#787059") if trim else tint
				st.set_color(color.darkened(.18 * (1. - fold) * .5))
				st.set_uv(Vector2(u, v))
				st.add_vertex(
					Vector3(
						sin(theta) * r * (1.17 - .17 * v),
						shoulder - v * length + hem,
						cos(theta) * r * .85 + v * .06
					)
				)
	st.generate_normals()
	var mesh = MeshInstance3D.new()
	mesh.mesh = st.commit()
	parent.add_child(mesh)
	return mesh


static func harness(actor, parent: Node3D, armored: bool) -> void:
	var cloth = Color("#403437") if armored else Color("#273642")
	var iron = Color("#656c72")
	fabric(parent, 1.28, .44, 1.46, cloth, false)
	fabric(parent, .64, .33, .93, Color("#454747"), true)
	for side in [-1, 1]:
		for part in [[.16, .35, .15, .51], [.135, .40, .135, .21], [.145, .16, .22, .09]]:
			var boot = BoxMesh.new()
			boot.size = Vector3(part[0] * 2, part[1], part[2] * 2)
			actor.mesh(parent, boot, Vector3(side * .17, part[3], -.035), Color("#373d43"))
		for part in [[.125, .34, 1.13], [.108, .29, .89]]:
			var guard = CylinderMesh.new()
			guard.top_radius = part[0]
			guard.bottom_radius = part[0] * .83
			guard.height = part[1]
			actor.mesh(parent, guard, Vector3(side * .36, part[2], -.07), iron).rotation.z = (
				side * .08
			)
	for j in 4:
		var collar = CylinderMesh.new()
		collar.radial_segments = 12
		collar.top_radius = .31 - j * .022
		collar.bottom_radius = .35 - j * .023
		collar.height = .095
		actor.mesh(parent, collar, Vector3(0, 1.32 + j * .055, 0), iron.darkened(j * .06)).scale.z = .82
	var crest = BoxMesh.new()
	crest.size = Vector3(.04, .29, .40)
	actor.mesh(parent, crest, Vector3(0, 1.73, -.035), Color("#a59a7b"))
	var belt = CylinderMesh.new()
	belt.height = .11
	belt.top_radius = .32
	belt.bottom_radius = .33
	actor.mesh(parent, belt, Vector3(0, .98, 0), Color("#776449"))
