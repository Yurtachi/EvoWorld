extends SceneTree
## End-to-end scene/controls smoke check; uses an isolated checkpoint directory.
## godot --headless --path . -s scripts/ui/verify_ui.gd
const Store = preload("res://scripts/persistence/save_store.gd")
var errors: Array[String] = []

func _init() -> void:
	_verify.call_deferred()

func _verify() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	_expect(main.new_dialog.visible, "first launch offers new-world naming")
	main.world_input.text = "Test garden"
	main.pet_input.text = "Clover"
	main.seed_input.text = "12345"
	main.new_dialog.confirmed.emit()
	_expect(not main.new_dialog.visible, "valid new-world form closes")
	_expect(main.world.creatures[main.world.pet_id].name == "Clover", "pet naming reaches real SimWorld")
	_expect(main.world.seed == 12345 and main.world_name == "Test garden", "world name and seed applied")
	_expect(main.paused and main.world.tick == 0, "new world starts paused")
	# Tool selection travels through actual toolbar signals.
	main.tool_buttons.food.pressed.emit()
	var food_count: int = main.world.foods.size()
	var food_pos := _free_point(main.world, 4)
	main._apply_tool(food_pos)
	_expect(main.world.foods.size() == food_count + 1, "food tool adds actual food")
	main.tool_buttons.creature.pressed.emit()
	var creature_count: int = main.world.creatures.size()
	for i in range(3):
		main._apply_tool(_free_point(main.world, 18))
	_expect(main.world.creatures.size() == creature_count + 3, "creature tool introduces three organisms")
	main.tool_buttons.obstacle.pressed.emit()
	var rock_count: int = main.world.obstacles.size()
	main._apply_tool(_free_point(main.world, 26))
	_expect(main.world.obstacles.size() == rock_count + 1, "rock tool adds actual obstacle")
	main.tool_buttons.select.pressed.emit()
	main._apply_tool(main.world.creatures[main.world.pet_id].pos)
	_expect(main.selected_id == main.world.pet_id, "world picking selects the pet")
	main._refresh()
	_expect(main.pet_name.text == "Clover", "inspector displays selected identity")
	_expect(main.reason_text.text == main.world.creatures[main.selected_id].last_reason, "inspector reason comes from simulation")
	await process_frame
	await process_frame
	var inspector: Control = main.pet_name.get_parent()
	var scroll: ScrollContainer = inspector.get_parent()
	_expect(inspector.size.x <= scroll.size.x, "inspector fits horizontally without clipping")
	var starting_tick: int = main.world.tick
	main._process(0.2)
	_expect(main.world.tick == starting_tick, "pause prevents ticking")
	main.speed_buttons[5.0].pressed.emit()
	main.pause_button.pressed.emit()
	main._process(0.2)
	_expect(main.world.tick >= starting_tick + 9, "5x playback advances fixed ticks")
	main.pause_button.pressed.emit()
	var folder := "user://saves/ui_test_%s_%s" % [OS.get_process_id(), Time.get_ticks_usec()]
	main.store = Store.new(folder)
	main._save()
	var snapshot: Dictionary = main.world.to_dict()
	main.world.step()
	main._load()
	_expect(main.world.to_dict() == snapshot, "UI save/load restores exact checkpoint")
	_expect(main.world_name == "Test garden" and main.paused, "load restores name and pauses")
	# Zoom and camera paths are exercised with the actual input handler.
	var zoom_before: Vector2 = main.camera.zoom
	var wheel := InputEventMouseButton.new()
	wheel.position = Vector2(400, 300)
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	main._unhandled_input(wheel)
	_expect(main.camera.zoom.x > zoom_before.x, "wheel input zooms camera")
	main._find_pet()
	main._toggle_follow()
	_expect(main.follow, "pet follow can be enabled")
	main._fit_world()
	_expect(not main.follow, "fit returns to free camera")
	var shortcut := InputEventKey.new()
	shortcut.pressed = true
	shortcut.keycode = KEY_SPACE
	var was_paused: bool = main.paused
	main._input(shortcut)
	_expect(main.paused != was_paused, "Space toggles playback through global input")
	main.paused = true
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		var path := folder.path_join("world.json" + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(folder)
	main.queue_free()
	await process_frame
	for message in errors:
		printerr("FAIL UI: ", message)
	print("UI integration: ", "ok" if errors.is_empty() else "FAILED")
	quit(0 if errors.is_empty() else 1)

func _free_point(world, radius: float) -> Vector2:
	for y in range(32, int(world.size.y) - 32, 33):
		for x in range(32, int(world.size.x) - 32, 33):
			var point := Vector2(x, y)
			var clear := true
			for rock in world.obstacles:
				if point.distance_to(rock.pos) < radius + rock.radius:
					clear = false
			for food in world.foods:
				if point.distance_to(food.pos) < radius + 3:
					clear = false
			for creature in world.creatures.values():
				if point.distance_to(creature.pos) < radius + creature.genome.size:
					clear = false
			if clear:
				return point
	return Vector2(-1, -1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
