class_name SpellDirector
extends Node
## Read-only ArtKit audiovisual presentation director & multi-spell ArtKitArbitrator (v0.2.1).
## Consumes ExpressionSpec, RuntimeEvent stream, and SubjectRuntimeState snapshots without
## mutating physics state or calling global Engine.time_scale.

class ActiveAtmosphereSlot extends RefCounted:
	var cast_id: String
	var priority: int
	var omen_profile: Dictionary
	var aftermath_profile: Dictionary
	var light_weight: float

	func _init(p_cast_id: String, p_priority: int, p_expr: Dictionary) -> void:
		cast_id = p_cast_id
		priority = p_priority
		omen_profile = p_expr.get("omen_profile", {}).duplicate(true)
		aftermath_profile = p_expr.get("aftermath_profile", {}).duplicate(true)
		light_weight = clampf(float(p_expr.get("camera_impulse_level", 0.0)), 0.0, 1.0)


## Arbitrates simultaneous spell atmosphere/light/audio cues cleanly without flickering.
var _arbitration_stack: Array[ActiveAtmosphereSlot] = []


func register_cast_expression(cast_id: String, expression: Dictionary, priority: int = 1) -> void:
	unregister_cast_expression(cast_id)
	_arbitration_stack.append(ActiveAtmosphereSlot.new(cast_id, priority, expression))
	_arbitration_stack.sort_custom(func(a: ActiveAtmosphereSlot, b: ActiveAtmosphereSlot) -> bool:
		return a.priority > b.priority
	)


func unregister_cast_expression(cast_id: String) -> void:
	_arbitration_stack = _arbitration_stack.filter(func(slot: ActiveAtmosphereSlot) -> bool:
		return slot.cast_id != cast_id
	)


## Returns clamped multi-spell environment blending directives (sky_darken <= 0.7, max 3 lights).
func compute_arbitrated_atmosphere() -> Dictionary:
	if _arbitration_stack.is_empty():
		return {"sky_darken": 0.0, "ambient_fog_tint_strength": 0.0, "active_light_slots": 0}
	var lead := _arbitration_stack[0]
	var sky_darken := clampf(float(lead.omen_profile.get("sky_darken", 0.0)), 0.0, 0.7)
	var fog_tint := clampf(float(lead.omen_profile.get("ambient_fog_tint_strength", 0.0)), 0.0, 1.0)
	var lights := mini(MagicDSLTypes.MAX_POINT_LIGHTS, _arbitration_stack.size())
	return {
		"lead_cast_id": lead.cast_id,
		"sky_darken": sky_darken,
		"ambient_fog_tint_strength": fog_tint,
		"active_light_slots": lights,
	}


## Predictable delivery silence (0..120 ms) triggered deterministically on release/delivery transition.
func get_pre_delivery_silence_ms(expression: Dictionary) -> int:
	var ap: Dictionary = expression.get("audio_profile", {})
	return clampi(int(ap.get("pre_delivery_silence_ms", 0)), 0, MagicDSLTypes.MAX_PRE_DELIVERY_SILENCE_MS)


## Local combat hit-stop (0..140 ms) applied per struck actor / active strike animation,
## NEVER mutating Engine.time_scale so camera, audio, and neighboring spells remain deterministic.
func get_local_hitstop_ms(expression: Dictionary) -> int:
	var af: Dictionary = expression.get("aftermath_profile", {})
	return clampi(int(af.get("hitstop_local_ms", 0)), 0, MagicDSLTypes.MAX_HITSTOP_LOCAL_MS)


## Maps Desired vs Realized structural strain ratio (0.0..1.0+) to ArtKit shader/audio parameters.
func compute_strain_feedback(desired_load_lu: float, realized_load_lu: float, capacity_lu: float) -> Dictionary:
	var safe_cap := maxf(capacity_lu, 0.001)
	var strain_ratio := clampf(realized_load_lu / safe_cap, 0.0, 1.5)
	var deviation := absf(desired_load_lu - realized_load_lu) / safe_cap
	return {
		"crack_intensity": clampf((strain_ratio - 0.5) * 2.0, 0.0, 1.0),
		"audio_pitch_shift": clampf(1.0 + (strain_ratio - 0.5) * 0.25, 0.85, 1.35),
		"spark_rate_scale": clampf(strain_ratio + deviation * 0.5, 0.0, 2.0),
	}


func on_runtime_event(event: MagicDSLTypes.RuntimeEvent) -> void:
	# Wave 1A/1B hooks connect registered Audio/Shader modules here strictly via event.type + subject_id
	if event.type in ["ON_TIMEOUT", "ON_DEPLETED", "ON_CONSTRAINT_EXCEEDED"]:
		pass
