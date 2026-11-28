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
var blade_root: Marker3D
var blade_tip: Marker3D
var sword_arm: Array[MeshInstance3D] = []
var grip: Node3D
var drawing := false
var stance := 0.
var recovery := 0.
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
	sword.size = Vector3(.055, .035, .85)
	grip = Node3D.new()
	figure.add_child(grip)
	grip.position = Vector3(.37, .79, -.09)
	grip.rotation.x = -.65
	blade_root = Marker3D.new()
	blade_tip = Marker3D.new()
	grip.add_child(blade_root)
	grip.add_child(blade_tip)
	blade_root.position.z = -.09
	blade_tip.position.z = blade_root.position.z - sword.size.z
	mesh(grip, sword, (blade_root.position+blade_tip.position)*.5, Color("#9aa4ac"))
	var guard := BoxMesh.new()
	guard.size = Vector3(.22,.045,.055)
	mesh(grip, guard, blade_root.position, Color("#766d5d"))


func blade_socket() -> Transform3D:
	var direction := blade_root.global_position.direction_to(blade_tip.global_position)
	return Transform3D(Basis.looking_at(direction,Vector3.UP),blade_root.global_position)


func pose_weapon(fraction: float, weight: float) -> void:
	drawing = true
	stance = weight*sin(fraction*PI*.88)
	facing = Vector3(-sin(arena.yaw),0,-cos(arena.yaw))
	figure.rotation.y = arena.yaw
	figure.rotation.x = -.17*stance
	figure.rotation.z = -.12*stance
	var windup := (1.-fraction)*(.26+.69*weight)
	var axis: Vector3 = arena.aim().rotated(Vector3.UP,windup)
	axis = axis.rotated(figure.global_basis.x, windup*.45)
	grip.position = Vector3(.37+.22*stance,.82+.36*stance,-.10-.31*fraction)
	grip.look_at(grip.global_position+axis)
	figure.position = Vector3(-.12*stance,-.115*stance,.13*stance)
	place_sword_arm()


func place_sword_arm() -> void:
	var shoulder := Vector3(.33,1.38,0.)
	var hand := grip.position
	var elbow := shoulder.lerp(hand,.48)+Vector3(.095,-.055,.095)
	var joints := [shoulder,elbow,hand]
	for i in 2:
		var start: Vector3 = joints[i]
		var end: Vector3 = joints[i+1]
		var part := sword_arm[i]
		part.position = (start+end)*.5
		part.basis = Basis(Quaternion(Vector3.UP,end.direction_to(start)))
		part.scale.y = start.distance_to(end)/part.mesh.height


func release_weapon() -> void:
	if drawing:
		drawing = false
		recovery = .34


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
	if drawing:
		return
	recovery = maxf(0.,recovery-dt)
	grip.rotation = grip.rotation.lerp(Vector3(-.65,0,0),minf(1.,dt*7.))
	grip.position = grip.position.lerp(Vector3(.37,.79,-.09),minf(1.,dt*7.))
	figure.position = figure.position.lerp(Vector3.ZERO,minf(1.,dt*7.))
	place_sword_arm()
	figure.rotation.z = -.10*sin(PI*recovery/.34)
	figure.rotation.y = atan2(-facing.x, -facing.z)
	figure.rotation.x = (
		-TAU * (.60 - remaining) / .6
		if state == "roll"
		else (-.24 if guarded else (lean if Engine.get_physics_frames() <= gesture_until else 0.))
	)
