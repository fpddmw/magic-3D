extends RefCounted
## Input-only replay. The normal hall creates the cast, settles contacts, and draws every frame.
var failures: Array[String] = []

func ticks(h, count: int) -> void:
	for i in count:
		await h.get_tree().physics_frame

func expect(ok: bool, label: String) -> void:
	print("F03 CHECK ",label," ",ok)
	if not ok:
		failures.append(label)

func run(h, take: String) -> void:
	h.info.get_parent().visible = false
	var variant := int(take.trim_prefix("v"))
	if variant < 1 or variant > 3:
		h.get_tree().quit(2)
		return
	h.selected = h.catalog.size()-4+variant
	var entry = h.catalog[h.selected]
	print("F03 ENGINE ",Engine.get_version_info().string," physics=",ProjectSettings.get_setting("physics/3d/physics_engine"),
		" recipe=",entry.path," sha256=",FileAccess.get_sha256(entry.path))
	h.pitch = [.045,.21,.04][variant-1]
	h.yaw = [0.,.045,-.055][variant-1]
	if variant == 2:
		h.player.position.x = -2.65
	await ticks(h,48)
	var cast = h.cast_entry(entry)
	if not cast:
		push_error("Could not start reviewed cast")
		h.get_tree().quit(1)
		return
	if variant == 3:
		await ticks(h,202)
		cast.input_event("release")
	await ticks(h,326 if variant==2 else 126)
	if variant == 1:
		expect(cast.receipts.size()==1 and cast.receipts[0].body.name=="CrackedPier","single pier receipt")
		if cast.receipts.size()==1:
			var hit: Dictionary = cast.receipts[0]
			expect(is_equal_approx(hit.normal.length(),1.) and hit.u>.5,"wing contact and unit normal")
		for i in 24:
			h.pitch = lerpf(.045,.27,(i+1)/24.)
			h.yaw = lerpf(0.,.32,(i+1)/24.)
			await ticks(h,1)
		var empty = h.cast_entry(entry)
		await ticks(h,143)
		expect(empty.receipts.is_empty() and empty.exit_reason=="completed","empty flight completes without impact")
	elif variant == 2:
		expect(cast.receipts.is_empty() and cast.exit_reason=="completed","heavy full range erosion")
	else:
		expect(cast.receipts.is_empty() and cast.exit_reason=="released","release retract without impact")
		expect(h.world.optical.is_empty(),"released optical handle closed")
	expect(h.casts.is_empty(),"cast ledger closed")
	print("F03 RESULT ",JSON.stringify({"take":take,"failures":failures}))
	h.shutdown_audio()
	await ticks(h,3)
	h.get_tree().quit(0 if failures.is_empty() else 1)
