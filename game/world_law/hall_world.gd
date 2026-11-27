extends Node3D

var media := ["ambient_air"]
var slots: Dictionary = {}
var edges: Array = []
var units: Dictionary
var director
var max_bodies := 64
signal material_contact(body: RigidBody3D)
var target_limit := 16
var damage_events := 0


func make_body(
	label: String, p: Vector3, mass_kg: float, size: Vector3, mat: Material, attrs: Dictionary
) -> RigidBody3D:
	if get_tree().get_nodes_in_group("world_body").size() >= max_bodies:
		return null
	var b = RigidBody3D.new()
	b.name = label
	b.position = p
	b.mass = mass_kg
	b.contact_monitor = true
	b.max_contacts_reported = 8
	b.continuous_cd = true
	for k in attrs:
		b.set_meta(k, attrs[k])
	var m = MeshInstance3D.new()
	m.mesh = BoxMesh.new()
	m.mesh.size = size
	m.material_override = mat
	var c = CollisionShape3D.new()
	c.shape = BoxShape3D.new()
	c.shape.size = size
	b.add_child(m)
	b.add_child(c)
	add_child(b, true)
	b.add_to_group("world_body")
	b.body_entered.connect(func(_other): material_contact.emit(b))
	return b


func axis(kind: String, origin: Vector3, aim: Vector3, p: Vector3) -> Vector3:
	match kind:
		"aim":
			return aim
		"up":
			return Vector3.UP
		"down":
			return Vector3.DOWN
		"radial_in":
			return (origin - p).normalized()
		"radial_out":
			return (p - origin).normalized()
		_:
			return Vector3.UP.cross(p - origin).normalized()


func column_weight(geometry: Dictionary, distribution, delta: Vector3) -> float:
	var r = Vector2(delta.x, delta.z).length() / geometry.radius_m
	var y = delta.y / geometry.height_m
	if r > 1. or y < 0. or y > 1.:
		return 0.
	var radial = distribution.radial if distribution is Dictionary else distribution
	var weight = 1.
	if radial == "bell":
		weight = pow(1. - r * r, 2.)
	elif radial == "linear_falloff":
		weight = 1. - r
	if distribution is Dictionary and distribution.axial == "linear_falloff":
		weight *= 1. - y
	return weight


func column_direction(v: Dictionary, delta: Vector3) -> Vector3:
	var radial = Vector3(delta.x, 0., delta.z).normalized()
	return radial * v.radial + Vector3.UP.cross(radial) * v.tangential + Vector3.UP * v.axial


func candidates(sp: Dictionary, origin: Vector3, aim: Vector3, channel: String) -> Dictionary:
	var out = {}
	var pool = (
		[slots.self]
		if sp.get("scope") == "self" and slots.has("self")
		else get_tree().get_nodes_in_group("world_body")
	)
	for b in pool:
		if sp.get("scope") == "self" and b != slots.get("self"):
			continue
		var delta: Vector3 = b.global_position - origin
		var d = delta.length()
		var g = sp.geometry
		var w: float
		if g.shape == "column":
			w = column_weight(g, sp.distribution, delta)
			if w <= 0.:
				continue
		else:
			if d > g.extent_m:
				continue
			if g.shape == "cone" and delta.dot(aim) < d * cos(deg_to_rad(g.half_angle_deg)):
				continue
			w = 1. if sp.distribution == "uniform" else maxf(0., 1. - d / g.extent_m)
		if (
			channel in ["pressure", "optical"]
			or (channel == "thermal" and b.get_meta("thermal_path", "radiation") == "radiation")
		):
			if d > .01:
				var ray = PhysicsRayQueryParameters3D.create(origin, b.global_position)
				if slots.has("caster"):
					ray.exclude = [slots.caster.get_rid()]
				var hit = get_world_3d().direct_space_state.intersect_ray(ray)
				if not hit.is_empty() and hit.collider != b:
					if channel != "optical":
						continue
					w *= float(hit.collider.get_meta("transmission", 0.))
		if channel == "thermal" and b.get_meta("thermal_path", "radiation") == "insulated":
			continue
		if channel == "optical":
			w *= transmission(origin, b.global_position)
		if w > 0.:
			out[b] = w
	if out.size() <= target_limit:
		return out
	var nearest = out.keys()
	nearest.sort_custom(
		func(a, b):
			var da = origin.distance_squared_to(a.global_position)
			var db = origin.distance_squared_to(b.global_position)
			return a.get_instance_id() < b.get_instance_id() if da == db else da < db
	)
	for i in range(target_limit, nearest.size()):
		out.erase(nearest[i])
	return out


func deliver(b: PhysicsBody3D, j: Vector3) -> bool:
	if j.is_zero_approx():
		return false
	if b.has_meta("integrity"):
		var residual = float(b.get_meta("integrity")) - j.length()
		b.set_meta("integrity", maxf(0, residual))
		damage_events += 1
		if residual <= 0 and b.freeze:
			b.freeze = false
			b.set_meta("broken", true)
			director.play_at("stone_strain", b.global_position, 1.)
	if b.has_meta("poise"):
		b.set_meta("poise", maxf(0., float(b.get_meta("poise")) - j.length()))
	b.set_meta("disturbed_until", Engine.get_physics_frames() + 12)
	b.apply_central_impulse(j)
	return true


func support(origin: Vector3, extent: float) -> StaticBody3D:
	var b = StaticBody3D.new()
	var c = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = extent
	shape.height = .08
	c.shape = shape
	b.add_child(c)
	b.position = origin
	add_child(b)
	return b


func load_on(support_body: StaticBody3D) -> float:
	var kg = 0.
	for b in get_tree().get_nodes_in_group("world_body"):
		if support_body in b.get_colliding_bodies():
			kg += b.mass
	return kg


# Remaining distance and hop count both constrain propagation along live material edges.
func network(
	root, kind: String, eligible: Dictionary, reach: float, hops: int, g: Dictionary
) -> Dictionary:
	var states = [[root, 0., 0]]
	var visited = {}
	var best = {}
	var valid = edges.filter(
		func(e): return e.kind == kind and eligible.has(e.a) and eligible.has(e.b)
	)
	if valid.size() > g.edges or not eligible.has(root):
		return {}
	while not states.is_empty():
		var item = states.pop_front()
		var node = item[0]
		var distance = float(item[1])
		var depth = int(item[2])
		var state = [node, depth]
		if distance > reach or visited.get(state, INF) <= distance:
			continue
		visited[state] = distance
		best[node] = minf(best.get(node, INF), distance)
		if best.size() > g.nodes:
			return {}
		if depth >= hops:
			continue
		for e in valid:
			if e.intact and (e.a == node or e.b == node):
				states.append([e.b if e.a == node else e.a, distance + e.length_m, depth + 1])
	return best


func remove_support(surface: StaticBody3D) -> void:
	for b in get_tree().get_nodes_in_group("world_body"):
		if surface in b.get_colliding_bodies():
			b.sleeping = false
	surface.queue_free()


var optical: Dictionary = {}


func transmission(from: Vector3, to: Vector3) -> float:
	var ray = to - from
	var value = 1.
	for layer in optical.values():
		var crossing = ray.dot(layer.normal)
		if absf(crossing) < .00001:
			continue
		var t = (layer.center - from).dot(layer.normal) / crossing
		if t >= 0. and t <= 1. and (from + ray * t).distance_to(layer.center) <= layer.radius:
			value *= layer.transmission
	return value


func _physics_process(dt: float) -> void:
	# Paired transfers conserve heat; mass supplies finite heat capacity.
	for edge in edges:
		if edge.kind != "thermal" or not edge.intact:
			continue
		var a: RigidBody3D = edge.a
		var b: RigidBody3D = edge.b
		var ta = float(a.get_meta("temperature_delta", 0.))
		var tb = float(b.get_meta("temperature_delta", 0.))
		var q = (ta - tb) * minf(.5, dt) / (1. / a.mass + 1. / b.mass)
		a.set_meta("temperature_delta", ta - q / a.mass)
		b.set_meta("temperature_delta", tb + q / b.mass)
