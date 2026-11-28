extends RefCounted

const COUNT := 12


# The tangent at a nearly straight segment keeps its preceding frame.
static func frames(points: PackedVector3Array) -> PackedVector3Array:
	var result := PackedVector3Array()
	var previous := (points[1] - points[0]).normalized()
	var normal := Vector3.UP.slide(previous)
	if normal.length_squared() < 0.001:
		normal = Vector3.RIGHT.slide(previous)
	normal = normal.normalized()
	for i in points.size():
		var tangent := (
			(points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		)
		var axis := previous.cross(tangent)
		if axis.length_squared() > 0.000001:
			normal = normal.rotated(axis.normalized(), atan2(axis.length(), previous.dot(tangent)))
		normal = normal.slide(tangent).normalized()
		result.append(normal)
		previous = tangent
	return result


# Closed-form step response of a critically damped second-order segment.
static func settle(t: float, frequency: float) -> float:
	var x := maxf(0.0, t) * frequency
	return 1.0 - (1.0 + x) * exp(-x)
