extends RefCounted
# Exercises the same entry point, physics step, ledger and recipe bytes as gameplay.
var checks:Dictionary={}
var measurements:Dictionary={}

func entry(h,fragment:String) -> Dictionary:
	for row in h.catalog:
		if row.path.ends_with(fragment): return row
	return {}

func ticks(h,n:int) -> void:
	for i in n: await h.get_tree().physics_frame

func evidence(key:String,condition:bool,detail=null) -> void:
	checks[key]=condition
	if detail!=null: measurements[key]=detail

func run(h) -> void:
	await ticks(h,6)
	var tree=h.get_tree()
	var c=h.cast_entry(entry(h,"/pressure_wind.json"))
	await ticks(h,36)
	var before=c.ratio()
	c.input_event("release")
	evidence("paid_charge_releases_same_tick",before>0.2 and c.reserve==0. and "deliver" in c.started,before)
	await ticks(h,12)
	var interrupted=h.cast_entry(entry(h,"/pressure_wind.json"))
	await ticks(h,24)
	interrupted.input_event("interrupt")
	evidence("interrupt_prevents_delivery",not interrupted.started.has("deliver"))
	var stone=h.cast_entry(entry(h,"/cast_stone.json"))
	var body:RigidBody3D=stone.bodies.stone
	await ticks(h,4)
	body.set_meta("damage",2.)
	h.world.edges.append({"a":body,"b":h.world.slots.spring,"kind":"material","intact":true,"length_m":1.})
	var witness=[body.get_instance_id(),body.get_rid(),body.global_transform,body.linear_velocity,body.angular_velocity,body.get_meta("damage")]
	stone.input_event("release")
	var after=[body.get_instance_id(),body.get_rid(),body.global_transform,body.linear_velocity,body.angular_velocity,body.get_meta("damage")]
	evidence("world_handoff_preserves_body_state_and_edge",witness==after and body.get_meta("control")=="world" and h.world.edges.back().a==body and h.world.edges.back().intact,body.get_instance_id())
	await ticks(h,4)
	evidence("world_body_continues",body.global_transform!=witness[2])
	h.mana=300
	var sheet=h.cast_entry(entry(h,"/bear_load.json"))
	await ticks(h,2)
	var surface=sheet.surfaces.boundary
	var weight=h.world.make_body("Load",surface.position+Vector3(2.9,.56,.6),3.,Vector3.ONE*.55,h.hall.mats.stone,{})
	await ticks(h,45)
	evidence("support_carries_contact",sheet.surfaces.has("boundary") and weight.get_colliding_bodies().has(surface))
	var high=weight.position.y
	weight.mass=15.
	await ticks(h,9)
	evidence("support_breaks_on_overload",sheet.broken.has("boundary"),sheet.events.filter(func(e): return e.event=="overload"))
	sheet.input_event("release")
	await ticks(h,24)
	evidence("unsupported_load_falls",weight.position.y<high-.05,[high,weight.position.y])
	h.player.command("roll")
	evidence("roll_spends_stamina",h.player.stamina<100 and h.player.state=="roll")
	await ticks(h,42)
	h.player.struck(60.,Vector3.FORWARD)
	evidence("poise_stagger",h.player.state=="stagger")
	var file=entry(h,"/transfer/admitted.json")
	if not file.is_empty():
		h.mana=300
		var concurrent=h.cast_entry(entry(h,"/cast_stone.json"))
		await transfer(h,file,concurrent.bodies.stone)
	var result={"engine":Engine.get_version_info().string,"physics":ProjectSettings.get_setting("physics/3d/physics_engine"),"checks":checks,"observations":measurements}
	print("HALL_RESULT ",JSON.stringify(result))
	tree.quit(1 if checks.values().has(false) else 0)

func transfer(h,file:Dictionary,manifest:RigidBody3D) -> void:
	var anchor=h.world.slots.spring
	var center:Vector3=Vector3(0,3.3,-6)
	anchor.global_position=center
	h.world.slots.target=anchor
	var moving
	var pillar
	for b in h.get_tree().get_nodes_in_group("world_body"):
		if b.name=="LooseStone": moving=b
		if b.name=="CrackedPier": pillar=b
	var targets=[h.enemy,pillar,moving,manifest]
	var spread=[Vector3(-2,0,0),Vector3(2,0,0),Vector3(0,0,-2),Vector3(0,0,2)]
	var snapshots=[]
	for i in targets.size():
		var b=targets[i]
		b.freeze=true
		b.global_transform=Transform3D(Basis(),center+spread[i])
		b.linear_velocity=Vector3.ZERO
		b.gravity_scale=0.
		b.sleeping=false
		b.angular_velocity=Vector3.ZERO
	pillar.set_meta("integrity",.1)
	await ticks(h,3)
	h.mana=300
	var cast=h.cast_entry(file)
	for n in cast.contracts.values():
		if n.has("reserve"): await ticks(h,ceili(60*n.reserve.full_charge_s*.8))
	evidence("other_cast_owns_body_at_delivery",typeof(manifest.get_meta("control"))==TYPE_INT)
	for b in targets:
		b.freeze=(b==pillar)
		snapshots.append(b.linear_velocity)
	await ticks(h,2)
	measurements["positions_before_release"]=[]
	for b in targets: measurements["positions_before_release"].append(str(b.global_position-center))
	cast.input_event("release")
	await ticks(h,3)
	for i in targets.size():
		var dv:Vector3=targets[i].linear_velocity-snapshots[i]
		evidence("transfer_inward_"+str(targets[i].name),dv.dot(-spread[i])>.001,Array([dv.x,dv.y,dv.z]))
	evidence("transfer_environment_overload",pillar.get_meta("broken",false))

func bench(h) -> void:
	var tree=h.get_tree()
	# Real draw frames, no fixed-FPS flag; sample includes casts and physics.
	var warm=75
	var samples=[]
	var prev=Time.get_ticks_usec()
	for i in warm+300:
		await RenderingServer.frame_post_draw
		var now=Time.get_ticks_usec()
		if i>=warm: samples.append(float(now-prev)/1000.)
		prev=now
		if i%75==0:
			h.mana=300.
			h.cast_entry(entry(h,"/pressure_wind.json"))
		if i%75==42: h.send_event("release")
	samples.sort()
	var view=h.get_viewport()
	var dest=OS.get_environment("HALL_SCREENSHOT")
	if dest!="": view.get_texture().get_image().save_png(dest)
	print("HALL_BENCH ",JSON.stringify({"samples":samples.size(),"p50_ms":samples[149],"p95_ms":samples[284],"max_ms":samples.back(),"gpu":RenderingServer.get_video_adapter_name(),"method":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"viewport":str(view.get_visible_rect().size),"texture_px":str(view.get_texture().get_size()),"video_mem_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED),"physics":ProjectSettings.get_setting("physics/3d/physics_engine")}))
	tree.quit()
