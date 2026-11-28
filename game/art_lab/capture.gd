extends RefCounted

var failed := false


func shot(lab, directory: String, filename: String) -> Image:
	for frame in 3:
		await RenderingServer.frame_post_draw
	var img: Image = lab.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var err := img.save_png(directory.path_join(filename + ".png"))
	if err != OK:
		failed = true
		push_error("Capture " + filename + ": " + error_string(err))
	img.resize(480, roundi(480.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
	return img


func panel(images: Array, cols: int, cell_width: int, dest: String) -> void:
	var cell_height := roundi(float(images[0].get_height()) / images[0].get_width() * cell_width)
	var rows := ceili(float(images.size()) / cols)
	var sheet := Image.create_empty(
		cols * (cell_width + 4) + 4, rows * (cell_height + 4) + 4, false, Image.FORMAT_RGB8
	)
	sheet.fill(Color("#20242a"))
	for n in images.size():
		var scaled: Image = images[n].duplicate()
		scaled.resize(cell_width, cell_height, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(
			scaled,
			Rect2i(Vector2i.ZERO, scaled.get_size()),
			Vector2i(4 + (n % cols) * (cell_width + 4), 4 + (n / cols) * (cell_height + 4))
		)
	if sheet.save_png(dest) != OK:
		failed = true
		push_error("Could not save contact sheet: " + dest)


func run(lab, directory: String) -> void:
	failed = false
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		push_error("Capture directory: " + error_string(error))
		if not lab.review_path.is_empty():
			lab.get_tree().quit(1)
		return
	var study: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://art_lab/reference_studies/celestial_descent.json")
	)
	var cases: Array = JSON.parse_string(
		FileAccess.get_file_as_string("res://art_lab/variations/review.json")
	)
	var snapshots := []
	var records := []
	var moon = lab.moons[0]
	var state := [
		lab.view,
		lab.set_piece.open,
		lab.double_cast,
		lab.cut_at,
		lab.turn,
		lab.turn_at,
		lab.rehearsal,
		lab.t,
		moon.mask.duplicate(),
		lab.yaw_offset
	]
	lab.playing = false
	lab.rehearsal = ""
	lab.turn = false
	lab.turn_at = 4.
	lab.double_cast = false
	lab.cut_at = -1.
	lab.yaw_offset = 0.
	lab.set_space(false)
	moon.mask = [true, true, true, true]
	await lab.get_tree().physics_frame
	await lab.get_tree().physics_frame
	for i in study.times.size():
		for v in 3:
			lab.view = v
			lab.seek(study.times[i])
			snapshots.append(await shot(lab, directory, "phase_%d_view_%d" % [i, v]))
		records.append(
			{
				"t": lab.t,
				"phase": study.phases[i],
				"released": moon.launched,
				"contact": moon.contact_time,
				"center": str(moon.global_position)
			}
		)
	panel(snapshots, 3, 480, directory.path_join("contact-sheet.png"))
	snapshots.clear()
	lab.view = 1
	for layer in 4:
		for n in 4:
			moon.mask[n] = n == layer
		lab.seek(3.2)
		snapshots.append(await shot(lab, directory, "layer_%d" % layer))
	panel(snapshots, 2, 480, directory.path_join("layers.png"))
	snapshots.clear()
	moon.mask = [true, true, true, true]
	for i in cases.size():
		var cfg: Dictionary = cases[i]
		lab.set_space(cfg.get("open", false))
		lab.double_cast = cfg.get("double", false)
		lab.cut_at = cfg.get("interrupt", -1.)
		lab.turn = cfg.get("turn", false)
		lab.view = cfg.view
		await lab.get_tree().physics_frame
		lab.seek(cfg.time)
		snapshots.append(await shot(lab, directory, "condition_%d" % i))
		records.append(
			{
				"case": cfg.name,
				"t": lab.t,
				"open": lab.set_piece.open,
				"launched": moon.launched,
				"instances": 2 if lab.double_cast else 1
			}
		)
	panel(snapshots, 2, 480, directory.path_join("conditions.png"))
	var measurements := continuity(lab)
	if not measurements.passed:
		failed = true
		push_error("Cast continuity check failed")
	var f := FileAccess.open(directory.path_join("observations.json"), FileAccess.WRITE)
	if not f:
		push_error("Cannot write observations: " + error_string(FileAccess.get_open_error()))
		if not lab.review_path.is_empty():
			lab.get_tree().quit(1)
		return
	f.store_string(
		JSON.stringify(
			{
				"engine": Engine.get_version_info().string,
				"device": RenderingServer.get_video_adapter_name(),
				"driver": RenderingServer.get_current_rendering_driver_name(),
				"method": RenderingServer.get_current_rendering_method(),
				"continuity": measurements,
				"records": records
			},
			"\t"
		)
	)
	f.close()
	print("ArtLab captured: ", directory)
	if not lab.review_path.is_empty():
		lab.get_tree().quit(1 if failed else 0)
	else:
		lab.view = state[0]
		lab.set_space(state[1])
		lab.double_cast = state[2]
		lab.cut_at = state[3]
		lab.turn = state[4]
		lab.turn_at = state[5]
		lab.rehearsal = state[6]
		moon.mask = state[8]
		lab.yaw_offset = state[9]
		lab.seek(state[7])
		lab.panel.visible = true
		lab.special = false


# Compare two histories at identical times. Only the caster turns after release.
func continuity(lab) -> Dictionary:
	lab.double_cast = false
	lab.cut_at = -1.
	lab.turn = false
	lab.set_space(false)
	var m = lab.moons[0]
	lab.seek(m.RELEASE - 0.00001)
	var before: Vector3 = m.global_position
	var identity: int = m.core.get_instance_id()
	lab.t = m.RELEASE
	lab.sample()
	var jump: float = before.distance_to(m.global_position)
	lab.t = 4.8
	lab.sample()
	var straight: Vector3 = m.global_position
	lab.turn = true
	lab.turn_at = 4.
	lab.seek(4.8)
	var turn_delta: float = straight.distance_to(m.global_position)
	lab.seek(7.3)
	var hit: float = m.contact_time
	lab.cut_at = 2.5
	lab.seek(4.8)
	var no_departure: bool = not m.launched and m.contact_time < 0.
	var stable: bool = identity == m.core.get_instance_id()
	return {
		"transfer_jump_m": jump,
		"post_turn_delta_m": turn_delta,
		"same_core": stable,
		"contact_s": hit,
		"cut_prevents_departure": no_departure,
		"passed": jump < .002 and turn_delta < .0001 and stable and hit > m.RELEASE and no_departure
	}
