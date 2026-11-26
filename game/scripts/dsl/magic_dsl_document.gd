# Spec v0.2 Contract Stub — Wave 1 implementation target
# Loads and validates a CompiledSpellDSL v0.2 JSON document against structural & budget invariants.
class_name MagicDSLDocument
extends Resource

@export var schema_version: String = MagicDSLTypes.SCHEMA_VERSION
@export var meta: Dictionary = {}
@export var subjects: Array = []
@export var spatial: Array = []
@export var relations: Array = []
@export var processes: Array = []
@export var contract: Dictionary = {}
@export var expression: Dictionary = {}
@export var budget: Dictionary = {}


static func load_from_json_file(res_path: String) -> Dictionary:
	var result := {
		"ok": false,
		"errors": PackedStringArray(),
		"document": null,
	}
	if not FileAccess.file_exists(res_path):
		result["errors"].append("File not found: %s" % res_path)
		return result

	var text := FileAccess.get_file_as_string(res_path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		result["errors"].append("Invalid JSON root object in %s" % res_path)
		return result

	return from_dict(parsed)


static func from_dict(data: Dictionary) -> Dictionary:
	var errors := validate_dict(data)
	if not errors.is_empty():
		return {
			"ok": false,
			"errors": errors,
			"document": null,
		}

	var doc := MagicDSLDocument.new()
	doc.schema_version = str(data.get("schema_version", ""))
	doc.meta = data.get("meta", {}).duplicate(true)
	doc.subjects = data.get("subjects", []).duplicate(true)
	doc.spatial = data.get("spatial", []).duplicate(true)
	doc.relations = data.get("relations", []).duplicate(true)
	doc.processes = data.get("processes", []).duplicate(true)
	doc.contract = data.get("contract", {}).duplicate(true)
	doc.expression = data.get("expression", {}).duplicate(true)
	doc.budget = data.get("budget", {}).duplicate(true)

	return {
		"ok": true,
		"errors": PackedStringArray(),
		"document": doc,
	}


static func validate_dict(data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if str(data.get("schema_version", "")) != MagicDSLTypes.SCHEMA_VERSION:
		errors.append("Unsupported schema_version; expected '%s'" % MagicDSLTypes.SCHEMA_VERSION)

	for req_key in ["meta", "subjects", "spatial", "relations", "processes", "contract", "expression", "budget"]:
		if not data.has(req_key):
			errors.append("Missing required top-level section: %s" % req_key)

	if not errors.is_empty():
		return errors

	var raw_subjects: Array = data.get("subjects", [])
	if raw_subjects.is_empty() or raw_subjects.size() > MagicDSLTypes.MAX_SUBJECTS_PER_SPELL:
		errors.append("subjects count out of budget [1..%d]" % MagicDSLTypes.MAX_SUBJECTS_PER_SPELL)

	var subject_ids := {}
	for subj in raw_subjects:
		if subj is Dictionary and subj.has("id"):
			subject_ids[str(subj["id"])] = subj

	var raw_spatial: Array = data.get("spatial", [])
	for sp in raw_spatial:
		if not (sp is Dictionary):
			errors.append("spatial entry must be Dictionary")
			continue
		var sid := str(sp.get("subject_id", ""))
		if not subject_ids.has(sid):
			errors.append("spatial references unknown subject_id: %s" % sid)
		var geom: Dictionary = sp.get("geometry", {})
		if int(geom.get("node_budget", 0)) > MagicDSLTypes.MAX_PATH_NODES:
			errors.append("node_budget exceeds MAX_PATH_NODES (%d)" % MagicDSLTypes.MAX_PATH_NODES)
		if int(geom.get("edge_budget", 0)) > MagicDSLTypes.MAX_PATH_EDGES:
			errors.append("edge_budget exceeds MAX_PATH_EDGES (%d)" % MagicDSLTypes.MAX_PATH_EDGES)
		if int(geom.get("quad_budget", 0)) > MagicDSLTypes.MAX_SURFACE_QUADS:
			errors.append("quad_budget exceeds MAX_SURFACE_QUADS (%d)" % MagicDSLTypes.MAX_SURFACE_QUADS)

	var raw_processes: Array = data.get("processes", [])
	if raw_processes.is_empty() or raw_processes.size() > MagicDSLTypes.MAX_PROCESSES_PER_SPELL:
		errors.append("processes count out of budget [1..%d]" % MagicDSLTypes.MAX_PROCESSES_PER_SPELL)

	for proc in raw_processes:
		if not (proc is Dictionary):
			continue
		for op in proc.get("operations", []):
			if not (op is Dictionary):
				continue
			if str(op.get("family", "")) == "TRANSFORM":
				var tid := str(op.get("transform_id", ""))
				if not MagicCapabilityMatrix.is_transform_legal(tid):
					errors.append("Unregistered transform_id: %s" % tid)
				if int(op.get("max_output_bodies", 0)) > MagicDSLTypes.MAX_FRACTURE_BODIES:
					errors.append("max_output_bodies exceeds MAX_FRACTURE_BODIES (%d)" % MagicDSLTypes.MAX_FRACTURE_BODIES)

	var raw_budget: Dictionary = data.get("budget", {})
	if str(raw_budget.get("compiler_status", "")) != "VALID":
		errors.append("budget.compiler_status must be VALID before runtime load")

	return errors
