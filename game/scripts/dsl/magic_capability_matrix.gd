# Spec v0.2 Contract Stub — Wave 1 implementation target
# Executable Capability Matrix & Registered Transform table matching docs/02_Magic_DSL_v0.2_正式语法与语义规范.md
class_name MagicCapabilityMatrix
extends RefCounted

const CAPABILITY_TABLE := {
	MagicDSLTypes.Carrier.BODY: {
		MagicDSLTypes.Capability.POSE_MOVE: MagicDSLTypes.SupportStatus.SUPPORTED,
		MagicDSLTypes.Capability.EXTENT_SCALE: MagicDSLTypes.SupportStatus.LIMITED,
		MagicDSLTypes.Capability.LOCAL_DEFORMATION: MagicDSLTypes.SupportStatus.UNSUPPORTED,
		MagicDSLTypes.Capability.FRACTURE_OR_SPLIT: MagicDSLTypes.SupportStatus.LIMITED,
		MagicDSLTypes.Capability.SOLID_COLLISION: MagicDSLTypes.SupportStatus.SUPPORTED,
		MagicDSLTypes.Capability.STRUCTURAL_PROPAGATE: MagicDSLTypes.SupportStatus.UNSUPPORTED,
		MagicDSLTypes.Capability.PROFILE_DISTRIBUTION: MagicDSLTypes.SupportStatus.LIMITED,
		MagicDSLTypes.Capability.SPATIAL_QUERY_AND_FIELD: MagicDSLTypes.SupportStatus.LIMITED,
	},
	MagicDSLTypes.Carrier.PATH_GRAPH: {
		MagicDSLTypes.Capability.POSE_MOVE: MagicDSLTypes.SupportStatus.SUPPORTED,
		MagicDSLTypes.Capability.EXTENT_SCALE: MagicDSLTypes.SupportStatus.SUPPORTED,
		MagicDSLTypes.Capability.LOCAL_DEFORMATION: MagicDSLTypes.SupportStatus.LIMITED,
		MagicDSLTypes.Capability.FRACTURE_OR_SPLIT: MagicDSLTypes.SupportStatus.SUPPORTED,
		MagicDSLTypes.Capability.SOLID_COLLISION: MagicDSLTypes.SupportStatus.LIMITED,
		MagicDSLTypes.Capability.STRUCTURAL_PROPAGATE: MagicDSLTypes.SupportStatus.SUPPORTED,
		MagicDSLTypes.Capability.PROFILE_DISTRIBUTION: MagicDSLTypes.SupportStatus.SUPPORTED,
		MagicDSLTypes.Capability.SPATIAL_QUERY_AND_FIELD: MagicDSLTypes.SupportStatus.SUPPORTED,
	},
	MagicDSLTypes.Carrier.SURFACE: {
		MagicDSLTypes.Capability.POSE_MOVE: MagicDSLTypes.SupportStatus.SUPPORTED,
		MagicDSLTypes.Capability.EXTENT_SCALE: MagicDSLTypes.SupportStatus.SUPPORTED,
		MagicDSLTypes.Capability.LOCAL_DEFORMATION: MagicDSLTypes.SupportStatus.LIMITED,
		MagicDSLTypes.Capability.FRACTURE_OR_SPLIT: MagicDSLTypes.SupportStatus.LIMITED,
		MagicDSLTypes.Capability.SOLID_COLLISION: MagicDSLTypes.SupportStatus.LIMITED,
		MagicDSLTypes.Capability.STRUCTURAL_PROPAGATE: MagicDSLTypes.SupportStatus.LIMITED,
		MagicDSLTypes.Capability.PROFILE_DISTRIBUTION: MagicDSLTypes.SupportStatus.SUPPORTED,
		MagicDSLTypes.Capability.SPATIAL_QUERY_AND_FIELD: MagicDSLTypes.SupportStatus.SUPPORTED,
	},
	MagicDSLTypes.Carrier.REGION: {
		MagicDSLTypes.Capability.POSE_MOVE: MagicDSLTypes.SupportStatus.SUPPORTED,
		MagicDSLTypes.Capability.EXTENT_SCALE: MagicDSLTypes.SupportStatus.SUPPORTED,
		MagicDSLTypes.Capability.LOCAL_DEFORMATION: MagicDSLTypes.SupportStatus.UNSUPPORTED,
		MagicDSLTypes.Capability.FRACTURE_OR_SPLIT: MagicDSLTypes.SupportStatus.UNSUPPORTED,
		MagicDSLTypes.Capability.SOLID_COLLISION: MagicDSLTypes.SupportStatus.UNSUPPORTED,
		MagicDSLTypes.Capability.STRUCTURAL_PROPAGATE: MagicDSLTypes.SupportStatus.UNSUPPORTED,
		MagicDSLTypes.Capability.PROFILE_DISTRIBUTION: MagicDSLTypes.SupportStatus.SUPPORTED,
		MagicDSLTypes.Capability.SPATIAL_QUERY_AND_FIELD: MagicDSLTypes.SupportStatus.SUPPORTED,
	},
}

const REGISTERED_TRANSFORMS := {
	"PATH_LIQUID_TO_BODY_SOLID": true,
	"BODY_SOLID_TO_SHARDS": true,
	"BODY_SOLID_TO_LIQUID_REGION": true,
	"FOG_REGION_TO_ICE_SHARDS": true,
	"FIELD_RECONFIGURE": true,
}


static func get_support_status(carrier: MagicDSLTypes.Carrier, capability: MagicDSLTypes.Capability) -> MagicDSLTypes.SupportStatus:
	var row: Dictionary = CAPABILITY_TABLE.get(carrier, {})
	return row.get(capability, MagicDSLTypes.SupportStatus.UNSUPPORTED)


static func is_supported(carrier: MagicDSLTypes.Carrier, capability: MagicDSLTypes.Capability) -> bool:
	return get_support_status(carrier, capability) != MagicDSLTypes.SupportStatus.UNSUPPORTED


static func is_transform_legal(transform_id: String) -> bool:
	return REGISTERED_TRANSFORMS.has(transform_id)
