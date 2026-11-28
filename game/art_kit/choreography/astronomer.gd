extends RefCounted


static func dress(artist: Node3D) -> void:
	var textiles := {
		"Ash brocade": ["#788379", .14],
		"Midnight velvet": ["#202b3b", .11],
		"Old gilt": ["#b69763", .78],
		"Gunmetal": ["#4a5964", .82],
		"Waxed leather": ["#48352a", .19]
	}
	for item in artist.find_children("*", "MeshInstance3D", true, false):
		item.layers = 2
		for surface in item.mesh.get_surface_count():
			var original: Material = item.mesh.surface_get_material(surface)
			if not original or not textiles.has(original.resource_name):
				continue
			var spec: Array = textiles[original.resource_name]
			var mat := ShaderMaterial.new()
			mat.shader = preload("res://art_kit/materials/vestment.gdshader")
			mat.set_shader_parameter("dye", Color(spec[0]))
			mat.set_shader_parameter("metal", spec[1])
			mat.set_shader_parameter(
				"engraving", preload("res://assets/textures/observatory/etch_normal.png")
			)
			item.set_surface_override_material(surface, mat)
