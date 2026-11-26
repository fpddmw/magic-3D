# Spec v0.2 Contract Stub — ArtKit & Read-Only Presentation Director
# Strictly read-only consumer of committed world state, Desired-vs-Realized strain, and WorldEvents.
# NEVER mutates world geometry, physics, or authoritative inventory.
class_name SpellDirector
extends Node

signal beat_observed(spell_id: String, phase_tag: String)

@export var world_environment: WorldEnvironment
@export var main_camera: Camera3D


func on_process_started(spell_doc: MagicDSLDocument, process_id: String) -> void:
	if spell_doc == null:
		return
	var spell_id := str(spell_doc.meta.get("id", ""))
	beat_observed.emit(spell_id, "process:" + process_id)
	# TODO(Wave 1): Lower ArtKit 4-layer visual stack & AudioDirector drone/contrast modulation
	# strictly from spell_doc.expression and committed subject/process states.


func on_world_event_committed(spell_doc: MagicDSLDocument, event_type: String, payload: Dictionary) -> void:
	if spell_doc == null:
		return
	var spell_id := str(spell_doc.meta.get("id", ""))
	beat_observed.emit(spell_id, "event:" + event_type)
	# TODO(Wave 1): Trigger pre-impact silence window, impulse-scaled hit-stop, decal projection,
	# hall reverb impact SFX, or fracture debris strictly proportional to payload impulse/stress.


func on_support_withdrawn(spell_doc: MagicDSLDocument, fade_duration_s: float = 1.0) -> void:
	if spell_doc != null:
		var spell_id := str(spell_doc.meta.get("id", ""))
		beat_observed.emit(spell_id, "support_withdrawn")
	# TODO(Wave 1): Interpolate temporary lighting/camera offsets back to baseline while leaving
	# persistent WorldLaw entities (ice bodies, puddles, scorches) untouched.
	var _unused := fade_duration_s
