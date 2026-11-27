extends Node3D

const STONE = preload("res://art_kit/stone.gdshader")
var batches := {}
var meshes := {}
var mats := {}
var rng := RandomNumberGenerator.new()

func stone(key:String, color:Color, masonry:float) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = STONE
	mat.set_shader_parameter("tone",color)
	mat.set_shader_parameter("masonry",masonry)
	mats[key]=mat

func block(p:Vector3, size:Vector3, mat:String, rot:=0.0) -> void:
	instance("box",mat,Transform3D(Basis(Vector3.FORWARD,rot).scaled_local(size),p))

func instance(shape:String, mat:String, xf:Transform3D) -> void:
	var key=shape+"/"+mat
	if not batches.has(key): batches[key]=[]
	batches[key].append(xf)

func column(p:Vector3, radius:float, height:float, mat:String) -> void:
	instance("round",mat,Transform3D(Basis().scaled(Vector3(radius*2,height,radius*2)),p))

func segment(a:Vector3,b:Vector3,w:float,depth:float,mat:String) -> void:
	var along=(b-a).normalized()
	var z_axis=Vector3.FORWARD if absf(along.dot(Vector3.FORWARD))<0.8 else Vector3.RIGHT
	var x_axis=along.cross(z_axis).normalized()
	var basis=Basis(x_axis,along,x_axis.cross(along)).scaled_local(Vector3(w,a.distance_to(b)+.045,depth))
	instance("box",mat,Transform3D(basis,(a+b)/2))

func arch(a:Vector3,b:Vector3,rise:float,width:float,depth:float,mat:String) -> void:
	var mid=(a+b)/2
	for start in [a,b]:
		var prev:Vector3=start
		for j in range(1,10):
			var t=float(j)/9.
			var q:Vector3=start.lerp(mid,t)+Vector3.UP*rise*sqrt(t)
			segment(prev,q,width,depth,mat)
			prev=q

func collision_box(p:Vector3,size:Vector3) -> void:
	var body=StaticBody3D.new()
	var col=CollisionShape3D.new()
	var shape=BoxShape3D.new()
	shape.size=size
	col.shape=shape
	body.position=p
	body.add_child(col)
	add_child(body)

func glazing(p:Vector3, radius:float) -> void:
	var brass="bronze"
	for j in range(48):
		var t=TAU*j/48
		var u=TAU*(j+1)/48
		for r in [radius,radius*.77,radius*.27]:
			segment(p+Vector3(cos(t),sin(t),0)*r,p+Vector3(cos(u),sin(u),0)*r,.085,.22,brass)
	for j in range(12):
		var t=TAU*j/12
		var dir=Vector3(cos(t),sin(t),0)
		segment(p+dir*radius*.27,p+dir*radius,.08,.19,brass)
		var center=p+dir*radius*.54
		for k in range(12):
			var a=TAU*k/12
			var b=TAU*(k+1)/12
			segment(center+Vector3(cos(a),sin(a),0)*radius*.22,center+Vector3(cos(b),sin(b),0)*radius*.22,.048,.12,"trim")
	var glow=StandardMaterial3D.new()
	glow.albedo_color=Color("#516a75")
	glow.emission_enabled=true
	glow.emission=Color("#526e80")
	glow.emission_energy_multiplier=1.4
	var disk=CylinderMesh.new()
	disk.top_radius=radius
	disk.bottom_radius=radius
	disk.height=.06
	var glass=MeshInstance3D.new()
	glass.mesh=disk
	glass.material_override=glow
	glass.rotation.x=PI/2
	glass.position=p+Vector3.FORWARD*.16
	add_child(glass)

func _ready() -> void:
	rng.seed=11617
	stone("stone",Color("#58606a"),1.)
	stone("trim",Color("#777a77"),.28)
	stone("dark",Color("#373f48"),.8)
	stone("floor",Color("#73777c"),1.)
	stone("bronze",Color("#85765a"),.08)
	meshes.box=BoxMesh.new()
	var drum=CylinderMesh.new()
	drum.radial_segments=10
	drum.rings=1
	drum.top_radius=.5
	drum.bottom_radius=.5
	drum.height=1.
	meshes.round=drum
	block(Vector3(0,-.35,-4),Vector3(24,.7,40),"floor")
	collision_box(Vector3(0,-.35,-4),Vector3(24,.7,40))
	for side in [-1,1]:
		var x=side*10.
		block(Vector3(x,4,-4),Vector3(.8,8,40),"stone")
		collision_box(Vector3(x,6,-4),Vector3(.8,12,40))
		for z in range(-19,15,5):
			var foot=Vector3(side*6.6,0,z)
			for tier in range(3):
				block(foot+Vector3.UP*(.14+tier*.26),Vector3(2.1-tier*.25,.28,2.1-tier*.25),"trim")
			column(foot+Vector3.UP*4.4,.73,7.4,"stone")
			collision_box(foot+Vector3.UP*4,Vector3(1.45,8,1.45))
			for j in range(8):
				var off=Vector3(cos(j*PI/4),0,sin(j*PI/4))*.67
				column(foot+off+Vector3.UP*4.4,.17,7.4,"trim")
			for y in [1.,5.8,7.85,8.12]:
				column(foot+Vector3.UP*y,.93,.20,"trim")
			if z<11:
				arch(foot+Vector3.UP*8,foot+Vector3(0,8,5),2.5,.32,.46,"trim")
				arch(foot+Vector3.UP*8,Vector3(-foot.x,8,z+5),5.9,.24,.33,"dark")
			if side==1:
				arch(foot+Vector3.UP*8,Vector3(-foot.x,8,z),6.1,.56,.65,"stone")
				arch(foot+Vector3.UP*7.75,Vector3(-foot.x,7.75,z),6.1,.14,.72,"trim")
			block(Vector3(x-side*.52,3.4,z),Vector3(.6,6.8,1.1),"trim")
			var l=OmniLight3D.new()
			l.position=foot+Vector3(-side*.9,2.8,0)
			l.light_color=Color("#e7ac71")
			l.light_energy=2.3
			l.omni_range=6.4
			add_child(l)
			column(l.position-Vector3.UP*.22,.27,.38,"bronze")
			var coal=SphereMesh.new()
			coal.radius=.13
			coal.height=.39
			var flame=MeshInstance3D.new()
			flame.mesh=coal
			var fire=StandardMaterial3D.new()
			fire.emission_enabled=true
			fire.emission=Color("#ffbd73")
			fire.emission_energy_multiplier=3.
			flame.material_override=fire
			flame.position=l.position
			add_child(flame)
	for side in [-1,1]:
		block(Vector3(side*7.6,7.3,-22.5),Vector3(7.4,14.6,1),"stone")
		block(Vector3(side*5.3,.042,-4),Vector3(.10,.045,37),"bronze")
		block(Vector3(side*5.56,.045,-4),Vector3(.05,.05,37),"trim")
	block(Vector3(0,3.55,-22.7),Vector3(8,7.1,1),"dark")
	block(Vector3(0,12.7,-22.7),Vector3(8,2.6,1),"stone")
	glazing(Vector3(0,9.2,-22.25),2.85)
	for i in range(5):
		block(Vector3(0,i*.17,-16-i*.65),Vector3(10-i*.24,.27,2.2),"trim")
		collision_box(Vector3(0,i*.17,-16-i*.65),Vector3(10-i*.24,.27,2.2))
	collision_box(Vector3(0,7,-23.1),Vector3(22,14,1))
	collision_box(Vector3(0,4,15.9),Vector3(24,8,.5))
	for i in range(110):
		var side=rng.randf_range(6.,9.5)*(1 if i%2 else -1)
		block(Vector3(side,.18,rng.randf_range(-21,14)),Vector3(rng.randf_range(.18,.85),rng.randf_range(.16,.65),rng.randf_range(.22,.85)),"dark",rng.randf_range(-.5,.5))
	for key in batches:
		var pieces=key.split("/")
		var multi=MultiMesh.new()
		multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.mesh=meshes[pieces[0]]
		multi.instance_count=batches[key].size()
		for i in multi.instance_count: multi.set_instance_transform(i,batches[key][i])
		var node=MultiMeshInstance3D.new()
		node.multimesh=multi
		node.material_override=mats[pieces[1]]
		add_child(node)
