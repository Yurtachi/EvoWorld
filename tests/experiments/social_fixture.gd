extends RefCounted
## Experimental harness, not an automatically installed product policy.
const World = preload("res://scripts/world/sim_world.gd")
const Rng = preload("res://scripts/core/sim_rng.gd")
const A = preload("res://scripts/behavior/actions.gd")
const HORIZON := 100
const TARGETS := [Vector2(140, 200), Vector2(500, 200)]

class Navigator extends RefCounted:
	var goal := Vector2.ZERO
	var stationary := false
	var last_reason := "experiment.public_landmark"
	func decide(creature, obs: Dictionary, _rng) -> int:
		if stationary:
			return 4
		if int(obs.water_id) != -1 and float(obs.water_distance) <= creature.genome.size + 5.0:
			return 13
		if creature.pos.distance_to(goal) < 2.0:
			return 4
		creature.heading = (goal - creature.pos).angle()
		return 0
	func on_death(_creature) -> void:
		pass

static func greedy(q: Array, state: int) -> int:
	return 1 if float(q[state][1]) > float(q[state][0]) else 0

static func episode(seed_value: int, arm: String, q: Array, explore: bool = false, choice_rng = null, forced_side: int = -1, forced_symbol: int = -1, noise: float = 0.1) -> Dictionary:
	var world := World.new(seed_value, {"size": Vector2(640, 400), "creature_count": 0,
		"food_count": 0, "obstacle_count": 0, "food_regrow": false,
		"reproduction_enabled": false, "water_enabled": true,
		"signal_enabled": arm != "disabled", "signal_range": 200.0,
		"signal_cost": 0.3, "signal_noise": noise, "signal_ttl": 100})
	var layout := Rng.new(seed_value)
	var side: int = int(layout.between(0.0, 1.999999)) if forced_side < 0 else forced_side
	world.place_water(TARGETS[side], 18.0)
	var receiver = world.creatures[world.spawn_creature(Vector2(320, 200))]
	var sender = world.creatures[world.spawn_creature(Vector2(320, 100))]
	# Deliberate sensory intervention in this fixture, outside genetic bounds.
	for body in [receiver, sender]:
		body.genome.speed = 40.0
		body.genome.size = 10.0
		body.genome.metabolism = 1.0
		body.genome.vision_fov = TAU
		body.hydration = 60.0
	receiver.genome.vision_range = 30.0
	sender.genome.vision_range = 500.0
	var initial_sender: Dictionary = world.sense(sender)
	var initial_receiver: Dictionary = world.sense(receiver)
	assert(initial_sender.waters.size() == 1 and initial_receiver.waters.is_empty())
	var observed_side := 0 if initial_sender.waters[0].center.x < 320.0 else 1
	var symbol := 1 - observed_side # fixed neutral encoder, not learned semantics
	var energy_sender: float = sender.energy
	var energy_receiver: float = receiver.energy
	var sent: bool = world.emitir_sinal(sender.id, symbol)
	if arm == "shuffled" and not receiver.last_signal.is_empty():
		var independent := Rng.new(seed_value + 700001)
		receiver.last_signal.symbol = int(independent.between(0.0, 1.999999)) if forced_symbol < 0 else forced_symbol
	var heard: Dictionary = world.sense(receiver).signal
	var state := 2 if heard.is_empty() else int(heard.symbol)
	var choice := greedy(q, state)
	if explore and choice_rng.between(0.0, 1.0) < 0.2:
		choice = int(choice_rng.between(0.0, 1.999999))
	var receiver_policy := Navigator.new()
	receiver_policy.goal = TARGETS[choice]
	receiver.brain = receiver_policy
	var sender_policy := Navigator.new()
	sender_policy.stationary = true
	sender.brain = sender_policy
	var drank := false
	var arrived := false
	var steps := HORIZON
	for step in range(HORIZON):
		world.step()
		arrived = arrived or receiver.pos.distance_to(TARGETS[side]) <= 18.0 + receiver.genome.size + 5.0
		for event in world.events:
			if event.type == "drink" and int(event.creature_id) == receiver.id:
				drank = true
		if drank:
			steps = step + 1
			break
	return {"seed": seed_value, "arm": arm, "side": side, "sender_water_count": initial_sender.waters.size(),
		"receiver_water_count": initial_receiver.waters.size(), "sent": sent, "symbol": symbol,
		"received": -1 if heard.is_empty() else int(heard.symbol), "state": state, "choice": choice,
		"arrived": arrived, "drank": drank, "steps": steps,
		"receiver_energy_cost": energy_receiver - receiver.energy,
		"sender_energy_cost": energy_sender - sender.energy, "signal_cost": 0.3 if sent else 0.0}
