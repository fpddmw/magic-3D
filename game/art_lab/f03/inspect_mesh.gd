extends SceneTree
## Render the imported morphs without emissive textures, from six viewing directions.
const CARRIER = preload("res://art_kit/families/F03_arc_blade/F03_arc_blade.glb")

func _initialize() -> void:
	call_deferred("review")

func review() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#222832")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#a1aaba")
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	stage.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-44, -26, 5)
	stage.add_child(sun)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#a6abad")
	material.roughness = .68
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.64
	camera.position = Vector3(0, 0, 5)
	stage.add_child(camera)
	var angles := [Vector3(-52,0,5), Vector3(5,24,-8), Vector3(-35,52,20),
		Vector3(32,160,8), Vector3(3,5,0), Vector3(-42,213,0)]
	for i in 6:
		var model = CARRIER.instantiate()
		stage.add_child(model)
		var form = "narrow_edge" if i < 3 else "wide_crescent"
		var body: MeshInstance3D = model.get_node(form)
		for child in model.get_children():
			child.visible = child == body
		body.material_override = material
		body.set_blend_shape_value(body.find_blend_shape_by_name("arc_open"), [0., .55, 1., 1., .75, 1.][i])
		if i in [1, 2, 5]:
			body.set_blend_shape_value([0, 0, 2, 0, 0, 3][i], 1.)
		model.rotation_degrees = angles[i]
		model.position = Vector3((i%3-1)*2.22, (.5-floori(i/3.)) * 1.38-.18, 0)
	camera.size = 4.05
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("F03_GRAY")
	var result := root.get_texture().get_image().save_png(path)
	print("F03 GRAY six angles / two forms / four imported morphs: ", result)
	quit(result)
