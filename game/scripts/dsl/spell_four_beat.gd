# DRAFT v0.1 — pending co-design finalization with GPT (see docs/02_魔法本体论与DSL讨论稿.md)
class_name SpellFourBeat
extends Resource

enum ChargeOmen {
	NONE,
	DIM_SKY,
	FLOAT_DEBRIS,
	DRAW_MOISTURE,
	SILENCE_FIELD,
	GROUND_SEAL,
}

enum GenesisSource {
	CASTER,
	SKY_DESCENT,
	GROUND_ERUPTION,
	ENVIRONMENT_DRAW,
}

enum MotionLaw {
	BALLISTIC,
	SLOW_ADVANCE,
	SWEEP_CREST,
	ORBIT_GUARD,
	IMPLODE_TO_SLAM,
	STATIC_ANCHOR,
}

enum BlockResponse {
	SHATTER,
	DEFLECT_SIDEWAYS,
	PENETRATE,
	ENCASE_OR_BIND,
	PASS_THROUGH,
}

enum AftermathKind {
	NONE,
	PERSISTENT_SOLID,
	PUDDLE_WET,
	SCORCH_EMBER,
	FOG_CLOUD,
	GRAVITY_CRATER,
	RUNE_ECHO,
}

@export_group("Beat 1 & 2 · Wind-up & Charging Omen")
@export var charge_duration_s: float = 0.8
@export var charge_omen: ChargeOmen = ChargeOmen.NONE

@export_group("Beat 2 & 3 · Genesis & Motion")
@export var genesis_source: GenesisSource = GenesisSource.CASTER
@export var motion_law: MotionLaw = MotionLaw.BALLISTIC
@export var block_response: BlockResponse = BlockResponse.SHATTER

@export_group("Beat 3 · Director Impact")
@export var hit_stop_s: float = 0.06
@export var camera_pitch_shift_deg: float = 0.0
@export var camera_zoom_bias: float = 0.0
@export var ambient_dim_factor: float = 0.25
@export var audio_impact_weight: float = 0.7

@export_group("Beat 4 · Aftermath")
@export var aftermath_kind: AftermathKind = AftermathKind.NONE
@export var aftermath_duration_s: float = 0.0


static func from_dict(data: Dictionary) -> SpellFourBeat:
	var res := SpellFourBeat.new()
	res.charge_duration_s = float(data.get("charge_duration_s", 0.8))
	res.charge_omen = ChargeOmen.get(str(data.get("charge_omen", "NONE")), ChargeOmen.NONE)
	res.genesis_source = GenesisSource.get(str(data.get("genesis_source", "CASTER")), GenesisSource.CASTER)
	res.motion_law = MotionLaw.get(str(data.get("motion_law", "BALLISTIC")), MotionLaw.BALLISTIC)
	res.block_response = BlockResponse.get(str(data.get("block_response", "SHATTER")), BlockResponse.SHATTER)
	res.hit_stop_s = float(data.get("hit_stop_s", 0.06))
	res.camera_pitch_shift_deg = float(data.get("camera_pitch_shift_deg", 0.0))
	res.camera_zoom_bias = float(data.get("camera_zoom_bias", 0.0))
	res.ambient_dim_factor = float(data.get("ambient_dim_factor", 0.25))
	res.audio_impact_weight = float(data.get("audio_impact_weight", 0.7))
	res.aftermath_kind = AftermathKind.get(str(data.get("aftermath_kind", "NONE")), AftermathKind.NONE)
	res.aftermath_duration_s = float(data.get("aftermath_duration_s", 0.0))
	return res
