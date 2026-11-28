extends RefCounted
const LAYOUT = preload("res://art_kit/families/F10_array/layout.gd")
var cfg: Dictionary
var slots: Array = []
var order: Array = []
var origin: Vector3
var elapsed := 0.
var active := false
var last_dispatch := -1.
var peak_acceleration := 0.
var force_spent := 0.
var changes: Array = []
var booked: int
var ledger: Dictionary
# Pilot tariff in N.s per mana, charged for measured control/delivery, outside ArtKit.
const IMPULSE_PER_MANA = 900.


func begin(
	candidates: Array, anchor: Vector3, recipe: Dictionary, capacity: int, account: Dictionary
) -> void:
	if active:
		interrupt()
	order.clear()
	changes.clear()
	slots.clear()
	elapsed = 0.
	last_dispatch = -1.
	peak_acceleration = 0.
	force_spent = 0.
	cfg = recipe
	origin = anchor
	booked = capacity
	ledger = account
	slots.resize(capacity)
	active = true
	var eligible := candidates.filter(
		func(b):
			return (
				is_instance_valid(b)
				and not b.controller
				and b.global_position.distance_to(origin) <= cfg.Subjects.range_m
			)
	)
	eligible.sort_custom(
		func(a, b):
			return (
				a.global_position.distance_squared_to(origin)
				< b.global_position.distance_squared_to(origin)
			)
	)
	for i in mini(eligible.size(), capacity):
		slots[i] = weakref(eligible[i])
		order.append(
			{
				"slot": i,
				"rid": eligible[i].get_instance_id(),
				"distance": eligible[i].global_position.distance_to(origin),
				"mass": eligible[i].mass
			}
		)


func member(i: int):
	return slots[i].get_ref() if slots[i] else null


func goal(i: int) -> Vector3:
	var stages: Array = cfg.Processes.layouts
	var k := 0
	while k + 1 < stages.size() and elapsed >= stages[k + 1].at:
		k += 1
	var geometry: Dictionary = cfg.Processes.geometry
	var to := LAYOUT.offset(
		stages[k].layout,
		i,
		booked,
		elapsed,
		geometry.radius_m,
		geometry.height_m,
		geometry.turn_rad_s
	)
	if k > 0:
		var prior := LAYOUT.offset(
			stages[k - 1].layout,
			i,
			booked,
			elapsed,
			geometry.radius_m,
			geometry.height_m,
			geometry.turn_rad_s
		)
		to = prior.lerp(to, smoothstep(0., cfg.Processes.blend_s, elapsed - stages[k].at))
	return origin + to


func step(dt: float) -> void:
	if not active:
		return
	elapsed += dt
	if elapsed > cfg.Contracts.max_control_s or ledger.mana <= .0001:
		interrupt()
		return
	var jobs: Array = []
	var total := 0.
	for i in booked:
		var b = member(i)
		if not is_instance_valid(b) or elapsed < (i * cfg.Contracts.gather_spacing_s):
			continue
		if b.controller and b.controller.get_ref() != self:
			slots[i] = null
			continue
		if not b.controller:
			b.take_control(self, cfg.get("Expression", {}))
			changes.append({"event": "pickup", "slot": i, "t": elapsed, "id": b.kind.id})
		if b.control_state != "held":
			continue
		var delta: Vector3 = goal(i) - b.global_position
		var requested: Vector3 = (delta * 13. - b.linear_velocity * 6.1 + Vector3.UP * 9.8) * b.mass
		var force := requested.limit_length(cfg.Contracts.force_cap_N)
		jobs.append([b, force])
		total += force.length()
	var ceiling := minf(cfg.Contracts.force_sum_N, ledger.mana * IMPULSE_PER_MANA / dt)
	var scale := minf(1., ceiling / maxf(.0001, total))
	for job in jobs:
		var b = job[0]
		var force: Vector3 = job[1] * scale
		b.apply_central_force(force)
		b.apply_torque((Vector3.UP * .39 - b.angular_velocity) * b.mass * .13)
		b.load_surface(force.length() / cfg.Contracts.force_cap_N)
		peak_acceleration = maxf(peak_acceleration, force.y / b.mass)
	force_spent += total * scale * dt
	ledger.mana = maxf(0., ledger.mana - total * scale * dt / IMPULSE_PER_MANA)


func dispatch(target: Vector3) -> bool:
	if not active or elapsed - last_dispatch < cfg.Contracts.dispatch_interval_s:
		return false
	for i in booked:
		var b = member(i)
		if not is_instance_valid(b) or not b.controller or b.controller.get_ref() != self:
			continue
		var speed: float = cfg.Contracts.dispatch_speed_m_s
		var impulse: Vector3 = (
			(b.global_position.direction_to(target) * speed - b.linear_velocity) * b.mass
		)
		var cost := impulse.length() / IMPULSE_PER_MANA
		if ledger.mana < cost:
			return false
		ledger.mana -= cost
		b.handoff("dispatched")
		b.apply_central_impulse(impulse)
		slots[i] = null
		last_dispatch = elapsed
		changes.append({"event": "dispatch", "slot": i, "t": elapsed, "id": b.kind.id})
		return true
	return false


func interrupt() -> void:
	active = false
	for i in booked:
		var b = member(i)
		if is_instance_valid(b) and b.controller and b.controller.get_ref() == self:
			b.handoff("released")
			changes.append({"event": "release", "slot": i, "t": elapsed, "id": b.kind.id})
		slots[i] = null
