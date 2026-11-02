extends "res://scripts/terminal/terminal_mundo.gd"
## Trusted, bounded synchronous bridge. No external capabilities. Each method
## delegates exactly one physical action; the world revalidates every request.
var world
var creature
var terminal_id: int
var moved := false
var observation: Dictionary = {}

func _init(sim_world, actor, device_id: int) -> void:
	world = sim_world
	creature = actor
	terminal_id = device_id

func olhar() -> Dictionary:
	observation = world.terminal_observe(creature, terminal_id)
	return {"ok": not observation.is_empty(), "pos": observation.get("pos", [])}

func marcar(pos: Vector2i) -> Dictionary:
	return {"ok": world.terminal_mark(creature, terminal_id, pos)}

func mover(direction: String, units: int) -> Dictionary:
	moved = world.terminal_move(creature, terminal_id, direction, units)
	return {"ok": moved}

func desenhar(shape: String) -> Dictionary:
	return {"ok": world.terminal_draw(creature, terminal_id, shape)}

func ler(book: String) -> Dictionary:
	return {"ok": world.terminal_read(creature, terminal_id, book)}
