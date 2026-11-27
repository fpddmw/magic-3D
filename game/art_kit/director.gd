extends Node3D

const FX=preload("res://art_kit/phenomenon.gdshader")
var kit:Dictionary
var voices:Dictionary={}
var audio_cache:Dictionary={}
var clock_s:=0.
var last_impact:=0.
var sequence:=0

func sound(kind:String, ambient:=false) -> AudioStreamWAV:
	if audio_cache.has(kind): return audio_cache[kind]
	var hz=22050
	var duration=3.0 if ambient else .68
	var bytes=PackedByteArray()
	bytes.resize(int(hz*duration)*2)
	var rng=RandomNumberGenerator.new()
	rng.seed=kind.hash()
	var f=61.+posmod(kind.hash(),71)
	var low=0.
	for i in bytes.size()/2:
		var t=float(i)/hz
		low=lerpf(low,rng.randf_range(-1.,1.),.12)
		var tone=sin(TAU*f*t+1.8*sin(26*t))*exp(-6.*t)
		var ring=sin(TAU*f*2.79*t)*exp(-4.*t)*.19
		var air=low*(.4 if ambient else 1.3*exp(-8.*t))
		var v=air if ambient else (tone*.36+ring+air)*minf(1,t*110.)*minf(1,(duration-t)*12.)
		bytes.encode_s16(i*2,int(clampf(v,-1,1)*21000))
	var stream=AudioStreamWAV.new()
	stream.mix_rate=hz
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.data=bytes
	if ambient:
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_end=bytes.size()/2
	audio_cache[kind]=stream
	return stream

func play_at(kind:String,p:Vector3, strength:float) -> void:
	if get_child_count()>48: return
	var audio=AudioStreamPlayer3D.new()
	audio.stream=sound(kind)
	audio.position=p
	audio.volume_db=linear_to_db(clampf(strength,.15,1.))
	audio.unit_size=6.
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()

func cue(key:String, tr:Dictionary, spatial:Dictionary, p:Vector3, beat:float) -> void:
	# The process supplies one beat for optics, deformation and the audio accent.
	var fresh=not voices.has(key)
	if fresh:
		if voices.size()>=kit.max_tracks: return
		sequence+=1
		var node=MeshInstance3D.new()
		var material=ShaderMaterial.new()
		material.shader=FX
		var carrier=spatial.get("carrier","Region")
		match carrier:
			"Body":
				var m=SphereMesh.new()
				m.radial_segments=8
				m.rings=4
				node.mesh=m
			"SurfacePatch": node.mesh=BoxMesh.new()
			"PathGraph": node.mesh=CylinderMesh.new()
			_: node.mesh=TorusMesh.new()
		var mat_name=tr.get("material","silver_mist")
		var adapter=kit.adapters[mat_name][carrier]
		var variants=["facet","ridge","seam","grain","film","halo","rind","thread"]
		material.set_shader_parameter("adapter",float(variants.find(adapter)))
		material.set_shader_parameter("accent",kit.highlight_fraction)
		material.set_shader_parameter("tint",Color("#9aaab9") if mat_name!="crystal" else Color("#8abdbd"))
		node.material_override=material
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		voices[key]={"node":node,"material":material,"weight":0.0,"order":sequence,"last_accent":-1,"priority":int(tr.get("focus")!="secondary"),"carrier":carrier}
	var v:Dictionary=voices[key]
	v.until=clock_s+(.28 if tr.cue=="impact" else .20)
	v.node.position=p
	var radius=minf(spatial.get("geometry",{}).get("extent_m",1.0),6.)
	var size=radius*(.26+.5*beat) if tr.get("motion")!="gather" else radius*(.80-.55*beat)
	match v.carrier:
		"Body": v.node.scale=Vector3.ONE*size
		"SurfacePatch": v.node.scale=Vector3(size*2,.045,size*2)
		"PathGraph": v.node.scale=Vector3(.12,size,.12)
		_: v.node.scale=Vector3(size,.10+beat*.15,size)
	v.material.set_shader_parameter("beat",beat)
	var accent=int(beat*3)
	if tr.has("audio") and (fresh or accent>v.last_accent):
		play_at(tr.audio,p,.35+.65*beat)
	v.last_accent=accent
	v.node.visible=tr.has("visual") or tr.has("material") or tr.has("space_fx")
	if tr.get("camera")=="local_impact": last_impact=clock_s

func _process(dt:float) -> void:
	clock_s+=dt
	var winner=""
	var rank=-1
	for key in voices:
		var v:Dictionary=voices[key]
		var score=int(v.priority)*1000000+int(v.order)
		if v.until>=clock_s and score>rank:
			winner=key
			rank=score
	for key in voices.keys():
		var v:Dictionary=voices[key]
		var level=1. if key==winner else (.3 if v.until>=clock_s else 0.)
		v.weight=move_toward(v.weight,level,dt/kit.focus_blend_s)
		v.material.set_shader_parameter("emphasis",v.weight)
		if clock_s>v.until and v.weight<=0.:
			v.node.queue_free()
			voices.erase(key)
