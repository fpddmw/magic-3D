extends Node3D

const LAYOUT = preload("res://art_kit/audio/observatory_buses.tres")
const EVENTS := {"foundation": 0.03, "breath": .63, "filigree": 2.16, "release": 3.85}
var voices := {}
var last_time := -1.0


func _ready() -> void:
	for key in ["foundation", "breath", "filigree", "release", "stone_contact"]:
		var voice := AudioStreamPlayer3D.new()
		voice.stream = load("res://assets/audio/observatory/" + key + ".wav")
		voice.unit_size = 5
		voice.max_db = -2
		add_child(voice)
		voices[key] = voice
	set_space(false)


func set_space(open: bool) -> void:
	var space := "OpenSky" if open else "Vault"
	AudioServer.set_bus_send(AudioServer.get_bus_index("Preparation"), space)
	for key in voices:
		voices[key].bus = (
			"Foundation" if key == "foundation" else ("Preparation" if key == "breath" else space)
		)


func sample(t: float, contact: float, interrupted: bool, seeking: bool) -> void:
	var restart := seeking or t < last_time or t - last_time > .25
	for key in voices:
		var voice: AudioStreamPlayer3D = voices[key]
		if restart:
			voice.stop()
		if interrupted:
			if voice.playing:
				voice.stop()
			continue
		var stamp: float = contact if key == "stone_contact" else EVENTS[key]
		if stamp < 0. or t < stamp or t >= stamp + voice.stream.get_length():
			continue
		if restart or last_time < stamp:
			voice.play(t - stamp)
	voices.breath.volume_db = (-5.0 * smoothstep(3.68, 3.85, t) if t < 3.85 else 0.)
	last_time = t
