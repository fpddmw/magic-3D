extends RefCounted


# Parameter domain. The vertex shader sweeps these samples in a transported frame.
static func strip(longitudinal: int = 192, across: int = 8) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var positions := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in longitudinal + 1:
		for j in across + 1:
			var parameter := Vector2(float(i) / longitudinal, float(j) / across)
			positions.append(Vector3(parameter.x, parameter.y, 0))
			uv.append(parameter)
			if i < longitudinal and j < across:
				var a := i * (across + 1) + j
				indices.append_array(
					[a, a + 1, a + across + 1, a + 1, a + across + 2, a + across + 1]
				)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	return mesh
