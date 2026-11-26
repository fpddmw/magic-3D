# DRAFT v0.1 — pending co-design finalization with GPT (see docs/02_魔法本体论与DSL讨论稿.md)
class_name SpellContract
extends Resource

enum FormationMode {
	INSTANT,
	CHANNEL_SCULPT,
}

enum OwnershipMode {
	DETACHED,
	SUSTAINED_FOCUS,
	ANCHORED_VESSEL_OR_GROUND,
	SELF_ATTUNEMENT,
}

enum InterruptionRule {
	FIZZLE_UNFORMED,
	RELEASE_PARTIAL,
	DROP_TO_WORLD_PHYSICS,
}

@export var formation: FormationMode = FormationMode.INSTANT
@export var ownership: OwnershipMode = OwnershipMode.DETACHED
@export var charge_window_s: float = 0.0
@export var mana_cost: float = 20.0
@export var sustain_mana_per_s: float = 0.0
@export var interruption_rule: InterruptionRule = InterruptionRule.RELEASE_PARTIAL


static func from_dict(data: Dictionary) -> SpellContract:
	var res := SpellContract.new()
	res.formation = FormationMode.get(str(data.get("formation", "INSTANT")), FormationMode.INSTANT)
	res.ownership = OwnershipMode.get(str(data.get("ownership", "DETACHED")), OwnershipMode.DETACHED)
	res.charge_window_s = float(data.get("charge_window_s", 0.0))
	res.mana_cost = float(data.get("mana_cost", 20.0))
	res.sustain_mana_per_s = float(data.get("sustain_mana_per_s", 0.0))
	res.interruption_rule = InterruptionRule.get(
		str(data.get("interruption_rule", "RELEASE_PARTIAL")),
		InterruptionRule.RELEASE_PARTIAL
	)
	return res
