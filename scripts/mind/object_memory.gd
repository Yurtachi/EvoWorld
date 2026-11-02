extends RefCounted
## Hypotheses derive from experienced categories; evidence only from real contact.
const Data = preload("res://scripts/core/sim_data.gd")
const LIMIT := 48
const TTL := 3600
const CATEGORIES := ["capsula", "pedra"]

static func state(mind) -> Dictionary:
	if mind.objects.is_empty():
		mind.objects = {"entries": {}, "types": {}, "target": 0, "curiosity_enabled": true, "cooldowns": {}}
	return mind.objects

static func novelty(mind, row: Dictionary, tick: int) -> float:
	if not mind.memory_enabled: return 1.0
	var s := state(mind)
	var known: Dictionary = s.types.get(row.category, {})
	var entry: Dictionary = s.entries.get(str(row.id), {})
	var familiarity := float(known.get("familiarity", 0.0)) * 0.4 + float(entry.get("familiarity", 0.0))
	var age := maxf(0.0, float(tick - int(known.get("tick", tick))))
	return clampf(1.0 / (1.0 + familiarity) + minf(0.35, age / 1800.0), 0.02, 1.0)

static func candidate(mind, creature, sensors: Dictionary, tick: int) -> Dictionary:
	var best := {"score": -4.0, "id": 0, "novelty": 0.0, "risk": 0.0}
	for row in sensors.get("objects", []):
		var s := state(mind)
		if tick < int(s.cooldowns.get(str(row.id), 0)): continue
		var entry: Dictionary = s.entries.get(str(row.id), {}) if mind.memory_enabled else {}
		if tick < int(entry.get("retry_tick", 0)): continue
		var known: Dictionary = s.types.get(row.category, {}) if mind.memory_enabled else {}
		var n := novelty(mind, row, tick)
		var risk := maxf(0.0, -float(known.get("value", 0.0))) * float(known.get("confidence", 0.0))
		var t: Dictionary = mind.traits(creature)
		var curiosity := float(t.curiosity) if s.curiosity_enabled else 0.0
		var score := n * curiosity - risk * float(t.caution)
		if mind.affect_enabled and mind.policy_mode == "full":
			var a: Dictionary = mind.affect.values
			# Boredom is a derived gap in stimulation, not an invented bodily event.
			var boredom: float = creature.personality.boredom if creature.personality != null else 0.0
			score *= 1.0 + float(a.entusiasmo) * 0.8 + boredom * 0.2
			score -= float(a.receio) * (0.4 + float(t.caution))
		if score > float(best.score): best = {"score": score, "id": int(row.id), "novelty": n, "risk": risk}
	return best

static func observe(mind, sensors: Dictionary, tick: int) -> void:
	if not mind.memory_enabled: return
	var s := state(mind)
	for key in s.cooldowns.keys():
		if tick >= int(s.cooldowns[key]): s.cooldowns.erase(key)
	for key in s.entries.keys():
		if tick > int(s.entries[key].valid_until): s.entries.erase(key)
	for category in s.types.keys():
		if tick - int(s.types[category].tick) > TTL: s.types.erase(category)
	for row in sensors.get("objects", []):
		var key := str(row.id)
		if not s.types.has(row.category):
			s.types[row.category] = {"value": 0.0, "confidence": 0.0, "tick": tick, "evidence_tick": 0, "familiarity": 0.0, "samples": 0, "source": "observado"}
		var category: Dictionary = s.types[row.category]
		if category.source == "interagido" and tick - int(category.evidence_tick) > TTL:
			category.value = 0.0
			category.confidence = 0.0
			category.samples = 0
			category.source = "observado"
		category.familiarity = minf(12.0, float(category.familiarity) + 0.004)
		category.tick = tick
		if not s.entries.has(key):
			if s.entries.size() >= LIMIT: s.entries.erase(s.entries.keys()[0])
			s.entries[key] = {"category": row.category, "source": "observado", "confidence": 0.35, "tick": tick, "evidence_tick": 0, "valid_until": tick + TTL, "familiarity": 0.0, "retry_tick": 0, "hypothesis": 0.0, "evidence": {}}
		var e: Dictionary = s.entries[key]
		if e.source == "interagido" and tick - int(e.evidence_tick) > TTL:
			e.source = "observado"
			e.evidence = {}
			e.confidence = 0.35
		e.tick = tick
		e.valid_until = tick + TTL
		e.familiarity = minf(12.0, float(e.familiarity) + 0.008)
		# Seeing never writes value/evidence. Category expectation stays a hypothesis.
		e.hypothesis = float(s.types.get(row.category, {}).get("value", 0.0))

static func interacted(mind, row: Dictionary, tick: int, evidence: Dictionary) -> void:
	var s := state(mind)
	if s.cooldowns.size() >= LIMIT: s.cooldowns.erase(s.cooldowns.keys()[0])
	s.cooldowns[str(row.id)] = tick + 180
	if not mind.memory_enabled: return
	observe(mind, {"objects": [row]}, tick)
	var e: Dictionary = s.entries[str(row.id)]
	e.source = "interagido"
	e.confidence = 1.0
	e.evidence = evidence.duplicate(true)
	e.evidence_tick = tick
	e.familiarity = minf(12.0, float(e.familiarity) + 1.0)
	e.retry_tick = tick + 180
	var known: Dictionary = s.types[row.category]
	# Only measured body deltas may teach value. Never apply learned value to body.
	var value := clampf((float(evidence.energy) + float(evidence.hydration)) / 6.0 - float(evidence.toxicity) * 4.0, -1.0, 1.0)
	known.value = snappedf(lerpf(float(known.value), value, 0.6), 0.000001)
	known.confidence = minf(1.0, float(known.confidence) + 0.25)
	known.familiarity = minf(12.0, float(known.familiarity) + 0.8)
	known.samples = mini(10000, int(known.samples) + 1)
	known.tick = tick
	known.evidence_tick = tick
	known.source = "interagido"
	s.types[row.category] = known

static func valid(s: Variant, max_tick: int) -> bool:
	if not s is Dictionary: return false
	if s.is_empty(): return true
	if s.size() != 5 or not s.get("entries") is Dictionary or s.entries.size() > LIMIT or not s.get("types") is Dictionary or s.types.size() > CATEGORIES.size() or not Data.integer(s.get("target")) or not s.get("curiosity_enabled") is bool or not s.get("cooldowns") is Dictionary or s.cooldowns.size() > LIMIT: return false
	for key in s.cooldowns:
		if not Data.integer_text(key) or int(key) <= 0 or not Data.integer(s.cooldowns[key]) or int(s.cooldowns[key]) > max_tick + 180: return false
	for key in s.entries:
		var e = s.entries[key]
		if not Data.integer_text(key) or int(key) <= 0 or not e is Dictionary or e.size() != 10 or e.get("category") not in CATEGORIES or e.get("source") not in ["observado", "interagido"]: return false
		for field in ["tick", "valid_until", "retry_tick"]:
			if not Data.integer(e.get(field)) or int(e[field]) > max_tick + TTL: return false
		if int(e.tick) > max_tick or int(e.valid_until) < int(e.tick): return false
		if not Data.integer(e.get("evidence_tick")) or int(e.evidence_tick) > int(e.tick): return false
		for field in ["confidence", "familiarity", "hypothesis"]:
			if not Data.number(e.get(field)) or absf(float(e[field])) > (12.0 if field == "familiarity" else 1.0): return false
		if float(e.confidence) < 0.0 or float(e.familiarity) < 0.0 or not e.get("evidence") is Dictionary: return false
		if e.source == "observado" and not e.evidence.is_empty(): return false
		if e.source == "interagido":
			if e.evidence.size() != 4 or float(e.confidence) != 1.0: return false
			for field in ["energy", "hydration", "toxicity", "surprise"]:
				if not Data.number(e.evidence.get(field)) or absf(float(e.evidence[field])) > 10.0: return false
			for field in ["toxicity", "surprise"]:
				if float(e.evidence[field]) < 0.0 or float(e.evidence[field]) > 1.0: return false
	for category in s.types:
		var k = s.types[category]
		if category not in CATEGORIES or not k is Dictionary or k.size() != 7 or not Data.integer(k.get("tick")) or int(k.tick) > max_tick or not Data.integer(k.get("evidence_tick")) or int(k.evidence_tick) > int(k.tick) or not Data.integer(k.get("samples")) or int(k.samples) > 10000 or k.get("source") not in ["observado", "interagido"]: return false
		if k.source == "observado" and (float(k.get("value", 0.0)) != 0.0 or float(k.get("confidence", 0.0)) != 0.0 or int(k.samples) != 0): return false
		for field in ["value", "confidence", "familiarity"]:
			if not Data.number(k.get(field)) or absf(float(k[field])) > (12.0 if field == "familiarity" else 1.0): return false
		if float(k.confidence) < 0.0 or float(k.familiarity) < 0.0: return false
		if k.source == "interagido" and (int(k.samples) == 0 or float(k.confidence) <= 0.0): return false
	return true
