extends SceneTree
## godot --headless --path . -s tests/experiments/evo_run.gd -- --ticks 6000
## Fixed seeds, no manual feeding or energy grants after initialization.
const World = preload("res://scripts/world/sim_world.gd")
const Text = preload("res://scripts/core/textos.gd")
const SEEDS := [7421, 104729, 8675309]
const OUTPUT := "res://tests/experiments/results/evo_run_results.json"
const CONFIG := {
	"size": Vector2(600, 420), "creature_count": 12, "food_count": 120,
	"food_capacity": 160, "food_regrow_interval": 10, "food_regrow_batch": 4,
	"obstacle_count": 5, "max_population": 60, "min_reproduction_age": 120,
	"reproduction_cooldown": 200, "max_age": 3000, "mutation_rate": 0.3, "mutation_scale": 0.025
}

func _init() -> void:
	var ticks := 6000
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		if args.size() != 2 or args[0] != "--ticks" or not args[1].is_valid_int() or int(args[1]) < 1 or int(args[1]) > 100000:
			printerr(Text.texto("evolution_ticks_invalid"))
			quit(1)
			return
		ticks = int(args[1])
	var runs: Array = []
	for scenario in ["recursos_renováveis", "sem_alimento"]:
		for world_seed in SEEDS:
			var config := CONFIG.duplicate()
			if scenario == "sem_alimento":
				config.merge({"food_count": 0, "food_regrow": false}, true)
			var world := World.new(world_seed, config)
			var founders := world.creatures.size()
			var samples: Array = [_sample(world, scenario, founders)]
			var previous_energy: float = samples[0]["body_energy"]
			var nonincreasing_energy := true
			for i in range(ticks):
				world.step()
				if scenario == "sem_alimento":
					var current := _body_energy(world)
					nonincreasing_energy = nonincreasing_energy and current <= previous_energy + 0.000001
					previous_energy = current
				if world.tick % 500 == 0 or world.tick == ticks:
					samples.append(_sample(world, scenario, founders))
			var encoded := JSON.stringify(world.to_dict(), "", true, true)
			var restored := World.from_dict(JSON.parse_string(encoded))
			if restored == null or JSON.stringify(restored.to_dict(), "", true, true) != encoded:
				printerr(Text.texto("evolution_save_invalid"))
				quit(1)
				return
			runs.append({"seed": world_seed, "scenario": scenario, "samples": samples,
				"save_round_trip_equal": true,
				"no_food_energy_nonincreasing": nonincreasing_energy if scenario == "sem_alimento" else null,
				"final_lineage_example": _deepest_lineage(world)})
	var protocol := CONFIG.duplicate()
	protocol["size"] = [CONFIG.size.x, CONFIG.size.y]
	var output := {"engine": Engine.get_version_info()["string"], "ticks": ticks,
		"seeds": SEEDS, "config": protocol, "runs": runs}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(output, "\t", true, true))
	file.close()
	print(Text.texto("evolution_result", [OUTPUT]))
	quit(0)

func _sample(world, scenario: String, founders: int) -> Dictionary:
	var generation := 0
	var deaths := 0
	for record in world.genealogy.records.values():
		generation = maxi(generation, int(record.generation))
		if int(record.death_tick) != -1: deaths += 1
	var sample := {"tick": world.tick, "population": world.creatures.size(), "foods": world.foods.size(),
		"max_generation": generation, "births": world.genealogy.records.size() - founders,
		"deaths": deaths, "diversity": world.genetic_diversity(), "body_energy": _body_energy(world)}
	print(Text.texto("evolution_sample", [scenario, world.seed, world.tick, generation,
		world.creatures.size(), sample.births, JSON.stringify(sample.diversity)]))
	return sample

func _body_energy(world) -> float:
	var result := 0.0
	for creature in world.creatures.values(): result += creature.energy
	return result

func _deepest_lineage(world) -> Array:
	var deepest := -1
	var creature_id := -1
	for record in world.genealogy.records.values():
		if int(record.generation) > deepest:
			deepest = int(record.generation)
			creature_id = int(record.creature_id)
	return world.lineage(creature_id)
