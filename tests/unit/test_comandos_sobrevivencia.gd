extends RefCounted
## Regressão da revisão final: ordens do jogador não podem matar o pet de fome nem prendê-lo para sempre.
const World = preload("res://scripts/world/sim_world.gd")

func run() -> Array:
	var falhas: Array = []
	_fome_prevalece(falhas)
	_ordem_expira(falhas)
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
