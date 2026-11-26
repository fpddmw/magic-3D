# DRAFT v0.1 — pending co-design finalization with GPT (see docs/02_魔法本体论与DSL讨论稿.md)
class_name SpellDSL
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var rune_signature: PackedStringArray = PackedStringArray()
@export var contract: SpellContract
@export var manifold: SpellManifold
@export var essence: SpellEssence
@export var four_beat: SpellFourBeat


static func from_dict(data: Dictionary) -> SpellDSL:
	var spell := SpellDSL.new()
	spell.id = str(data.get("id", ""))
	spell.display_name = str(data.get("display_name", ""))

	var raw_runes: Variant = data.get("rune_signature", [])
	var runes := PackedStringArray()
	if raw_runes is Array:
		for item in raw_runes:
			runes.append(str(item))
	spell.rune_signature = runes

	spell.contract = SpellContract.from_dict(data.get("contract", {}))
	spell.manifold = SpellManifold.from_dict(data.get("manifold", {}))
	spell.essence = SpellEssence.from_dict(data.get("essence", {}))
	spell.four_beat = SpellFourBeat.from_dict(data.get("four_beat", {}))
	return spell
