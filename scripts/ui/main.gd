extends Node2D
const World = preload("res://scripts/world/sim_world.gd")
const Store = preload("res://scripts/persistence/save_store.gd")
const GardenTheme = preload("res://scripts/ui/garden_theme.gd")
const Texto = preload("res://scripts/core/textos.gd")
const DialogoAPI = preload("res://scripts/communication/dialogo.gd")
const ComandosAPI = preload("res://scripts/communication/comandos.gd")
const Laboratory = preload("res://scripts/ui/laboratory.gd")
const FoodCatalog = preload("res://scripts/environment/food_catalog.gd")
const FpsChart = preload("res://scripts/ui/fps_chart.gd")
const PersonalityInspector = preload("res://scripts/ui/personality_inspector.gd")
const TeachingPanel = preload("res://scripts/ui/teaching_panel.gd")
const SIDEBAR := 350.0
var teaching: VBoxContainer
var teaching_scroll: ScrollContainer
var teaching_button: Button
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
var comandos := ComandosAPI.new()
var lab: VBoxContainer
var caregiver_scroll: ScrollContainer
var lab_scroll: ScrollContainer
var lab_button: Button
var care_button: Button
var mode_note: Label
var chat_dialog: AcceptDialog
var chat_input: LineEdit
var chat_response: Label
var chat_evidence: Label
var chat_receipt: Label
var last_response: Dictionary = {}
var command_target := Vector2.ZERO
var settings_dialog: AcceptDialog
var help_dialog: AcceptDialog
var population_input: SpinBox
var new_population: SpinBox
var protection_input: CheckButton
var autosave_input: CheckButton
var settings_speed: OptionButton
var initial_population := 12
var food_type := "fruta"
var food_buttons: Dictionary = {}
var hydration_text: Label
var thirst_note: Label
var last_event_text: Label
var food_profile: Label
var food_warning: Label
var offer_button: Button
var receipts: Label
var receipt_rows: Array[String] = []
var pending_offers: Array[Dictionary] = []
var observed_drinks: Dictionary = {}
var personality_inspector: TabContainer
var roster: OptionButton
var roster_ids: Array = []
var expand_dialog: ConfirmationDialog
var expand_side: OptionButton
var expand_amount: SpinBox
var expand_preview: Label
var fps_chart: Control
var protected_mode := true
var autosave_enabled := true
var autosave_elapsed := 0.0
var autosave_tick := -1
var settings_path := "user://ui-settings.cfg"
var _lab_elapsed := 0.0
var _capture_mode := false
var _world_dirty := false
@onready var view = $WorldView
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("152d25"))
	get_window().min_size = Vector2i(1100, 680)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fps-benchmark="):
			initial_population = clampi(arg.get_slice("=", 1).to_int(), 1, 100)
			_capture_mode = true
		if arg.begins_with("--capture="):
			_capture_mode = true
	if DisplayServer.get_name() != "headless" and not _capture_mode:
		_read_settings()
	_build_ui()
	_build_new_dialog()
	_build_chat()
	_build_settings()
	_build_help()
	_build_expand()
	_set_speed(speed)
	create_world(Texto.texto("world_default"), Texto.texto("pet_default"), 7421)
	get_viewport().size_changed.connect(_fit_world)
	# Reproducible capture mode uses this same running scene and real SimWorld.
	var capture_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			capture_path = argument.trim_prefix("--capture=")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fps-benchmark=") and capture_path.is_empty():
			capture_path = "reports/E4-fps-%d.png" % initial_population
	if not capture_path.is_empty():
		_capture_demo.call_deferred(capture_path)
	else:
		_open_new_world.call_deferred()

func create_world(garden_name: String, creature_name: String, world_seed: int) -> void:
	world = World.new_world(world_seed, {"creature_count": initial_population, "initial_names": Texto.NOMES_INICIAIS})
	# The name catalog applies only at this new-world boundary, never on load.
	var index := 0
	for creature in world.creatures.values():
		creature.name = Texto.NOMES_INICIAIS[index % Texto.NOMES_INICIAIS.size()]
		if index >= Texto.NOMES_INICIAIS.size():
			creature.name += " %d" % (index / Texto.NOMES_INICIAIS.size() + 1)
		index += 1
	world_name = garden_name
	world.creatures[world.pet_id].name = creature_name
	for creature in world.creatures.values():
		world.genealogy.records[creature.id]["name"] = creature.name
	for event in world.events:
		if event.get("type") == "spawn" and world.creatures.has(int(event.get("creature_id", -1))):
			event["name"] = world.creatures[int(event.creature_id)].name
	selected_id = world.pet_id
	paused = true
	accumulator = 0
	follow = false
	_reset_session()
	_world_dirty = true
	view.set_world(world)
	_set_tool("select")
	_fit_world()
	_refresh()
	_notify(Texto.texto("welcome", [creature_name]))

func _process(delta: float) -> void:
	if world == null:
		return
	# O alvo é uma posição explícita; nunca é extraído do texto livre.
	comandos.atualizar_alvo(world, command_target)
	if not paused:
		accumulator += minf(delta, 0.25) * speed
		while accumulator >= World.TICK_DT:
			if not _can_step():
				break
			world.step()
			_observe_physical_events()
			accumulator -= World.TICK_DT
	_lab_elapsed += delta
	if _lab_elapsed >= 0.5:
		lab.observe(world, selected_id)
		_lab_elapsed = 0
	fps_chart.sample(delta)
	_autosave(delta)
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
	_button(header_row, Texto.texto("settings"), _open_settings)
	_button(header_row, Texto.texto("help"), func(): help_dialog.popup_centered())
	var sidebar := _panel(ui, Vector4(-SIDEBAR - 20, 116, -20, -20), Vector4(1, 0, 1, 1))
	var side_column := VBoxContainer.new()
	sidebar.add_child(side_column)
	var modes := HBoxContainer.new()
	side_column.add_child(modes)
	care_button = _button(modes, Texto.texto("caregiver"), _show_lab.bind(false))
	teaching_button = _button(modes, Texto.texto("te_title"), _show_teaching)
	lab_button = _button(modes, Texto.texto("laboratory"), _show_lab.bind(true))
	for button in [care_button, lab_button, teaching_button]:
		button.add_theme_font_size_override("font_size", 13)
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	care_button.button_pressed = true
	var scroll := ScrollContainer.new()
	caregiver_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_column.add_child(scroll)
	lab_scroll = ScrollContainer.new()
	lab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lab_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_column.add_child(lab_scroll)
	lab = Laboratory.new()
	lab_scroll.add_child(lab)
	lab.intervention.connect(func():
		_world_dirty = true
		if teaching != null and teaching.world == world:
			teaching.refresh(true))
	lab_scroll.hide()
	teaching_scroll = ScrollContainer.new()
	teaching_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	teaching_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_column.add_child(teaching_scroll)
	teaching = TeachingPanel.new()
	teaching_scroll.add_child(teaching)
	teaching.target_requested.connect(func(): _set_tool("teaching"))
	teaching.changed.connect(func(): _world_dirty = true)
	teaching_scroll.hide()
	var inspector := VBoxContainer.new()
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector.add_theme_constant_override("separation", 5)
	scroll.add_child(inspector)
	_label(inspector, Texto.texto("care_notes"), 12, Color("bccc98"))
	pet_name = _label(inspector, Texto.texto("pet_default"), 28)
	pet_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity = _label(inspector, "", 13, Color("acbfad"))
	identity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_note = _label(inspector, "", 12, Color("d4d6ab"))
	mode_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	roster = OptionButton.new()
	roster.fit_to_longest_item = false
	roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster.item_selected.connect(func(index):
		selected_id = roster.get_item_id(index)
		follow = false
		_refresh())
	inspector.add_child(roster)
	personality_inspector = PersonalityInspector.new()
	_button(inspector, Texto.texto("chat_open"), func(): chat_dialog.popup_centered())
	inspector.add_child(personality_inspector)
	var attention := _button(inspector, Texto.texto("tool_attention"), _set_tool.bind("attention"))
	attention.tooltip_text = Texto.texto("attention_help")
	attention.toggle_mode = true
	tool_buttons["attention"] = attention
	_separator(inspector)
	energy_text = _label(inspector, Texto.texto("energy"), 15)
	energy_bar = ProgressBar.new()
	energy_bar.custom_minimum_size.y = 9
	energy_bar.show_percentage = false
	inspector.add_child(energy_bar)
	hydration_text = _wrapped(inspector, "")
	thirst_note = _wrapped(inspector, "")
	thirst_note.add_theme_color_override("font_color", Color("ffd19c"))
	age_text = _label(inspector, "", 14, Color("acbfad"))
	last_event_text = _wrapped(inspector, "")
	_label(inspector, Texto.texto("food_choice"), 12, Color("bccc98"))
	food_profile = _wrapped(inspector, "")
	food_warning = _wrapped(inspector, Texto.texto("food_warning"))
	food_warning.add_theme_color_override("font_color", Color("ffd19c"))
	offer_button = _button(inspector, Texto.texto("offer"), _offer_food)
	_label(inspector, Texto.texto("receipt_title"), 12, Color("bccc98"))
	receipts = _wrapped(inspector, Texto.texto("receipt_empty"))
	_separator(inspector)
	_label(inspector, Texto.texto("current_action"), 12, Color("bccc98"))
	action_text = _label(inspector, Texto.acao("rest"), 20)
	action_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason_text = _label(inspector, "", 14, Color("c8d1bf"))
	reason_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason_text.custom_minimum_size.y = 24
	genes_text = _label(inspector, "", 13, Color("acbfad"))
	genes_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	genes_text.hide()
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
	var bottom := _panel(ui, Vector4(20, -205, -SIDEBAR - 36, -20), Vector4(0, 1, 1, 1))
	var bottom_col := VBoxContainer.new()
	bottom.add_child(bottom_col)
	var toolbar := HBoxContainer.new()
	bottom_col.add_child(toolbar)
	for key in ["select", "food", "water", "obstacle", "creature"]:
		var button := _button(toolbar, Texto.texto("tool_" + key), _set_tool.bind(key))
		button.toggle_mode = true
		tool_buttons[key] = button
	var food_row := HBoxContainer.new()
	bottom_col.add_child(food_row)
	for kind in ["fruta", "semente", "folha", "cogumelo"]:
		var button := _button(food_row, Texto.texto("tool_" + kind), _choose_food.bind(kind))
		button.icon = _food_icon(kind)
		button.toggle_mode = true
		button.button_pressed = kind == food_type
		food_buttons[kind] = button
	_button(food_row, Texto.texto("tool_expand"), _open_expand)
	var playback := HBoxContainer.new()
	bottom_col.add_child(playback)
	fps_chart = FpsChart.new()
	fps_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	playback.add_child(fps_chart)
	pause_button = _button(playback, Texto.texto("play"), _toggle_pause)
	for multiplier in [1, 2, 5]:
		var button := _button(playback, Texto.texto("speed", [multiplier]), _set_speed.bind(float(multiplier)))
		button.toggle_mode = true
		button.button_pressed = multiplier == 1
		speed_buttons[float(multiplier)] = button
	status = _label(bottom_col, "", 12, Color("c2cdb5"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for row in [toolbar, food_row, playback]:
		_compact_buttons(row)
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
	new_dialog.min_size = Vector2i(580, 600)
	new_dialog.theme = ui.theme
	new_dialog.dialog_hide_on_ok = false
	ui.add_child(new_dialog)
	var column := _window_column(new_dialog)
	_label(column, Texto.texto("begin_name"), 24)
	_wrapped(column, Texto.texto("dialog_intro"))
	world_input = _field(column, Texto.texto("garden_name"), Texto.texto("world_default"), 48)
	pet_input = _field(column, Texto.texto("pet_name"), Texto.texto("pet_default"), 32)
	seed_input = _field(column, Texto.texto("seed_caption"), Texto.texto("seed_default"), 10)
	_label(column, Texto.texto("initial_population"), 13)
	new_population = _population_field(column)
	new_population.value = initial_population
	dialog_error = _wrapped(column, Texto.texto("pet_rules"))
	dialog_error.add_theme_color_override("font_color", Color("d4d6ab"))
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
	initial_population = int(new_population.value)
	create_world(world_input.text.strip_edges(), pet_input.text.strip_edges(), seed_input.text.to_int())

func _unhandled_input(event: InputEvent) -> void:
	if new_dialog.visible or chat_dialog.visible or settings_dialog.visible or help_dialog.visible or expand_dialog.visible or teaching.reset_dialog.visible:
		return
	if event is InputEventMouseButton and _over_world(event.position):
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			command_target = get_global_mouse_position().clamp(Vector2.ZERO, world.size)
			view.command_target = command_target
			_world_dirty = true
			_notify(Texto.texto("target_set"))
			return
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var before := get_global_mouse_position()
			var factor := 1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12
			camera.zoom = Vector2.ONE * clampf(camera.zoom.x * factor, 0.001, 3.0)
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
	if new_dialog == null or new_dialog.visible or chat_dialog.visible or settings_dialog.visible or help_dialog.visible or expand_dialog.visible or teaching.reset_dialog.visible:
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
	if world == null or new_dialog.visible or chat_dialog.visible or settings_dialog.visible or help_dialog.visible or expand_dialog.visible or teaching.reset_dialog.visible:
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
				if (distance < maxf(creature.genome.size + 5, 13 / camera.zoom.x) or view.label_hit(creature, pos)) and distance < nearest:
					selected_id = creature.id
					nearest = distance
			follow = false
		"teaching":
			teaching.mark(pos)
			_set_tool("select")
			_refresh()
		"attention":
			_give_attention(pos)
		"food":
			var id := world.place_food(pos, food_type)
			_notify(Texto.texto("food_placed" if id >= 0 else "food_blocked"))
		"water":
			var id := world.place_water(pos)
			_notify(Texto.texto("water_placed" if id >= 0 else "water_blocked"))
			if id >= 0 and not world.water_enabled:
				_notify(Texto.texto("water_legacy"))
		"obstacle":
			var before: int = world.obstacles.size()
			world.place_obstacle(pos, 24.0)
			_notify(Texto.texto("rock_placed" if world.obstacles.size() > before else "rock_blocked"))
		"creature":
			if world.creatures.size() >= world.max_population:
				_notify(Texto.texto("population_limit"))
				return
			var id := world.spawn_creature(pos)
			if id >= 0:
				selected_id = id
			_notify(Texto.texto("creature_placed" if id >= 0 else "creature_blocked"))
	_refresh()
	_world_dirty = true

func _refresh() -> void:
	teaching.observe(world, selected_id)
	view.teaching_snapshot = teaching.snapshot
	view.teaching_target = teaching.target if teaching.selected_skill() == "ir_ate_local" else Vector2.INF
	mode_note.text = Texto.texto("protection_active" if protected_mode else "protection_off")
	title.text = Texto.texto("title", [Texto.nome_mundo(world_name)])
	stats.text = Texto.texto("garden_stats", [world.creatures.size(), world.foods.size(), world.waters.size(), world.tick, Engine.get_frames_per_second()])
	_refresh_roster()
	var params: Dictionary = FoodCatalog.PARAMETERS[food_type]
	food_profile.text = Texto.texto("food_profile", [Texto.texto("food_" + food_type), Texto.numero(params.palatability), Texto.numero(params.nutrition, 0), Texto.numero(params.hydration, 0), Texto.numero(params.toxicity, 0)])
	food_warning.visible = float(params.toxicity) > 0
	offer_button.disabled = not world.creatures.has(selected_id)
	thirst_note.visible = false
	receipts.text = Texto.texto("receipt_empty") if receipt_rows.is_empty() else "\n\n".join(receipt_rows.slice(maxi(0, receipt_rows.size() - 4)))
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
		hydration_text.text = ""
		last_event_text.text = ""
		personality_inspector.observe(null, world)
		return
	var creature = world.creatures[selected_id]
	personality_inspector.observe(creature, world)
	pet_name.text = Texto.nome_criatura(creature.name)
	identity.text = Texto.texto("identity", [Texto.texto("your_pet" if selected_id == world.pet_id else "organism"), creature.id, creature.genome.generation])
	energy_text.text = Texto.texto("energy_value", [Texto.numero(creature.energy), Texto.numero(creature.max_energy)])
	energy_bar.value = creature.energy / creature.max_energy * 100
	hydration_text.text = Texto.texto("hydration_value", [Texto.numero(creature.hydration), Texto.numero(creature.thirst * 100, 0)]) if world.water_enabled else Texto.texto("hydration_off")
	thirst_note.visible = world.water_enabled and creature.thirst > 0.6
	thirst_note.text = Texto.texto("thirst_warning")
	last_event_text.text = Texto.texto("last_event_none")
	for index in range(world.events.size() - 1, -1, -1):
		var event: Dictionary = world.events[index]
		if int(event.get("creature_id", -1)) == selected_id:
			last_event_text.text = Texto.texto("last_event", [Texto.evento(event)])
			break
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
	if settings_speed != null:
		settings_speed.select([1.0, 2.0, 5.0].find(value))
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
	var available := get_viewport_rect().size - Vector2(SIDEBAR + 100, 390)
	var zoom_level := minf(available.x / world.size.x, available.y / world.size.y)
	camera.zoom = Vector2.ONE * clampf(zoom_level, 0.001, 2.0)
	camera.position = world.size * 0.5 + _camera_bias()
	follow = false

func _over_world(pos: Vector2) -> bool:
	var size := get_viewport_rect().size
	return pos.x < size.x - SIDEBAR - 36 and pos.y > 150 and pos.y < size.y - 215

func _save(slot: String = "world") -> void:
	var result := store.save_world(world, slot, {"name": world_name})
	if slot == "autosave":
		if result.ok:
			autosave_tick = world.tick
			_world_dirty = false
		_notify(Texto.texto("autosave_ok") if result.ok else Texto.texto("autosave_failed", [Texto.mensagem(result.message)]), 8)
	else:
		_notify(Texto.mensagem(result.message), 8)

func _load(slot: String = "world") -> void:
	var result := store.load_world(slot)
	if result.ok:
		world = result.world
		var name_value = result.metadata.get("name", Texto.texto("world_restored"))
		world_name = str(name_value).left(48)
		selected_id = world.pet_id
		paused = true
		accumulator = 0
		_reset_session()
		view.set_world(world)
		_set_tool("select")
		_fit_world()
		_refresh()
	_notify(Texto.mensagem(result.message), 10)

func _reset_session() -> void:
	if teaching != null:
		teaching.world = null
	comandos = ComandosAPI.new()
	# Quando o simulador fornecer o adaptador integrado, usa a mesma instância.
	for property in world.get_property_list():
		if property.name == "comandos" and world.get("comandos") != null:
			comandos = world.get("comandos")
	command_target = world.creatures[world.pet_id].pos if world.creatures.has(world.pet_id) else world.size * 0.5
	# O alvo de seguir restaurado deve sobreviver ao primeiro quadro da UI.
	if comandos.has_method("to_dict"):
		var state: Dictionary = comandos.to_dict(world)
		var order: Dictionary = state.get("order", {})
		if order.get("target") is Array and order.target.size() == 2:
			command_target = Vector2(float(order.target[0]), float(order.target[1]))
	view.command_target = command_target
	autosave_elapsed = 0
	autosave_tick = world.tick
	_world_dirty = false
	lab.reset()
	lab.observe(world, selected_id, true)
	roster_ids.clear()
	roster.clear()
	pending_offers.clear()
	receipt_rows.clear()
	observed_drinks.clear()
	for event in world.events:
		if event.type == "drink":
			observed_drinks["%s/%s/%s" % [event.tick, event.creature_id, event.water_id]] = true
	fps_chart.reset()
	last_response.clear()
	chat_response.text = Texto.texto("chat_empty")
	chat_evidence.text = Texto.texto("evidence_none")
	chat_receipt.text = ""
	chat_input.text = ""

func _can_step() -> bool:
	if protected_mode and world.creatures.has(world.pet_id):
		var pet = world.creatures[world.pet_id]
		if pet.energy <= pet.max_energy * 0.15 or pet.age + 1 >= world.max_age:
			paused = true
			accumulator = 0
			_notify(Texto.texto("protection_paused"), 12)
			return false
	return true

func _autosave(delta: float) -> void:
	if not autosave_enabled or _capture_mode:
		return
	autosave_elapsed += delta
	if autosave_elapsed >= 60:
		autosave_elapsed = 0
		if world.tick != autosave_tick or _world_dirty:
			_save("autosave")

func _show_teaching() -> void:
	caregiver_scroll.hide()
	lab_scroll.hide()
	teaching_scroll.show()
	care_button.button_pressed = false
	lab_button.button_pressed = false
	teaching_button.button_pressed = true
	teaching.refresh(true)

func _show_lab(enabled: bool) -> void:
	teaching_scroll.hide()
	teaching_button.button_pressed = false
	caregiver_scroll.visible = not enabled
	lab_scroll.visible = enabled
	lab_button.button_pressed = enabled
	care_button.button_pressed = not enabled
	if world != null:
		lab.observe(world, selected_id, true)

func _build_chat() -> void:
	chat_dialog = _window("chat_title", Vector2i(820, 600))
	var column := _window_column(chat_dialog)
	_wrapped(column, Texto.texto("chat_intro"))
	chat_input = _field(column, Texto.texto("chat_examples"), "", 180)
	chat_input.placeholder_text = Texto.texto("chat_placeholder")
	chat_input.text_submitted.connect(func(_text): _send_chat())
	var questions := HBoxContainer.new()
	column.add_child(questions)
	for key in ["gostos", "aprendizado", "agua"]:
		var question := Texto.texto("question_" + key)
		_button(questions, question, func():
			chat_input.text = question
			_send_chat())
	_button(column, Texto.texto("chat_send"), _send_chat)
	_wrapped(column, Texto.texto("chat_target"))
	chat_response = _wrapped(column, Texto.texto("chat_empty"))
	chat_receipt = _wrapped(column, "")
	chat_receipt.add_theme_color_override("font_color", Color("dbe8a5"))
	_separator(column)
	_label(column, Texto.texto("evidence_title"), 13, Color("bccc98"))
	chat_evidence = _wrapped(column, Texto.texto("evidence_none"))

func _send_chat() -> void:
	var intent := DialogoAPI.interpretar(chat_input.text)
	var pet = world.creatures.get(world.pet_id)
	last_response = DialogoAPI.responder(intent, pet, world)
	chat_response.text = str(last_response.texto)
	var receipt := comandos.aplicar(intent, world, command_target)
	_world_dirty = _world_dirty or (receipt.aceito and intent.intent != "perguntar_estado" and intent.intent not in DialogoAPI.CONSULTAS)
	chat_receipt.text = str(receipt.texto)
	if intent.intent in DialogoAPI.CONSULTAS:
		chat_receipt.text = Texto.texto("query_receipt")
	if receipt.aceito and intent.intent == "proteger":
		protected_mode = true
		chat_receipt.text = Texto.texto("protection_active")
		_sync_settings()
	elif receipt.aceito and not receipt.aplicado:
		var integrated := false
		for property in world.get_property_list():
			if property.name == "comandos":
				integrated = true
		if not integrated:
			chat_receipt.text += " " + Texto.texto("chat_pending")
	var rows: Array[String] = []
	if not last_response.evidencias.is_empty():
		rows.append(Texto.texto("evidence_snapshot", [world.tick, world.pet_id]))
	for evidence in last_response.evidencias:
		var source := Texto.fonte_e4(evidence)
		if not source.is_empty():
			rows.append(source)
			continue
		var field: String = str(evidence.get("campo", "events"))
		var value = evidence.get("valor")
		var shown := ""
		match field:
			"last_action": shown = Texto.acao(str(value))
			"last_reason": shown = Texto.razao(str(value))
			"events": shown = Texto.evento(value) if value is Dictionary else Texto.texto("lab_none")
			"foods": shown = str(value)
			_: shown = Texto.numero(float(value), 3) if value is float else str(value)
		rows.append(Texto.texto("evidence_value", [Texto.texto("evidence_" + field), shown]))
	chat_evidence.text = Texto.texto("evidence_none") if rows.is_empty() else "\n".join(rows)
	lab.observe(world, selected_id, true)
	teaching.refresh(true)

func _build_settings() -> void:
	settings_dialog = _window("settings_title", Vector2i(620, 600))
	settings_dialog.ok_button_text = Texto.texto("apply")
	var column := _window_column(settings_dialog)
	_label(column, Texto.texto("settings_speed"), 14)
	settings_speed = OptionButton.new()
	for multiplier in [1, 2, 5]:
		settings_speed.add_item(Texto.texto("speed", [multiplier]))
	column.add_child(settings_speed)
	_label(column, Texto.texto("initial_population"), 14)
	population_input = _population_field(column)
	protection_input = CheckButton.new()
	protection_input.text = Texto.texto("protected_mode")
	column.add_child(protection_input)
	_wrapped(column, Texto.texto("protected_info"))
	var warning := _wrapped(column, Texto.texto("survival_warning"))
	warning.add_theme_color_override("font_color", Color("f0c19a"))
	autosave_input = CheckButton.new()
	autosave_input.text = Texto.texto("autosave")
	column.add_child(autosave_input)
	_wrapped(column, Texto.texto("autosave_info"))
	_button(column, Texto.texto("autosave_load"), func():
		settings_dialog.hide()
		_load("autosave"))
	settings_dialog.confirmed.connect(_apply_settings)
	_sync_settings()

func _open_settings() -> void:
	_sync_settings()
	settings_dialog.popup_centered()

func _sync_settings() -> void:
	if settings_speed == null:
		return
	settings_speed.select([1.0, 2.0, 5.0].find(speed))
	population_input.value = initial_population
	protection_input.button_pressed = protected_mode
	autosave_input.button_pressed = autosave_enabled

func _apply_settings() -> void:
	_set_speed([1.0, 2.0, 5.0][settings_speed.selected])
	initial_population = int(population_input.value)
	new_population.value = initial_population
	protected_mode = protection_input.button_pressed
	autosave_enabled = autosave_input.button_pressed
	var config := ConfigFile.new()
	config.set_value("ui", "initial_population", initial_population)
	config.set_value("ui", "protected_mode", protected_mode)
	config.set_value("ui", "autosave_enabled", autosave_enabled)
	config.set_value("ui", "speed", speed)
	_notify(Texto.texto("settings_saved" if config.save(settings_path) == OK else "settings_failed"))
	_refresh()

func _read_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	var population = config.get_value("ui", "initial_population", 12)
	if population is int or population is float:
		initial_population = clampi(int(population), 1, 100)
	protected_mode = config.get_value("ui", "protected_mode", true) == true
	autosave_enabled = config.get_value("ui", "autosave_enabled", true) == true
	var saved_speed = config.get_value("ui", "speed", 1.0)
	if saved_speed in [1.0, 2.0, 5.0]:
		speed = float(saved_speed)

func _build_help() -> void:
	help_dialog = _window("help_title", Vector2i(650, 570))
	_wrapped(_window_column(help_dialog), Texto.texto("social_help") + "\n\n" + Texto.texto("help_body"))

func _population_field(parent: Node) -> SpinBox:
	var field := SpinBox.new()
	field.min_value = 1
	field.max_value = 100
	field.step = 1
	parent.add_child(field)
	var menu := field.get_line_edit().get_menu()
	_localize_edit_menu(menu)
	menu.about_to_popup.connect(_localize_edit_menu.bind(menu))
	return field

func _window(code: String, dimensions: Vector2i) -> AcceptDialog:
	var dialog := AcceptDialog.new()
	dialog.title = Texto.texto(code)
	dialog.ok_button_text = Texto.texto("close")
	dialog.min_size = dimensions
	dialog.theme = ui.theme
	dialog.exclusive = false
	ui.add_child(dialog)
	return dialog

func _window_column(dialog: AcceptDialog) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	return column

func _wrapped(parent: Node, value: String) -> Label:
	# A quebra deve existir antes de anexar: Window preserva o tamanho que
	# assumiu quando um Label temporariamente sem quebra pediu toda a linha.
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("c8d6c0"))
	parent.add_child(label)
	return label

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
	for argument in arguments:
		if argument.begins_with("--fps-benchmark="):
			await _benchmark_fps(path)
			get_tree().quit()
			return
	if state.begins_with("e3-"):
		await _capture_e3(state, path)
		get_tree().quit()
		return
	if state.begins_with("e4-"):
		await _capture_e4(state, path)
		get_tree().quit()
		return
	if state.begins_with("e2-"):
		await _capture_e2(state, path)
		get_tree().quit()
		return
	if state.begins_with("e1-"):
		await _capture_e1(state, path)
		get_tree().quit()
		return
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
	if state in ["laboratory", "lineage", "signals"]:
		for i in range(1080):
			world.step()
			if world.tick % 50 == 0:
				lab.observe(world, selected_id)
		var generation := -1
		for creature in world.creatures.values():
			if creature.genome.generation > generation:
				selected_id = creature.id
				generation = creature.genome.generation
		_show_lab(true)
		_refresh()
		await get_tree().process_frame
		if state == "lineage":
			lab_scroll.scroll_vertical = int(lab.mutations.position.y) - 35
		if state == "signals":
			if world.has_method("emitir_sinal"):
				lab.signal_switch.button_pressed = true
				lab.emit_button.pressed.emit()
				world.step()
				lab.observe(world, selected_id, true)
				_refresh()
				await get_tree().process_frame
			lab_scroll.scroll_vertical = int(lab.signals.position.y) - 45
	if state == "dialogue":
		chat_input.text = Texto.texto("chat_placeholder")
		_send_chat()
		chat_dialog.popup_centered()
	if state == "settings":
		_open_settings()
	if state == "help":
		help_dialog.popup_centered()
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

func _e4_inspection_fixture(approach: bool = false, contention: bool = false) -> void:
	# Explicit visual fixture, never used by new/load gameplay paths.
	world = World.new_world(51001, {"creature_count": 0, "food_count": 0, "water_count": 0, "obstacle_count": 0, "food_regrow": false, "reproduction_enabled": false, "signal_noise": 0.0})
	world.pet_id = world.spawn_creature(Vector2(300, 200), Texto.NOMES_INICIAIS[0])
	world.spawn_creature(Vector2(375 if approach else 320, 200), Texto.NOMES_INICIAIS[1])
	for creature in world.creatures.values():
		# Inspection only: full field of view makes the encounter reproducible.
		creature.genome.vision_fov = floorf(TAU * 1000000.0) / 1000000.0
		world.genealogy.records[creature.id].genome = creature.genome.to_dict()
		creature.energy = creature.max_energy * 0.95
		if contention:
			creature.energy = creature.max_energy * 0.5
		creature.heading = 0
		if approach:
			creature.personality.loneliness = 1.0
	selected_id = world.pet_id
	paused = true
	_reset_session()
	view.set_world(world)
	if contention:
		world.place_food(Vector2(310, 200), "fruta")
	world.step()
	command_target = Vector2(700, 400)
	view.command_target = command_target
	_refresh()
	personality_inspector.current_tab = 4
	camera.zoom = Vector2.ONE * 1.4
	camera.position = Vector2(340, 220) + _camera_bias()
	_notify(Texto.texto("social_demo"), 30)

func _capture_e4(state: String, path: String) -> void:
	_e4_inspection_fixture(state == "e4-approach", state == "e4-aversao")
	var pet = world.creatures[world.pet_id]
	if state == "e4-gostos":
		pet.energy = pet.max_energy * 0.5
		world._eat(pet, world.place_food(pet.pos, "fruta"))
	if state == "e4-aprendizado":
		for index in range(5):
			teaching.mark(pet.pos)
			teaching.observe_button.pressed.emit()
			world.step()
			teaching.refresh(true)
	if state == "e4-agua":
		world.place_water(pet.pos + Vector2(35, 0), 18)
	if state in ["e4-gostos", "e4-nao-sei", "e4-aprendizado", "e4-agua"]:
		chat_input.text = Texto.texto("question_" + ("gostos" if state in ["e4-gostos", "e4-nao-sei"] else state.trim_prefix("e4-")))
		_send_chat()
		chat_dialog.popup_centered()
	if state.begins_with("e4-sinais"):
		_show_lab(true)
		lab.signal_switch.button_pressed = true
		lab.emit_button.pressed.emit()
		world.step()
		lab.observe(world, selected_id, true)
	_refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	if state.begins_with("e4-sinais"):
		lab_scroll.scroll_vertical = int(lab.signal_result.position.y) - 30
		if state == "e4-sinais-log":
			lab_scroll.scroll_vertical = int(lab.signal_controls.position.y)
	if state == "e4-encontros":
		caregiver_scroll.scroll_vertical = int(personality_inspector.position.y) - 8
		personality_inspector.get_child(4).scroll_vertical = int(personality_inspector.encounters.position.y) - 80
	var warmup := Time.get_ticks_msec() + 900
	while Time.get_ticks_msec() < warmup:
		await get_tree().process_frame
	await capture_screenshot(path)

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
	_wrapped(parent, caption)
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


func _food_icon(kind: String) -> Texture2D:
	return preload("res://scripts/render/food_shapes.gd").icon(kind)

func _choose_food(kind: String) -> void:
	food_type = kind
	for key in food_buttons:
		food_buttons[key].button_pressed = key == kind
	_set_tool("food")
	_refresh()

func _refresh_roster() -> void:
	var ids: Array = world.creatures.keys()
	if ids != roster_ids:
		roster_ids = ids
		roster.clear()
		for id in ids:
			var creature = world.creatures[id]
			roster.add_item("%s · #%d" % [Texto.nome_criatura(creature.name), id], id)
	for index in range(ids.size()):
		var creature = world.creatures[ids[index]]
		roster.set_item_text(index, "%s · %s" % [Texto.nome_criatura(creature.name), PersonalityInspector.urgent(creature, world)])
	roster.tooltip_text = Texto.texto("roster", [ids.size()])
	roster.select(ids.find(selected_id))

func _receipt(message: String) -> void:
	receipt_rows.append(message)
	if receipt_rows.size() > 32:
		receipt_rows.pop_front()
	_notify(message, 9)

func _offer_food() -> void:
	if not world.creatures.has(selected_id):
		_notify(Texto.texto("offer_none"))
		return
	var id: int = world.oferecer_alimento(selected_id, food_type)
	if id < 0:
		_notify(Texto.texto("offer_blocked"))
		return
	var creature = world.creatures[selected_id]
	for food in world.foods:
		if food.id == id:
			pending_offers.append({"id": id, "creature_id": selected_id, "name": Texto.nome_criatura(creature.name), "pos": food.pos, "distance": creature.pos.distance_to(food.pos), "tick": world.tick, "approached": false})
	_receipt(Texto.texto("offer_placed", [world.tick, id, Texto.texto("food_" + food_type), Texto.nome_criatura(creature.name)]))
	_world_dirty = true
	_refresh()

func _observe_physical_events() -> void:
	# Aproximação é medida por posição. Refeição/bebida exigem evento positivo.
	for offer in pending_offers.duplicate():
		var creature = world.creatures.get(offer.creature_id)
		if creature != null and not offer.approached:
			var distance: float = creature.pos.distance_to(offer.pos)
			if distance < float(offer.distance) - 0.5:
				offer.approached = true
				_receipt(Texto.texto("offer_approached", [world.tick, offer.name, offer.id, Texto.numero(offer.distance), Texto.numero(distance)]))
		var ate := false
		for event in world.events:
			if event.type == "eat" and int(event.get("food_id", -1)) == int(offer.id) and int(event.creature_id) == int(offer.creature_id) and int(event.tick) >= int(offer.tick) and float(event.get("energy", 0)) > 0:
				_receipt(Texto.texto("offer_eaten", [event.tick, offer.name, offer.id, Texto.numero(event.energy)]))
				ate = true
				break
		var exists := false
		for food in world.foods:
			if int(food.id) == int(offer.id):
				exists = true
				break
		if ate or not exists or creature == null:
			if not ate:
				_receipt(Texto.texto("offer_no_meal", [world.tick, offer.id]))
			pending_offers.erase(offer)
	for event in world.events:
		if event.type == "drink" and float(event.get("hydration", 0)) > 0:
			var key := "%s/%s/%s" % [event.tick, event.creature_id, event.water_id]
			if not observed_drinks.has(key):
				observed_drinks[key] = true
				_receipt(Texto.evento(event))
	if observed_drinks.size() > World.EVENT_LIMIT * 2:
		var retained: Dictionary = {}
		for event in world.events:
			if event.type == "drink":
				retained["%s/%s/%s" % [event.tick, event.creature_id, event.water_id]] = true
		observed_drinks = retained

func _build_expand() -> void:
	expand_dialog = ConfirmationDialog.new()
	expand_dialog.title = Texto.texto("expand_title")
	expand_dialog.ok_button_text = Texto.texto("expand_confirm")
	expand_dialog.cancel_button_text = Texto.texto("keep_exploring")
	expand_dialog.min_size = Vector2i(580, 370)
	expand_dialog.theme = ui.theme
	expand_dialog.dialog_hide_on_ok = false
	ui.add_child(expand_dialog)
	var column := _window_column(expand_dialog)
	_label(column, Texto.texto("expand_side"), 14)
	expand_side = OptionButton.new()
	expand_side.add_item(Texto.texto("expand_right"))
	expand_side.add_item(Texto.texto("expand_bottom"))
	column.add_child(expand_side)
	_label(column, Texto.texto("expand_amount"), 14)
	expand_amount = SpinBox.new()
	expand_amount.min_value = 1
	expand_amount.max_value = 100000
	expand_amount.step = 1
	expand_amount.value = 300
	column.add_child(expand_amount)
	var menu := expand_amount.get_line_edit().get_menu()
	_localize_edit_menu(menu)
	menu.about_to_popup.connect(_localize_edit_menu.bind(menu))
	expand_preview = _wrapped(column, "")
	expand_side.item_selected.connect(func(_index): _update_expand_preview())
	expand_amount.value_changed.connect(func(_value): _update_expand_preview())
	expand_dialog.confirmed.connect(_confirm_expand)

func _open_expand() -> void:
	paused = true
	_update_expand_preview()
	expand_dialog.popup_centered()

func _update_expand_preview() -> void:
	var target: Vector2 = world.size
	target[expand_side.selected] += expand_amount.value
	var valid := target.x <= 100000 and target.y <= 100000
	expand_dialog.get_ok_button().disabled = not valid
	var area: float = expand_amount.value * world.size[1 - expand_side.selected]
	expand_preview.text = Texto.texto("expand_preview", [Texto.numero(world.size.x, 0), Texto.numero(world.size.y, 0), Texto.numero(target.x, 0), Texto.numero(target.y, 0), Texto.numero(area, 0)])
	if not valid:
		expand_preview.text += "\n" + Texto.texto("expand_invalid")

func _confirm_expand() -> void:
	if world.expand("right" if expand_side.selected == 0 else "bottom", expand_amount.value):
		expand_dialog.hide()
		view.set_world(world)
		_fit_world()
		_world_dirty = true
		_notify(Texto.texto("expand_ok", [Texto.numero(world.size.x, 0), Texto.numero(world.size.y, 0)]), 10)
		_refresh()
	else:
		expand_preview.text = Texto.texto("expand_invalid")


func _capture_e1(state: String, path: String) -> void:
	# Exercita as mesmas ações da interface; cenários permanecem identificados.
	if state == "e1-expand-before":
		_open_expand()
	if state == "e1-expand-after":
		expand_side.select(0)
		expand_amount.value = 300
		_confirm_expand()
		expand_side.select(1)
		expand_amount.value = 200
		_confirm_expand()
	if state == "e1-water":
		var creature = world.creatures[selected_id]
		creature.hydration = 25
		world.place_water(creature.pos, 30)
		world.step()
		_observe_physical_events()
		camera.zoom = Vector2.ONE * 1.1
		camera.position = creature.pos + _camera_bias()
	if state == "e1-foods":
		_choose_food("cogumelo")
	if state in ["e1-offer", "e1-inspector"]:
		# Fixture explícita: fome/sede baixas para observar física sem longa espera.
		# Criaturas não são deslocadas e ingestão/bebida usam o executor real.
		var creature = world.creatures[selected_id]
		world.foods.clear()
		creature.energy = 48
		creature.hydration = 35
		view.show_sensors = false
		world.place_water(creature.pos, 30)
		_offer_food()
		for i in range(120):
			world.step()
			_observe_physical_events()
			if not pending_offers.is_empty():
				continue
			if creature.hydration > 40 and creature.energy > 48:
				break
		if state == "e1-inspector":
			creature.hydration = 25
			_choose_food("cogumelo")
		selected_id = creature.id
		camera.zoom = Vector2.ONE * 1.1
		camera.position = creature.pos + _camera_bias()
	_refresh()
	var warmup := Time.get_ticks_msec() + 1400
	while Time.get_ticks_msec() < warmup:
		await get_tree().process_frame
	if state in ["e1-offer", "e1-inspector"]:
		caregiver_scroll.scroll_vertical = int(receipts.position.y) - 30 if state == "e1-offer" else 110
		await get_tree().process_frame
		await get_tree().process_frame
	await capture_screenshot(path)

func _benchmark_fps(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		printerr("O benchmark gráfico exige uma janela renderizada.")
		get_tree().quit(1)
		return
	protected_mode = false
	paused = false
	_set_speed(1)
	var warmup := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < warmup:
		await get_tree().process_frame
	fps_chart.reset()
	var intervals: Array[float] = []
	var start := Time.get_ticks_usec()
	var previous := start
	while Time.get_ticks_usec() - start < 8000000:
		await RenderingServer.frame_post_draw
		var current := Time.get_ticks_usec()
		intervals.append(float(current - previous) / 1000000.0)
		previous = current
	var elapsed := float(previous - start) / 1000000.0
	var mean := intervals.size() / elapsed
	intervals.sort()
	var p95: float = intervals[int((intervals.size() - 1) * 0.95)] * 1000
	var result := {"initial_population": initial_population, "final_population": world.creatures.size(), "frames": intervals.size(), "seconds": elapsed, "mean_fps": mean, "p95_frame_ms": p95, "godot": Engine.get_version_info().string, "adapter": RenderingServer.get_video_adapter_name(), "display": DisplayServer.get_name(), "window": [get_window().size.x, get_window().size.y], "speed": speed, "tick": world.tick}
	var output := FileAccess.open(path.get_basename() + ".json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	output.close()
	paused = true
	_notify(Texto.texto("fps_sample", [world.creatures.size(), Texto.numero(mean), Texto.numero(1.0 / intervals.back())]), 15)
	print(JSON.stringify(result))
	await capture_screenshot(path)


func _compact_buttons(row: Container) -> void:
	for child in row.get_children():
		if child is Button:
			child.add_theme_font_size_override("font_size", 14)
			child.add_theme_stylebox_override("normal", GardenTheme.panel(Color("354e42"), 8, 8))
			child.add_theme_stylebox_override("hover", GardenTheme.panel(Color("496454"), 8, 8))
			child.add_theme_stylebox_override("pressed", GardenTheme.panel(Color("d5deaa"), 8, 8))


func _give_attention(pos: Vector2) -> void:
	if not world.creatures.has(selected_id):
		_receipt(Texto.texto("attention_none"))
		return
	if not world.personality_enabled:
		_receipt(Texto.texto("attention_legacy"))
		return
	var creature = world.creatures[selected_id]
	# Always let the simulator validate range, occlusion and the encounter interval.
	if world.interagir_jogador(selected_id, pos):
		_receipt(Texto.texto("attention_ok", [world.tick, Texto.nome_criatura(creature.name)]))
		_world_dirty = true
	elif creature.pos.distance_to(pos) > creature.genome.size + 5:
		_receipt(Texto.texto("attention_far"))
	elif creature.personality.bonds.has("player") and world.tick - int(creature.personality.bonds.player.last_tick) < 30:
		_receipt(Texto.texto("attention_wait", [30 - (world.tick - int(creature.personality.bonds.player.last_tick))]))
	else:
		_receipt(Texto.texto("attention_blocked"))

func _capture_e2(state: String, path: String) -> void:
	# Explicit fixture: physiological deficits, then real physical ingest/contact.
	var creature = world.creatures[selected_id]
	if state not in ["e2-garden", "e2-roster"]:
		creature.energy = 48
		creature.hydration = 35
		creature.personality.fatigue = 0.72
		creature.personality.boredom = 0.43
		creature.personality.loneliness = 0.58
		# Food, rather than the creature, is placed at contact range for this fixture.
		world.place_food(creature.pos, "fruta")
		var item: Dictionary = world.foods.back()
		world._eat(creature, item.id)
		_give_attention(creature.pos)
		if state == "e2-attention":
			_give_attention(creature.pos)
		camera.zoom = Vector2.ONE * 1.25
		camera.position = creature.pos + _camera_bias()
	_refresh()
	var tabs := {"e2-traits": 1, "e2-memory": 2, "e2-preferences": 3, "e2-bonds": 4}
	personality_inspector.current_tab = tabs.get(state, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	caregiver_scroll.scroll_vertical = int(personality_inspector.position.y) - 6 if state not in ["e2-garden", "e2-roster"] else 0
	if state == "e2-roster":
		roster.show_popup()
	if state == "e2-attention":
		caregiver_scroll.scroll_vertical = int(receipts.position.y) - 24
	if state == "e2-expression":
		var body_scroll: ScrollContainer = personality_inspector.get_child(0)
		body_scroll.scroll_vertical = int(personality_inspector.expression.position.y) - 8
	var warmup := Time.get_ticks_msec() + 1200
	while Time.get_ticks_msec() < warmup:
		await get_tree().process_frame
	await capture_screenshot(path)


func _capture_e3(state: String, path: String) -> void:
	# Explicit open-terrain fixture; real API, physics and Q updates throughout.
	world = World.new_world(7421, {"creature_count": 1, "food_count": 0, "obstacle_count": 0, "water_count": 0, "food_regrow": false, "reproduction_enabled": false})
	selected_id = world.pet_id
	world.creatures[selected_id].name = Texto.texto("pet_default")
	_reset_session()
	view.set_world(world)
	_refresh()
	_show_teaching()
	var creature = world.creatures[selected_id]
	var direction: Vector2 = (world.size * 0.5 - creature.pos).normalized()
	teaching.mark(creature.pos + direction * 120)
	if state == "e3-water":
		world.place_water(creature.pos + direction * 70, 24)
		creature.hydration = 65
		teaching.skill.select(1)
		teaching.skill.item_selected.emit(1)
	teaching.show_button.pressed.emit()
	if state != "e3-route":
		for i in range(200):
			world.step()
			if not creature.ensino.running():
				break
		teaching.refresh(true)
		if state in ["e3-reward", "e3-events", "e3-water"]:
			teaching.reward_button.pressed.emit()
		if state == "e3-observe":
			teaching.mark(creature.pos + direction * 75)
			teaching.observe_button.pressed.emit()
		if state in ["e3-history", "e3-learned"]:
			# Evaluate retained real outcomes; no fabricated learned badge.
			teaching.reward_button.pressed.emit()
			for trial in range(5):
				teaching.mark(creature.pos + Vector2.from_angle(creature.heading) * 40)
				teaching.observe_button.pressed.emit()
				for step_index in range(200):
					world.step()
					if not creature.ensino.running():
						break
				teaching.refresh(true)
				if not teaching.reward_button.disabled:
					teaching.reward_button.pressed.emit()
	_refresh()
	camera.zoom = Vector2.ONE * 1.25
	camera.position = creature.pos + direction * 45 + _camera_bias()
	await get_tree().process_frame
	await get_tree().process_frame
	if state in ["e3-history", "e3-events"]:
		teaching_scroll.scroll_vertical = int(teaching.metrics.position.y) - 4 if state == "e3-history" else int(teaching.events.position.y) - 35
	if state == "e3-reset":
		teaching.reset_button.pressed.emit()
	var warmup := Time.get_ticks_msec() + 1200
	while Time.get_ticks_msec() < warmup:
		await get_tree().process_frame
	await capture_screenshot(path)
