extends RefCounted
## Finite, open leading front. Its local metres are independent of materials and animation.
const SEGMENTS = 24
const SKIN = .012
var pose := Transform3D.IDENTITY
var distance := 0.
var speed: float
var limit: float
var half_width: float
var arc_mix: float
var bank: float
var strips: Array[PhysicsShapeQueryParameters3D] = []
var local_frames: Array[Transform3D] = []
var space: PhysicsDirectSpaceState3D

func edge(s: float, angle: float) -> Vector3:
	var theta := (2.*s-1.)*angle
	var crown := (cos(theta)-cos(angle))/sin(angle)
	return Vector3(sin(theta)/sin(angle), crown*sin(.64), -crown*cos(.64))

func configure(arena, law: Dictionary, max_distance: float) -> void:
	speed = maxf(.01,law.speed_m_s)
	limit = clampf(law.range_m,0.,max_distance)
	half_width = clampf(law.width_m,.2,7.)*.5
	arc_mix = inverse_lerp(45.,160.,clampf(law.span_deg,45.,160.))
	bank = deg_to_rad(law.bank_deg)
	space = arena.get_world_3d().direct_space_state
	var points := PackedVector3Array()
	for i in SEGMENTS+1:
		var s := float(i)/SEGMENTS
		points.append(half_width*edge(s,deg_to_rad(22.5)).lerp(edge(s,deg_to_rad(80.)),arc_mix))
	for i in SEGMENTS:
		var a := points[i]
		var b := points[i+1]
		var shape := CapsuleShape3D.new()
		shape.radius = SKIN
		shape.height = a.distance_to(b)+2.*SKIN
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.margin = .0005
		query.exclude = [arena.player.get_rid()]
		strips.append(query)
		local_frames.append(Transform3D(Basis(Quaternion(Vector3.UP,(b-a).normalized())),(a+b)*.5))

func attach(socket: Transform3D) -> void:
	pose = Transform3D(socket.basis * Basis(Vector3.BACK, bank),socket.origin)

func advance(dt: float) -> Dictionary:
	var length := minf(speed*dt,limit-distance)
	var motion := -pose.basis.z*length
	var first := 1.
	var receipt := {}
	for i in strips.size():
		var query := strips[i]
		var start := pose*local_frames[i]
		query.transform = start
		query.motion = Vector3.ZERO
		var rest := space.get_rest_info(query)
		var safe := 0.
		if rest.is_empty():
			query.motion = motion
			var swept := space.cast_motion(query)
			if swept[0] >= first:
				continue
			safe = swept[0]
			# Rest info reports a point on the collider at the unsafe end of the sweep.
			query.motion = Vector3.ZERO
			query.transform = Transform3D(start.basis,start.origin+motion*swept[1]-pose.basis.z*.0015)
			rest = space.get_rest_info(query)
			if rest.is_empty():
				# Thin or grazing hits: evaluate the moving shape via Jolt's rest query.
				query.transform = start
				query.motion = motion
				rest = space.get_rest_info(query)
		if not rest.is_empty() and (receipt.is_empty() or safe < first):
			first = safe
			receipt = {"point":rest.point, "normal":rest.normal,
				"body":instance_from_id(rest.collider_id), "u":(i+.5)/SEGMENTS}
	distance += length*first
	pose.origin += motion*first
	return receipt
