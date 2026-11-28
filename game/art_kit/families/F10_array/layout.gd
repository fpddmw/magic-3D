extends RefCounted


## Slots have stable indices. The layout changes their destinations, never their membership.
static func offset(
	layout: String, i: int, n: int, t: float, r: float, height: float, turn: float
) -> Vector3:
	var u: float = (i + .5) / n
	var radius := r
	var angle := lerpf(-1.36, 1.36, u)
	var y := height + .65 * cos(angle)
	if layout == "ring":
		angle = TAU * u + t * turn
		y = height + .34 * sin(2. * angle)
	elif layout == "layers":
		var layers := 3 if n > 10 else 2
		var tier := i % layers
		var count := ceili(float(n - tier) / layers)
		angle = TAU * (floori(float(i) / layers) + .5) / count + .48 * tier + t * turn
		radius = r * (.78 + .19 * tier)
		y = height - .57 + tier * .98
	else:
		angle += .20 * sin(t * turn)
	return Vector3(sin(angle) * radius, y, -cos(angle) * radius)
