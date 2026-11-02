extends RefCounted
const World = preload("res://scripts/world/sim_world.gd")
const Genes = preload("res://scripts/creature/genome.gd")
const Creature = preload("res://scripts/creature/sim_creature.gd")
const Genealogy = preload("res://scripts/evolution/genealogy.gd")
const Inheritance = preload("res://scripts/evolution/inheritance.gd")
const Store = preload("res://scripts/persistence/save_store.gd")
const Text = preload("res://scripts/core/textos.gd")
const Atelier = preload("res://scripts/atelier/atelier.gd")
const TerminalLearning = preload("res://scripts/mind/terminal_learning.gd")
const Knowledge = preload("res://scripts/library/knowledge.gd")

func check(ok: bool, message: String, failures: Array) -> void:
	if not ok: failures.append(message)

func studio(seed_value: int = 155001, voluntary: bool = true) -> Object:
	var w = World.new(seed_value, {
		"creature_count": 0, "food_count": 0, "water_count": 0, "obstacle_count": 0,
		"food_regrow": false, "reproduction_enabled": true, "personality_enabled": true, "water_enabled": true,
		"reproduction_voluntary": voluntary, "reproduction_min_familiarity": 0.12,
		"reproduction_compatibility_threshold": 0.5, "mind_offspring": false
	})
	return w

func spawn_actor(w: Object, pos: Vector2, name: String, size_val: float = 8.0) -> Creature:
	var g := Genes.new()
	g.size = size_val
	g.speed = 32.0
	g.vision_range = 220.0
	g.vision_fov = snappedf(TAU, 0.000001)
	g.temperament = {"curiosity": 0.5, "caution": 0.3, "sociability": 0.5, "impulsivity": 0.4}
	var cid: int = w.spawn_creature(pos, name, g)
	var c: Creature = w.creatures[cid]
	c.energy = c.max_energy
	c.hydration = 90.0
	c.age = w.min_reproduction_age + 10
	c.reproduction_cooldown = 0
	return c

func run() -> Array:
	var f: Array = []
	_voluntary_reproduction_conditions(f)
	_non_inheritance_explicit(f)
	_offspring_mind_activation(f)
	_genealogy_and_save_v14(f)
	_convivencia_f7(f)
	_legacy_compatibility(f)
	_ui_texts(f)
	return f

func _voluntary_reproduction_conditions(f: Array) -> void:
	var w = studio(155010, true)
	var p1 = spawn_actor(w, Vector2(300, 300), "P1", 8.0)
	var p2 = spawn_actor(w, Vector2(310, 300), "P2", 8.0)
	w.enable_mind(p1.id)
	w.enable_mind(p2.id)

	# Initially no bonds: unfamiliar
	var check_res: Dictionary = w.can_reproduce(p1.id, p2.id)
	check(not check_res.allowed and check_res.reason == "self_unfamiliar_with_partner", "permitiu reproducao sem familiaridade", f)

	# Set up familiarity and positive valence
	p1.personality.bonds[str(p2.id)] = {"count": 1, "familiarity": 0.35, "valence": 0.4, "last_tick": w.tick}
	p2.personality.bonds[str(p1.id)] = {"count": 1, "familiarity": 0.35, "valence": 0.4, "last_tick": w.tick}

	check_res = w.can_reproduce(p1.id, p2.id)
	check(check_res.allowed and check_res.reason == "consent_granted", "recusou com condicoes perfeitas: " + check_res.reason, f)

	# 1. Energy
	var old_e: float = p1.energy
	p1.energy = p1.max_energy * 0.7
	check(not w.can_reproduce(p1.id, p2.id).allowed, "energia insuficiente permitida", f)
	p1.energy = old_e

	# 2. Critical thirst (parent)
	p1.hydration = 35.0
	check_res = w.can_reproduce(p1.id, p2.id)
	check(not check_res.allowed and check_res.reason == "parent_critical_thirst", "sede critica permitida", f)
	p1.hydration = 90.0

	# 3. Partner low energy
	var old_p2_e: float = p2.energy
	p2.energy = p2.max_energy * 0.2
	check_res = w.can_reproduce(p1.id, p2.id)
	check(not check_res.allowed and check_res.reason == "partner_low_energy", "parceiro sem energia permitida", f)
	p2.energy = old_p2_e

	# 4. Critical hunger (partner has enough energy > 35%, but hunger > 0.55)
	p2.energy = p2.max_energy * 0.40
	check_res = w.can_reproduce(p1.id, p2.id)
	check(not check_res.allowed and check_res.reason == "partner_critical_hunger", "parceiro fome critica permitida", f)
	p2.energy = old_p2_e

	# 5. Critical thirst (partner)
	p2.hydration = 35.0
	check_res = w.can_reproduce(p1.id, p2.id)
	check(not check_res.allowed and check_res.reason == "partner_critical_thirst", "parceiro sede critica permitida", f)
	p2.hydration = 90.0

	# 6. Aversion
	p1.personality.bonds[str(p2.id)].valence = -0.4
	check_res = w.can_reproduce(p1.id, p2.id)
	check(not check_res.allowed and check_res.reason == "self_aversion_to_partner", "aversao propria permitida", f)
	p1.personality.bonds[str(p2.id)].valence = 0.4

	p2.personality.bonds[str(p1.id)].valence = -0.3
	check_res = w.can_reproduce(p1.id, p2.id)
	check(not check_res.allowed and check_res.reason == "partner_aversion_to_self", "aversao do parceiro permitida", f)
	p2.personality.bonds[str(p1.id)].valence = 0.4

	# 6. Affective states: Frustracao
	p1.mind.affect.values.frustracao = 0.50
	check_res = w.can_reproduce(p1.id, p2.id)
	check(not check_res.allowed and check_res.reason == "self_affect_frustrated", "frustracao alta permitida", f)
	p1.mind.affect.values.frustracao = 0.1

	# 7. Affective states: Receio / Fear
	p2.mind.affect.values.receio = 0.45
	check_res = w.can_reproduce(p1.id, p2.id)
	check(not check_res.allowed and check_res.reason == "partner_affect_fear", "receio alto permitida", f)
	p2.mind.affect.values.receio = 0.05

	# 8. Affective states: Saturacao social
	p1.mind.affect.values.saturacao_social = 0.70
	check_res = w.can_reproduce(p1.id, p2.id)
	check(not check_res.allowed and check_res.reason == "self_affect_saturated", "saturacao social permitida", f)
	p1.mind.affect.values.saturacao_social = 0.1

	# 9. Incompatible genomes (size discrepancy)
	p2.genome.size = 20.0 # diff is 12, compat is clamp(1.0 - 1.2) = 0.0 < 0.5
	check_res = w.can_reproduce(p1.id, p2.id)
	check(not check_res.allowed and check_res.reason == "incompatible_genomes", "genomas incompativeis permitidos", f)
	p2.genome.size = 8.0

	# 10. Partner too far away
	p2.pos = Vector2(800, 800)
	check_res = w.can_reproduce(p1.id)
	check(not check_res.allowed and check_res.reason == "no_partner_nearby", "parceiro distante encontrado", f)
	p2.pos = Vector2(310, 300)

	# Execute reproduction
	var child_id: int = w.reproduce(p1.id, p2.id)
	check(child_id > 0, "reproducao consentida falhou", f)
	if child_id > 0:
		var child: Creature = w.creatures[child_id]
		check(child.genome.parents == [p1.id, p2.id], "filhote sem registro de ambos genitores", f)
		check(p1.reproduction_cooldown > 0 and p2.reproduction_cooldown > 0, "cooldown nao aplicado aos genitores", f)

func _non_inheritance_explicit(f: Array) -> void:
	var w = studio(155020, true)
	w.mind_offspring = true
	var p1 = spawn_actor(w, Vector2(300, 300), "P1", 8.0)
	var p2 = spawn_actor(w, Vector2(310, 300), "P2", 8.0)
	w.enable_mind(p1.id)
	w.enable_mind(p2.id)

	# Populate parent 1 with extensive acquired states
	p1.personality.bonds[str(p2.id)] = {"count": 1, "familiarity": 0.8, "valence": 0.6, "last_tick": w.tick}
	p2.personality.bonds[str(p1.id)] = {"count": 1, "familiarity": 0.8, "valence": 0.6, "last_tick": w.tick}
	p1.personality.episodes.append({"tick": 10, "kind": "contact", "valence": 0.5})
	p1.personality.preferences["food_mushroom"] = 0.9
	p1.personality.conditioning["water"] = 0.7

	# Populate mind knowledge & reading
	Knowledge.add(p1.mind, {"pedra": 0.0}, "observado", 0.8, 15)
	p1.mind.knowledge.reading = {"id": 1, "book_id": "guia", "page": 3}
	p1.mind.experiences.append({"tick": 12, "kind": "visual", "source": 0})

	# Populate terminal state
	p1.mind.terminal = TerminalLearning.empty()
	p1.mind.terminal.state.conhecidos["MOVER"] = "manual"
	p1.mind.terminal.state.tentativas.append({"program": "MOVER LESTE 1", "tick": 15, "success": true})
	p1.mind.terminal.outcomes.append({"action": "mover", "success": true})

	# Populate atelier drawings
	if p1.atelier != null:
		p1.atelier.drawings.append({"id": 99, "strokes": []})

	# Reproduce
	var child_id: int = w.reproduce(p1.id, p2.id)
	check(child_id > 0, "reproducao falhou para teste de nao-heranca", f)
	if child_id <= 0: return

	var child: Creature = w.creatures[child_id]

	# Positive inheritance:
	check(child.genome.parents == [p1.id, p2.id], "pais nao herdados", f)
	check(child.genome.temperament.has("curiosity"), "temperamento nao herdado", f)
	var temp_diff: float = absf(child.genome.temperament.curiosity - p1.genome.temperament.curiosity)
	check(temp_diff <= 0.35, "mutacao de temperamento excedeu limites gaussianos", f)

	# STRICT NON-INHERITANCE CHECKS:
	check(child.personality.episodes.is_empty(), "filhote herdou episodios de memoria", f)
	check(child.personality.bonds.is_empty(), "filhote herdou vinculos sociais", f)
	check(child.personality.preferences.is_empty(), "filhote herdou preferencias", f)
	check(child.personality.conditioning.is_empty(), "filhote herdou condicionamento", f)
	check(child.mind.experiences.is_empty(), "filhote herdou experiencias mentais", f)
	check(child.mind.knowledge.is_empty(), "filhote herdou fatos da biblioteca/conhecimento", f)
	check(child.mind.knowledge.get("reading", {}).is_empty(), "filhote herdou estado de leitura", f)
	check(child.mind.terminal.is_empty(), "filhote herdou comandos/historico de terminal", f)
	if child.atelier != null:
		check(child.atelier.drawings.is_empty(), "filhote herdou habilidades/desenhos do atelier", f)

func _offspring_mind_activation(f: Array) -> void:
	var w = studio(155030, true)
	w.mind_offspring = false
	w.mind_all = false

	var p1 = spawn_actor(w, Vector2(300, 300), "P1", 8.0)
	var p2 = spawn_actor(w, Vector2(310, 300), "P2", 8.0)
	p1.personality.bonds[str(p2.id)] = {"count": 1, "familiarity": 0.5, "valence": 0.5, "last_tick": w.tick}
	p2.personality.bonds[str(p1.id)] = {"count": 1, "familiarity": 0.5, "valence": 0.5, "last_tick": w.tick}

	var c1_id: int = w.reproduce(p1.id, p2.id)
	check(c1_id > 0, "c1 falhou", f)
	if c1_id > 0:
		check(w.creatures[c1_id].mind == null, "filhote ganhou mente quando desativado", f)

	# Now enable mind_offspring
	w.mind_offspring = true
	p1.reproduction_cooldown = 0
	p2.reproduction_cooldown = 0
	p1.energy = p1.max_energy
	p2.energy = p2.max_energy

	var c2_id: int = w.reproduce(p1.id, p2.id)
	check(c2_id > 0, "c2 falhou", f)
	if c2_id > 0:
		check(w.creatures[c2_id].mind != null, "filhote nao ganhou mente quando mind_offspring ativo", f)

func _genealogy_and_save_v14(f: Array) -> void:
	var w = studio(155040, true)
	w.mind_offspring = true
	var p1 = spawn_actor(w, Vector2(300, 300), "P1", 8.0)
	var p2 = spawn_actor(w, Vector2(310, 300), "P2", 8.0)
	p1.personality.bonds[str(p2.id)] = {"count": 1, "familiarity": 0.5, "valence": 0.5, "last_tick": w.tick}
	p2.personality.bonds[str(p1.id)] = {"count": 1, "familiarity": 0.5, "valence": 0.5, "last_tick": w.tick}
	var child_id: int = w.reproduce(p1.id, p2.id)
	check(child_id > 0, "reproducao para save v14 falhou", f)

	# Roundtrip test
	var dict_v14: Dictionary = w.to_dict()
	check(dict_v14.get("save_version") == World.SAVE_VERSION, "versao do save nao e a atual", f)
	check(dict_v14.has("reproduction_rules"), "save v14 sem reproduction_rules", f)

	var restored = World.from_dict(dict_v14)
	check(restored != null, "from_dict falhou para save v14", f)
	if restored != null:
		check(restored.reproduction_voluntary == true, "reproduction_voluntary nao restaurado", f)
		check(restored.mind_offspring == true, "mind_offspring nao restaurado", f)
		check(restored.genealogy.records.has(child_id), "genealogia do filhote nao encontrada", f)
		var rec = restored.genealogy.records[child_id]
		check(rec.parents == [p1.id, p2.id], "pais na genealogia restaurada incorretos", f)

	# Migration chain v13 -> v14
	var legacy_v13 = dict_v14.duplicate(true)
	legacy_v13.save_version = 13
	legacy_v13.erase("reproduction_rules")
	var mig13 = World._migrate_v13(legacy_v13)
	check(mig13.get("save_version") == 14, "migrate_v13 falhou", f)
	check(World._migrate_v13(World._migrate_v13(legacy_v13)) == mig13, "migrate_v13 nao idempotente", f)

	# Hostile save verification
	var bad: Dictionary
	for hostile_kind in ["nan_fam", "nan_compat", "bad_rule_type", "future_data_in_v13", "dup_id", "illegal_parents"]:
		bad = dict_v14.duplicate(true)
		match hostile_kind:
			"nan_fam":
				bad.reproduction_rules.min_familiarity = NAN
			"nan_compat":
				bad.reproduction_rules.compatibility_threshold = NAN
			"bad_rule_type":
				bad.reproduction_rules.voluntary = "true"
			"future_data_in_v13":
				bad.save_version = 13
				# v13 cannot have reproduction_rules
			"dup_id":
				# Duplicate child id in waters
				bad.waters.append({"id": child_id, "pos": [300.0, 300.0], "radius": 20.0})
			"illegal_parents":
				# Genealogy parents with self-reference
				for entry in bad.genealogy:
					if int(entry.creature_id) == child_id:
						entry.parents = [child_id, p1.id]
		check(World.from_dict(bad) == null, "save hostil aceito: " + hostile_kind, f)

func _convivencia_f7(f: Array) -> void:
	var w = studio(155050, true)
	w.mind_all = true
	var a = spawn_actor(w, Vector2(300, 300), "A", 8.0)
	var b = spawn_actor(w, Vector2(300, 240), "B", 8.0) # North, dist 60
	var c = spawn_actor(w, Vector2(300, 360), "C", 8.0) # South, dist 60
	w.enable_mind(a.id)
	w.enable_mind(b.id)
	w.enable_mind(c.id)

	# Encounter history: B is positive friend, C is hostile/averse
	a.personality.bonds[str(b.id)] = {"count": 1, "familiarity": 0.8, "valence": 0.8, "last_tick": w.tick}
	a.personality.bonds[str(c.id)] = {"count": 1, "familiarity": 0.8, "valence": -0.8, "last_tick": w.tick}

	# In seeking company ("buscar_companhia"), A should prefer B over C
	a.mind.set_goal("buscar_companhia", w.tick, "test")
	w.step()
	check(a.pos.y < 300.0, "buscar_companhia nao aproximou do parceiro positivo B", f)

	# Reset positions
	a.pos = Vector2(300, 300)
	# In seeking privacy ("buscar_privacidade"), A should move away from negative C (towards North / away from C)
	a.mind.set_goal("buscar_privacidade", w.tick, "test")
	w.step()
	check(a.pos.y < 300.0, "buscar_privacidade nao afastou do ameacador C", f)

	# Ablation: sem_memoria (clear bonds)
	var w_abl = studio(155051, true)
	w_abl.mind_all = true
	var a_abl = spawn_actor(w_abl, Vector2(300, 300), "A", 8.0)
	var b_abl = spawn_actor(w_abl, Vector2(300, 240), "B", 8.0)
	var c_abl = spawn_actor(w_abl, Vector2(300, 360), "C", 8.0)
	w_abl.enable_mind(a_abl.id)
	w_abl.enable_mind(b_abl.id)
	w_abl.enable_mind(c_abl.id)
	a_abl.personality.bonds.clear()

	# Without memory/bonds, scores for equidistant peers are purely symmetric
	a_abl.mind.set_goal("buscar_companhia", w_abl.tick, "test")
	w_abl.step()
	# Movement occurred without preferential valence bias
	check(a_abl.pos != Vector2(300, 300), "movimento sem memoria falhou", f)

func _legacy_compatibility(f: Array) -> void:
	var w = studio(155060, false) # voluntary = false
	var parent = spawn_actor(w, Vector2(300, 300), "Genitor", 8.0)
	parent.energy = parent.max_energy
	parent.age = w.min_reproduction_age + 5

	var child_id: int = w.reproduce(parent.id)
	check(child_id > 0, "reproducao assexuada legada falhou no modo retrocompativel", f)
	if child_id > 0:
		var child: Creature = w.creatures[child_id]
		check(child.genome.parents == [parent.id], "filhote legado sem pai unico", f)

func _ui_texts(f: Array) -> void:
	# Verify that all M5 UI keys return valid non-empty strings with 'parece' and never 'sente'
	for key in [
		"ui.m5.reproduction.voluntary", "ui.m5.reproduction.consent_ok", "ui.m5.reproduction.refused_hunger",
		"ui.m5.reproduction.refused_thirst", "ui.m5.reproduction.refused_unfamiliar", "ui.m5.reproduction.refused_aversion",
		"ui.m5.reproduction.refused_frustration", "ui.m5.reproduction.refused_fear", "ui.m5.reproduction.refused_saturation",
		"ui.m5.reproduction.refused_incompatible", "ui.m5.inheritance.genome_ok", "ui.m5.inheritance.temperament_ok",
		"ui.m5.inheritance.memory_isolated", "ui.m5.inheritance.culture_isolated", "ui.m5.convivencia.attitude_differentiated"
	]:
		var msg := Text.texto(key)
		check(not msg.is_empty(), "chave de texto ausente: " + key, f)
		check(not msg.contains("sente") and not msg.contains("Sente"), "texto violou proibicao de 'sente': " + msg, f)
