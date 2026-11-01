extends Node2D
const World = preload("res://scripts/world/sim_world.gd")
const Store = preload("res://scripts/persistence/save_store.gd")
const GardenTheme = preload("res://scripts/ui/garden_theme.gd")
const Texto = preload("res://scripts/core/textos.gd")
const SIDEBAR := 308.0
var world: World
var store := Store.new()
var world_name := Texto.texto("world_default")
var selected_id := -1
var paused := true
var speed := 1.0
var accumulator := 0.0
var tool := "select"
var follow := false
var status_time := 0.0
var ui: Control
var stats: Label
var title: Label
var status: Label
var pet_name: Label
var identity: Label
var energy_text: Label
var energy_bar: ProgressBar
var age_text: Label
var action_text: Label
var reason_text: Label
var genes_text: Label
var pause_button: Button
var follow_button: Button
var tool_buttons: Dictionary = {}
var speed_buttons: Dictionary = {}
var new_dialog: ConfirmationDialog
var world_input: LineEdit
var pet_input: LineEdit
var seed_input: LineEdit
var dialog_error: Label
var dialog_was_paused := true
@onready var view = $WorldView
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("152d25"))
	get_window().min_size = Vector2i(1100, 680)
	_build_ui()
	_build_new_dialog()
	create_world(Texto.texto("world_default"), Texto.texto("pet_default"), 7421)
	get_viewport().size_changed.connect(_fit_world)
	# Reproducible capture mode uses this same running scene and real SimWorld.
	var capture_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			capture_path = argument.trim_prefix("--capture=")
	if not capture_path.is_empty():
		_capture_demo.call_deferred(capture_path)
	else:
		_open_new_world.call_deferred()

func create_world(garden_name: String, creature_name: String, world_seed: int) -> void:
	world = World.new(world_seed)
	world_name = garden_name
	world.creatures[world.pet_id].name = creature_name
	selected_id = world.pet_id
	paused = true
	accumulator = 0
	follow = false
	view.set_world(world)
	_set_tool("select")
	_fit_world()
	_refresh()
	_notify(Texto.texto("welcome", [creature_name]))

func _process(delta: float) -> void:
	if world == null:
		return
	if not paused:
		accumulator += minf(delta, 0.25) * speed
		while accumulator >= World.TICK_DT:
			world.step()
			accumulator -= World.TICK_DT
	if follow and world.creatures.has(selected_id):
		camera.position = world.creatures[selected_id].pos + _camera_bias()
	view.selected_id = selected_id
	view.pointer = get_global_mouse_position()
	view.show_pointer = _over_world(get_viewport().get_mouse_position()) and not new_dialog.visible
	view.queue_redraw()
	status_time = maxf(0, status_time - delta)
	_refresh()

func _build_ui() -> void:
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = GardenTheme.create()
	$Interface.add_child(ui)
	var header := _panel(ui, Vector4(20, 18, -20, 100), Vector4(0, 0, 1, 0))
	var header_row := HBoxContainer.new()
	header.add_child(header_row)
	var branding := VBoxContainer.new()
	branding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(branding)
	title = _label(branding, Texto.texto("title", [world_name]), 23)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stats = _label(branding, "", 13, Color("acbfad"))
	stats.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_button(header_row, Texto.texto("new_world"), _open_new_world).tooltip_text = Texto.texto("new_tooltip")
	_button(header_row, Texto.texto("save"), _save).tooltip_text = Texto.texto("save_tooltip")
	_button(header_row, Texto.texto("load"), _load).tooltip_text = Texto.texto("load_tooltip")
	var sidebar := _panel(ui, Vector4(-SIDEBAR - 20, 116, -20, -20), Vector4(1, 0, 1, 1))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar.add_child(scroll)
	var inspector := VBoxContainer.new()
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector.add_theme_constant_override("separation", 5)
	scroll.add_child(inspector)
	_label(inspector, Texto.texto("field_notes"), 12, Color("bccc98"))
	pet_name = _label(inspector, Texto.texto("pet_default"), 28)
	pet_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity = _label(inspector, "", 13, Color("acbfad"))
	identity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_separator(inspector)
	energy_text = _label(inspector, Texto.texto("energy"), 15)
	energy_bar = ProgressBar.new()
	energy_bar.custom_minimum_size.y = 9
	energy_bar.show_percentage = false
	inspector.add_child(energy_bar)
	age_text = _label(inspector, "", 14, Color("acbfad"))
	_separator(inspector)
	_label(inspector, Texto.texto("current_action"), 12, Color("bccc98"))
	action_text = _label(inspector, Texto.acao("rest"), 20)
	action_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason_text = _label(inspector, "", 14, Color("c8d1bf"))
	reason_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason_text.custom_minimum_size.y = 24
	_label(inspector, Texto.texto("genome"), 12, Color("bccc98"))
	genes_text = _label(inspector, "", 13, Color("acbfad"))
	genes_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_separator(inspector)
	var actions := HBoxContainer.new()
	inspector.add_child(actions)
	_button(actions, Texto.texto("find_pet"), _find_pet).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	follow_button = _button(actions, Texto.texto("follow"), _toggle_follow)
	follow_button.toggle_mode = true
	var sensor_button := _button(inspector, Texto.texto("vision"), func(): view.show_sensors = not view.show_sensors)
	sensor_button.toggle_mode = true
	sensor_button.tooltip_text = Texto.texto("vision_tooltip")
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector.add_child(filler)
	_separator(inspector)
	var note := _label(inspector, Texto.texto("survival_note"), 12, Color("a8baa6"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bottom := _panel(ui, Vector4(20, -190, -SIDEBAR - 36, -20), Vector4(0, 1, 1, 1))
	var bottom_col := VBoxContainer.new()
	bottom.add_child(bottom_col)
	var toolbar := HBoxContainer.new()
	bottom_col.add_child(toolbar)
	for key in ["select", "food", "obstacle", "creature"]:
		var button := _button(toolbar, Texto.texto("tool_" + key), _set_tool.bind(key))
		button.toggle_mode = true
		tool_buttons[key] = button
	var playback := HBoxContainer.new()
	bottom_col.add_child(playback)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	playback.add_child(spacer)
	pause_button = _button(playback, Texto.texto("play"), _toggle_pause)
	for multiplier in [1, 2, 5]:
		var button := _button(playback, Texto.texto("speed", [multiplier]), _set_speed.bind(float(multiplier)))
		button.toggle_mode = true
		button.button_pressed = multiplier == 1
		speed_buttons[float(multiplier)] = button
	status = _label(bottom_col, "", 12, Color("c2cdb5"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var hint := _label(ui, Texto.texto("shortcuts"), 12, Color("bfd0b5"))
	hint.anchor_right = 1
	hint.offset_left = 28
	hint.offset_right = -SIDEBAR - 36
	hint.offset_top = 112
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build_new_dialog() -> void:
	new_dialog = ConfirmationDialog.new()
	new_dialog.title = Texto.texto("dialog_title")
	new_dialog.ok_button_text = Texto.texto("create_garden")
	new_dialog.cancel_button_text = Texto.texto("keep_exploring")
	new_dialog.min_size = Vector2i(540, 430)
	new_dialog.theme = ui.theme
	new_dialog.dialog_hide_on_ok = false
	ui.add_child(new_dialog)
	var column := VBoxContainer.new()
	new_dialog.add_child(column)
	_label(column, Texto.texto("begin_name"), 24)
	var intro := _label(column, Texto.texto("dialog_intro"), 14, Color("b7c7b1"))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	world_input = _field(column, Texto.texto("garden_name"), Texto.texto("world_default"), 48)
	pet_input = _field(column, Texto.texto("pet_name"), Texto.texto("pet_default"), 32)
	seed_input = _field(column, Texto.texto("seed_caption"), Texto.texto("seed_default"), 10)
	dialog_error = _label(column, Texto.texto("pet_rules"), 12, Color("d4d6ab"))
	dialog_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	new_dialog.confirmed.connect(_confirm_new_world)
	new_dialog.canceled.connect(func(): paused = dialog_was_paused)

func _open_new_world() -> void:
	dialog_was_paused = paused
	paused = true
	new_dialog.popup_centered()
	pet_input.grab_focus()
	pet_input.select_all()

func _confirm_new_world() -> void:
	if world_input.text.strip_edges().is_empty() or pet_input.text.strip_edges().is_empty():
		dialog_error.text = Texto.texto("names_required")
		return
	if not seed_input.text.is_valid_int() or seed_input.text.to_int() < 0 or seed_input.text.to_int() > 2147483647:
		dialog_error.text = Texto.texto("seed_invalid")
		return
	new_dialog.hide()
	dialog_error.text = Texto.texto("pet_rules")
	create_world(world_input.text.strip_edges(), pet_input.text.strip_edges(), seed_input.text.to_int())

func _unhandled_input(event: InputEvent) -> void:
	if new_dialog.visible:
		return
	if event is InputEventMouseButton and _over_world(event.position):
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var before := get_global_mouse_position()
			var factor := 1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12
			camera.zoom = Vector2.ONE * clampf(camera.zoom.x * factor, 0.22, 3.0)
			camera.force_update_scroll()
			camera.position += before - get_global_mouse_position()
			follow = false
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_apply_tool(get_global_mouse_position())
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		camera.position -= event.relative / camera.zoom
		follow = false

func _input(event: InputEvent) -> void:
	# Global shortcuts work even after clicking a focused toolbar button.
	if new_dialog == null or new_dialog.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var handled := true
		if event.ctrl_pressed and event.keycode == KEY_S:
			_save()
		elif event.ctrl_pressed and event.keycode == KEY_L:
			_load()
		elif event.keycode == KEY_SPACE:
			_toggle_pause()
		elif event.keycode == KEY_F:
			_fit_world()
		elif event.keycode == KEY_ESCAPE:
			_set_tool("select")
		elif event.keycode == KEY_F12:
			capture_screenshot()
		else:
			handled = false
		if handled:
			get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if world == null or new_dialog.visible:
		return
	var direction := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if not Input.is_key_pressed(KEY_CTRL) and direction != Vector2.ZERO:
		camera.position += direction.normalized() * delta * 500 / camera.zoom.x
		follow = false

func _apply_tool(pos: Vector2) -> void:
	if not Rect2(Vector2.ZERO, world.size).has_point(pos):
		_notify(Texto.texto("inside_boundary"))
		return
	match tool:
		"select":
			selected_id = -1
			var nearest := INF
			for creature in world.creatures.values():
				var distance: float = pos.distance_to(creature.pos)
				if distance < maxf(creature.genome.size + 5, 13 / camera.zoom.x) and distance < nearest:
					selected_id = creature.id
					nearest = distance
			follow = false
		"food":
			var id := world.place_food(pos)
			_notify(Texto.texto("food_placed" if id >= 0 else "food_blocked"))
		"obstacle":
			var before: int = world.obstacles.size()
			world.place_obstacle(pos, 24.0)
			_notify(Texto.texto("rock_placed" if world.obstacles.size() > before else "rock_blocked"))
		"creature":
			if world.creatures.size() >= 150:
				_notify(Texto.texto("population_limit"))
				return
			var id := world.spawn_creature(pos)
			if id >= 0:
				selected_id = id
			_notify(Texto.texto("creature_placed" if id >= 0 else "creature_blocked"))
	_refresh()

func _refresh() -> void:
	title.text = Texto.texto("title", [Texto.nome_mundo(world_name)])
	stats.text = Texto.texto("stats", [world.seed, world.tick,
		Engine.get_frames_per_second(), world.creatures.size() + world.foods.size() + world.obstacles.size(), world.creatures.size(), world.foods.size()])
	pause_button.text = Texto.texto("play" if paused else "pause")
	follow_button.button_pressed = follow
	if status_time <= 0:
		status.text = Texto.texto("inspect_hint") if tool == "select" else Texto.texto("place_hint", [Texto.texto("place_" + tool)])
	if not world.creatures.has(selected_id):
		pet_name.text = Texto.texto("no_selection")
		identity.text = Texto.texto("select_hint")
		energy_text.text = Texto.texto("no_energy")
		energy_bar.value = 0
		age_text.text = ""
		action_text.text = Texto.texto("observe")
		reason_text.text = Texto.texto("selected_dead" if selected_id >= 0 else "reason_hint")
		genes_text.text = ""
		return
	var creature = world.creatures[selected_id]
	pet_name.text = Texto.nome_criatura(creature.name)
	identity.text = Texto.texto("identity", [Texto.texto("your_pet" if selected_id == world.pet_id else "organism"), creature.id, creature.genome.generation])
	energy_text.text = Texto.texto("energy_value", [Texto.numero(creature.energy), Texto.numero(creature.max_energy)])
	energy_bar.value = creature.energy / creature.max_energy * 100
	age_text.text = Texto.texto("age_value", [Texto.numero(creature.age * World.TICK_DT), creature.age])
	age_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_text.text = Texto.acao(creature.last_action)
	reason_text.text = Texto.razao(creature.last_reason)
	genes_text.text = Texto.texto("genes", [Texto.numero(creature.genome.size), Texto.numero(creature.genome.speed),
		Texto.numero(creature.genome.vision_range, 0), Texto.numero(creature.genome.metabolism, 2), Texto.numero(creature.genome.hue, 2)])

func _set_tool(value: String) -> void:
	tool = value
	view.tool = value
	for key in tool_buttons:
		tool_buttons[key].button_pressed = key == value
	status_time = 0

func _set_speed(value: float) -> void:
	speed = value
	for key in speed_buttons:
		speed_buttons[key].button_pressed = is_equal_approx(key, value)

func _toggle_pause() -> void:
	paused = not paused
	accumulator = 0

func _toggle_follow() -> void:
	follow = not follow and world.creatures.has(selected_id)

func _find_pet() -> void:
	if world.creatures.has(world.pet_id):
		selected_id = world.pet_id
		camera.position = world.creatures[selected_id].pos + _camera_bias()
	else:
		_notify(Texto.texto("pet_dead"))

func _camera_bias() -> Vector2:
	return Vector2((SIDEBAR + 16) * 0.5, 25) / camera.zoom

func _fit_world() -> void:
	if world == null:
		return
	var available := get_viewport_rect().size - Vector2(SIDEBAR + 100, 370)
	var zoom_level := minf(available.x / world.size.x, available.y / world.size.y)
	camera.zoom = Vector2.ONE * clampf(zoom_level, 0.05, 2.0)
	camera.position = world.size * 0.5 + _camera_bias()
	follow = false

func _over_world(pos: Vector2) -> bool:
	var size := get_viewport_rect().size
	return pos.x < size.x - SIDEBAR - 36 and pos.y > 150 and pos.y < size.y - 200

func _save() -> void:
	var result := store.save_world(world, "world", {"name": world_name})
	_notify(Texto.mensagem(result.message), 8)

func _load() -> void:
	var result := store.load_world("world")
	if result.ok:
		world = result.world
		var name_value = result.metadata.get("name", Texto.texto("world_restored"))
		world_name = str(name_value).left(48)
		selected_id = world.pet_id
		paused = true
		accumulator = 0
		view.set_world(world)
		_set_tool("select")
		_fit_world()
		_refresh()
	_notify(Texto.mensagem(result.message), 10)

func _notify(message: String, seconds: float = 5.0) -> void:
	status.text = message
	status_time = seconds

func capture_screenshot(path: String = "") -> void:
	if DisplayServer.get_name() == "headless":
		_notify(Texto.texto("screenshot_graphics"))
		return
	if path.is_empty():
		DirAccess.make_dir_recursive_absolute("user://screenshots")
		path = "user://screenshots/evoworld-%s.png" % Time.get_datetime_string_from_system().replace(":", "-")
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error == OK:
		_notify(Texto.texto("screenshot_saved", [ProjectSettings.globalize_path(path)]), 8)
		print(Texto.texto("screenshot_saved", [ProjectSettings.globalize_path(path)]))
	else:
		_notify(Texto.texto("screenshot_failed", [error]))

func _capture_demo(path: String) -> void:
	var arguments := OS.get_cmdline_user_args()
	if "--capture-minimum" in arguments:
		get_window().size = Vector2i(1100, 680)
		await get_tree().process_frame
		_fit_world()
	var state := "inspect"
	for argument in arguments:
		if argument.begins_with("--capture-state="):
			state = argument.trim_prefix("--capture-state=")
	if "--show-new-world" not in arguments:
		for i in range(120):
			world.step()
	_refresh()
	var folder := "user://saves/i18n_capture_%d" % OS.get_process_id()
	if state in ["save", "load", "invalid-load"]:
		# Cenários reais, sempre isolados do salvamento do jogador.
		store = Store.new(folder)
		if state == "invalid-load":
			DirAccess.make_dir_recursive_absolute(folder)
			var invalid := FileAccess.open(folder.path_join("world.json"), FileAccess.WRITE)
			invalid.store_string("{invalid")
			invalid.close()
			_load()
		else:
			_save()
			if state == "load":
				world.step()
				_load()
	if state == "tools":
		_set_tool("food")
		view.show_sensors = true
	if state == "creature":
		for creature in world.creatures.values():
			if creature.id != world.pet_id:
				selected_id = creature.id
				break
	if "--show-new-world" in arguments:
		_open_new_world()
		if state == "menu":
			var menu := pet_input.get_menu()
			_localize_edit_menu(menu)
			menu.position = new_dialog.position + Vector2i(70, 220)
			menu.popup()
	var warmup_until := Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < warmup_until:
		await get_tree().process_frame
	await capture_screenshot(path)
	if state in ["save", "load", "invalid-load"]:
		for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
			var fixture := folder.path_join("world.json" + suffix)
			if FileAccess.file_exists(fixture):
				DirAccess.remove_absolute(fixture)
		DirAccess.remove_absolute(folder)
	get_tree().quit()

func _panel(parent: Node, offsets: Vector4, anchors: Vector4) -> PanelContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.anchor_left = anchors.x
	panel.anchor_top = anchors.y
	panel.anchor_right = anchors.z
	panel.anchor_bottom = anchors.w
	panel.offset_left = offsets.x
	panel.offset_top = offsets.y
	panel.offset_right = offsets.z
	panel.offset_bottom = offsets.w
	return panel

func _label(parent: Node, text: String, font_size: int = 15, color: Color = Color("eeeede")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _separator(parent: Node) -> void:
	var separator := HSeparator.new()
	separator.modulate = Color(0.7, 0.8, 0.6, 0.3)
	parent.add_child(separator)

func _field(parent: Node, caption: String, value: String, limit: int) -> LineEdit:
	_label(parent, caption, 13, Color("b7c7b1"))
	var input := LineEdit.new()
	input.text = value
	input.max_length = limit
	parent.add_child(input)
	var menu := input.get_menu()
	_localize_edit_menu(menu)
	menu.about_to_popup.connect(_localize_edit_menu.bind(menu))
	return input

func _localize_edit_menu(menu: PopupMenu) -> void:
	for index in range(menu.item_count):
		if not menu.is_item_separator(index):
			menu.set_item_text(index, Texto.texto(Texto.MENUS.get(menu.get_item_id(index), "text_unknown")))
		var submenu := menu.get_item_submenu_node(index)
		if submenu != null:
			_localize_edit_menu(submenu)
