# DRAFT v0.1 — pending co-design finalization with GPT (see docs/02_魔法本体论与DSL讨论稿.md)
class_name SpellManifold
extends Resource

enum Dimension {
	POINT_0D,
	CURVE_OR_GRAPH_1D,
	SURFACE_2D,
	SOLID_3D,
	FIELD_3D,
	RELATION,
}

enum AnchorTarget {
	NONE,
	CASTER_BODY,
	LOCKED_TARGET,
	WORLD_SURFACE,
	ENVIRONMENT_SOURCE,
}

@export var dimension: Dimension = Dimension.POINT_0D
@export var scale_m: float = 2.0
@export var branch_count: int = 1
@export var anchor_target: AnchorTarget = AnchorTarget.NONE


static func from_dict(data: Dictionary) -> SpellManifold:
	var res := SpellManifold.new()
	res.dimension = Dimension.get(str(data.get("dimension", "POINT_0D")), Dimension.POINT_0D)
	res.scale_m = float(data.get("scale_m", 2.0))
	res.branch_count = int(data.get("branch_count", 1))
	res.anchor_target = AnchorTarget.get(str(data.get("anchor_target", "NONE")), AnchorTarget.NONE)
	return res
