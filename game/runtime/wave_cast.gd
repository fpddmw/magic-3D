extends "res://runtime/cast.gd"
const WAVE = preload("res://art_kit/families/F04_wave/F04_wave.tscn")
var trial: Dictionary
var trace := false
var wave
var center: Vector3
var radius := 0.
var remaining_impulse := 0.
var paid_impulse := 0.
var received: Dictionary = {}
var shape := SphereShape3D.new()
var query := PhysicsShapeQueryParameters3D.new()
var rise: Curve
var apex: Curve


func setup(host, recipe: Dictionary, receipt: Dictionary, id: int) -> bool:
	if host.mana < receipt.upfront_mana:
		return false
	rise = load("res://art_kit/curves/" + trial.art.curve_id + ".tres")
	apex = load("res://art_kit/curves/" + trial.art.hold_curve + ".tres")
	center = host.player.global_position
	var space: PhysicsDirectSpaceState3D = host.get_world_3d().direct_space_state
	var ray = PhysicsRayQueryParameters3D.create(
		center + Vector3.UP * .5, center + Vector3.DOWN * 3.
	)
	ray.exclude = [host.player.get_rid()]
	var floor_hit = space.intersect_ray(ray)
	if floor_hit.is_empty():
		return false
	center = floor_hit.position + floor_hit.normal * .035
	wave = WAVE.instantiate()
	host.add_child(wave)
	wave.global_position = center
	wave.configure(trial.art.palette, trial.art.ground == "X07")
	query.shape = shape
	query.transform.origin = center
	query.exclude = [host.player.get_rid()]
	process_ended.connect(on_exit)
	host.player.intent = trial.art.pose
	host.director.play_at("low_rise", center, .85)
	return super.setup(host, recipe, receipt, id)


func action(pid: String, op: Dictionary, dt: float) -> bool:
	if op.ability == "impulse":
		paid_impulse = ratio() * quote.total_impulse_budget
		remaining_impulse = paid_impulse
		if trace:
			print("A4 COMMIT age=", elapsed, " paid_Ns=", paid_impulse)
		reserve = 0.
		return true
	return super.action(pid, op, dt)


func paid_step(pid: String, dt: float) -> void:
	if pid == trial.binding.prepare:
		var t: float = active[pid].time
		var charge: float = contracts[nodes[pid].contract].reserve.full_charge_s
		var f := rise.sample_baked(clampf(t / charge, 0., 1.))
		var h := apex.sample_baked(clampf((t - charge) / trial.art.hold_s, 0., 1.))
		arena.player.pose_weapon(f, 1.)
		wave.realized(lerpf(.92, .32, f), .23 * (1. - h), 0.)
		return
	var limit: float = subs.field.spatial.geometry.extent_m
	radius = minf(limit, radius + dt * trial.front.speed_m_s)
	wave.realized(maxf(.32, radius), smoothstep(.1, 1.7, radius), smoothstep(.35, 1.5, radius))
	shape.radius = maxf(.01, radius)
	var space: PhysicsDirectSpaceState3D = arena.get_world_3d().direct_space_state
	for item in space.intersect_shape(query, 64):
		var body = item.collider
		if not body is RigidBody3D or body.freeze or received.has(body):
			continue
		var hit: Dictionary = arena.world.surface_contact(center, body)
		if hit.is_empty():
			continue
		var direction: Vector3 = (
			(center.direction_to(body.global_position) + Vector3.UP * trial.front.loft).normalized()
		)
		var j := minf(remaining_impulse, body.mass * trial.front.kick_m_s)
		if j <= 0.:
			continue
		arena.world.deliver(body, direction * j, hit.position)
		remaining_impulse -= j
		received[body] = radius
		if trace:
			print(
				"A4 HIT ",
				JSON.stringify(
					{"body": body.name, "r": radius, "point": str(hit.position), "j_Ns": j}
				)
			)
	if radius >= limit:
		finish(pid, {}, "completed")


func on_exit(_pid: String, reason: String, continuing: bool) -> void:
	if continuing:
		arena.player.pose_weapon(1., 0.)
		arena.player.release_weapon()
		arena.director.play_at("air_release", center, 1.)
	else:
		arena.player.release_weapon()
		wave.finish(reason)
		if trace:
			print(
				"A4 EXIT ",
				reason,
				" radius=",
				radius,
				" contacts=",
				received.size(),
				" delivered_Ns=",
				paid_impulse - remaining_impulse
			)
