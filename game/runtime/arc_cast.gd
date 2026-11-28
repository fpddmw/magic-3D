extends "res://runtime/cast.gd"
## Only the F03 pilot uses this finite travelling front. Payment and exits use Cast.
const FRONT = preload("res://world_law/arc_front.gd")
const EFFECT = preload("res://art_kit/families/F03_arc_blade/F03_arc_blade.tscn")
var trial: Dictionary
var front = FRONT.new()
var effect
var in_flight := false
var at_apex := false
var impulse := 0.
var receipts: Array = []
var exit_reason := ""
var trace := false

func record(kind: String, info: Dictionary = {}) -> void:
	if trace:
		info.merge({"event":kind,"cast":serial,"tick":Engine.get_physics_frames(),"age":snappedf(elapsed,.0001)})
		print("F03 ",JSON.stringify(info))

func setup(host, recipe: Dictionary, receipt: Dictionary, id: int) -> bool:
	if host.mana < receipt.upfront_mana:
		return false
	front.configure(host,trial.front,recipe.Subjects[0].spatial.geometry.extent_m)
	effect = EFFECT.instantiate()
	host.add_child(effect)
	effect.configure(trial.art,front.half_width,front.arc_mix)
	host.player.pose_weapon(0.,trial.art.weight)
	front.attach(host.player.blade_socket())
	effect.global_transform = front.pose
	process_ended.connect(on_process_ended)
	var ok := super.setup(host,recipe,receipt,id)
	record("prepare",{"form":trial.art.form,"width_m":trial.front.width_m,"curve":trial.art.curve_id,
		"mana_after_entry":host.mana,"root":str(host.player.blade_root.global_position)})
	return ok

func start(pid: String) -> void:
	super.start(pid)
	if pid == trial.binding.flight and active.has(pid) and not in_flight:
		launch()


func action(pid: String, op: Dictionary, dt: float) -> bool:
	if pid == trial.binding.flight:
		if op.ability == "impulse":
			impulse = ratio()*quote.total_impulse_budget
			reserve = 0.
			return true
		if op.ability == "attenuate":
			# The optical ledger follows the committed front; close() removes its handle.
			arena.world.optical["%d/%s" % [serial,op.target]] = {
				"center":front.pose.origin,"normal":-front.pose.basis.z,"radius":front.half_width,
				"transmission":arena.world.units.transmission}
			return true
	return super.action(pid,op,dt)

func paid_step(pid: String, dt: float) -> void:
	if pid == trial.binding.prepare:
		var t := float(active[pid].time)
		var duration := float(contracts[nodes[pid].contract].max_s)-float(trial.art.hold_s)
		var f := clampf(t/duration,0.,1.)
		var hold := clampf((t-duration)/maxf(.001,trial.art.hold_s),0.,1.)
		arena.player.pose_weapon(f,trial.art.weight)
		front.attach(arena.player.blade_socket())
		effect.global_transform = front.pose
		if trial.art.get("formation","edge_draw") == "edge_draw":
			effect.global_position += front.pose.basis.x*front.half_width*(1.-f)
		effect.prepare(f,hold)
		if trial.art.hold_s > 0 and not at_apex and t+.00001 >= duration:
			at_apex = true
			record("apex",{"hold_s":trial.art.hold_s})
		return
	if pid != trial.binding.flight:
		return
	var result: Dictionary = front.advance(dt)
	effect.global_transform = front.pose
	for op in nodes[pid].active:
		if op.ability == "attenuate":
			arena.world.optical["%d/%s" % [serial,op.target]].center = front.pose.origin
	if trace and (Engine.get_physics_frames()%6 == 0 or not result.is_empty()):
		record("front",{"distance_m":front.distance,"position":str(front.pose.origin)})
	if not result.is_empty():
		var body = result.body
		var applied := 0.
		if body is RigidBody3D and impulse > 0.:
			arena.world.deliver(body,-front.pose.basis.z*impulse,result.point)
			applied = impulse
		receipts.append(result)
		record("contact",{"collider":body.name,"point":str(result.point),"normal":str(result.normal),
			"body_origin":str(body.global_position),"distance_m":front.distance,"u":result.u,"impulse":applied})
		impulse = 0.
		effect.contact(result.point,result.normal,result.u)
		record("contact_feedback",{"flash_origin":str(effect.get_node("Contact/Flash").global_position),
			"stone_audio":effect.get_node("Contact/Stone").playing})
		finish(pid,{},"contact")
	elif front.distance >= front.limit-.00001:
		finish(pid,{},"completed")

func launch() -> void:
	in_flight = true
	arena.player.pose_weapon(1.,0.)
	front.attach(arena.player.blade_socket())
	effect.global_transform = front.pose
	effect.launch()
	record("launch",{"root":str(arena.player.blade_root.global_position),
		"tip":str(arena.player.blade_tip.global_position),"axis":str(-front.pose.basis.z),
		"budget":impulse,"distance_limit":front.limit})
	arena.player.release_weapon()

func on_process_ended(pid: String, reason: String, continuing: bool) -> void:
	if continuing:
		return
	exit_reason = reason
	if not in_flight:
		arena.player.release_weapon()
	effect.finish(reason)
	record("exit",{"process":pid,"reason":reason,"distance_m":front.distance,
		"receipts":receipts.size(),"ending":"retract" if reason=="released" else "erosion",
		"mana":arena.mana})
