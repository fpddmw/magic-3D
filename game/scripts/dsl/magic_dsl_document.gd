class_name MagicDSLDocument
extends RefCounted
## Magic DSL v0.2.1 4-Stage Validator (GDScript mirror of game/tools/validate_dsl.py).
## Stage 1: Structure Validation
## Stage 2: Semantic Reference & Process Graph Validation
## Stage 3: Capability Matrix & Limited-Condition Validation
## Stage 4: Independent Budget Floor & ArtKit Registry Verification (ignores compiler_status)


static func _is_valid_ref(ref_str: String, subjects_by_id: Dictionary, allow_env: bool = false) -> bool:
	if ref_str in MagicDSLTypes.VALID_CASTER_REFS or ref_str in MagicDSLTypes.VALID_TARGET_REFS:
		return true
	if allow_env and ref_str in MagicDSLTypes.VALID_ENV_REFS:
		return true
	if ref_str.begins_with("SUBJECT:") or ref_str.begins_with("WORLD_REF:"):
		var parts := ref_str.split(":", true, 1)
		return parts.size() == 2 and subjects_by_id.has(parts[1])
	return false


static func validate_stage1_structure(doc: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(doc.get("schema_version", "")) != MagicDSLTypes.SCHEMA_VERSION:
		errors.append("[STAGE_1_STRUCTURE] schema_version must be '%s'" % MagicDSLTypes.SCHEMA_VERSION)
	for req_key in ["spell_id", "display_name", "contract", "subjects", "spatial", "relations", "process_graph", "expression", "budget"]:
		if not doc.has(req_key):
			errors.append("[STAGE_1_STRUCTURE] missing top-level property '%s'" % req_key)

	var subjects: Variant = doc.get("subjects", [])
	if not (subjects is Array) or subjects.is_empty() or subjects.size() > MagicDSLTypes.MAX_SUBJECTS:
		errors.append("[STAGE_1_STRUCTURE] subjects must be Array of length 1..%d" % MagicDSLTypes.MAX_SUBJECTS)
	else:
		for i in range(subjects.size()):
			var s: Variant = subjects[i]
			if not (s is Dictionary):
				errors.append("[STAGE_1_STRUCTURE] subjects[%d] must be Object" % i)
				continue
			if s.has("overrides"):
				errors.append("[STAGE_1_STRUCTURE] subjects[%d] contains forbidden 'overrides' property" % i)
			var skind := str(s.get("kind", ""))
			if not (skind in MagicDSLTypes.SUBJECT_KINDS):
				errors.append("[STAGE_1_STRUCTURE] subjects[%d].kind invalid: '%s'" % [i, skind])
			elif skind == "MATERIAL":
				if not (s.has("material_id") and s.has("initial_phase") and s.has("capacity_mu") and s.has("initial_inventory_mu") and s.has("visual_modules")):
					errors.append("[STAGE_1_STRUCTURE] subjects[%d] (MATERIAL) missing required fields" % i)
			elif skind == "FIELD":
				if not (s.has("field_channel") and s.has("initial_intensity") and s.has("max_intensity") and s.has("visual_modules")):
					errors.append("[STAGE_1_STRUCTURE] subjects[%d] (FIELD) missing required fields" % i)
				var fch := str(s.get("field_channel", ""))
				if fch == "SPATIAL_BARRIER" and not s.has("barrier_policy"):
					errors.append("[STAGE_1_STRUCTURE] subjects[%d] SPATIAL_BARRIER requires barrier_policy" % i)
				elif fch != "SPATIAL_BARRIER" and s.has("barrier_policy"):
					errors.append("[STAGE_1_STRUCTURE] subjects[%d] barrier_policy only permitted on SPATIAL_BARRIER" % i)

	var spatial_list: Variant = doc.get("spatial", [])
	if not (spatial_list is Array) or spatial_list.size() > MagicDSLTypes.MAX_SPATIALS:
		errors.append("[STAGE_1_STRUCTURE] spatial must be Array of length 0..%d" % MagicDSLTypes.MAX_SPATIALS)
	else:
		for i in range(spatial_list.size()):
			var sp: Dictionary = spatial_list[i]
			var carrier := str(sp.get("carrier", ""))
			if not (carrier in MagicDSLTypes.CARRIERS):
				errors.append("[STAGE_1_STRUCTURE] spatial[%d].carrier invalid: '%s'" % [i, carrier])
				continue
			if str(sp.get("dimension", "")) != MagicDSLTypes.CARRIER_DIMENSION_MAP[carrier]:
				errors.append("[STAGE_1_STRUCTURE] spatial[%d].dimension mismatches carrier '%s'" % [i, carrier])
			var valid_gens: Array = MagicDSLTypes.GENERATORS_BY_CARRIER[carrier]
			if not (str(sp.get("generator", "")) in valid_gens):
				errors.append("[STAGE_1_STRUCTURE] spatial[%d].generator '%s' invalid for carrier '%s'" % [i, sp.get("generator", ""), carrier])
			if carrier == "PATH_GRAPH" and not sp.has("per_segment_phase"):
				errors.append("[STAGE_1_STRUCTURE] spatial[%d] PATH_GRAPH requires per_segment_phase" % i)
			var ref: Dictionary = sp.get("reference", {})
			if ref.has("binding"):
				errors.append("[STAGE_1_STRUCTURE] spatial[%d].reference.binding is forbidden in v0.2.1; use relations[]" % i)
			if not (str(ref.get("spawn_anchor", "")) in MagicDSLTypes.SPAWN_ANCHORS):
				errors.append("[STAGE_1_STRUCTURE] spatial[%d].reference.spawn_anchor invalid" % i)

	var pg: Variant = doc.get("process_graph", {})
	if pg is Dictionary:
		for proc in pg.get("processes", []):
			if proc is Dictionary and proc.has("start"):
				errors.append("[STAGE_1_STRUCTURE] process '%s' uses removed 'start' property" % proc.get("id", "?"))
			for phase in ["on_enter", "while_active", "on_exit"]:
				for op in proc.get(phase, []):
					if not (op is Dictionary):
						continue
					if str(op.get("op", "")) == "DRIVE":
						var ch := str(op.get("channel", ""))
						var mode := str(op.get("mode", ""))
						if ch in MagicDSLTypes.DRIVE_IMPULSE_CHANNELS and mode != "IMPULSE":
							errors.append("[STAGE_1_STRUCTURE] DRIVE impulse channel '%s' requires mode == IMPULSE" % ch)
						elif ch in MagicDSLTypes.DRIVE_CONTINUOUS_CHANNELS and not (mode in MagicDSLTypes.DRIVE_CONTINUOUS_MODES):
							errors.append("[STAGE_1_STRUCTURE] DRIVE continuous channel '%s' requires TARGET or RATE mode" % ch)

	var budget: Dictionary = doc.get("budget", {})
	if float(budget.get("derived_upfront_mana", 0.0)) <= 0.0:
		errors.append("[STAGE_1_STRUCTURE] budget.derived_upfront_mana must be > 0.0")

	return errors


static func validate_stage2_semantic(doc: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var subjects_by_id := {}
	for i in range(doc.get("subjects", []).size()):
		var subj: Dictionary = doc["subjects"][i]
		var sid := str(subj.get("id", ""))
		if subjects_by_id.has(sid):
			errors.append("[STAGE_2_SEMANTIC] duplicate subject id '%s'" % sid)
		subjects_by_id[sid] = subj
		if str(subj.get("kind", "")) == "MATERIAL":
			if float(subj.get("initial_inventory_mu", 0.0)) > float(subj.get("capacity_mu", 0.0)):
				errors.append("[STAGE_2_SEMANTIC] subjects[%d]: initial_inventory_mu exceeds capacity_mu" % i)
		elif str(subj.get("kind", "")) == "FIELD":
			if float(subj.get("initial_intensity", 0.0)) > float(subj.get("max_intensity", 0.0)):
				errors.append("[STAGE_2_SEMANTIC] subjects[%d]: initial_intensity exceeds max_intensity" % i)

	var relations_by_id := {}
	for i in range(doc.get("relations", []).size()):
		var rel: Dictionary = doc["relations"][i]
		var rid := str(rel.get("id", ""))
		if relations_by_id.has(rid):
			errors.append("[STAGE_2_SEMANTIC] duplicate relation id '%s'" % rid)
		relations_by_id[rid] = rel
		if not _is_valid_ref(str(rel.get("source_ref", "")), subjects_by_id):
			errors.append("[STAGE_2_SEMANTIC] relations[%d].source_ref invalid" % i)
		if not _is_valid_ref(str(rel.get("target_ref", "")), subjects_by_id):
			errors.append("[STAGE_2_SEMANTIC] relations[%d].target_ref invalid" % i)

	var pg: Dictionary = doc.get("process_graph", {})
	var procs_by_id := {}
	var declared_handles := {}
	for proc in pg.get("processes", []):
		var pid := str(proc.get("id", ""))
		if procs_by_id.has(pid):
			errors.append("[STAGE_2_SEMANTIC] duplicate process id '%s'" % pid)
		procs_by_id[pid] = proc
		for phase in ["on_enter", "while_active", "on_exit"]:
			for op in proc.get(phase, []):
				if op is Dictionary and op.has("handle_id"):
					declared_handles[str(op["handle_id"])] = true

	var provider_cfg: Dictionary = doc.get("contract", {}).get("combat", {}).get("provider", {})
	var energy_source := str(provider_cfg.get("energy_source", ""))

	for proc in pg.get("processes", []):
		var pid := str(proc.get("id", ""))
		for phase in ["on_enter", "while_active", "on_exit"]:
			for op in proc.get(phase, []):
				var kind := str(op.get("op", ""))
				if kind == "ESTABLISH":
					if phase != "on_enter":
						errors.append("[STAGE_2_SEMANTIC] %s.%s: ESTABLISH only allowed in on_enter" % [pid, phase])
					var tid := str(op.get("target_id", ""))
					if str(op.get("target_kind", "")) == "SUBJECT" and not subjects_by_id.has(tid):
						errors.append("[STAGE_2_SEMANTIC] %s.%s: ESTABLISH unknown subject '%s'" % [pid, phase, tid])
					elif str(op.get("target_kind", "")) == "RELATION" and not relations_by_id.has(tid):
						errors.append("[STAGE_2_SEMANTIC] %s.%s: ESTABLISH unknown relation '%s'" % [pid, phase, tid])
				elif kind == "COUPLE":
					if not relations_by_id.has(str(op.get("relation_id", ""))):
						errors.append("[STAGE_2_SEMANTIC] %s.%s: COUPLE unknown relation" % [pid, phase])
				elif kind in ["DRIVE", "CONSTRAIN", "TRANSFORM", "TRANSFER"]:
					var tsid := str(op.get("target_subject_id", ""))
					if not subjects_by_id.has(tsid):
						errors.append("[STAGE_2_SEMANTIC] %s.%s: %s targets unknown subject '%s'" % [pid, phase, kind, tsid])
					if kind == "TRANSFER" and not _is_valid_ref(str(op.get("source_ref", "")), subjects_by_id, true):
						errors.append("[STAGE_2_SEMANTIC] %s.%s: TRANSFER invalid source_ref" % [pid, phase])
				elif kind == "WITHDRAW" and str(op.get("target_scope", "")) == "HANDLE":
					var hid := str(op.get("target_id", ""))
					if not declared_handles.has(hid):
						errors.append("[STAGE_2_SEMANTIC] %s.%s: WITHDRAW(HANDLE) unknown handle '%s'" % [pid, phase, hid])

		for tr in proc.get("transitions", []):
			for npid in tr.get("next_process_ids", []):
				if not procs_by_id.has(npid):
					errors.append("[STAGE_2_SEMANTIC] %s transition targets unknown process '%s'" % [pid, npid])
			if str(tr.get("action", "")) == "HANDOFF_TO_RESERVE":
				var hhs: Array = tr.get("handoff_handles", [])
				if hhs.is_empty():
					errors.append("[STAGE_2_SEMANTIC] %s HANDOFF_TO_RESERVE requires non-empty handoff_handles" % pid)
				if not (energy_source in ["POST_RELEASE_RESERVE", "VESSEL_RESERVE"]):
					errors.append("[STAGE_2_SEMANTIC] %s HANDOFF_TO_RESERVE incompatible with energy_source '%s'" % [pid, energy_source])

	# Reachability BFS from entry_processes
	var visited := {}
	var queue: Array[String] = []
	for eid in pg.get("entry_processes", []):
		if not procs_by_id.has(eid):
			errors.append("[STAGE_2_SEMANTIC] entry_processes references unknown process '%s'" % eid)
		else:
			queue.append(str(eid))
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		if visited.has(cur):
			continue
		visited[cur] = true
		for tr in procs_by_id[cur].get("transitions", []):
			for nxt in tr.get("next_process_ids", []):
				if procs_by_id.has(nxt) and not visited.has(nxt):
					queue.append(str(nxt))
	for pid in procs_by_id:
		if not visited.has(pid):
			errors.append("[STAGE_2_SEMANTIC] unreachable orphan process '%s'" % pid)

	return errors


static func compute_independent_budget(doc: Dictionary) -> Dictionary:
	var min_upfront := 2.0
	var emissive_lights := 0
	for subj in doc.get("subjects", []):
		var skind := str(subj.get("kind", ""))
		if skind == "MATERIAL":
			min_upfront += 3.0 + float(subj.get("initial_inventory_mu", 0.0)) * 1.25
		elif skind == "FIELD":
			min_upfront += 6.0 + float(subj.get("initial_intensity", 0.0)) * 0.20
		elif skind == "WORLD_REF":
			min_upfront += 2.0
		var vm: Variant = subj.get("visual_modules", null)
		if vm is Dictionary and float(vm.get("tint_palette", {}).get("emissive_boost", 0.0)) > 0.25:
			emissive_lights += 1
		elif skind == "FIELD" and str(subj.get("field_channel", "")) == "LIGHT_EMISSION":
			emissive_lights += 1

	var peak_bodies := 0
	var peak_nodes := 0
	var peak_quads := 0
	for sp in doc.get("spatial", []):
		var c := str(sp.get("carrier", ""))
		if c == "BODY":
			min_upfront += 1.5
			peak_bodies += 1
		elif c == "PATH_GRAPH":
			min_upfront += float(sp.get("node_budget", 0)) * 0.25 + float(sp.get("edge_budget", 0)) * 0.15
			peak_nodes += int(sp.get("node_budget", 0))
		elif c == "SURFACE":
			min_upfront += float(sp.get("quad_budget", 0)) * 0.15
			peak_quads += int(sp.get("quad_budget", 0))
		elif c == "REGION":
			min_upfront += float(sp.get("initial_extent_m", 0.0)) * 0.50

	min_upfront += float(doc.get("relations", []).size()) * 1.5

	var min_sustain := 0.0
	var requires_reserve := false
	var controller := str(doc.get("contract", {}).get("combat", {}).get("controller", ""))
	var rel_map := {}
	for r in doc.get("relations", []):
		rel_map[r.get("id", "")] = r

	for proc in doc.get("process_graph", {}).get("processes", []):
		for op in proc.get("while_active", []):
			var kind := str(op.get("op", ""))
			if kind == "DRIVE" and controller == "CASTER_FOCUS":
				min_sustain += 1.2
			elif kind == "TRANSFER":
				min_sustain += 0.5
			elif kind == "CONSTRAIN":
				var pref := str(op.get("provider_ref", ""))
				if pref == "CASTER_MANA":
					min_sustain += maxf(0.5, float(op.get("capacity_lu", 0.0)) * 0.02)
				elif pref in ["POST_RELEASE_RESERVE", "VESSEL_RESERVE"]:
					requires_reserve = true
		for phase in ["on_enter", "on_exit"]:
			for op in proc.get(phase, []):
				var kind2 := str(op.get("op", ""))
				if kind2 == "TRANSFORM" and op.has("max_output_bodies"):
					peak_bodies += int(op["max_output_bodies"])
				elif kind2 == "COUPLE" and controller == "CASTER_FOCUS":
					var rel: Dictionary = rel_map.get(op.get("relation_id", ""), {})
					if str(rel.get("channel", "")) in ["DISTURBANCE_TO_PERCEPTION", "ENERGY_FEED"]:
						min_sustain += 1.2
				elif kind2 == "TRANSFER" and str(op.get("source_ref", "")) == "CASTER:RESERVE":
					requires_reserve = true
		for tr in proc.get("transitions", []):
			if str(tr.get("action", "")) == "HANDOFF_TO_RESERVE":
				requires_reserve = true

	return {
		"min_upfront_mana": min_upfront,
		"min_sustain_mana_per_s": min_sustain,
		"min_reserve_mana": 4.0 if requires_reserve else 0.0,
		"computed_peak_bodies": peak_bodies,
		"computed_peak_nodes": peak_nodes,
		"computed_peak_quads": peak_quads,
		"computed_point_lights": mini(MagicDSLTypes.MAX_POINT_LIGHTS, emissive_lights),
	}


static func validate_stage4_budget_and_artkit(doc: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	# Never trust doc["budget"]["compiler_status"] == "VALID"
	var budget: Dictionary = doc.get("budget", {})
	var provider: Dictionary = doc.get("contract", {}).get("combat", {}).get("provider", {})
	var calc := compute_independent_budget(doc)

	var upfront := float(budget.get("derived_upfront_mana", 0.0))
	var sustain := float(budget.get("derived_sustain_mana_per_s", 0.0))
	var reserve := float(budget.get("derived_reserve_mana", 0.0))

	if upfront + 1e-5 < float(calc["min_upfront_mana"]):
		errors.append("[STAGE_4_BUDGET_ARTKIT] derived_upfront_mana (%s) below computed floor (%s)" % [upfront, calc["min_upfront_mana"]])
	if upfront > float(provider.get("max_upfront_mana", 0.0)):
		errors.append("[STAGE_4_BUDGET_ARTKIT] derived_upfront_mana exceeds contract max_upfront_mana")
	if sustain + 1e-5 < float(calc["min_sustain_mana_per_s"]):
		errors.append("[STAGE_4_BUDGET_ARTKIT] derived_sustain_mana_per_s (%s) below computed floor (%s)" % [sustain, calc["min_sustain_mana_per_s"]])
	if sustain > float(provider.get("max_sustain_mana_per_s", 0.0)):
		errors.append("[STAGE_4_BUDGET_ARTKIT] derived_sustain_mana_per_s exceeds contract max_sustain_mana_per_s")
	if absf(reserve - float(provider.get("post_release_reserve_mana", 0.0))) > 1e-3:
		errors.append("[STAGE_4_BUDGET_ARTKIT] derived_reserve_mana must equal contract post_release_reserve_mana")
	if reserve + 1e-5 < float(calc["min_reserve_mana"]):
		errors.append("[STAGE_4_BUDGET_ARTKIT] reserve-backed cast below min_reserve_mana (%s)" % calc["min_reserve_mana"])

	if int(calc["computed_peak_bodies"]) > MagicDSLTypes.MAX_DYNAMIC_BODIES or int(budget.get("peak_dynamic_bodies", 0)) < int(calc["computed_peak_bodies"]):
		errors.append("[STAGE_4_BUDGET_ARTKIT] peak_dynamic_bodies inconsistent or over ceiling")
	if int(calc["computed_peak_nodes"]) > MagicDSLTypes.MAX_PATH_NODES or int(budget.get("peak_path_nodes", 0)) < int(calc["computed_peak_nodes"]):
		errors.append("[STAGE_4_BUDGET_ARTKIT] peak_path_nodes inconsistent or over ceiling")
	if int(calc["computed_peak_quads"]) > MagicDSLTypes.MAX_SURFACE_QUADS or int(budget.get("peak_surface_quads", 0)) < int(calc["computed_peak_quads"]):
		errors.append("[STAGE_4_BUDGET_ARTKIT] peak_surface_quads inconsistent or over ceiling")
	if int(budget.get("peak_point_lights", 0)) < int(calc["computed_point_lights"]) or int(budget.get("peak_point_lights", 0)) > MagicDSLTypes.MAX_POINT_LIGHTS:
		errors.append("[STAGE_4_BUDGET_ARTKIT] peak_point_lights inconsistent or > %d" % MagicDSLTypes.MAX_POINT_LIGHTS)

	for i in range(doc.get("subjects", []).size()):
		var vm: Variant = doc["subjects"][i].get("visual_modules", null)
		if not (vm is Dictionary):
			continue
		if not (str(vm.get("contour_module", "")) in MagicDSLTypes.ARTKIT_CONTOUR_MODULES):
			errors.append("[STAGE_4_BUDGET_ARTKIT] subjects[%d] unregistered contour_module" % i)
		for sm in vm.get("surface_modules", []):
			if not (str(sm) in MagicDSLTypes.ARTKIT_SURFACE_MODULES):
				errors.append("[STAGE_4_BUDGET_ARTKIT] subjects[%d] unregistered surface_module '%s'" % [i, sm])
		for secm in vm.get("secondary_modules", []):
			if not (str(secm) in MagicDSLTypes.ARTKIT_SECONDARY_MODULES):
				errors.append("[STAGE_4_BUDGET_ARTKIT] subjects[%d] unregistered secondary_module '%s'" % [i, secm])

	var ap: Dictionary = doc.get("expression", {}).get("audio_profile", {})
	if not (str(ap.get("drone_module", "")) in MagicDSLTypes.AUDIO_DRONE_MODULES):
		errors.append("[STAGE_4_BUDGET_ARTKIT] unregistered drone_module")
	if not (str(ap.get("impact_module", "")) in MagicDSLTypes.AUDIO_IMPACT_MODULES):
		errors.append("[STAGE_4_BUDGET_ARTKIT] unregistered impact_module")
	if not (str(ap.get("sustain_loop_module", "")) in MagicDSLTypes.AUDIO_SUSTAIN_MODULES):
		errors.append("[STAGE_4_BUDGET_ARTKIT] unregistered sustain_loop_module")

	return errors


static func validate_all(doc: Dictionary) -> Dictionary:
	var s1 := validate_stage1_structure(doc)
	if not s1.is_empty():
		return {"valid": false, "failed_stage": "STAGE_1_STRUCTURE", "errors": s1, "computed_budget": {}}
	var s2 := validate_stage2_semantic(doc)
	if not s2.is_empty():
		return {"valid": false, "failed_stage": "STAGE_2_SEMANTIC", "errors": s2, "computed_budget": {}}
	var s3 := MagicCapabilityMatrix.validate_limited_conditions(doc)
	if not s3.is_empty():
		return {"valid": false, "failed_stage": "STAGE_3_CAPABILITY", "errors": s3, "computed_budget": {}}
	var s4 := validate_stage4_budget_and_artkit(doc)
	var calc := compute_independent_budget(doc)
	if not s4.is_empty():
		return {"valid": false, "failed_stage": "STAGE_4_BUDGET_ARTKIT", "errors": s4, "computed_budget": calc}
	return {"valid": true, "failed_stage": "", "errors": [], "computed_budget": calc}
