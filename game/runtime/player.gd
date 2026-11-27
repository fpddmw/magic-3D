extends CharacterBody3D

var arena
var mass := 7.
var kick := Vector3.ZERO
var stamina := 100.
var poise := 50.
var state := "walk"
var remaining := 0.
var guarded := false
var facing := Vector3.FORWARD
var figure: Node3D
var hit_done := false
var gesture_until := -1
var lean := 0.


func gesture(kind: String) -> void:
	gesture_until = Engine.get_physics_frames() + 8
	lean = {"gather_power": -.17, "cast": .23, "brace": -.23}.get(kind, 0.)


func mesh(parent, geometry: Mesh, p: Vector3, color: Color):
	var m = MeshInstance3D.new()
	m.mesh = geometry
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = .55
	mat.roughness = .45
	m.material_override = mat
	m.position = p
	parent.add_child(m)
	return m


func _ready() -> void:
	var col = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = .35
	capsule.height = 1.8
	col.shape = capsule
	col.position.y = .9
	add_child(col)
	figure = Node3D.new()
	add_child(figure)
	var cloak = CylinderMesh.new()
	cloak.top_radius = .32
	cloak.bottom_radius = .48
	cloak.height = 1.22
	mesh(figure, cloak, Vector3(0, 1.17, 0), Color("#48515a")).scale = Vector3(.74, .36, .68)
	preload("res://art_kit/vestment.gd").harness(self, figure, false)
	var helm = SphereMesh.new()
	helm.radius = .235
	helm.height = .48
	mesh(figure, helm, Vector3(0, 1.65, 0), Color("#596672"))
	for x in [-.31, .31]:
		var shoulder = SphereMesh.new()
		shoulder.radius = .21
		shoulder.height = .28
		mesh(figure, shoulder, Vector3(x, 1.38, 0), Color("#697078"))
	var sword = BoxMesh.new()
	sword.size = Vector3(.065, .85, .055)
	mesh(figure, sword, Vector3(.49, .71, -.21), Color("#a4acb0")).rotation.x = -.46


func apply_central_impulse(impulse: Vector3) -> void:
	kick += impulse / mass


func command(kind: String) -> void:
	if state != "walk":
		return
	if kind == "roll" and stamina >= 24:
		state = "roll"
		remaining = .60
		stamina -= 24
		arena.send_event("interrupt")
	if kind == "swing" and stamina >= 18:
		state = "swing"
		remaining = .78
		stamina -= 18
		hit_done = false


func struck(power: float, direction: Vector3) -> void:
	if state == "roll" and remaining > .18 and remaining < .51:
		return
	if guarded and facing.dot(-direction) > .1 and stamina >= power:
		stamina -= power
		arena.director.play_at("stone_strain", global_position, .7)
		return
	poise -= power
	if poise <= 0:
		state = "stagger"
		remaining = .9
		poise = 50
		arena.send_event("interrupt")


func _physics_process(dt: float) -> void:
	if not arena:
		return
	var input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir = Vector3(input.x, 0, input.y).rotated(Vector3.UP, arena.yaw)
	guarded = Input.is_action_pressed("guard") and state == "walk"
	if state == "walk":
		if dir.length() > .1:
			facing = dir.normalized()
		var speed = 2.0 if guarded else 3.8
		speed *= arena.mobility()
		velocity.x = move_toward(velocity.x, dir.x * speed, dt * 14)
		velocity.z = move_toward(velocity.z, dir.z * speed, dt * 14)
		if not guarded:
			stamina = minf(100., stamina + dt * 14.)
	else:
		remaining -= dt
		var v = 5.8 if state == "roll" and remaining > .18 else .2
		velocity.x = facing.x * v
		velocity.z = facing.z * v
		if state == "swing" and remaining < .39 and not hit_done:
			hit_done = true
			for b in get_tree().get_nodes_in_group("world_body"):
				var d = b.global_position - (global_position + Vector3.UP)
				if d.length() < 2.3 and facing.dot(d.normalized()) > .16:
					arena.world.deliver(b, facing * 11.)
		if remaining <= 0:
			state = "walk"
	velocity.y -= 9.8 * dt
	velocity += kick
	move_and_slide()
	velocity -= kick
	kick = kick.move_toward(Vector3.ZERO, dt * 6.)
	figure.rotation.y = atan2(-facing.x, -facing.z)
	figure.rotation.x = (
		-TAU * (.60 - remaining) / .6
		if state == "roll"
		else (-.24 if guarded else (lean if Engine.get_physics_frames() <= gesture_until else 0.))
	)
