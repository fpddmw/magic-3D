extends Node3D

const Stage = preload("res://art_lab/scenes/stage.gd")
const Moon = preload("res://art_lab/scenes/celestial.gd")
const Poses = preload("res://art_kit/choreography/poses.gd")
const Stems = preload("res://art_kit/audio/stems.gd")
const Actor = preload("res://assets/models/astronomer.glb")
const Capture = preload("res://art_lab/capture.gd")
var set_piece := Stage.new()
var camera := Camera3D.new()
var casters: Array[Node3D] = []
var rigs: Array[AnimationTree] = []
var skeletons: Array[Skeleton3D] = []
var moons: Array[Node3D] = []
var sound := Stems.new()
var second_voice := Stems.new()
var panel := CanvasLayer.new()
var slider := HSlider.new()
var status := Label.new()
var t := 0.
var playing := true
var view := 0
var double_cast := false
var turn := false
var turn_at := 4.
var cut_at := -1.
var yaw_offset := 0.
var special := false
var frame := 0
var rehearsal := ""
var old_mix: AudioBusLayout
var film := false
var film_rate := 30.
var review_path := ""
var recorder := Capture.new()


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	old_mix = AudioServer.generate_bus_layout()
	add_child(set_piece)
	for k in 2:
		var artist: Node3D = Actor.instantiate()
		add_child(artist)
		dress(artist)
		casters.append(artist)
		skeletons.append(artist.find_children("*", "Skeleton3D", true, false)[0])
		rigs.append(Poses.rig(artist))
		var m := Moon.new()
		m.phase_offset = k * 1.3
		add_child(m)
		moons.append(m)
	AudioServer.set_bus_layout(Stems.LAYOUT)
	add_child(sound)
	add_child(second_voice)
	add_child(camera)
	camera.current = true
	camera.near = .06
	setup_ui()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lab-capture="):
			review_path = arg.trim_prefix("--lab-capture=")
		if arg == "--lab-film":
			film = true
		if arg == "--lab-outdoor":
			set_space(true)
		if arg == "--lab-double":
			double_cast = true
		if arg == "--lab-turn":
			turn = true
		if arg.begins_with("--lab-cut="):
			cut_at = arg.trim_prefix("--lab-cut=").to_float()
	if film or not review_path.is_empty():
		special = true
		panel.visible = false
	if not review_path.is_empty():
		recorder.call_deferred("run", self, review_path)


func dress(artist: Node3D) -> void:
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


func _exit_tree() -> void:
	if old_mix:
		AudioServer.set_bus_layout(old_mix)


func setup_ui() -> void:
	add_child(panel)
	var margin := MarginContainer.new()
	margin.anchor_left = .03
	margin.anchor_top = .80
	margin.anchor_right = .63
	margin.anchor_bottom = .97
	panel.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	status.add_theme_color_override("font_color", Color("#efdfbd"))
	box.add_child(status)
	slider.min_value = 0.
	slider.max_value = Moon.END
	slider.step = 1. / 60.
	slider.value_changed.connect(
		func(value):
			playing = false
			seek(value)
	)
	box.add_child(slider)
	var help := Label.new()
	help.text = "Space  播停    ← → 逐帧    1–5 机位    拖右键 环视    O 内外景    I 打断    T 转身\nQ W E R  分层    D 双术    P 姿态    C 导出图板    H 界面    Esc 回雨殿"
	help.add_theme_font_size_override("font_size", 14)
	box.add_child(help)


func set_space(open: bool) -> void:
	set_piece.set_space(open)
	sound.set_space(open)
	second_voice.set_space(open)


func actor_at(k: int, clock: float) -> Vector3:
	var elapsed := clock
	var was_cut := cut_at >= 0. and clock >= cut_at
	if was_cut:
		clock = cut_at
	var a := casters[k]
	a.position = Vector3(1.86 * k, 0, -.8 * k)
	a.position.y = .64 * smoothstep(.65, 2.65, clock) * (1. - smoothstep(Moon.RELEASE, 5.20, clock))
	a.rotation.y = (
		(-.18 if k == 0 else -.50)
		+ (smoothstep(turn_at, turn_at + .45, clock) * 1.58 if turn else 0.)
	)
	if turn:
		a.position.x += .62 * smoothstep(turn_at, turn_at + .72, elapsed)
	var clip: String
	var u: float
	if not rehearsal.is_empty():
		clip = rehearsal
		u = clampf(clock / Moon.END, 0., 1.)
	elif clock < 1.27:
		clip = "gather"
		u = smoothstep(0, 1.27, clock)
	elif clock < 2.32:
		clip = "open"
		u = smoothstep(1.27, 2.32, clock)
	elif clock < Moon.RELEASE:
		clip = "loft"
		u = smoothstep(2.32, Moon.RELEASE, clock)
	else:
		clip = "release"
		u = 1. - exp(-2.8 * (clock - Moon.RELEASE))
	Poses.sample(rigs[k], clip, u)
	var sk := skeletons[k]
	if was_cut:
		var captured: Array[Quaternion] = []
		for j in sk.get_bone_count():
			captured.append(sk.get_bone_pose_rotation(j))
		var fall := smoothstep(cut_at, cut_at + .62, elapsed)
		Poses.sample(rigs[k], "stagger", fall)
		for j in sk.get_bone_count():
			sk.set_bone_pose_rotation(j, captured[j].slerp(sk.get_bone_pose_rotation(j), fall))
		a.position.y *= 1. - fall
	var hand_idx := sk.find_bone("HandR")
	var hand := sk.to_global(sk.get_bone_global_pose(hand_idx).origin)
	var crown := a.to_global(Vector3(-.79, 2.53 + .17 * smoothstep(1.5, 3.4, clock), .12))
	return hand.lerp(crown, smoothstep(.25, 2.16, clock))


func seek(value: float) -> void:
	t = clampf(value, 0., Moon.END)
	for moon in moons:
		moon.reset_motion()
	sample(true)


func sample(seeking := false) -> void:
	for k in 2:
		var m = moons[k]
		m.visible = k == 0 or double_cast
		casters[k].visible = m.visible
		if not m.visible:
			continue
		var local := maxf(0., t - .71 * k)
		if cut_at >= 0. and cut_at < Moon.RELEASE and local >= cut_at and m.interrupt_time < 0.:
			m.global_position = actor_at(k, cut_at - .0001)
			m.interrupt(cut_at)
		if local >= Moon.RELEASE and not m.launched and m.interrupt_time < 0.:
			var back := actor_at(k, Moon.RELEASE - 1. / 60.)
			var anchor := actor_at(k, Moon.RELEASE - .00001)
			var aim := casters[k].global_basis * Vector3(-.82, .035, -.58)
			m.release(anchor, (anchor - back) * 60., aim)
		var anchor_now := actor_at(k, local)
		m.display(local, anchor_now)
	place_camera()
	for k in 2:
		var rack = sound if k == 0 else second_voice
		var m = moons[k]
		rack.global_position = m.global_position
		if m.contact_time >= 0.:
			rack.voices.stone_contact.global_position = m.contact_position
		rack.sample(
			t - .71 * k,
			m.contact_time,
			m.interrupt_time >= 0. or not playing or not m.visible,
			seeking
		)
	slider.set_value_no_signal(t)
	status.text = (
		"天体降临   /   %s   ·   %.2f s   ·   %s"
		% [
			"暗穹" if set_piece.open else "石殿",
			t,
			rehearsal if not rehearsal.is_empty() else ["三分之四", "月面", "建筑尺度", "侧面", "背面"][view]
		]
	)


func place_camera() -> void:
	var pos: Vector3 = moons[0].global_position
	var framing := Vector3(-.24, 2.06, 0).lerp(pos, .22 if t < Moon.RELEASE else .50)
	var eye := Vector3(2.65, .21, 5.78)
	camera.fov = 43.
	if view == 1:
		framing = pos
		eye = Vector3(.74, .29, 1.98)
		camera.fov = 55.
	elif view == 2:
		eye = Vector3(4.35, -.25, 10.4)
		framing = Vector3(-.4, 2.65, -.7)
		camera.fov = 52.
	elif view == 3:
		eye = Vector3(4.9, -.12, .25)
	elif view == 4:
		eye = Vector3(-2.15, .45, -4.7)
	eye = eye.rotated(Vector3.UP, yaw_offset)
	camera.position = framing + eye
	camera.look_at(framing, Vector3.UP)


func _process(dt: float) -> void:
	if not review_path.is_empty():
		return
	if film:
		t = float(frame) / film_rate
		frame += 1
		if t > Moon.END:
			get_tree().quit()
			return
	elif playing:
		t += minf(dt, .1)
		if t > Moon.END:
			seek(0)
			return
	sample()


func _unhandled_input(event: InputEvent) -> void:
	if special:
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw_offset -= event.relative.x * .007
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			playing = not playing
			sound.last_time = -1.
		KEY_LEFT, KEY_RIGHT:
			playing = false
			seek(t + (1. / 60. if event.keycode == KEY_RIGHT else -1. / 60.))
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			view = event.keycode - KEY_1
			yaw_offset = 0.
		KEY_O:
			set_space(not set_piece.open)
			seek(t)
		KEY_I:
			cut_at = t if t < Moon.RELEASE and cut_at < 0. else -1.
			seek(t)
		KEY_T:
			turn = not turn
			turn_at = t
			seek(t)
		KEY_D:
			double_cast = not double_cast
			seek(t)
		KEY_H:
			panel.visible = not panel.visible
		KEY_Q, KEY_W, KEY_E, KEY_R:
			var n: int = [KEY_Q, KEY_W, KEY_E, KEY_R].find(event.keycode)
			for m in moons:
				m.mask[n] = not m.mask[n]
		KEY_P:
			var names := ["", "gather", "open", "loft", "release", "sweep", "stagger"]
			rehearsal = names[(names.find(rehearsal) + 1) % names.size()]
			seek(0)
		KEY_C:
			playing = false
			special = true
			panel.visible = false
			recorder.run(self, OS.get_user_data_dir() + "/art_lab")
		KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/main.tscn")
