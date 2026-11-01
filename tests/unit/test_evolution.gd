extends RefCounted
const World = preload("res://scripts/world/sim_world.gd")
const Genes = preload("res://scripts/creature/genome.gd")
const Inheritance = preload("res://scripts/evolution/inheritance.gd")
const Rng = preload("res://scripts/core/sim_rng.gd")
const Store = preload("res://scripts/persistence/save_store.gd")
const Q = preload("res://scripts/behavior/q_brain.gd")
const Obs = preload("res://scripts/behavior/observation.gd")
const Actions = preload("res://scripts/behavior/actions.gd")
const Text = preload("res://scripts/core/textos.gd")

func run() -> Array:
	var failures: Array = []
	_eligibility_and_energy(failures)
	_brain_reproduction(failures)
	_inheritance(failures)
	_generations_and_saves(failures)
	_population_and_death(failures)
	_phenotype(failures)
	_migration(failures)
	_bad_ancestry(failures)
	return failures

func _config() -> Dictionary:
	return {"creature_count": 0, "food_count": 0, "obstacle_count": 0, "food_regrow": false,
		"min_reproduction_age": 5, "reproduction_cooldown": 10, "max_population": 30}

func _check(value: bool, description: String, failures: Array) -> void:
	if not value: failures.append(description)

func _snapshot(world) -> String:
	return JSON.stringify(world.to_dict(), "", true, true)

func _eligibility_and_energy(failures: Array) -> void:
	var world := World.new(551, _config())
	var parent = world.creatures[world.spawn_creature(Vector2(300, 300), "Genitor", Genes.new())]
	parent.energy = parent.max_energy
	_check(world.reproduce(parent.id) == -1, "Um recém-nascido se reproduziu", failures)
	parent.age = world.min_reproduction_age
	parent.energy = parent.max_energy * 0.89
	_check(world.reproduce(parent.id) == -1, "Reprodução sem energia mínima", failures)
	parent.energy = parent.max_energy
	var before: float = parent.energy
	var child_id := world.reproduce(parent.id)
	_check(child_id != -1, "Reprodução elegível falhou", failures)
	if child_id == -1: return
	var child = world.creatures[child_id]
	_check(child.id != parent.id and child.genome.id != parent.genome.id and child.genome.id != child.id, "Filhote sem IDs próprios", failures)
	_check(is_equal_approx(before, parent.energy + child.energy), "Reprodução criou ou perdeu energia na transferência", failures)
	_check(child.genome.parents == [parent.id] and child.genome.generation == 1 and child.age == 0, "Identidade hereditária inválida", failures)
	parent.energy = parent.max_energy
	_check(world.reproduce(parent.id) == -1, "Cooldown ignorado", failures)
	world.reproduction_enabled = false
	for i in range(world.reproduction_cooldown): world.step()
	_check(parent.reproduction_cooldown == 0, "Cooldown não avançou com os passos", failures)
	world.reproduction_enabled = true
	parent.energy = parent.max_energy
	_check(world.reproduce(parent.id) != -1, "Reprodução continuou bloqueada após cooldown", failures)
	parent.reproduction_cooldown = 0
	parent.alive = false
	_check(world.reproduce(parent.id) == -1, "Organismo morto se reproduziu", failures)
	world.step()
	_check(not world.creatures.has(parent.id) and world.reproduce(parent.id) == -1, "Organismo morto ressurgiu", failures)
	_check(Text.razao("evolution.age") == Text.texto("reason_age") and Text.razao("evolution.external") == Text.texto("reason_external"), "Razões de morte sem tradução", failures)

func _brain_reproduction(failures: Array) -> void:
	var world := World.new(900, _config())
	var parent = world.creatures[world.spawn_creature(Vector2(300, 300), "Aprendiz", Genes.new())]
	var brain := Q.new()
	brain.epsilon_start = 0.0
	brain.epsilon_min = 0.0
	brain.q[Obs.state_index(0, 2, false) * Actions.COUNT + Actions.REST] = 1.0
	parent.brain = brain
	parent.age = world.min_reproduction_age - 1
	parent.energy = parent.max_energy
	var before: float = parent.energy
	world.step()
	_check(world.creatures.size() == 2 and parent.brain == brain, "Reprodução não preservou o cérebro do genitor", failures)
	var actual_cost: float = before - parent.energy
	world.step()
	_check(is_equal_approx(brain.total_reward, -actual_cost), "Aprendizado não contabilizou o custo real da reprodução", failures)
	_check(brain.steps == 2, "Aprendizado parou após reprodução", failures)
	var restored := World.from_dict(JSON.parse_string(_snapshot(world)))
	_check(restored != null and _snapshot(restored) == _snapshot(world), "Cérebro e filhote não persistiram juntos", failures)
	if restored != null:
		parent.energy = parent.max_energy
		parent.reproduction_cooldown = 0
		restored.creatures[parent.id].energy = parent.max_energy
		restored.creatures[parent.id].reproduction_cooldown = 0
		var original_child := world.reproduce(parent.id)
		var restored_child := restored.reproduce(parent.id)
		_check(original_child != -1 and original_child == restored_child and _snapshot(world) == _snapshot(restored), "Próxima mutação ou ID divergiu após carregar", failures)

func _inheritance(failures: Array) -> void:
	var parent := Genes.new()
	parent.id = 1
	var unchanged: Dictionary = Inheritance.inherit(parent, 2, Rng.new(7), 0.0, 0.025)
	for gene in Genes.BOUNDS:
		_check(unchanged.genome.get(gene) == parent.get(gene), "Gene não herdado sem mutação: " + gene, failures)
	_check(unchanged.mutations.is_empty(), "Mutações inventadas com taxa zero", failures)
	var rng := Rng.new(712)
	var positive := false
	var negative := false
	for i in range(250):
		# Exercise both physical bounds as well as interior values.
		if i % 3 != 0:
			for gene in Genes.BOUNDS: parent.set(gene, Genes.BOUNDS[gene][0 if i % 3 == 1 else 1])
		else: parent = Genes.new()
		parent.bound_genes()
		var inherited: Dictionary = Inheritance.inherit(parent, 2, rng, 1.0, 0.025)
		var restored := Genes.from_dict(JSON.parse_string(JSON.stringify(inherited.genome.to_dict())))
		_check(restored != null and restored.to_dict() == inherited.genome.to_dict(), "Mutação nos bounds não fez round-trip", failures)
		var logged: Dictionary = {}
		for mutation in inherited.mutations:
			logged[mutation.gene] = mutation.delta
			positive = positive or mutation.delta > 0.0
			negative = negative or mutation.delta < 0.0
		for gene in Genes.BOUNDS:
			var value: float = inherited.genome.get(gene)
			var delta := snappedf(value - float(parent.get(gene)), 0.000001)
			var span: float = Genes.BOUNDS[gene][1] - Genes.BOUNDS[gene][0]
			_check(value >= Genes.BOUNDS[gene][0] and value <= Genes.BOUNDS[gene][1], "Mutação fora dos bounds: " + gene, failures)
			_check(absf(delta) <= 3.0 * span * 0.025 + 0.000001, "Herança fora do delta máximo: " + gene, failures)
			_check(is_equal_approx(delta, float(logged.get(gene, 0.0))), "Delta não corresponde à mutação: " + gene, failures)
	_check(positive and negative, "Variação não apresentou ambos os sinais", failures)

## Controlled food injection proves ancestry across 3+ generations. It is not an
## adaptation experiment: food placement is explicit and energy enters as food.
func _fed_lineage(seed: int):
	var config := _config()
	config.merge({"min_reproduction_age": 8, "reproduction_cooldown": 15, "mutation_rate": 1.0}, true)
	var world := World.new(seed, config)
	world.spawn_creature(Vector2(300, 300), "Fundadora", Genes.new())
	for i in range(100):
		for creature in world.creatures.values():
			world.place_food(creature.pos + Vector2.from_angle(creature.heading) * 2.0)
		world.step()
	return world

func _generations_and_saves(failures: Array) -> void:
	var world = _fed_lineage(90210)
	var deepest := 0
	var deepest_id := -1
	for record in world.genealogy.records.values():
		if record.generation >= deepest:
			deepest = record.generation
			deepest_id = record.creature_id
	_check(deepest >= 3, "Não foram alcançadas três gerações descendentes", failures)
	var lineage: Array = world.lineage(deepest_id)
	_check(lineage.size() == deepest + 1, "Linhagem não conecta cada geração", failures)
	_check(world.descendants(lineage[0].creature_id).size() == world.genealogy.records.size() - 1, "Consulta de descendentes perdeu organismos", failures)
	var seen: Dictionary = {}
	for entry in lineage:
		_check(not seen.has(entry.creature_id), "Ciclo na genealogia", failures)
		seen[entry.creature_id] = true
		for parent in entry.parents: _check(int(parent) < int(entry.creature_id), "Ancestral posterior ao filho", failures)
	lineage[0]["name"] = "Alteração externa"
	_check(world.lineage(deepest_id)[0].name != "Alteração externa", "Consulta expôs escrita no histórico", failures)
	var mutation_events := 0
	for event in world.events:
		if event.type == "mutation": mutation_events += 1
	_check(mutation_events > 0, "Mutações ausentes dos eventos", failures)
	var encoded := _snapshot(world)
	var restored := World.from_dict(JSON.parse_string(encoded))
	_check(restored != null, "Save v2 com genealogia não carrega", failures)
	if restored == null: return
	_check(_snapshot(restored) == encoded, "Round-trip v2 alterou estado", failures)
	var default_json := World.from_dict(JSON.parse_string(JSON.stringify(world.to_dict())))
	_check(default_json != null and _snapshot(default_json) == encoded, "Precisão JSON padrão alterou genealogia", failures)
	for i in range(70):
		world.step()
		restored.step()
	_check(_snapshot(world) == _snapshot(restored), "Retomada de reprodução divergiu do save", failures)
	_check(_snapshot(_fed_lineage(90210)) == encoded, "Reprodução divergiu com a mesma semente", failures)
	_check(_snapshot(_fed_lineage(90211)) != encoded, "Sementes distintas não alteraram mutações", failures)
	var store := Store.new("user://tests_evolution")
	var saved := store.save_world(world, "lineage")
	var loaded := store.load_world("lineage")
	_check(saved.ok and loaded.ok and _snapshot(loaded.world) == _snapshot(world), "SaveStore perdeu a genealogia v2", failures)

func _population_and_death(failures: Array) -> void:
	var config := _config()
	config["max_population"] = 3
	config["max_age"] = 45
	var world := World.new(70, config)
	var founder = world.creatures[world.spawn_creature(Vector2(400, 400), "Origem", Genes.new())]
	founder.energy = founder.max_energy
	for i in range(150):
		var before := _energy(world)
		world.step()
		_check(_energy(world) <= before + 0.000001, "Energia aumentou sem consumo de recursos", failures)
		_check(world.creatures.size() <= 3, "População excedeu o limite", failures)
	_check(world.creatures.is_empty(), "Morte por idade não ocorreu", failures)
	_check(world.genealogy.records.size() == 2, "Crescimento sem recursos ou nascimento não registrado", failures)
	_check(world.lineage(founder.id).size() == 1 and world.descendants(founder.id).size() == 1, "Ancestrais mortos foram descartados", failures)
	var age_deaths := 0
	for event in world.events:
		if event.type == "death" and event.reason == "age": age_deaths += 1
	_check(age_deaths == 2, "Mortes por idade não registradas", failures)
	var restored := World.from_dict(JSON.parse_string(_snapshot(world)))
	_check(restored != null and _snapshot(restored) == _snapshot(world), "Mundo extinto perdeu o histórico no save", failures)
	var full := World.new(72, config)
	for i in range(3): full.spawn_creature(Vector2(300, 300))
	_check(full.spawn_creature(Vector2(300, 300)) == -1, "Introdução excedeu limite populacional", failures)
	var parent = full.creatures.values()[0]
	parent.age = 10
	parent.energy = parent.max_energy
	var before: float = parent.energy
	_check(full.reproduce(parent.id) == -1 and parent.energy == before, "Reprodução no limite consumiu energia", failures)

func _energy(world) -> float:
	var result := 0.0
	for creature in world.creatures.values(): result += creature.energy
	return result

func _body(genes):
	var config := _config()
	config["reproduction_enabled"] = false
	var world := World.new(44, config)
	var creature = world.creatures[world.spawn_creature(Vector2(300, 300), "Fenótipo", genes)]
	creature.energy = 50.0
	creature.age = 30
	creature.heading = 0.0
	return {"world": world, "creature": creature}

func _phenotype(failures: Array) -> void:
	var slow := Genes.new()
	var fast := Genes.new()
	slow.speed = 18.0
	fast.speed = 65.0
	var a: Dictionary = _body(slow)
	var b: Dictionary = _body(fast)
	a.world.step()
	b.world.step()
	_check(b.creature.pos.x > a.creature.pos.x and b.creature.energy < a.creature.energy, "Velocidade não alterou deslocamento e custo", failures)
	var small := Genes.new()
	var large := Genes.new()
	small.size = 6.0
	large.size = 16.0
	a = _body(small)
	b = _body(large)
	a.world.place_food(Vector2(320, 300))
	b.world.place_food(Vector2(320, 300))
	a.world.step()
	b.world.step()
	_check(a.creature.last_action == "seek_food" and b.creature.last_action == "eat" and b.creature.max_energy > a.creature.max_energy, "Tamanho não alterou alcance e capacidade", failures)
	var low := Genes.new()
	var high := Genes.new()
	low.metabolism = 0.5
	high.metabolism = 1.8
	a = _body(low)
	b = _body(high)
	a.world.step()
	b.world.step()
	_check(a.creature.energy > b.creature.energy, "Metabolismo não alterou gasto real", failures)
	low.vision_range = 45.0
	high.vision_range = 240.0
	a = _body(low)
	b = _body(high)
	a.world.place_food(Vector2(400, 300))
	b.world.place_food(Vector2(400, 300))
	_check(a.world.sense(a.creature).foods.is_empty() and b.world.sense(b.creature).foods.size() == 1, "Visão não alterou percepção", failures)
	var world := World.new(1, _config())
	world.spawn_creature(Vector2(300, 300), "Menor", small)
	world.spawn_creature(Vector2(400, 300), "Maior", large)
	_check(is_equal_approx(world.genetic_diversity().size, 25.0), "Variância por gene incorreta", failures)
	_check(world.genetic_diversity().speed == 0.0, "Gene constante apresentou diversidade", failures)

func _migration(failures: Array) -> void:
	var world := World.new(321, {"creature_count": 2})
	world.creatures[world.pet_id].brain = Q.new()
	for i in range(20): world.step()
	var old := world.to_dict()
	old["save_version"] = 1
	old.erase("genealogy")
	for key in World.EVOLUTION_DEFAULTS: old.config.erase(key)
	for entry in old.creatures: entry.erase("reproduction_cooldown")
	var restored := World.from_dict(JSON.parse_string(JSON.stringify(old)))
	_check(restored != null, "Save v1 não migrou", failures)
	if restored == null: return
	_check(restored.to_dict().save_version == World.SAVE_VERSION and restored.genealogy.records.size() == 2, "Migração não adicionou genealogia v2", failures)
	_check(restored.pet_id == world.pet_id and restored.rng.to_dict() == world.rng.to_dict(), "Migração alterou identidade ou RNG", failures)
	_check(restored.creatures[restored.pet_id].brain.to_dict() == world.creatures[world.pet_id].brain.to_dict(), "Migração perdeu aprendizado", failures)
	_check(_snapshot(restored) == _snapshot(world), "Migração alterou campos existentes", failures)
	# v1 permitted unverified parent/generation metadata. Keep it in the genome,
	# explicitly marking the reconstructed root instead of inventing ancestors.
	old.creatures[0].genome.parents = [old.creatures[0].id]
	old.creatures[0].genome.generation = 4
	restored = World.from_dict(old)
	_check(restored != null, "Migração recusou metadados de linhagem válidos no v1", failures)
	if restored != null:
		var creature_id: int = old.creatures[0].id
		_check(restored.creatures[creature_id].genome.parents == [creature_id] and restored.creatures[creature_id].genome.generation == 4, "Migração reescreveu metadados antigos", failures)
		_check(restored.lineage(creature_id).size() == 1 and restored.lineage(creature_id)[0].legacy_root, "Migração criou um ciclo com metadados não verificados", failures)
		_check(World.from_dict(JSON.parse_string(_snapshot(restored))) != null, "Raiz legada não persiste em v2", failures)

func _bad_ancestry(failures: Array) -> void:
	var world = _fed_lineage(8)
	var good: Dictionary = world.to_dict()
	var bad := good.duplicate(true)
	bad.genealogy[0].parents = [bad.genealogy[0].creature_id]
	bad.genealogy[0].genome.parents = bad.genealogy[0].parents.duplicate()
	_check(World.from_dict(bad) == null, "Ciclo genealógico aceito", failures)
	bad = good.duplicate(true)
	bad.genealogy[1].parents = [2147483646]
	bad.genealogy[1].genome.parents = bad.genealogy[1].parents.duplicate()
	_check(World.from_dict(bad) == null, "Genitor ausente aceito", failures)
	bad = good.duplicate(true)
	bad.genealogy[1].mutations[0].delta = 99999.0
	_check(World.from_dict(bad) == null, "Delta de mutação inválido aceito", failures)
	bad = good.duplicate(true)
	bad.genealogy[1].generation = 20
	bad.genealogy[1].genome.generation = 20
	_check(World.from_dict(bad) == null, "Geração inconsistente aceita", failures)
	bad = good.duplicate(true)
	bad.genealogy.pop_front()
	_check(World.from_dict(bad) == null, "Genealogia incompleta aceita", failures)
	for key in ["mutation_rate", "mutation_scale", "max_population", "max_age"]:
		bad = good.duplicate(true)
		bad.config[key] = -1
		_check(World.from_dict(bad) == null, "Configuração inválida aceita: " + key, failures)
