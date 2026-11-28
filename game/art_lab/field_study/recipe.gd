extends RefCounted

# This is the closed, runnable subset. Strings in a literal rule denote capabilities.
const COLOUR := ["list", 3, 3, ["n", 0, 1]]
const SECTOR := ["tuple", ["n", -180, 180], ["n", 0.3, 4], ["n", 0.05, 2], ["n", 0.03, 0.8]]
const FORMAT := {
	"version": "field-study.1",
	"title": ["text"],
	"intent":
	{
		"runes": ["tuple", "重力", ["one", "聚", "散"], "引"],
		"anchor": ["text"],
		"connections": ["literal", ["共同组织", "局部关联"]]
	},
	"Concepts": ["literal", ["local_gravity", "finite_arcane_support"]],
	"Subjects":
	{
		"carrier": "Region",
		"shape": "sphere",
		"radius_m": ["n", 0.5, 6],
		"receiver": "mass_port",
		"max_receivers": ["int", 1, 24]
	},
	"Relations":
	{
		"channel": "gravity",
		"direction": ["one", "radial_in", "radial_out"],
		"distribution": "quartic",
		"softening_m": ["n", 0.02, 1],
		"peak_m_s2": ["n", 0.1, 14]
	},
	"Processes":
	{
		"prepare": {"on": "hold", "until": "funded_release", "timeout_s": ["n", 0.8, 4]},
		"active": {"on": "commit", "duration_s": ["n", 0.1, 3]},
		"cancel_on":
		["literal", ["interrupt", "invalid_release", "unfunded_release", "timeout", "source_lost"]]
	},
	"Contracts":
	{
		"aim": "live_then_capture",
		"reach_m": ["n", 2, 14],
		"steer_m_s": ["n", 0.2, 10],
		"drop_m": ["n", 0, 2],
		"drop_s": ["n", 0.1, 2],
		"clearance_m": ["n", 0.05, 0.8],
		"history": ["int", 2, 24],
		"rule": "finite_lab.1"
	},
	"Expression":
	{
		"surface": ["one", "slate_folds", "ochre_grain"],
		"color": COLOUR,
		"edge": COLOUR,
		"sectors": ["list", 1, 6, SECTOR],
		"ribs": ["int", 2, 18],
		"fan_deg": ["n", 4, 85],
		"rise_m": ["n", 0, 2],
		"inner_m": ["n", 0.03, 0.6],
		"bank_deg": ["n", 0, 65],
		"flow_m_s": ["n", 0.1, 3],
		"front_s": ["n", 0.01, 0.7],
		"fold_s": ["n", 0.02, 0.6],
		"tail_s": ["n", 0.1, 0.8],
		"preview_alpha": ["n", 0.03, 0.35],
		"history_alpha": ["n", 0, 1],
		"projection": ["one", "volume", "ground"],
		"boundary": "terrain_breaks",
		"body": ["literal", ["brace", "unload"]],
		"sound": ["literal", ["foundation", "breath", "release", "stone_contact"]]
	}
}


static func mismatch(value, rule, path: String) -> String:
	if rule is Dictionary:
		if not value is Dictionary:
			return path
		for key in rule:
			if not value.has(key):
				return path + "." + key
			var error := mismatch(value[key], rule[key], path + "." + key)
			if not error.is_empty():
				return error
		for key in value:
			if not rule.has(key):
				return path + "." + key
		return ""
	if rule is String:
		return "" if value is String and value == rule else path
	match rule[0]:
		"text":
			return "" if value is String and not value.is_empty() else path
		"one":
			return "" if value in rule.slice(1) else path
		"literal":
			return "" if typeof(value) == typeof(rule[1]) and value == rule[1] else path
		"n", "int":
			if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(value):
				return path
			if rule[0] == "int" and value != floor(value):
				return path
			return "" if value >= rule[1] and value <= rule[2] else path
		"tuple", "list":
			if not value is Array:
				return path
			if rule[0] == "tuple" and value.size() != rule.size() - 1:
				return path
			if rule[0] == "list" and (value.size() < rule[1] or value.size() > rule[2]):
				return path
			for i in value.size():
				var item_rule = rule[i + 1] if rule[0] == "tuple" else rule[3]
				var error := mismatch(value[i], item_rule, path + "[" + str(i) + "]")
				if not error.is_empty():
					return error
			return ""
	return path


static func compile_recipe(path: String) -> Dictionary:
	var raw := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(raw)
	var error := mismatch(data, FORMAT, "recipe")
	if not error.is_empty():
		push_error("Unsupported field recipe: " + error)
		return {}
	if (
		data.Contracts.drop_s > data.Processes.active.duration_s
		or data.Relations.softening_m > data.Subjects.radius_m
	):
		push_error("Field times or distances inconsistent")
		return {}
	if (data.intent.runes[1] == "聚") != (data.Relations.direction == "radial_in"):
		push_error("Radial mechanism contradicts the signed anchor in this study subset")
		return {}
	var world: Dictionary = {}
	for key in ["Concepts", "Subjects", "Relations", "Processes", "Contracts"]:
		world[key] = data[key]
	var stage: Dictionary = data.Expression
	var digest := raw.sha256_text()
	return {
		"digest": digest,
		"world_digest": JSON.stringify(world).sha256_text(),
		"title": data.title,
		"world": world,
		"stage": stage,
		"quote": quote(world)
	}


static func quote(w: Dictionary) -> Dictionary:
	# Fixed laboratory tariff; the recipe author specifies geometry and timing only.
	var effort: float = w.Subjects.radius_m * w.Relations.peak_m_s2 * w.Processes.active.duration_s
	return {
		"capacity": 6.0 + effort * .30,
		"min_ratio": .30,
		"fill_s": w.Processes.prepare.timeout_s * .72,
		"impulse_ns": effort * 3.0,
		"work_j": effort * 8.0,
		"reaction_ns": effort * 2.0
	}
