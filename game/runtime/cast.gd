extends RefCounted

var arena
var d:Dictionary
var quote:Dictionary
var nodes:Dictionary={}
var contracts:Dictionary={}
var subs:Dictionary={}
var relations:Dictionary={}
var parents:Dictionary={}
var arrived:Dictionary={}
var active:Dictionary={}
var started:Dictionary={}
var holds:Dictionary={}
var bodies:Dictionary={}
var surfaces:Dictionary={}
var broken:Dictionary={}
var captured:Dictionary={}
var poses_at_cast:Dictionary={}
var events:Array=[]
var reserve:=0.
var scale_factor:=1.
var elapsed:=0.
var serial:int

func setup(host,recipe:Dictionary,receipt:Dictionary,id:int) -> bool:
	arena=host
	d=recipe
	quote=receipt
	serial=id
	scale_factor=arena.tariff.scale[d.scale]
	for s in d.Subjects: subs[s.id]=s
	for r in d.Relations: relations[r.id]=r
	for c in d.Contracts: contracts[c.id]=c
	for n in d.Processes.nodes:
		nodes[n.id]=n
		for edge in n.on:
			for dest in edge.to:
				if not parents.has(dest): parents[dest]=[]
				if not n.id in parents[dest]: parents[dest].append(n.id)
	if arena.mana<quote.upfront_mana: return false
	arena.mana-=quote.upfront_mana
	for s in d.Subjects:
		if s.has("spatial"): poses_at_cast[s.id]=capture(s)
	for pid in d.Processes.entry: start(pid)
	return true

func source(s:Dictionary):
	while s.source.kind in ["Borrow","Derived"]: s=subs[s.source.ref]
	return arena.world.slots.get(s.source.get("slot",""))

func capture(s:Dictionary) -> Dictionary:
	var p:Vector3=arena.cast_origin()
	var aim:Vector3=arena.aim()
	match s.spatial.reference.anchor:
		"source","target":
			var b=source(s) if s.spatial.reference.anchor=="source" else arena.world.slots.get("target")
			if not is_instance_valid(b): return {}
			p=b.global_position
		"aim_point": p=arena.aim_point()
	return {"p":p,"aim":aim}

func pose(s:Dictionary) -> Dictionary:
	return capture(s) if s.spatial.reference.bind=="live" else captured.get(s.id,{})

func ratio() -> float:
	return clampf(reserve/quote.reserve_capacity,0.,1.) if quote.reserve_capacity>0. else 0.

func art(pid:String,cue:String,location=null) -> void:
	for i in d.Expression.size():
		var tr=d.Expression[i]
		if tr.process!=pid or tr.cue!=cue: continue
		var s:Dictionary=subs.get(tr.get("subject",""),{})
		var ref_pose=pose(s) if not s.is_empty() else {}
		var point:Vector3=ref_pose.get("p",arena.cast_origin())
		var beat=ratio() if tr.bind=="fill_ratio" else clampf(active[pid].time/contracts[nodes[pid].contract].max_s,0.,1.)
		if cue=="impact": beat=1.
		arena.director.cue("%s/%s"%[serial,i],tr,s.get("spatial",{}),point if location==null else location,beat)

func start(pid:String) -> void:
	if started.has(pid): return
	started[pid]=true
	active[pid]={"time":0.,"pulses":0}
	for op in nodes[pid].enter:
		if not action(pid,op,1.):
			finish(pid,{},"missing_condition")
			return
	art(pid,"enter")
	event(pid,"ready")

func close(handle:String) -> void:
	if surfaces.has(handle):
		arena.world.remove_support(surfaces[handle])
		surfaces.erase(handle)
	if bodies.has(handle): bodies[handle].set_meta("control","world")
	# Temporary optical and sensing properties belong to this cast and handle.
	for b in arena.get_tree().get_nodes_in_group("world_body"):
		var key="layer_%d_%s"%[serial,handle]
		if b.has_meta(key): b.remove_meta(key)
	holds.erase(handle)

func finish(pid:String,edge:Dictionary,reason:String) -> void:
	art(pid,"exit")
	for op in nodes[pid].exit:
		if holds.get(op.target)==pid:
			if op.ability=="handoff_world": events.append({"event":"handoff_world","body":bodies[op.target]})
			close(op.target)
	for h in edge.get("handoff",[]): holds[h.handle]=h.to
	for h in holds.keys():
		if holds[h]==pid: close(h)
	active.erase(pid)
	events.append({"event":"exit","reason":reason})
	for dest in edge.get("to",[]):
		if not arrived.has(dest): arrived[dest]=[]
		arrived[dest].append(pid)
		if nodes[dest].join=="any" or arrived[dest].size()==parents[dest].size(): start(dest)

func event(pid:String,kind:String) -> void:
	if not active.has(pid): return
	var ready=false
	for c in contracts.values():
		if c.has("reserve"): ready=reserve>0 and ratio()+.0000001>=c.reserve.min_release_ratio
	for edge in nodes[pid].on:
		if edge.event==kind and edge.when in ["always","reserve_ready" if ready else "reserve_low"]:
			finish(pid,edge,kind)
			return
	if kind in ["timeout","interrupt"]: finish(pid,{},kind)

func input_event(kind:String) -> void:
	for pid in active.keys():
		if contracts[nodes[pid].contract].controller=="caster": event(pid,kind)

func step(dt:float) -> void:
	elapsed+=dt
	for pid in active.keys():
		if not active.has(pid): continue
		var n=nodes[pid]
		var state=active[pid]
		var c=contracts[n.contract]
		var host_body=source(subs[c.provider]) if c.provider!="@caster" else null
		if c.provider!="@caster" and (not is_instance_valid(host_body) or not host_body.get_meta("linked",false)):
			finish(pid,{},"supply_unavailable")
			continue
		var rate:float=quote.rates[pid]
		var charge=c.has("reserve")
		var t=minf(dt,c.max_s-state.time)
		var balance:float=arena.mana if host_body==null else host_body.get_meta("mana",0.)
		var paid=minf(rate*t,quote.reserve_capacity-reserve) if charge else rate*t
		if paid>balance:
			paid=balance
			t=paid/rate
		if host_body==null: arena.mana-=paid
		else: host_body.set_meta("mana",balance-paid)
		if charge: reserve+=paid
		state.time+=t
		for op in n.active:
			if not action(pid,op,t):
				finish(pid,{},"missing_condition")
				break
		if not active.has(pid): continue
		art(pid,"active")
		if n.has("repeat"):
			while state.pulses<n.repeat.times and state.time+.000001>=(state.pulses+1)*n.repeat.interval_s:
				for op in n.repeat.actions: action(pid,op,1.)
				state.pulses+=1
		if t+0.000001<minf(dt,c.max_s-state.time+t): finish(pid,{},"supply_exhausted")
		elif state.time+.000001>=c.max_s: event(pid,"timeout")

func action(pid:String,op:Dictionary,dt:float) -> bool:
	var a=op.ability
	var t=op.target
	if a=="charge": return true
	var rel=relations.get(t,{})
	var s:Dictionary=subs[rel.get("from",t)]
	var law=arena.world
	if a=="form":
		if not rel.is_empty():
			if subs[rel.to].kind=="WorldRef" and not is_instance_valid(source(subs[rel.to])): return false
		else:
			captured[t]=poses_at_cast[t] if s.spatial.reference.bind=="cast" else capture(s)
			if captured[t].is_empty(): return false
			if s.kind=="Material":
				var b
				match s.source.kind:
					"Manifest": b=arena.spawn_material(captured[t].p,scale_factor,s.spatial.geometry.extent_m)
					"Derived": b=bodies.get(s.source.ref)
					_: b=source(s)
				if not is_instance_valid(b) or (s.has("initial_phase") and b.get_meta("phase","")!=s.initial_phase): return false
				if s.source.kind=="Derived": close(s.source.ref)
				bodies[t]=b
				b.set_meta("control",serial)
		holds[t]=pid
		return true
	var sp=s.spatial
	var at=pose(s)
	if at.is_empty(): return false
	var p:Vector3=at.p
	var channel=arena.registry.delivery[a]
	var u=law.units
	if a=="bear_load":
		if broken.has(t): return true
		if not surfaces.has(t): surfaces[t]=law.support(p,sp.geometry.extent_m)
		var load_kg=law.load_on(surfaces[t])
		if load_kg>scale_factor*u.load_capacity:
			broken[t]=true
			law.remove_support(surfaces[t])
			surfaces.erase(t)
			events.append({"event":"overload","load":load_kg})
			law.director.play_at("stone_strain",p,1.)
			art(pid,"impact",p)
		return true
	if a in ["project","grow","fracture","solidify","melt"]:
		var b=bodies[t]
		if a=="project": law.deliver(b,law.axis(op.axis,p,at.aim,b.global_position)*scale_factor*u.project_impulse)
		if a=="grow":
			var g=minf(u.max_growth,b.get_meta("growth",0.)+dt*u.growth_per_s)
			if not b.has_meta("original_size"): b.set_meta("original_size",b.get_child(1).shape.size)
			b.set_meta("growth",g)
			b.get_child(1).shape.size=b.get_meta("original_size")*(1.+g)
			b.get_child(0).mesh.size=b.get_child(1).shape.size
		if a=="fracture": arena.fracture(b,int(u.max_fragments))
		if a in ["solidify","melt"]:
			if b.mass>scale_factor*u.phase_mass or b.get_meta("phase","")!=("liquid" if a=="solidify" else "solid"): return false
			arena.phase(b,"solid" if a=="solidify" else "liquid")
		return true
	var targets:Dictionary=law.candidates(sp,p,at.aim,channel)
	if a in ["impulse","accelerate","warm","conduct","freeze"]:
		if a=="conduct" or a=="freeze":
			var eligible={}
			var root=source(s) if a=="freeze" else null
			for b in targets:
				if (a=="conduct" and b.get_meta("conductive",false)) or (a=="freeze" and b.has_meta("phase")):
					eligible[b]=targets[b]
					if a=="conduct" and (root==null or p.distance_squared_to(b.global_position)<p.distance_squared_to(root.global_position)): root=b
			var pol=op.get("propagation",{})
			var reach=minf(sp.geometry.extent_m,pol.get("reach_m",30.))
			if a=="freeze": reach=minf(reach,active[pid].time*pol.speed_m_s)
			var route=law.network(root,"material" if a=="freeze" else "electric",eligible,reach,pol.get("hops",12),sp.geometry)
			targets.clear()
			for b in route:
				if a=="freeze":
					if 1.-pol.attenuation*route[b]>0 and b.get_meta("phase")=="liquid": arena.phase(b,"solid")
				else: targets[b]=eligible[b]
			if a=="freeze": return true
		var budget:float
		match a:
			"impulse":
				budget=ratio()*quote.total_impulse_budget
				reserve=0.
			"accelerate": budget=scale_factor*u.acceleration*dt
			"warm": budget=scale_factor*u.heat_per_s*dt
			"conduct": budget=scale_factor*u.charge_per_pulse
		var total=0.
		for b in targets:
			if op.get("allocation")=="distance_weighted": targets[b]/=1.+p.distance_to(b.global_position)
			total+=targets[b]
		var hit=false
		var impact=p
		for b in targets:
			var value=budget*targets[b]/total
			if a in ["impulse","accelerate"]:
				var j=law.axis(op.axis,p,at.aim,b.global_position)*value
				if law.deliver(b,j):
					hit=true
					impact=b.global_position
			elif a=="warm": b.set_meta("temperature_delta",b.get_meta("temperature_delta",0.)+value/b.mass)
			else: b.set_meta("charge",b.get_meta("charge",0.)+value)
		if hit and a=="impulse": art(pid,"impact",impact)
		return true
	if a in ["attenuate","notify","illuminate"]:
		var key="layer_%d_%s"%[serial,t]
		for b in arena.get_tree().get_nodes_in_group("world_body"):
			if b.has_meta(key): b.remove_meta(key)
		for b in targets:
			if a=="attenuate" and b.get_meta("sight",false): b.set_meta(key,{"transmission":u.transmission})
			if a=="notify" and b.get_meta("disturbance",false): source(subs[rel.to]).set_meta("last_signal",b.get_instance_id())
			if a=="illuminate": b.set_meta(key,{"illumination":u.light_level*scale_factor*targets[b]})
		return true
	return false
