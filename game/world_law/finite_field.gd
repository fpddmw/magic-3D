extends RefCounted


# Accepted impulses are submitted without invoking the hall's impact/damage channel.
# A target is sampled once. Every request in a tick uses the same pre-delivery snapshot.
static func key(body: Node) -> String:
	return String(body.get_path())


static func velocity(body) -> Vector3:
	if body is RigidBody3D:
		return body.linear_velocity
	return body.velocity + body.kick


static func position(body) -> Vector3:
	return body.global_position + (Vector3.UP * .9 if body is CharacterBody3D else Vector3.ZERO)


static func collect(arena, center: Vector3, subject: Dictionary) -> Array:
	var bodies = arena.get_tree().get_nodes_in_group("world_body")
	if arena.player:
		bodies.append(arena.player)
	var picked: Array = []
	for body in bodies:
		if body is RigidBody3D:
			if body.freeze or body.collision_layer == 0:
				continue
		elif not (body is CharacterBody3D and body.has_method("apply_central_impulse")):
			continue
		var d := center.distance_to(position(body))
		if d < subject.radius_m:
			picked.append({"body": body, "distance": d, "key": key(body)})
	picked.sort_custom(
		func(a, b): return a.key < b.key if a.distance == b.distance else a.distance < b.distance
	)
	return picked.slice(0, int(subject.max_receivers))


static func submit(
	arena, w: Dictionary, center: Vector3, funded: float, dt: float, balance: Dictionary
) -> Dictionary:
	var jobs := collect(arena, center, w.Subjects)
	var total := 0.0
	var reaction := Vector3.ZERO
	var rel: Dictionary = w.Relations
	for j in jobs:
		var b = j.body
		var delta := center - position(b)
		var weight := pow(1.0 - pow(j.distance / w.Subjects.radius_m, 2), 2)
		var direction := delta / maxf(j.distance, rel.softening_m)
		if rel.direction == "radial_out":
			direction = -direction
		var impulse: Vector3 = b.mass * rel.peak_m_s2 * funded * weight * direction * dt
		j.request = impulse
		j.velocity = velocity(b)
		total += impulse.length()
		reaction -= impulse
	var scale := 1.0
	if total > 0.:
		scale = minf(scale, balance.impulse / total)
	if reaction.length() > 0.:
		scale = minf(scale, balance.reaction / reaction.length())
	if work(jobs, scale) > balance.work:
		var lo := 0.0
		var hi := scale
		for n in 18:
			var mid: float = (lo + hi) * .5
			if work(jobs, mid) > balance.work:
				hi = mid
			else:
				lo = mid
		scale = lo
	var used := work(jobs, scale)
	var receipts := []
	for j in jobs:
		var delivered: Vector3 = j.request * scale
		if delivered.length_squared() < 1e-18:
			continue
		j.body.apply_central_impulse(delivered)
		receipts.append(
			{
				"key": j.key,
				"mass": j.body.mass,
				"point": position(j.body),
				"requested": j.request,
				"delivered": delivered
			}
		)
	balance.impulse = maxf(0., balance.impulse - total * scale)
	balance.reaction = maxf(0., balance.reaction - reaction.length() * scale)
	balance.work = maxf(0., balance.work - used)
	return {"receipts": receipts, "scale": scale, "work": used, "reaction": reaction * scale}


static func work(jobs: Array, scale: float) -> float:
	var joules := 0.0
	for j in jobs:
		var impulse: Vector3 = j.request * scale
		joules += maxf(0., j.velocity.dot(impulse) + impulse.length_squared() / (2. * j.body.mass))
	return joules
