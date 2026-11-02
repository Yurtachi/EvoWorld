extends RefCounted
## Regressão da revisão final: ordens do jogador não podem matar o pet de fome nem prendê-lo para sempre.
const World = preload("res://scripts/world/sim_world.gd")
const Store = preload("res://scripts/persistence/save_store.gd")
const Commands = preload("res://scripts/communication/comandos.gd")

func run() -> Array:
	var falhas: Array = []
	_fome_prevalece(falhas)
	_ordem_expira(falhas)
	_ttl_save_load(falhas)
	return falhas

func _mundo() -> Object:
	return World.new(7421, {"creature_count": 1, "food_count": 0, "obstacle_count": 0, "food_regrow": 0.0, "reproduction_enabled": false})

func _fome_prevalece(falhas: Array) -> void:
	var w = _mundo()
	var pet = w.creatures[w.pet_id]
	pet.energy = pet.max_energy * 0.2
	w.comandos.aplicar("parar", w)
	w.place_food(pet.pos + Vector2.from_angle(pet.heading) * (pet.genome.size + 3.0))
	var comeu := false
	for i in 60:
		w.step()
		for e in w.events:
			if e.get("type") == "eat":
				comeu = true
	if not comeu:
		falhas.append("pet faminto com ordem 'parar' não comeu alimento adjacente")

func _ordem_expira(falhas: Array) -> void:
	var w = _mundo()
	var pet = w.creatures[w.pet_id]
	pet.energy = pet.max_energy
	w.comandos.aplicar("chamar", w, Vector2(w.size.x * 0.5, w.size.y * 0.5))
	for i in 700:
		pet.energy = pet.max_energy
		w.step()
	if not w.comandos.to_dict(w)["order"].is_empty():
		falhas.append("ordem 'chamar' não expirou após 700 ticks")

func _ttl_save_load(falhas: Array) -> void:
	var folder := "user://m0_ttl_%d" % OS.get_process_id()
	var store := Store.new(folder)
	for intent in Commands.TICKS_ORDEM:
		var w = _mundo()
		var pet = w.creatures[w.pet_id]
		w.comandos.aplicar(intent, w, pet.pos + Vector2(50, 0))
		# Spend all but seven ticks while hunger suspends execution. Expiration
		# must advance even while the order cannot control the pet.
		for i in int(Commands.TICKS_ORDEM[intent]) - 7:
			pet.energy = pet.max_energy * 0.2
			w.comandos.acao_pendente(pet, w)
		if not store.save_world(w, "partial").ok:
			falhas.append("falhou salvar TTL parcial: " + intent)
			continue
		var loaded := store.load_world("partial")
		if not loaded.ok:
			falhas.append("falhou carregar TTL parcial: " + intent)
			continue
		var restored = loaded.world
		var order: Dictionary = restored.comandos.to_dict(restored).order
		if order.get("remaining_ticks") != 7:
			falhas.append("save/load reiniciou TTL parcial: " + intent)
		# Repeated load/save also preserves the exact remainder.
		var again = World.from_dict(restored.to_dict())
		if again == null or again.comandos.to_dict(again).order != order:
			falhas.append("TTL mudou no segundo roundtrip: " + intent)
		var legacy: Dictionary = w.to_dict()
		legacy.commands.order.erase("remaining_ticks")
		var old = World.from_dict(legacy)
		if old == null or old.comandos.to_dict(old).order.get("remaining_ticks") != Commands.TICKS_ORDEM[intent]:
			falhas.append("ordem legada sem TTL deixou de carregar: " + intent)
		for i in 7:
			pet.energy = pet.max_energy * 0.2
			restored.creatures[restored.pet_id].energy = pet.energy
			w.step()
			restored.step()
			if JSON.stringify(w.to_dict(), "", true, true) != JSON.stringify(restored.to_dict(), "", true, true):
				falhas.append("continuação divergiu com TTL parcial: " + intent)
		if not restored.comandos.to_dict(restored).order.is_empty():
			falhas.append("ordem carregada não expirou após sete ticks: " + intent)
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(folder.path_join("partial.json" + suffix))
	DirAccess.remove_absolute(folder)
