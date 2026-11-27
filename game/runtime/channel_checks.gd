extends RefCounted


func ticks(h, n: int) -> void:
	for i in n:
		await h.get_tree().physics_frame


func run(h, report) -> void:
	h.send_event("interrupt")
	await ticks(h, 12)
	h.mana = 300.
	h.player.global_position = Vector3(0, 0, 7)
	h.yaw = 0.
	var spring = h.world.slots.spring
	spring.global_position = Vector3(-3.4, .18, 4)
	var path = [spring]
	for e in h.world.edges:
		if e.kind == "material" and e.a == path.back() and path.size() < 4:
			path.append(e.b)
	for b in path:
		h.phase(b, "liquid")
	var seam = h.world.edges.filter(func(e): return e.a == path[1] and e.b == path[2])
	for e in seam:
		e.intact = false
	await ticks(h, 4)
	var freezing = h.cast_entry(report.entry(h, "/water_front.json"))
	await ticks(h, 102)
	report.evidence(
		"phase_front_stops_at_cut",
		(
			path[1].get_meta("phase") == "solid"
			and path[2].get_meta("phase") == "liquid"
			and path[1].collision_layer != 0
			and path[2].collision_layer == 0
		)
	)
	for e in seam:
		e.intact = true
	await ticks(h, 30)
	report.evidence("phase_front_resumes_on_reconnect", path[2].get_meta("phase") == "solid")
	freezing.input_event("release")
	var q0 = float(path[0].get_meta("charge", 0.))
	var q2 = float(path[2].get_meta("charge", 0.))
	for e in seam:
		e.intact = false
	var electric = h.cast_entry(report.entry(h, "/electric.json"))
	await ticks(h, 42)
	report.evidence(
		"charge_follows_connected_edges",
		(
			float(path[0].get_meta("charge", 0.)) > q0
			and is_equal_approx(path[2].get_meta("charge", 0.), q2)
		)
	)
	electric.input_event("release")
	path[0].set_meta("temperature_delta", 10.)
	path[1].set_meta("temperature_delta", 0.)
	await ticks(h, 14)
	var first = float(path[0].get_meta("temperature_delta"))
	var second = float(path[1].get_meta("temperature_delta"))
	report.evidence(
		"thermal_edge_conserves_heat",
		second > 0. and is_equal_approx(first + second, 10.),
		[first, second]
	)
	h.mana = 300.
	var screen = h.cast_entry(report.entry(h, "/attenuate.json"))
	await ticks(h, 3)
	var origin = h.cast_origin()
	var sight = h.world.transmission(origin - h.aim(), origin + h.aim())
	var clear = h.world.transmission(
		origin + Vector3.RIGHT * 10. - h.aim(), origin + Vector3.RIGHT * 10. + h.aim()
	)
	screen.input_event("release")
	report.evidence(
		"optical_ray_crosses_finite_sheet",
		is_equal_approx(sight, .25) and is_equal_approx(clear, 1.) and h.world.optical.is_empty(),
		[sight, clear]
	)
	var lamp = h.world.slots.lamp
	lamp.set_meta("mana", 12.)
	lamp.set_meta("linked", true)
	var host = h.cast_entry(report.entry(h, "/hosted_light.json"))
	await ticks(h, 5)
	report.evidence("host_supplies_live_light", host.lights.size() == 1)
	var level = float(lamp.get_meta("mana"))
	lamp.set_meta("linked", false)
	await ticks(h, 4)
	report.evidence(
		"host_pays_and_disconnects",
		level < 12. and host.active.is_empty() and is_equal_approx(level, lamp.get_meta("mana"))
	)
	var signal_cast = h.cast_entry(report.entry(h, "/notify.json"))
	await ticks(h, 3)
	report.evidence("local_signal_returns_to_bound_receiver", lamp.has_meta("last_signal"))
	signal_cast.input_event("release")
