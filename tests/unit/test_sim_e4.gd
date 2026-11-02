extends RefCounted
const World = preload("res://scripts/world/sim_world.gd")
const D = preload("res://scripts/communication/dialogo.gd")
const Social = preload("res://scripts/social/social_dynamics.gd")
const Fixture = preload("res://tests/experiments/social_fixture.gd")
const Balanced = preload("res://tests/experiments/social_balanced_protocol.gd")
const P = preload("res://scripts/behavior/personality.gd")

func check(ok: bool, message: String, failures: Array) -> void:
	if not ok:
		failures.append(message)

func garden():
	var world := World.new(51001, {"creature_count": 0, "food_count": 0,
		"obstacle_count": 0, "food_regrow": false, "reproduction_enabled": false,
		"personality_enabled": true, "water_enabled": true})
	world.spawn_creature(Vector2(300, 200))
	world.spawn_creature(Vector2(320, 200))
	for creature in world.creatures.values():
		creature.genome.vision_fov = floorf(TAU * 1000000.0) / 1000000.0
		creature.energy = creature.max_energy * 0.95
		# Keep genealogy consistent after the fixture's inherited trait intervention.
		world.genealogy.records[creature.id].genome = creature.genome.to_dict()
	return world

func run() -> Array:
	var failures: Array = []
	var world = garden()
	var bodies: Array = world.creatures.values()
	var pet = bodies[0]
	var peer = bodies[1]
	world.pet_id = pet.id
	var before: Dictionary = pet.personality.to_dict()
	world.social_observar(pet.id)
	D.responder("perguntar_gostos", pet, world)
	world.comandos.aplicar("perguntar_estado", world)
	check(pet.personality.to_dict() == before, "consultas/clique não criam familiaridade", failures)
	check(not world.interagir_jogador(pet.id, Vector2(900, 600)), "clique distante não é encontro", failures)
	world.step()
	check(Social.relation(pet.personality, peer.id).familiarity > 0.0, "encontro físico cria familiaridade", failures)
	for index in range(1, 10):
		world.tick += 30
		world._personality_encounters(pet, world.sense(pet))
	var relation := Social.relation(pet.personality, peer.id)
	check(relation.encounters == 10 and relation.affinity > 0.2, "encontros repetidos criam afinidade", failures)
	pet.personality.loneliness = 1.0
	pet.genome.temperament.sociability = 1
	world.genealogy.records[pet.id].genome = pet.genome.to_dict()
	check(Social.decide(world, pet, world.sense(pet)).get("action") == "social_follow", "solidão e familiaridade motivam seguir", failures)
	pet.personality.loneliness = 0.0
	pet.energy = pet.max_energy * 0.95
	peer.energy = peer.max_energy * 0.05
	world.place_food(Vector2(310, 200), "fruta")
	check(Social.decide(world, pet, world.sense(pet)).get("action") == "social_share", "afinidade e fome do vizinho motivam ceder acesso", failures)
	pet.energy = pet.max_energy * 0.5
	pet.genome.temperament.impulsivity = 1
	world.genealogy.records[pet.id].genome = pet.genome.to_dict()
	check(Social.decide(world, pet, world.sense(pet)).get("action") == "social_compete", "fome motiva disputa sem vencedor prescrito", failures)
	for index in range(12):
		world.tick += 30
		world._personality_encounters(pet, world.sense(pet))
	check(Social.relation(pet.personality, peer.id).aversion > 0.4, "encontros com disputa produzem aversão", failures)
	pet.genome.temperament.caution = 1
	world.genealogy.records[pet.id].genome = pet.genome.to_dict()
	world.foods.clear()
	check(Social.decide(world, pet, world.sense(pet)).get("action") == "social_avoid", "aversão e cautela motivam evitar", failures)
	world.step() # Normalize physical values after the fixture's direct interventions.
	var snapshot: Dictionary = world.to_dict()
	var restored = World.from_dict(JSON.parse_string(JSON.stringify(snapshot)))
	check(restored != null, "save v7 social carrega", failures)
	if restored != null:
		check(JSON.stringify(restored.to_dict(), "", true, true) == JSON.stringify(snapshot, "", true, true), "round trip mantém vínculos e episódios", failures)
		for step in range(50):
			world.step()
			restored.step()
		check(JSON.stringify(world.to_dict(), "", true, true) == JSON.stringify(restored.to_dict(), "", true, true), "continuação social determinista", failures)
	var legacy: Dictionary = garden().to_dict()
	legacy.save_version = 6
	var original := JSON.stringify(legacy)
	var loaded_v6 = World.from_dict(legacy)
	check(loaded_v6 != null and loaded_v6.to_dict().save_version == 7, "save v6 carrega em v7", failures)
	check(JSON.stringify(legacy) == original, "migração não altera entrada", failures)
	var migrated := World._migrate_v6(legacy)
	check(World._migrate_v6(migrated) == migrated, "migração v6 idempotente", failures)
	var overflow: Dictionary = pet.personality.to_dict()
	for id in range(1, 35):
		overflow.bonds[str(id)] = {"count": 1, "valence": 0.0, "familiarity": 0.0, "last_tick": 0}
	check(P.from_dict(overflow) == null, "limite de vínculos validado", failures)
	_dialogue(failures)
	_channel(failures)
	_balanced_controls(failures)
	return failures

func _balanced_controls(failures: Array) -> void:
	# Only DEV seeds; these oracle rows test the design, never count as a holdout.
	var q: Array = [[0.0, 1.0], [1.0, 0.0], [1.0, 0.0]]
	check(Balanced.baseline_choice(263201, "prior", [0.25, 0.75]) == 1,
		"prior sem sinal escolhe MAP aprendido, incluindo lado direito", failures)
	check(Balanced.baseline_choice(263201, "prior", [0.75, 0.25]) == 0,
		"prior sem sinal respeita frequência TRAIN esquerda", failures)
	var rows: Array = []
	for arm in Balanced.ARMS:
		var choice := Balanced.baseline_choice(263201, arm, [0.5, 0.5]) if arm in ["uniform", "prior"] else -1
		for side in range(2):
			var row := Fixture.episode(263201, arm, q, false, null, side, 0, 0.0, choice)
			rows.append(row)
			if arm in ["disabled", "uniform", "prior"]:
				check(not row.sent and row.received == -1 and row.signal_cost == 0.0,
					"controle sem sinal não entrega nem cobra: " + arm, failures)
			if choice >= 0:
				check(row.choice == choice, "escolha sem sinal independe do lado oculto: " + arm, failures)
	var result := Balanced.analyze(rows, 1)
	check(result.summary.active.successes == 2, "oracle chega/bebe nos dois lados", failures)
	for arm in Balanced.ARMS.slice(1):
		check(result.summary[arm].successes == 1, "controle pareado tem 50%: " + arm, failures)
		check(result.comparisons[arm].seed_wins == 1 and result.comparisons[arm].wins == 1,
			"vitória contada por seed e episódio: " + arm, failures)
	check(result.status == "PARTIAL", "uma seed não satisfaz mínimo pré-registrado", failures)
	# A large overall gain cannot hide failure on one side.
	var synthetic: Array = []
	for arm in Balanced.ARMS:
		for seed_value in range(263201, 263209):
			for side in range(2):
				var row: Dictionary = rows[0].duplicate(true)
				row.arm = arm
				row.seed = seed_value
				row.side = side
				row.drank = arm == "active" and (side == 0 or seed_value < 263205)
				synthetic.append(row)
	check(Balanced.analyze(synthetic, 8).status == "PARTIAL",
		"75% agregado com 50% em um lado reprova", failures)

func _dialogue(failures: Array) -> void:
	var world = garden()
	var pet = world.creatures.values()[0]
	for question in ["do que você gosta?", "o que aprendeu?", "onde está a água?"]:
		var response := D.responder(D.interpretar(question), pet, world)
		check(response.texto.begins_with("Não sei") and response.comando.is_empty(), "sem evidência: " + question, failures)
		check(not response.evidencias.is_empty(), "fontes consultadas listadas", failures)
	pet.energy = pet.max_energy * 0.5
	var food_id: int = world.place_food(pet.pos, "fruta")
	world._eat(pet, food_id)
	check(D.responder("perguntar_gostos", pet, world).texto.contains("Fruta"), "preferência positiva real", failures)
	world.place_water(pet.pos + Vector2(30, 0), 18.0)
	check(D.responder("perguntar_agua", pet, world).texto.contains("Vejo"), "local de água somente por observação", failures)
	world.waters.clear()
	check(D.responder("perguntar_agua", pet, world).texto.begins_with("Não sei"), "não consulta mapa oculto", failures)
	var before: Dictionary = world.to_dict()
	check(world.comandos.aplicar("perguntar_aprendizado", world).aplicado == false, "sem pet selecionado consulta recusada", failures)
	world.pet_id = pet.id
	before = world.to_dict()
	check(world.comandos.aplicar("perguntar_aprendizado", world).aplicado, "consulta delimitada aceita", failures)
	check(world.to_dict() == before, "diálogo não muda estado", failures)
	for attempt in range(5):
		world.ensino_iniciar(pet.id, "ir_ate_local", pet.pos, false, 20, "q")
		world.step()
	check(D.responder("perguntar_aprendizado", pet, world).texto.contains("5 sucessos"), "habilidade somente após cinco sucessos autônomos reais", failures)

func _channel(failures: Array) -> void:
	# Oracle decoder only in this balanced deterministic fixture, not a trained result.
	var q: Array = [[0.0, 1.0], [1.0, 0.0], [1.0, 0.0]]
	var active := 0
	var shuffled := 0
	var disabled := 0
	for side in range(2):
		var row := Fixture.episode(51001, "active", q, false, null, side, -1, 0.0)
		active += int(row.drank)
		check(row.sender_water_count == 1 and row.receiver_water_count == 0, "informação assimétrica real", failures)
		check(row == Fixture.episode(51001, "active", q, false, null, side, -1, 0.0), "fixture determinista", failures)
		var off := Fixture.episode(51001, "disabled", q, false, null, side, -1, 0.0)
		disabled += int(off.drank)
		check(not off.sent and off.received == -1 and off.signal_cost == 0.0, "canal desligado sem entrega/custo", failures)
		for symbol in range(2):
			var mixed := Fixture.episode(51001, "shuffled", q, false, null, side, symbol, 0.0)
			shuffled += int(mixed.drank)
	check(active == 2 and shuffled == 2 and disabled == 1, "sinal independente balanceado: 50%, sem vantagem sobre desligado", failures)
