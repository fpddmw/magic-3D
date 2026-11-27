extends Node3D

var slots:Dictionary={}
var edges:Array=[]
var units:Dictionary
var director
var max_bodies:=64
var damage_events:=0

func make_body(label:String,p:Vector3,mass_kg:float,size:Vector3,mat:Material,attrs:Dictionary) -> RigidBody3D:
	if get_tree().get_nodes_in_group("world_body").size()>=max_bodies: return null
	var b=RigidBody3D.new()
	b.name=label
	b.position=p
	b.mass=mass_kg
	b.contact_monitor=true
	b.max_contacts_reported=8
	b.continuous_cd=true
	for k in attrs: b.set_meta(k,attrs[k])
	var m=MeshInstance3D.new()
	m.mesh=BoxMesh.new()
	m.mesh.size=size
	m.material_override=mat
	var c=CollisionShape3D.new()
	c.shape=BoxShape3D.new()
	c.shape.size=size
	b.add_child(m)
	b.add_child(c)
	add_child(b,true)
	b.add_to_group("world_body")
	return b

func axis(kind:String,origin:Vector3,aim:Vector3,p:Vector3) -> Vector3:
	match kind:
		"aim": return aim
		"up": return Vector3.UP
		"down": return Vector3.DOWN
		"radial_in": return (origin-p).normalized()
		"radial_out": return (p-origin).normalized()
		_: return Vector3.UP.cross(p-origin).normalized()

func candidates(sp:Dictionary,origin:Vector3,aim:Vector3,channel:String) -> Dictionary:
	var out={}
	for b in get_tree().get_nodes_in_group("world_body"):
		if sp.get("scope")=="self" and b!=slots.get("self"): continue
		var delta:Vector3=b.global_position-origin
		var d=delta.length()
		var g=sp.geometry
		if d>g.extent_m: continue
		if g.shape=="cone" and delta.dot(aim)<d*cos(deg_to_rad(g.half_angle_deg)): continue
		var w=1. if sp.distribution=="uniform" else maxf(0.,1.-d/g.extent_m)
		if channel in ["pressure","optical"] or (channel=="thermal" and b.get_meta("thermal_path","radiation")=="radiation"):
			if d>.01:
				var ray=PhysicsRayQueryParameters3D.create(origin,b.global_position)
				if slots.has("caster"): ray.exclude=[slots.caster.get_rid()]
				var hit=get_world_3d().direct_space_state.intersect_ray(ray)
				if not hit.is_empty() and hit.collider!=b:
					if channel!="optical": continue
					w*=float(hit.collider.get_meta("transmission",0.))
		if channel=="thermal" and b.get_meta("thermal_path","radiation")=="insulated": continue
		if w>0.: out[b]=w
	return out

func deliver(b:RigidBody3D,j:Vector3) -> bool:
	if j.is_zero_approx(): return false
	if b.has_meta("integrity"):
		var residual=float(b.get_meta("integrity"))-j.length()
		b.set_meta("integrity",maxf(0,residual))
		damage_events+=1
		if residual<=0 and b.freeze:
			b.freeze=false
			b.set_meta("broken",true)
			director.play_at("stone_strain",b.global_position,1.)
	if b.has_meta("poise"):
		b.set_meta("poise",maxf(0.,float(b.get_meta("poise"))-j.length()))
	b.apply_central_impulse(j)
	return true

func support(origin:Vector3,extent:float) -> StaticBody3D:
	var b=StaticBody3D.new()
	var c=CollisionShape3D.new()
	var shape=CylinderShape3D.new()
	shape.radius=extent
	shape.height=.08
	c.shape=shape
	b.add_child(c)
	b.position=origin
	add_child(b)
	return b

func load_on(support_body:StaticBody3D) -> float:
	var kg=0.
	for b in get_tree().get_nodes_in_group("world_body"):
		if support_body in b.get_colliding_bodies(): kg+=b.mass
	return kg

# Remaining distance and hop count both constrain propagation along live material edges.
func network(root,kind:String,eligible:Dictionary,reach:float,hops:int,g:Dictionary) -> Dictionary:
	var states=[[root,0.,0]]
	var visited={}
	var best={}
	var valid=edges.filter(func(e): return e.kind==kind and eligible.has(e.a) and eligible.has(e.b))
	if valid.size()>g.edges or not eligible.has(root): return {}
	while not states.is_empty():
		var item=states.pop_front()
		var node=item[0]
		var distance=float(item[1])
		var depth=int(item[2])
		var state=[node,depth]
		if distance>reach or visited.get(state,INF)<=distance: continue
		visited[state]=distance
		best[node]=minf(best.get(node,INF),distance)
		if best.size()>g.nodes: return {}
		if depth>=hops: continue
		for e in valid:
			if e.intact and (e.a==node or e.b==node):
				states.append([e.b if e.a==node else e.a,distance+e.length_m,depth+1])
	return best

func remove_support(surface:StaticBody3D) -> void:
	for b in get_tree().get_nodes_in_group("world_body"):
		if surface in b.get_colliding_bodies(): b.sleeping=false
	surface.queue_free()
