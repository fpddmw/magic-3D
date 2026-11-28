extends RigidBody3D

const STONE = preload("res://art_lab/f08/keystone.glb")
var barrier: StaticBody3D
var veil
var capacity_kg := 10.0
var measured := 0.0
var contact_ticks := 0
var last_point := Vector3.ZERO
var last_normal := Vector3.ZERO
var last_impulse := Vector3.ZERO


func _ready() -> void:
	max_contacts_reported = 12
	contact_monitor = true
	continuous_cd = true
	can_sleep = false
	var object: Node3D = STONE.instantiate()
	add_child(object)
	var m: MeshInstance3D = object.find_children("*", "MeshInstance3D", true, false)[0]
	var stone := ShaderMaterial.new()
	stone.shader = preload("res://art_lab/f08/limestone.gdshader")
	stone.set_shader_parameter("grain", preload("res://art_kit/slate.jpg"))
	m.layers = 2
	m.material_override = stone
	var collider := CollisionShape3D.new()
	collider.shape = m.mesh.create_convex_shape()
	add_child(collider)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	measured = 0.0
	for i in state.get_contact_count():
		if state.get_contact_collider_object(i) == barrier:
			last_point = state.get_contact_collider_position(i)
			last_normal = state.get_contact_local_normal(i)
			last_impulse = state.get_contact_impulse(i)
			# The exercise rates the membrane in carried kg at the calibration
			# acceleration. A free-flying stone has zero transmitted load.
			measured = clampf(mass / capacity_kg, 0, 1)
			contact_ticks += 1
			break
	veil.set_contact(last_point, measured)
