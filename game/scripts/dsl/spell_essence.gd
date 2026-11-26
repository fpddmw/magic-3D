# DRAFT v0.1 — pending co-design finalization with GPT (see docs/02_魔法本体论与DSL讨论稿.md)
class_name SpellEssence
extends Resource

enum Domain {
	NONE,
	WATER_FROST,
	FIRE_STONE,
	WIND_LIGHTNING,
	STAR_GRAVITY,
	LIGHT_DARK,
	TIME_BOUNDARY,
}

enum PhaseShiftTarget {
	NONE,
	SOLID_ICE,
	LIQUID_WATER,
	VAPOR_FOG,
	MOLTEN_LAVA,
	HARD_STONE,
	SHATTERED_SHARDS,
}

@export var primary_domain: Domain = Domain.WATER_FROST
@export var secondary_domain: Domain = Domain.NONE
@export var phase_shift_target: PhaseShiftTarget = PhaseShiftTarget.NONE

@export_group("Systemic & Physical Traits")
@export var mass_weight: float = 1.0
@export var rigidity: float = 0.0
@export var conductivity: float = 0.0
@export var thermal_polarity: float = 0.0
@export var gravity_polarity: float = 0.0
@export var time_scale: float = 1.0
@export var luminance_polarity: float = 0.0
@export var opacity: float = 0.5
@export var leaves_persistent_state: bool = true


static func from_dict(data: Dictionary) -> SpellEssence:
	var res := SpellEssence.new()
	res.primary_domain = Domain.get(str(data.get("primary_domain", "WATER_FROST")), Domain.WATER_FROST)
	res.secondary_domain = Domain.get(str(data.get("secondary_domain", "NONE")), Domain.NONE)
	res.phase_shift_target = PhaseShiftTarget.get(
		str(data.get("phase_shift_target", "NONE")),
		PhaseShiftTarget.NONE
	)
	res.mass_weight = float(data.get("mass_weight", 1.0))
	res.rigidity = float(data.get("rigidity", 0.0))
	res.conductivity = float(data.get("conductivity", 0.0))
	res.thermal_polarity = float(data.get("thermal_polarity", 0.0))
	res.gravity_polarity = float(data.get("gravity_polarity", 0.0))
	res.time_scale = float(data.get("time_scale", 1.0))
	res.luminance_polarity = float(data.get("luminance_polarity", 0.0))
	res.opacity = float(data.get("opacity", 0.5))
	res.leaves_persistent_state = bool(data.get("leaves_persistent_state", true))
	return res
