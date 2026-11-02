extends SceneTree
const World = preload("res://scripts/world/sim_world.gd")
func _init() -> void:
	for seed_value in [160003, 7421]:
		var w = World.new_pet_world(seed_value, "P1")
		var c = w.creatures[w.pet_id]
		for i in 5000:
			w.step()
			if i % 200 == 0 or not c.alive:
				print(seed_value, " tick=", w.tick, " energy=", c.energy, " hyd=", c.hydration, " goal=", c.mind.objetivo_atual, " action=", c.last_action, " pos=", c.pos, " target=", c.mind.spatial.objetivo_atual)
			if not c.alive: break
	quit()
