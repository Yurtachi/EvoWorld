extends RefCounted
## Read-only presentation of the creature's knowledge; never reads hidden types.

static func novelty(snapshot: Dictionary, row: Dictionary, tick: int) -> float:
	if not snapshot.get("memory_enabled", false): return 1.0
	var objects: Dictionary = snapshot.get("objects", {})
	var known: Dictionary = objects.get("types", {}).get(row.category, {})
	var entry: Dictionary = objects.get("entries", {}).get(str(row.id), {})
	var familiarity := float(known.get("familiarity", 0)) * 0.4 + float(entry.get("familiarity", 0))
	var age := maxf(0, tick - int(known.get("tick", tick)))
	return clampf(1.0 / (1.0 + familiarity) + minf(0.35, age / 1800.0), 0.02, 1.0)

static func reaction(snapshot: Dictionary, visible: Array, tick: int, action: String) -> String:
	if visible.is_empty(): return "m2_unnoticed"
	var objects: Dictionary = snapshot.get("objects", {})
	var target := int(objects.get("target", 0))
	var row: Dictionary = visible[0]
	var has_target := false
	for item in visible:
		if int(item.id) == target:
			row = item
			has_target = true
	if not has_target:
		for item in visible:
			if novelty(snapshot, item, tick) > novelty(snapshot, row, tick): row = item
	if snapshot.get("memory_enabled", false):
		var known: Dictionary = objects.get("types", {}).get(row.category, {})
		var risk := maxf(0, -float(known.get("value", 0))) * float(known.get("confidence", 0))
		if risk > 0.1: return "m2_cautious"
		if novelty(snapshot, row, tick) < 0.4: return "m2_familiar"
	if snapshot.get("affect_enabled", false) and float(snapshot.get("afetos", {}).get("receio", 0)) > 0.4:
		return "m2_cautious"
	if action == "investigate_object": return "m2_investigating"
	if snapshot.get("objetivo_atual") == "investigar_objeto": return "m2_curious"
	return "m2_noticed"
