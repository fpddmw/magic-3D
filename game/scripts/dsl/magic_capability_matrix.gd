class_name MagicCapabilityMatrix
extends RefCounted
## Stage 3 Capability Matrix & Limited-Condition Contract Verifier for Magic DSL v0.2.1.
## Distinguishes SUPPORTED, LIMITED (requires explicit bounded checks), PLANNED, and UNSUPPORTED.

const MATERIAL_CARRIER_MATRIX := {
	"WATER|BODY": "SUPPORTED",
	"WATER|PATH_GRAPH": "SUPPORTED",
	"WATER|SURFACE": "PLANNED",
	"WATER|REGION": "LIMITED",
	"ICE|BODY": "SUPPORTED",
	"ICE|PATH_GRAPH": "LIMITED",
	"ICE|SURFACE": "SUPPORTED",
	"ICE|REGION": "PLANNED",
	"FOG|BODY": "PLANNED",
	"FOG|PATH_GRAPH": "LIMITED",
	"FOG|SURFACE": "PLANNED",
	"FOG|REGION": "SUPPORTED",
	"LIGHTNING_PLASMA|BODY": "PLANNED",
	"LIGHTNING_PLASMA|PATH_GRAPH": "SUPPORTED",
	"LIGHTNING_PLASMA|SURFACE": "PLANNED",
	"LIGHTNING_PLASMA|REGION": "LIMITED",
	"FLAME|BODY": "LIMITED",
	"FLAME|PATH_GRAPH": "PLANNED",
	"FLAME|SURFACE": "PLANNED",
	"FLAME|REGION": "LIMITED",
	"STONE|BODY": "SUPPORTED",
	"STONE|PATH_GRAPH": "PLANNED",
	"STONE|SURFACE": "LIMITED",
	"STONE|REGION": "PLANNED",
	"METAL|BODY": "SUPPORTED",
	"METAL|PATH_GRAPH": "PLANNED",
	"METAL|SURFACE": "LIMITED",
	"METAL|REGION": "PLANNED",
	"ASH|REGION": "LIMITED",
	"VITAL_SPORE|REGION": "PLANNED",
}

const FIELD_CARRIER_MATRIX := {
	"GRAVITY|REGION": "SUPPORTED",
	"HEAT_EXTRACTION|REGION": "SUPPORTED",
	"HEAT_INJECTION|REGION": "SUPPORTED",
	"LIGHT_EMISSION|REGION": "SUPPORTED",
	"LIGHT_ATTENUATION|REGION": "SUPPORTED",
	"WIND_FORCE|REGION": "SUPPORTED",
	"ELECTRIC_POTENTIAL|REGION": "SUPPORTED",
	"ELECTRIC_POTENTIAL|PATH_GRAPH": "LIMITED",
	"SPATIAL_BARRIER|SURFACE": "SUPPORTED",
	"SPATIAL_BARRIER|REGION": "PLANNED",
	"LOCAL_TIME_RATE|REGION": "PLANNED",
	"VITAL_FLUX|REGION": "PLANNED",
}


static func get_material_carrier_tier(material_id: String, carrier: String) -> String:
	return MATERIAL_CARRIER_MATRIX.get("%s|%s" % [material_id, carrier], "UNSUPPORTED")


static func get_field_carrier_tier(field_channel: String, carrier: String) -> String:
	return FIELD_CARRIER_MATRIX.get("%s|%s" % [field_channel, carrier], "UNSUPPORTED")


static func validate_limited_conditions(doc: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var subjects_by_id := {}
	for subj in doc.get("subjects", []):
		if subj is Dictionary and subj.has("id"):
			subjects_by_id[subj["id"]] = subj

	var spatial_list: Array = doc.get("spatial", [])
	for i in range(spatial_list.size()):
		var sp: Dictionary = spatial_list[i]
		var sid: String = str(sp.get("subject_id", ""))
		if not subjects_by_id.has(sid):
			continue
		var subj: Dictionary = subjects_by_id[sid]
		var carrier: String = str(sp.get("carrier", ""))
		var skind: String = str(subj.get("kind", ""))

		if skind == "MATERIAL":
			var mid: String = str(subj.get("material_id", ""))
			var tier := get_material_carrier_tier(mid, carrier)
			if tier != "SUPPORTED" and tier != "LIMITED":
				errors.append("[STAGE_3_CAPABILITY] spatial[%d]: material+carrier %s|%s is '%s'" % [i, mid, carrier, tier])
			if mid == "ICE" and carrier == "PATH_GRAPH" and int(sp.get("node_budget", 0)) > MagicDSLTypes.MAX_PATH_NODES:
				errors.append("[STAGE_3_CAPABILITY] spatial[%d]: ICE+PATH_GRAPH limited to <= %d nodes" % [i, MagicDSLTypes.MAX_PATH_NODES])
		elif skind == "FIELD":
			var fch: String = str(subj.get("field_channel", ""))
			var ftier := get_field_carrier_tier(fch, carrier)
			if ftier != "SUPPORTED" and ftier != "LIMITED":
				errors.append("[STAGE_3_CAPABILITY] spatial[%d]: field+carrier %s|%s is '%s'" % [i, fch, carrier, ftier])
			if fch == "SPATIAL_BARRIER":
				if carrier != "SURFACE" or not subj.has("barrier_policy"):
					errors.append("[STAGE_3_CAPABILITY] spatial[%d]: SPATIAL_BARRIER requires SURFACE carrier and barrier_policy" % i)

	var pg: Dictionary = doc.get("process_graph", {})
	for p in pg.get("processes", []):
		for phase in ["on_enter", "while_active", "on_exit"]:
			for op in p.get(phase, []):
				if str(op.get("op", "")) != "TRANSFORM":
					continue
				var tsid: String = str(op.get("target_subject_id", ""))
				if not subjects_by_id.has(tsid):
					continue
				var tsubj: Dictionary = subjects_by_id[tsid]
				var tid: String = str(op.get("transform_id", ""))
				if tid == "PHASE_CHANGE" and str(tsubj.get("material_id", "")) == "WATER" and str(op.get("target_phase", "")) == "SOLID":
					var mob := int(op.get("max_output_bodies", -1))
					if mob < 1 or mob > MagicDSLTypes.MAX_DYNAMIC_BODIES:
						errors.append("[STAGE_3_CAPABILITY] %s.%s: Water->Ice freeze requires max_output_bodies in 1..%d" % [p.get("id", "?"), phase, MagicDSLTypes.MAX_DYNAMIC_BODIES])
				if tid == "PROPAGATE":
					var prop: Dictionary = op.get("propagation", {})
					if int(prop.get("max_hops", 0)) > MagicDSLTypes.MAX_PROPAGATE_HOPS:
						errors.append("[STAGE_3_CAPABILITY] %s.%s: PROPAGATE max_hops exceeds cap %d" % [p.get("id", "?"), phase, MagicDSLTypes.MAX_PROPAGATE_HOPS])

	return errors
