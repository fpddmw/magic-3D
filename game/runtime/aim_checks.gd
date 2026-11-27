extends RefCounted
# A functional test in the main hall. Mouse-look, recipe selection and casting enter
# through the same input handler used by the player. No renderer timing is sampled.

var checks := {}
var samples := {}
var probes := {}


func tick(h, count: int) -> void:
	for i in count:
		await h.get_tree().physics_frame


func aim_at(h, point: Vector3) -> Vector3:
	# Invert the hall's third-person camera arm so its real ray meets the floor mark.
	var delta: Vector3 = point - h.player.global_position
	var yaw = atan2(-delta.x, -delta.z) + asin(1.25 / Vector2(delta.x, delta.z).length())
	var eye = h.player.position + Vector3(1.25, 1.92, 4.).rotated(Vector3.UP, yaw)
	var ray = point - eye
	var pitch = atan2(ray.y, Vector2(ray.x, ray.z).length())
	var motion = InputEventMouseMotion.new()
	motion.relative = Vector2((h.yaw - yaw) / .002, (h.pitch - pitch) / .002)
	h._unhandled_input(motion)
	h.place_camera()
	return h.aim_point()


func button(h, pressed: bool) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = pressed
	h._unhandled_input(event)


func select(h, path: String) -> bool:
	var key = InputEventKey.new()
	key.keycode = KEY_E
	key.pressed = true
	for i in h.catalog.size():
		if h.catalog[h.selected].path.ends_with(path):
			return true
		h._unhandled_input(key)
	return false


func snapshot(h) -> Dictionary:
	var row := {"mana": h.mana}
	for id in probes:
		var b: RigidBody3D = probes[id]
		var v = b.linear_velocity
		row[id] = {"v": [v.x, v.y, v.z], "heat": b.get_meta("temperature_delta", 0.)}
	return row


func v(row, id) -> Vector3:
	var a = row[id].v
	return Vector3(a[0], a[1], a[2])


func vec(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


func run(h) -> void:
	var scene = h.data("res://data/magic_v0_3/studies/aim_field/scene.json")
	var paths = {"fixed": "/wind_fixed.json", "follow": "/wind_follow.json"}
	if "--heldout" in OS.get_cmdline_user_args():
		paths = {"heldout": "/aim_transfer/admitted.json"}
	await tick(h, 4)
	h.player.set_physics_process(false)
	h.player.position = vec(scene.position)
	for o in scene.objects:
		var b = h.world.make_body(
			o.id, vec(o.position), o.mass, Vector3.ONE * .3, h.hall.mats.trim, {}
		)
		b.gravity_scale = 0.
		b.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		b.linear_damp = 0.
		probes[o.id] = b
	var steps = Engine.physics_ticks_per_second
	for mode in paths:
		for o in scene.objects:
			var b: RigidBody3D = probes[o.id]
			b.freeze = true
			b.position = vec(o.position)
			b.linear_velocity = Vector3.ZERO
			b.set_meta("temperature_delta", 0.)
		await tick(h, 2)
		for b in probes.values():
			b.freeze = false
		await tick(h, 2)
		h.mana = scene.caster_mana
		var start = aim_at(h, vec(scene.aim_point))
		checks[mode + "_catalog"] = select(h, paths[mode])
		if not checks[mode + "_catalog"]:
			break
		button(h, true)
		var cast = h.latest_cast
		checks[mode + "_input_began_cast"] = cast != null and cast in h.casts
		if not checks[mode + "_input_began_cast"]:
			break
		await tick(h, roundi(steps * scene.events[0].at))
		var before = snapshot(h)
		var end = aim_at(h, vec(scene.events[0].vector))
		await tick(h, roundi(steps * (scene.events[1].at - scene.events[0].at)))
		var after = snapshot(h)
		checks[mode + "_same_active_cast"] = h.casts == [cast] and h.latest_cast == cast
		button(h, false)
		await tick(h, roundi(steps * (scene.until_s - scene.events[1].at)))
		var coast = snapshot(h)
		samples[mode] = {
			"serial": cast.serial,
			"aim_start": [start.x, start.y, start.z],
			"aim_end": [end.x, end.y, end.z],
			"before_move": before,
			"before_release": after,
			"coast": coast
		}
		checks[mode + "_floor_marks"] = (
			start.distance_to(vec(scene.aim_point)) < .03
			and end.distance_to(vec(scene.events[0].vector)) < .03
		)
		checks[mode + "_initial_recipient"] = (
			v(before, "left").length() > .01 and v(before, "right").length() < .001
		)
		checks[mode + "_release"] = (
			cast.active.is_empty() and is_equal_approx(coast.mana, after.mana)
		)
		for id in probes:
			checks[mode + "_coast_" + id] = v(coast, id).distance_to(v(after, id)) < .005
		var left_delta = v(after, "left") - v(before, "left")
		var right_delta = v(after, "right") - v(before, "right")
		if mode == "fixed":
			checks.fixed_recipient = left_delta.y > .05 and right_delta.length() < .001
		elif mode == "follow":
			checks.follow_recipient = left_delta.length() < .005 and right_delta.y > .05
		else:
			# The preregistered expectation is horizontal displacement away from the
			# floor mark (the probe is on its -Z side), plus local heating.
			checks.heldout_outward = v(before, "left").z < -.03 and right_delta.z < -.03
			checks.heldout_no_spin = absf(v(before, "left").x) < .005 and absf(right_delta.x) < .005
			checks.heldout_horizontal = (
				absf(v(before, "left").y) < .005 and absf(right_delta.y) < .005
			)
			checks.heldout_left_stops = (
				left_delta.length() < .005 and is_equal_approx(after.left.heat, before.left.heat)
			)
			checks.heldout_heat_moves = (
				before.left.heat > 0. and before.right.heat == 0. and after.right.heat > 0.
			)
			checks.heldout_heat_ends = is_equal_approx(after.right.heat, coast.right.heat)
	if samples.has("fixed") and samples.has("follow"):
		checks.identical_first_half = (
			v(samples.fixed.before_move, "left").distance_to(v(samples.follow.before_move, "left"))
			< .001
		)
		checks.equal_payment = is_equal_approx(samples.fixed.coast.mana, samples.follow.coast.mana)
	var passed = samples.size() == paths.size() and not checks.values().has(false)
	print(
		"AIM_STUDY ",
		JSON.stringify(
			{
				"engine": Engine.get_version_info().string,
				"display": DisplayServer.get_name(),
				"physics": ProjectSettings.get_setting("physics/3d/physics_engine"),
				"checks": checks,
				"passed": passed,
				"samples": samples
			}
		)
	)
	h.shutdown_audio()
	await h.get_tree().create_timer(.25).timeout
	h.get_tree().quit(0 if passed else 1)
