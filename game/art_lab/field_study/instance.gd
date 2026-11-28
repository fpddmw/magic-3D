extends RefCounted

const Law = preload("res://world_law/finite_field.gd")
var arena
var plan: Dictionary
var quote: Dictionary
var phase := "idle"
var generation := 0
var tick := 0
var sequence := 0
var age := 0.
var funded := 0.
var reserve := 0.
var spent := 0.
var allocation_scale := 0.
var center := Vector3.ZERO
var origin := Vector3.ZERO
var history: Array[Vector3] = []
var receipts: Array = []
var events: Array = []
var balance: Dictionary = {}
var contacts_pending: Array = []
var recipients: Dictionary = {}
var ended_tick := -10000
var close_reason := ""
var world_frame := 0


func setup(host, compiled: Dictionary) -> void:
	arena = host
	plan = compiled.world
	quote = compiled.quote


func event(kind: String, detail: Dictionary = {}) -> void:
	sequence += 1
	var e = {
		"kind": kind,
		"tick": tick,
		"generation": generation,
		"seq": sequence,
		"instance": "field",
		"center": center
	}
	e.merge(detail)
	events.append(e)


func close(reason: String) -> void:
	var cost := 0.
	if phase == "active":
		cost = reserve * (.25 + .75 * clampf(age / plan.Processes.active.duration_s, 0, 1))
	arena.mana += reserve - cost
	spent += cost
	reserve = 0.
	close_reason = reason
	ended_tick = tick
	event("exit." + phase, {"reason": reason, "cost": cost})
	phase = "idle"


func step(dt: float, commands: Array, target: Dictionary, clip_descent: Callable) -> void:
	tick += 1
	events.clear()
	receipts.clear()
	for pair in contacts_pending:
		event("contact", pair)
	contacts_pending.clear()
	if phase == "idle":
		if not commands.has("hold") or not target.valid or commands.has("interrupt"):
			return
		generation += 1
		history.clear()
		recipients.clear()
		center = target.point
		phase = "prepare"
		age = 0.
		reserve = 0.
		funded = 0.
		close_reason = ""
		event("enter.prepare")
	if commands.has("interrupt") or commands.has("source_lost"):
		close("interrupt" if commands.has("interrupt") else "source_lost")
		return
	if phase == "prepare":
		if age + 0.000001 >= plan.Processes.prepare.timeout_s:
			close("timeout")
			return
		if target.valid:
			center = center.move_toward(target.point, plan.Contracts.steer_m_s * dt)
		if commands.has("release"):
			if not target.valid or funded < quote.min_ratio:
				close("invalid_release" if not target.valid else "unfunded_release")
				return
			phase = "active"
			age = 0.
			origin = center
			balance = {
				"impulse": funded * quote.impulse_ns,
				"work": funded * quote.work_j,
				"reaction": funded * quote.reaction_ns
			}
			event("commit", {"funded": funded})
		else:
			var payment := minf(
				arena.mana, minf(quote.capacity - reserve, dt * quote.capacity / quote.fill_s)
			)
			reserve += payment
			arena.mana -= payment
			funded = reserve / quote.capacity
			age += dt
			return
	if phase == "active":
		if age + 0.000001 >= plan.Processes.active.duration_s:
			close("timeout")
			return
		if (
			balance.impulse <= 0.0000001
			or balance.work <= 0.0000001
			or balance.reaction <= 0.0000001
		):
			close("depleted")
			return
		var desired := (
			origin
			+ (
				Vector3.DOWN
				* float(plan.Contracts.drop_m)
				* smoothstep(0., plan.Contracts.drop_s, age)
			)
		)
		center = clip_descent.call(origin, desired, plan.Contracts.clearance_m)
		history.append(center)
		if history.size() > int(plan.Contracts.history):
			history.pop_front()
		var outcome := Law.submit(arena, plan, center, funded, dt, balance)
		allocation_scale = outcome.scale
		receipts = outcome.receipts
		for r in receipts:
			recipients[r.key] = true
			sequence += 1
			r.seq = sequence
			r.generation = generation
		world_frame += 1
		age += dt


func contact(a: RigidBody3D, b: Node) -> void:
	if not recipients.has(Law.key(a)) or (phase != "active" and tick - ended_tick > 90):
		return
	var first := Law.key(a)
	var second := Law.key(b)
	var pair_key := first + "|" + second if first < second else second + "|" + first
	for p in contacts_pending:
		if p.pair == pair_key:
			return
	contacts_pending.append({"pair": pair_key, "point": a.global_position})
