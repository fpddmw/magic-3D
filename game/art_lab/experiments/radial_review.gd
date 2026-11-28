extends RefCounted
const MASON = preload("res://art_lab/field_study/masonry.gd")


func run(h) -> void:
	h.info.get_parent().hide()
	for body in h.get_tree().get_nodes_in_group("world_body"):
		body.hide()
		body.freeze = true
		body.collision_layer = 0
		body.collision_mask = 0
	var entry: Dictionary = h.catalog.filter(func(e): return e.get("trial", {}).get("family", "") == "F04")[0]
	var stones: Array = []
	var origins: Array = []
	for i in 8:
		var angle: float = i * TAU / 8. + .27
		var r: float = 2.25 + float(i % 3) * .63
		var pos: Vector3 = h.player.position + Vector3(cos(angle) * r, .33, sin(angle) * r)
		var extent := Vector3(.52, .30, .37) * (.85 + i * .045)
		var b = h.world.make_body(
			"PierStone%d" % i, pos, 1.4 + i * .51, extent * 2., h.hall.mats.stone, {}
		)
		MASON.skin(b, extent, 91 + i, Color("#aca597"))
		stones.append(b)
	var eye := Camera3D.new()
	h.add_child(eye)
	eye.position = h.player.position + Vector3(4.5, 4.45, 6.3)
	eye.look_at(h.player.position + Vector3(0, .55, -.4))
	eye.fov = 62.
	eye.current = true
	for k in 48:
		await h.get_tree().physics_frame
	for body in stones:
		origins.append(body.position)
	var spell = h.cast_entry(entry)
	var heights := 0.
	var drift := 0.
	for frame in 355:
		await h.get_tree().physics_frame
		for i in stones.size():
			heights = maxf(heights, stones[i].position.y - origins[i].y)
			drift = maxf(drift, origins[i].distance_to(stones[i].position))
	var ok: bool = (
		spell.received.size() == stones.size()
		and heights > .25
		and spell.remaining_impulse >= -.001
	)
	print(
		"A4 RESULT ",
		JSON.stringify(
			{
				"ok": ok,
				"bodies": stones.size(),
				"contacts": spell.received.size(),
				"max_rise_m": heights,
				"max_travel_m": drift,
				"mana_end": h.mana
			}
		)
	)
	h.shutdown_audio()
	h.get_tree().quit(0 if ok else 1)
