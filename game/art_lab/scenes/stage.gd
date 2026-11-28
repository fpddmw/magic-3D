extends Node3D

const Hall = preload("res://runtime/architecture.gd")
const ROCK = preload("res://assets/textures/observatory/crystal_normal.png")
var hall: Node3D
var ledge: Node3D
var environment := Environment.new()
var open := false
var sun := DirectionalLight3D.new()
var rim := DirectionalLight3D.new()


func _ready() -> void:
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := PanoramaSkyMaterial.new()
	sky_material.panorama = preload("res://assets/textures/observatory/dark_sky.jpg")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#afc0cf")
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.glow_enabled = true
	environment.glow_intensity = .32
	environment.ssao_enabled = true
	environment.ssao_radius = .85
	environment.ssao_intensity = 2.0
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.065
	environment.adjustment_saturation = .88
	environment.glow_bloom = .08
	environment.fog_enabled = true
	environment.fog_light_color = Color("#28333e")
	environment.fog_light_energy = .55
	environment.fog_sun_scatter = .03
	environment.fog_sky_affect = .12
	add_child(sun)
	sun.rotation_degrees = Vector3(-37, -51, -12)
	sun.light_color = Color("#ecdfcb")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 50
	add_child(rim)
	var key := DirectionalLight3D.new()
	key.light_cull_mask = 2
	key.rotation_degrees = Vector3(-31, 39, 0)
	key.light_color = Color("#d3e4f4")
	key.light_energy = 1.24
	add_child(key)
	rim.rotation_degrees = Vector3(-19, 145, 5)
	rim.light_color = Color("#abcdf5")
	rim.light_energy = .67
	hall = Hall.new()
	add_child(hall)
	for pane in hall.get_children():
		if pane is MeshInstance3D and pane.mesh is CylinderMesh and pane.position.z < -20.:
			var old: StandardMaterial3D = pane.material_override
			if old:
				old.emission_energy_multiplier = .39
				old.emission = Color("#586f85")
	ledge = make_terrace()
	add_child(ledge)
	set_space(false)


func make_terrace() -> Node3D:
	var root := Node3D.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var noise := FastNoiseLite.new()
	noise.seed = 6329
	noise.frequency = .11
	var point := func(x: float, z: float) -> Vector3:
		var rough := noise.get_noise_2d(x, z)
		var escarpment := smoothstep(8., 16., -z + rough * 3.) * 3.6
		return Vector3(
			x, -.025 + rough * .56 * smoothstep(2.5, 10., Vector2(x, z).length()) - escarpment, z
		)
	for x in range(-22, 22):
		for z in range(-19, 15):
			for uv in [
				Vector2i(0, 0),
				Vector2i(1, 0),
				Vector2i(1, 1),
				Vector2i(0, 0),
				Vector2i(1, 1),
				Vector2i(0, 1)
			]:
				var v: Vector3 = point.call(x + uv.x, z + uv.y)
				surface.set_uv(Vector2(v.x, v.z) * .42)
				surface.add_vertex(v)
	surface.generate_normals()
	surface.generate_tangents()
	var m := MeshInstance3D.new()
	m.mesh = surface.commit()
	var stone := StandardMaterial3D.new()
	stone.albedo_texture = preload("res://art_kit/slate.jpg")
	stone.albedo_color = Color("#9e9b99")
	stone.normal_enabled = true
	stone.normal_texture = ROCK
	stone.normal_scale = .72
	stone.roughness = .66
	m.material_override = stone
	root.add_child(m)
	m.create_trimesh_collision()
	return root


func set_space(exterior: bool) -> void:
	open = exterior
	hall.visible = not exterior
	ledge.visible = exterior
	for stage in [hall, ledge]:
		for body in stage.find_children("*", "StaticBody3D", true, false):
			body.collision_layer = 1 if stage.visible else 0
	environment.background_energy_multiplier = .66 if exterior else .26
	environment.ambient_light_energy = .40 if exterior else .21
	environment.fog_density = .008 if exterior else .015
	sun.light_energy = 1.12 if exterior else .34
	rim.light_energy = .40 if exterior else .20
	environment.tonemap_exposure = .85 if exterior else .84
