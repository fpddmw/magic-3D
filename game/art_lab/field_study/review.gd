extends RefCounted

var frames: Array = []
var inputs_seen: Array = []
var options: Dictionary
var n := 0
var finished := false
var total := 405
var case_name: String


func begin(court, opts: Dictionary) -> void:
	options = opts
	case_name = opts["case"]
	if case_name == "live":
		total = 560
	court.hud_enabled = false


func button(court, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = down
	court.get_viewport().push_input(e, true)


func key(court, code: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	court.get_viewport().push_input(e, true)
	e.pressed = false
	court.get_viewport().push_input(e, true)


func inputs(court) -> void:
	if finished:
		return
	n += 1
	if case_name == "live":
		if n == 12:
			print("FIELD_READY")
		return
	if n == 4 and case_name == "cross":
		key(court, KEY_G)
	if n == 48 and case_name == "character":
		var e := InputEventMouseMotion.new()
		e.relative = Vector2(0, 118)
		court.get_viewport().push_input(e, true)
	if n == 56 and case_name != "control":
		button(court, true)
	if n == 68 and case_name == "early":
		button(court, false)
	if n == 101 and case_name == "funded_early":
		button(court, false)
	if n == 120 and case_name == "invalid":
		var look := InputEventMouseMotion.new()
		look.relative = Vector2(0, -230)
		court.get_viewport().push_input(look, true)
	if n == 121 and case_name == "steer":
		var look := InputEventMouseMotion.new()
		look.relative = Vector2(100, 0)
		court.get_viewport().push_input(look, true)
	if n == 182 and case_name == "source_lost":
		key(court, KEY_B)
	if n == 140 and case_name in ["interrupt", "simultaneous"]:
		key(court, KEY_SPACE)
	if n == 140 and case_name == "simultaneous":
		button(court, false)
	if (
		n == 152
		and case_name not in ["control", "early", "funded_early", "simultaneous", "timeout"]
	):
		button(court, false)
	if n == 182 and case_name == "cut_active":
		key(court, KEY_SPACE)
	if n == 175 and case_name == "turn":
		var e := InputEventMouseMotion.new()
		e.relative = Vector2(100, 0)
		court.get_viewport().push_input(e, true)


func xyz(v: Vector3) -> Array:
	return [snappedf(v.x, .00001), snappedf(v.y, .00001), snappedf(v.z, .00001)]


func observe(court, commands: Array, target: Dictionary) -> void:
	if finished:
		return
	var s = court.session
	if not commands.is_empty():
		inputs_seen.append({"tick": n, "input": commands.duplicate()})
	var bodies = {}
	var list: Array = court.stones.duplicate()
	list.append(court.host.player)
	if court.prior:
		list.append(court.prior)
	for b in list:
		bodies[str(b.name)] = {
			"p": xyz(b.global_position),
			"v": xyz(preload("res://world_law/finite_field.gd").velocity(b))
		}
	var booked := []
	for r in s.receipts:
		booked.append([String(r.key).get_file(), r.mass, xyz(r.requested), xyz(r.delivered)])
	var emitted := []
	for e in s.events:
		emitted.append([e.kind, e.seq, e.get("reason", ""), e.get("pair", "")])
	frames.append(
		{
			"n": n,
			"phase": s.phase,
			"center": xyz(s.center),
			"aim": xyz(target.point),
			"funded": snappedf(s.funded, .00001),
			"spent": snappedf(s.spent, .00001),
			"bodies": bodies,
			"impulses": booked,
			"events": emitted,
			"stage": court.art.stage_events.duplicate(),
			"art_origin": xyz(court.art.global_position),
			"alpha": snappedf(court.art.visible_strength, .00001),
			"history": s.history.size(),
			"history_oldest": xyz(s.history.front()) if not s.history.is_empty() else [],
			"quota": s.balance.duplicate(),
			"allocation_scale": s.allocation_scale
		}
	)
	if n < total:
		return
	var output = options.get("output", "user://field-trace.json")
	var f := FileAccess.open(output, FileAccess.WRITE)
	if not f:
		push_error("Cannot store " + str(output))
		court.get_tree().quit(1)
		return
	var cross_identity: bool = (
		is_instance_valid(court.prior)
		and court.prior.get_instance_id() == court.prior_id
		and court.prior_receipt
		and court.prior.get_meta("control", "") == "world"
	)
	var data = {
		"case": case_name,
		"scene": "terrace" if court.alt_space else "nave",
		"recipe": court.compiled.digest,
		"world": court.compiled.world_digest,
		"stage_source": court.art.plan_hash,
		"camera": "player third person",
		"inputs": inputs_seen,
		"hz": Engine.physics_ticks_per_second,
		"godot": Engine.get_version_info().string,
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"device": RenderingServer.get_video_adapter_name(),
		"cross_handoff_same_body": cross_identity,
		"frames": frames
	}
	f.store_string(JSON.stringify(data))
	f.close()
	print("FIELD_TRACE ", case_name, " ", n, " ", output)
	finished = true
	if case_name not in ["live", "realtime_replay"]:
		court.get_tree().quit()
