extends Node3D

const ADAPTERS = {
	"Body": preload("res://art_kit/body.gdshader"),
	"PathGraph": preload("res://art_kit/path.gdshader"),
	"SurfacePatch": preload("res://art_kit/patch.gdshader"),
	"Region": preload("res://art_kit/region.gdshader")
}
var meshes: Dictionary = {}
var kit: Dictionary
var voices: Dictionary = {}
var audio_cache: Dictionary = {}
var clock_s := 0.
var last_impact := 0.
var sequence := 0


func prepare(vocabulary: Dictionary) -> void:
	var body = SphereMesh.new()
	body.radial_segments = 8
	body.rings = 4
	var ring = TorusMesh.new()
	ring.rings = 36
	ring.ring_segments = 12
	meshes = {
		"Body": body, "Region": ring, "PathGraph": CylinderMesh.new(), "SurfacePatch": BoxMesh.new()
	}
	# Cache short procedural clips once while loading the hall.
	if DisplayServer.get_name() != "headless":
		for name in vocabulary.audio:
			sound(name)
		sound("rain", true)


func sound(kind: String, ambient := false) -> AudioStreamWAV:
	if audio_cache.has(kind):
		return audio_cache[kind]
	var hz = 22050
	var duration = 3.0 if ambient else .68
	var bytes = PackedByteArray()
	bytes.resize(int(hz * duration) * 2)
	var rng = RandomNumberGenerator.new()
	rng.seed = kind.hash()
	var f = 61. + posmod(kind.hash(), 71)
	var low = 0.
	for i in bytes.size() / 2:
		var t = float(i) / hz
		low = lerpf(low, rng.randf_range(-1., 1.), .12)
		var tone = sin(TAU * f * t + 1.8 * sin(26 * t)) * exp(-6. * t)
		var ring = sin(TAU * f * 2.79 * t) * exp(-4. * t) * .19
		var air = low * (.4 if ambient else 1.3 * exp(-8. * t))
		var v = (
			air
			if ambient
			else (tone * .36 + ring + air) * minf(1, t * 110.) * minf(1, (duration - t) * 12.)
		)
		bytes.encode_s16(i * 2, int(clampf(v, -1, 1) * 21000))
	var stream = AudioStreamWAV.new()
	stream.mix_rate = hz
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.data = bytes
	if ambient:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = bytes.size() / 2
	audio_cache[kind] = stream
	return stream


func quiet(serial: int, window: float) -> void:
	# Only this cast's existing tail is attenuated. Input and world time run normally.
	for child in get_children():
		if child is AudioStreamPlayer3D and child.get_meta("cast_id", -1) == serial:
			child.volume_db = minf(
				child.volume_db, linear_to_db(clampf(window / kit.silence_window_s, .08, 1.))
			)


func play_at(kind: String, p: Vector3, strength: float, cast_id := -1) -> void:
	if get_child_count() > 48 or DisplayServer.get_name() == "headless":
		return
	var audio = AudioStreamPlayer3D.new()
	audio.stream = sound(kind)
	audio.set_meta("cast_id", cast_id)
	audio.position = p
	audio.volume_db = linear_to_db(clampf(strength, .15, 1.))
	audio.unit_size = 6.
	add_child(audio)
	audio.add_to_group("hall_audio")
	audio.finished.connect(audio.queue_free)
	audio.play()


func cue(key: String, tr: Dictionary, spatial: Dictionary, p: Vector3, beat: float) -> void:
	# The process supplies one beat for optics, deformation and the audio accent.
	var fresh = not voices.has(key)
	if fresh:
		if voices.size() >= kit.max_tracks:
			return
		sequence += 1
		var node = MeshInstance3D.new()
		var material = ShaderMaterial.new()
		var carrier = spatial.get("carrier", "Region")
		material.shader = ADAPTERS[carrier]
		node.mesh = meshes[carrier]
		var mat_name = tr.get("material", "silver_mist")
		var adapter = kit.adapters[mat_name][carrier]
		var variants = ["facet", "ridge", "seam", "grain", "film", "halo", "rind", "thread"]
		material.set_shader_parameter("adapter", float(variants.find(adapter)))
		material.set_shader_parameter("accent", kit.highlight_fraction)
		var motifs = [
			"pressure_front",
			"air_streaks",
			"light_veil",
			"stone_dust",
			"ice_rime",
			"water_thread",
			"ember_haze",
			"electric_arc",
			"gravity_rings",
			"motes",
			"ward_edge",
			"imprint"
		]
		material.set_shader_parameter("motif", float(motifs.find(tr.get("visual", "")) + 1))
		material.set_shader_parameter(
			"distortion",
			float(["refraction", "contour", "compression"].find(tr.get("space_fx", "")) + 1)
		)
		material.set_shader_parameter(
			"tint", Color("#9aaab9") if mat_name != "crystal" else Color("#8abdbd")
		)
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		voices[key] = {
			"node": node,
			"material": material,
			"weight": 0.0,
			"order": sequence,
			"last_accent": -1,
			"priority": int(tr.get("focus") != "secondary"),
			"carrier": carrier
		}
	var v: Dictionary = voices[key]
	v.until = clock_s + (.28 if tr.cue == "impact" else .20)
	v.node.position = p
	var radius = minf(spatial.get("geometry", {}).get("extent_m", 1.0), 6.)
	var size = (
		radius * (.26 + .5 * beat) if tr.get("motion") != "gather" else radius * (.80 - .55 * beat)
	)
	match tr.get("motion", ""):
		"pulse":
			size *= .78 + .22 * cos(beat * TAU)
		"ripple":
			size *= .86 + .14 * sin(beat * TAU * 2.)
		"drift":
			v.node.position.y += beat * .36
		"harden":
			size *= .78 + .22 * beat
		"fracture":
			v.node.rotation.y = beat * .25
		"fade":
			size *= 1. - .3 * beat
	match v.carrier:
		"Body":
			v.node.scale = Vector3.ONE * size
		"SurfacePatch":
			v.node.scale = Vector3(size * 2, .045, size * 2)
		"PathGraph":
			v.node.scale = Vector3(.12, size, .12)
		_:
			v.node.scale = Vector3(size, .10 + beat * .15, size)
	v.material.set_shader_parameter("beat", beat)
	var accent = int(beat * 3)
	if tr.has("audio") and (fresh or accent > v.last_accent):
		play_at(tr.audio, p, .35 + .65 * beat, int(key.get_slice("/", 0)))
	v.last_accent = accent
	v.node.visible = tr.has("visual") or tr.has("material") or tr.has("space_fx")
	if tr.get("camera") == "local_impact":
		last_impact = clock_s


func _process(dt: float) -> void:
	clock_s += dt
	var winner = ""
	var rank = -1
	for key in voices:
		var v: Dictionary = voices[key]
		var score = int(v.priority) * 1000000 + int(v.order)
		if v.until >= clock_s and score > rank:
			winner = key
			rank = score
	for key in voices.keys():
		var v: Dictionary = voices[key]
		var level = 1. if key == winner else (.3 if v.until >= clock_s else 0.)
		v.weight = move_toward(v.weight, level, dt / kit.focus_blend_s)
		v.material.set_shader_parameter("emphasis", v.weight)
		if clock_s > v.until and v.weight <= 0.:
			v.node.queue_free()
			voices.erase(key)


func prime_surfaces(at: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var warmers = []
	for carrier in meshes:
		var item = MeshInstance3D.new()
		var mat = ShaderMaterial.new()
		mat.shader = ADAPTERS[carrier]
		mat.set_shader_parameter("tint", Color.BLACK)
		item.material_override = mat
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		item.mesh = meshes[carrier]
		item.position = at
		item.scale = Vector3.ONE * .002
		add_child(item)
		warmers.append(item)
	await RenderingServer.frame_post_draw
	for item in warmers:
		item.queue_free()
