extends RefCounted
const Fixture = preload("res://tests/unit/test_sim_m1.gd")
const Mind = preload("res://scripts/mind/creature_mind.gd")
const Motivation = preload("res://scripts/mind/motivation.gd")

func run() -> Array:
	var f: Array = []
	var helper = Fixture.new()
	var w = helper.garden(93601)
	var pet = helper.body(w)
	var peer = helper.body(w, Vector2(120, 100))
	w.enable_mind(pet.id)
	w._rebuild_spatial()
	var sensors: Dictionary = w.sense(pet)
	pet.energy = pet.max_energy * 0.95
	pet.hydration = 100.0
	# Unit interventions isolate threshold changes from retrieval and from RNG.
	var physical := [pet.pos, pet.energy, pet.hydration]
	pet.mind.affect.values.solidao = 1.0
	if pet.mind.decide(pet, 0, sensors) != "buscar_companhia": f.append("solidao nao ativa companhia")
	pet.mind.objetivo_atual = ""
	pet.mind.affect.values.solidao = 0.0
	pet.mind.affect.values.saturacao_social = 1.0
	if pet.mind.decide(pet, 1, sensors) != "buscar_privacidade": f.append("saturacao nao ativa privacidade")
	pet.mind.objetivo_atual = ""
	pet.mind.affect.values.saturacao_social = 0.0
	pet.mind.affect.values.receio = 1.0
	if pet.mind.decide(pet, 2, sensors) != "buscar_privacidade": f.append("receio nao evita contato")
	pet.mind.objetivo_atual = ""
	if pet.mind.decide(pet, 3, {"creatures": []}) != "descansar": f.append("receio sem vizinho nao aumenta cautela")
	pet.mind.affect.values.receio = 0.0
	pet.mind.affect.values.satisfacao = 1.0
	pet.mind.objetivo_atual = ""
	if pet.mind.decide(pet, 4, sensors) == "explorar": f.append("satisfacao nao reduz exploracao")
	if physical != [pet.pos, pet.energy, pet.hydration]: f.append("modulacao escreveu no corpo")
	pet.mind.affect.values.frustracao = 1.0
	pet.mind.blocked_ticks = 5
	pet.mind.objetivo_atual = "explorar"
	pet.mind.goal_started = 5
	var on := Motivation.modulation(pet.mind)
	if on.minimum >= 12 or on.maximum >= 80 or not on.release_blocked: f.append("frustracao nao reduz persistencia bloqueada")
	if pet.mind.decide(pet, 5, sensors) == "explorar": f.append("frustracao nao troca estrategia bloqueada")
	pet.mind.objetivo_atual = "explorar"
	pet.mind.goal_started = 6
	pet.mind.affect_enabled = false
	var off := Motivation.modulation(pet.mind)
	if off.minimum != 12 or off.maximum != 80 or off.release_blocked or off.hysteresis != 0.08: f.append("ablacao conserva limiar afetivo")
	if pet.mind.decide(pet, 6, sensors) != "explorar": f.append("sem afeto rompe compromisso por contador de bloqueio")
	pet.mind.affect_enabled = true
	pet.energy = pet.max_energy * 0.1
	if pet.mind.decide(pet, 7, sensors) != "comer": f.append("frustracao sobrepoe fome critica")
	pet.energy = pet.max_energy
	pet.hydration = 5.0
	if pet.mind.decide(pet, 8, sensors) != "beber": f.append("afeto sobrepoe sede critica")
	pet.mind.remember(8, "contact", -0.8, 0.9, peer.id)
	var bias: float = pet.mind.memory_bias("buscar_companhia", 8, sensors)
	pet.mind.affect_enabled = false
	if pet.mind.memory_bias("buscar_companhia", 8, sensors) != bias: f.append("afeto mudou recuperacao de memoria")
	pet.mind.affect_enabled = true
	var thresholds: Dictionary = Motivation.modulation(pet.mind)
	pet.mind.memory_enabled = false
	if Motivation.modulation(pet.mind) != thresholds: f.append("ablacao de memoria mudou limiares afetivos")
	if pet.mind.memory_bias("buscar_companhia", 8, sensors) != 0.0: f.append("ablacao de memoria manteve vies")
	# Old v8 schema remains identical and accepts old states; no migration needed.
	var saved: Dictionary = pet.mind.to_dict()
	var loaded = Mind.from_dict(JSON.parse_string(JSON.stringify(saved, "", true, true)), 8)
	if loaded == null or loaded.to_dict() != saved: f.append("v8 perdeu continuacao dos limiares derivados")
	return f
