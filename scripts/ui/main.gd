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
const KnowledgePresenter = preload("res://scripts/ui/knowledge_presenter.gd")
const TerminalPresenter = preload("res://scripts/ui/terminal_presenter.gd")
const Books = preload("res://scripts/library/book_catalog.gd")
const ObjectPresenter = preload("res://scripts/ui/object_presenter.gd")
const Atelier = preload("res://scripts/atelier/atelier.gd")
const AtelierCanvas = preload("res://scripts/ui/atelier_canvas.gd")
const DEMO_SHAPES := ["linha", "circulo", "quadrado"]
const OBJECT_TYPES := ["capsula_neutra", "capsula_agradavel", "capsula_aversiva", "pedra"]
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
var mind_emotion: Label
var mind_desire: Label
var mind_reason: Label
var mind_enable: Button
var mind_cost: Label
var mind_intensity: ProgressBar
var book_dialog: AcceptDialog
var book_choice: OptionButton
var book_description: Label
var book_type := "guia_capsulas"
var knowledge_dialog: AcceptDialog
var knowledge_text: Label
var reading_text: Label
var terminal_activity_label: Label
var terminal_dialog: AcceptDialog
var terminal_panel_text: Label
var terminal_console_dialog: AcceptDialog
var console_warning_label: Label
var console_device_choice: OptionButton
var console_input: LineEdit
var console_output: Label
var manual_dialog: AcceptDialog
var manual_choice: OptionButton
var refuse_dialog: AcceptDialog
var refuse_duration_input: SpinBox
var question_card: VBoxContainer
var question_text: Label
var question_buttons: Dictionary = {}
var _question_id := ""
var _question_creature := -1
var tutorial_step := 0
var tutorial_text: Label
var tutorial_dialog: AcceptDialog
var object_dialog: AcceptDialog
var object_choice: OptionButton
var object_type := "capsula_neutra"
var object_reaction: Label
var object_activity: Label
var _object_sensor_key := ""
var _visible_objects: Array = []
var demo_dialog: AcceptDialog
var demo_shape_choice: OptionButton
var demo_scale_input: SpinBox
var demo_center_x_input: SpinBox
var demo_center_y_input: SpinBox
var demo_preview_canvas: Control
var demo_shape := "linha"
var board_canvas: Control
var board_status_label: Label
var board_live_label: Label
var gallery_title_label: Label
var gallery_empty_label: Label
var gallery_list: VBoxContainer
var _gallery_signature := ""
var _selected_board_id := -1
@onready var view = $WorldView
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("152d25"))
	get_window().min_size = Vector2i(1100, 680)
	var capture := _capture_options(OS.get_cmdline_user_args(), OS.is_debug_build())
	_capture_mode = not capture.path.is_empty()
	if _capture_mode and capture.benchmark:
		initial_population = capture.population
	if DisplayServer.get_name() != "headless" and not _capture_mode:
		_read_settings()
	_build_ui()
	_build_new_dialog()
	_build_chat()
	_build_settings()
	_build_help()
	_build_tutorial()
	_build_expand()
	_build_objects()
	_build_demo()
	_build_library()
	_build_terminal_ui()
	_set_speed(speed)
	create_world(Texto.texto("world_default"), Texto.texto("pet_default"), 7421)
	get_viewport().size_changed.connect(_fit_world)
	# Reproducible capture mode uses this same running scene and real SimWorld.
	var capture_path: String = capture.path
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
	_show_lab(false)
	_focus_selected()
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
	view.show_pointer = _over_world(get_viewport().get_mouse_position()) and not new_dialog.visible and (demo_dialog == null or not demo_dialog.visible)
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
	roster = OptionButton.new()
	roster.fit_to_longest_item = false
	roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster.item_selected.connect(func(index):
		selected_id = roster.get_item_id(index)
		_focus_selected()
		_refresh()
		lab.observe(world, selected_id, true))
	side_column.add_child(roster)
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
	mode_note.hide()
	question_card = VBoxContainer.new()
	inspector.add_child(question_card)
	question_text = _wrapped(question_card, "")
	question_text.add_theme_color_override("font_color", Color("fff0bb"))
	_wrapped(question_card, Texto.texto("m3c_question_note"))
	var answers := GridContainer.new()
	answers.columns = 2
	question_card.add_child(answers)
	for option in ["evitar", "seguro", "neutro", "silencio"]:
		question_buttons[option] = _button(answers, Texto.texto("m3c_answer_" + option), _answer_question.bind(option))
		question_buttons[option].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		question_buttons[option].add_theme_font_size_override("font_size", 12)
	question_card.hide()
	reading_text = _wrapped(inspector, "")
	terminal_activity_label = _wrapped(inspector, "")
	_button(inspector, Texto.texto("m3c_open"), _open_knowledge)
	_button(inspector, Texto.texto("m3c_tutorial_btn"), _open_library_tutorial)
	_button(inspector, Texto.texto("m4b_terminal_btn"), _open_terminal_panel)
	_button(inspector, Texto.texto("m4b_offer_manual_btn"), _open_offer_manual)
	_button(inspector, Texto.texto("m4b_refuse_btn"), _open_refuse_dialog)
	_button(inspector, Texto.texto("m4b_tutorial_btn"), _open_terminal_tutorial)
	_label(inspector, Texto.texto("m1_state"), 12, Color("bccc98"))
	mind_emotion = _wrapped(inspector, "")
	mind_emotion.add_theme_font_size_override("font_size", 20)
	mind_intensity = ProgressBar.new()
	mind_intensity.custom_minimum_size.y = 5
	mind_intensity.show_percentage = false
	inspector.add_child(mind_intensity)
	_label(inspector, Texto.texto("m1_desire"), 12, Color("bccc98"))
	mind_desire = _wrapped(inspector, "")
	mind_desire.add_theme_font_size_override("font_size", 20)
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", GardenTheme.panel(Color("354e42"), 10, 10))
	inspector.add_child(bubble)
	mind_reason = _wrapped(bubble, "")
	_label(inspector, Texto.texto("m2_reaction"), 12, Color("bccc98"))
	object_reaction = _wrapped(inspector, "")
	object_reaction.add_theme_font_size_override("font_size", 17)
	object_activity = _wrapped(inspector, "")
	mind_cost = _wrapped(inspector, Texto.texto("m1_cost"))
	mind_enable = _button(inspector, Texto.texto("m1_enable"), _enable_selected_mind)
	_wrapped(inspector, Texto.texto("m1_note"))
	_button(inspector, Texto.texto("m1_tutorial"), func(): tutorial_dialog.popup_centered())
	offer_button = _button(inspector, Texto.texto("offer"), _offer_food)
	_separator(inspector)
	_label(inspector, Texto.texto("m1_observe"), 12, Color("bccc98"))
	_button(inspector, Texto.texto("m2_present"), _open_objects)
	_button(inspector, Texto.texto("m1_companion"), _present_companion)
	_button(inspector, Texto.texto("m1_obstacle"), _set_tool.bind("obstacle"))
	_button(inspector, Texto.texto("m1_clear"), _clear_nearby_rocks)
	_wrapped(inspector, Texto.texto("m1_observe_note"))
	personality_inspector = PersonalityInspector.new()
	_button(inspector, Texto.texto("chat_open"), func(): chat_dialog.popup_centered())
	var attention := _button(inspector, Texto.texto("tool_attention"), _set_tool.bind("attention"))
	attention.tooltip_text = Texto.texto("attention_help")
	attention.toggle_mode = true
	tool_buttons["attention"] = attention
	_separator(inspector)
	_label(inspector, Texto.texto("m3_title"), 12, Color("bccc98"))
	var board_row := HBoxContainer.new()
	board_row.add_theme_constant_override("separation", 8)
	inspector.add_child(board_row)
	board_canvas = AtelierCanvas.new()
	board_row.add_child(board_canvas)
	var board_info := VBoxContainer.new()
	board_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_row.add_child(board_info)
	board_status_label = _wrapped(board_info, Texto.texto("m3_board_none"))
	board_live_label = _wrapped(board_info, "")
	board_live_label.add_theme_color_override("font_color", Color("dbe8a5"))
	_button(inspector, Texto.texto("m3_present"), _set_tool.bind("board"))
	_button(inspector, Texto.texto("m3_open_demo"), _open_demo)
	var quick_demo := HBoxContainer.new()
	inspector.add_child(quick_demo)
	for shape_key in DEMO_SHAPES:
		var shape_btn := _button(quick_demo, Texto.texto("shape_" + shape_key), _demonstrate_shape.bind(shape_key))
		shape_btn.add_theme_font_size_override("font_size", 13)
		shape_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(inspector, Texto.texto("m3_tutorial_btn"), _open_atelier_tutorial)
	gallery_title_label = _label(inspector, Texto.texto("m3_gallery"), 12, Color("bccc98"))
	gallery_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gallery_empty_label = _wrapped(inspector, Texto.texto("m3_gallery_empty"))
	gallery_list = VBoxContainer.new()
	gallery_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gallery_list.add_theme_constant_override("separation", 6)
	inspector.add_child(gallery_list)
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
	var details := _button(inspector, Texto.texto("m1_details"), func(): personality_inspector.visible = not personality_inspector.visible)
	details.toggle_mode = true
	inspector.add_child(personality_inspector)
	personality_inspector.hide()
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
	tool_buttons["object"] = _button(toolbar, Texto.texto("tool_object"), _open_objects)
	tool_buttons.object.toggle_mode = true
	tool_buttons["board"] = _button(toolbar, Texto.texto("tool_board"), _set_tool.bind("board"))
	tool_buttons.board.toggle_mode = true
	tool_buttons["demo"] = _button(toolbar, Texto.texto("tool_demo"), _open_demo)
	tool_buttons.demo.toggle_mode = true
	var food_row := HBoxContainer.new()
	bottom_col.add_child(food_row)
	tool_buttons["book"] = _button(food_row, Texto.texto("tool_book"), _open_books)
	tool_buttons.book.toggle_mode = true
	tool_buttons["terminal"] = _button(food_row, Texto.texto("tool_terminal"), _set_tool.bind("terminal"))
	tool_buttons.terminal.toggle_mode = true
	_button(food_row, Texto.texto("m4b_console_btn"), _open_terminal_console)
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
	if new_dialog.visible or chat_dialog.visible or settings_dialog.visible or help_dialog.visible or expand_dialog.visible or teaching.reset_dialog.visible or (tutorial_dialog != null and tutorial_dialog.visible) or (object_dialog != null and object_dialog.visible) or (demo_dialog != null and demo_dialog.visible) or (book_dialog != null and book_dialog.visible) or (knowledge_dialog != null and knowledge_dialog.visible) or (terminal_dialog != null and terminal_dialog.visible) or (terminal_console_dialog != null and terminal_console_dialog.visible) or (manual_dialog != null and manual_dialog.visible) or (refuse_dialog != null and refuse_dialog.visible):
		return
	if event is InputEventMouseButton and _over_world(event.position):
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			command_target = get_global_mouse_position().clamp(Vector2.ZERO, world.size)
			view.command_target = command_target
			view.show_command_target = true
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
	if new_dialog == null or new_dialog.visible or chat_dialog.visible or settings_dialog.visible or help_dialog.visible or expand_dialog.visible or teaching.reset_dialog.visible or (tutorial_dialog != null and tutorial_dialog.visible) or (object_dialog != null and object_dialog.visible) or (demo_dialog != null and demo_dialog.visible) or (book_dialog != null and book_dialog.visible) or (knowledge_dialog != null and knowledge_dialog.visible) or (terminal_dialog != null and terminal_dialog.visible) or (terminal_console_dialog != null and terminal_console_dialog.visible) or (manual_dialog != null and manual_dialog.visible) or (refuse_dialog != null and refuse_dialog.visible):
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
	if world == null or new_dialog.visible or chat_dialog.visible or settings_dialog.visible or help_dialog.visible or expand_dialog.visible or teaching.reset_dialog.visible or (tutorial_dialog != null and tutorial_dialog.visible) or (object_dialog != null and object_dialog.visible) or (demo_dialog != null and demo_dialog.visible) or (book_dialog != null and book_dialog.visible) or (knowledge_dialog != null and knowledge_dialog.visible) or (terminal_dialog != null and terminal_dialog.visible) or (terminal_console_dialog != null and terminal_console_dialog.visible) or (manual_dialog != null and manual_dialog.visible) or (refuse_dialog != null and refuse_dialog.visible):
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
		"object":
			var id := world.place_object(pos, object_type)
			_notify(Texto.texto("m2_placed", [id]) if id >= 0 else Texto.texto("m2_blocked"), 10)
		"book":
			var id := world.place_book(pos, book_type)
			_notify(Texto.texto("m3c_placed", [id, Texto.texto("book_" + book_type)]) if id >= 0 else Texto.texto("m3c_blocked"), 10)
		"terminal":
			var id := world.place_terminal(pos)
			_notify(Texto.texto("m4b_placed", [id]) if id >= 0 else Texto.texto("m4b_blocked"), 10)
		"board":
			var id := world.place_board(pos)
			if id >= 0:
				_selected_board_id = id
			_notify(Texto.texto("m3_placed", [id]) if id >= 0 else Texto.texto("m3_blocked"), 10)
		"demo":
			var board_id := _nearest_board_id(pos)
			if board_id < 0:
				_notify(Texto.texto("m3_demo_no_board"), 10)
			else:
				_selected_board_id = board_id
				var params := _demo_params()
				var ok := world.demonstrar_forma(board_id, demo_shape, params)
				var center: Array = params.get("center", [32.0, 32.0])
				_notify(Texto.texto("m3_demo_ok_params", [
					Texto.texto("shape_" + demo_shape),
					board_id,
					Texto.numero(float(params.get("scale", 1.0)), 2),
					str(int(roundf(float(center[0])))),
					str(int(roundf(float(center[1]))))
				]) if ok else Texto.texto("m3_demo_no_board"), 10)
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
	_refresh_library()
	_refresh_terminal_ui()
	_refresh_mind()
	_refresh_atelier()
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
	if follow:
		_focus_selected()

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
	_object_sensor_key = ""
	_gallery_signature = ""
	_selected_board_id = -1
	_visible_objects.clear()
	if teaching != null:
		teaching.world = null
	comandos = ComandosAPI.new()
	# Quando o simulador fornecer o adaptador integrado, usa a mesma instância.
	for property in world.get_property_list():
		if property.name == "comandos" and world.get("comandos") != null:
			comandos = world.get("comandos")
	command_target = world.creatures[world.pet_id].pos if world.creatures.has(world.pet_id) else world.size * 0.5
	view.show_command_target = false
	# O alvo de seguir restaurado deve sobreviver ao primeiro quadro da UI.
	if comandos.has_method("to_dict"):
		var state: Dictionary = comandos.to_dict(world)
		var order: Dictionary = state.get("order", {})
		if order.get("target") is Array and order.target.size() == 2:
			command_target = Vector2(float(order.target[0]), float(order.target[1]))
			view.show_command_target = true
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
	var column := _window_column(help_dialog)
	_button(column, Texto.texto("m1_tutorial"), func():
		help_dialog.hide()
		tutorial_dialog.popup_centered())
	_wrapped(column, Texto.texto("social_help") + "\n\n" + Texto.texto("help_body"))

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

static func _capture_options(arguments: PackedStringArray, debug_build: bool) -> Dictionary:
	var result := {"path": "", "benchmark": false, "population": 12}
	if not debug_build:
		return result
	var explicit_path := false
	for argument in arguments:
		if argument.begins_with("--capture="):
			explicit_path = true
			result.path = argument.trim_prefix("--capture=")
		if argument.begins_with("--fps-benchmark="):
			var count := argument.trim_prefix("--fps-benchmark=")
			if count.length() > 3 or not count.is_valid_int() or count.to_int() < 1 or count.to_int() > 100:
				return {"path": "", "benchmark": false, "population": 12}
			result.benchmark = true
			result.population = count.to_int()
	if result.benchmark and not explicit_path:
		result.path = "user://E4-fps-%d.png" % result.population
	result.path = result.path.replace("\\", "/")
	if not result.path.is_empty() and not _capture_path_valid(result.path):
		result.path = ""
	return result

static func _capture_path_valid(path: String) -> bool:
	if path.is_empty() or path.contains("\\"):
		return false
	for i in path.length():
		if path.unicode_at(i) < 32:
			return false
	# Reject traversal before simplification, including user://../ outside user data.
	if ".." in path.split("/") or path.get_file().is_empty() or path.get_extension().to_lower() != "png":
		return false
	if path.begins_with("user://"):
		return path.trim_prefix("user://").is_relative_path() and not path.trim_prefix("user://").contains(":")
	return path.is_absolute_path() and not path.contains("://")

func _capture_demo(path: String) -> void:
	if not OS.is_debug_build() or not _capture_path_valid(path):
		return
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
	if state.begins_with("m4b-"):
		await _capture_m4b(state, path)
		get_tree().quit()
		return
	if state.begins_with("m3c-"):
		await _capture_m3c(state, path)
		get_tree().quit()
		return
	if state.begins_with("m3-"):
		await _capture_m3(state, path)
		get_tree().quit()
		return
	if state.begins_with("m2-"):
		await _capture_m2(state, path)
		get_tree().quit()
		return
	if state.begins_with("e3-"):
		await _capture_e3(state, path)
		get_tree().quit()
		return
	if state.begins_with("m1-"):
		await _capture_m1(state, path)
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
	if not OS.is_debug_build() or not _capture_path_valid(path):
		return
	if DisplayServer.get_name() == "headless":
		printerr("O benchmark gráfico exige uma janela renderizada.")
		get_tree().quit(1)
		return
	protected_mode = false
	for offset in [Vector2(24, 0), Vector2(0, 50), Vector2(-45, 0)]:
		world.place_object(world.creatures[world.pet_id].pos + offset, OBJECT_TYPES[world.objects.size() % OBJECT_TYPES.size()])
	var bench_board_id := world.place_board(world.creatures[world.pet_id].pos + Vector2(0, -34))
	if bench_board_id >= 0:
		_selected_board_id = bench_board_id
		world.demonstrar_forma(bench_board_id, "circulo", {"scale": 1.0, "center": [32.0, 32.0]})
	world.place_book(world.creatures[world.pet_id].pos + Vector2(42, 18), "guia_capsulas")
	world.place_terminal(world.creatures[world.pet_id].pos + Vector2(-30, 24))
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
	result["active_minds"] = world.mind_enabled_ids.size()
	result["objects"] = world.objects.size()
	result["books"] = world.library.books.size()
	result["terminals"] = world.terminals.size()
	result["boards"] = world.boards.size()
	result["gallery"] = world.gallery.size()
	result["pet_mind_active"] = world.creatures.has(world.pet_id) and world.creatures[world.pet_id].mind != null
	var output := FileAccess.open(path.get_basename() + ".json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(result, "\t"))
		output.close()
	else:
		printerr("Benchmark: caminho de saída não gravável; use caminho absoluto.")
	paused = true
	if path.get_file().begins_with("M4b-"):
		_notify(Texto.texto("m4b_fps", [world.creatures.size(), Texto.numero(mean), world.terminals.size(), world.mind_enabled_ids.size()]), 15)
	elif path.get_file().begins_with("M3c-"):
		_notify(Texto.texto("m3c_fps", [world.creatures.size(), Texto.numero(mean), world.library.books.size(), world.mind_enabled_ids.size()]), 15)
	elif path.get_file().begins_with("M3-"):
		_notify(Texto.texto("m3_fps_sample", [world.creatures.size(), Texto.numero(mean), world.boards.size(), world.objects.size(), world.mind_enabled_ids.size(), Texto.texto("yes" if result.pet_mind_active else "no")]), 15)
	else:
		_notify(Texto.texto("m2_fps_sample", [world.creatures.size(), Texto.numero(mean), world.objects.size(), world.mind_enabled_ids.size(), Texto.texto("yes" if result.pet_mind_active else "no")]), 15)
	print(JSON.stringify(result))
	await capture_screenshot(path)



func _compact_buttons(row: Container) -> void:
	for child in row.get_children():
		if child is Button:
			child.add_theme_font_size_override("font_size", 13)
			child.add_theme_stylebox_override("normal", GardenTheme.panel(Color("354e42"), 6, 7))
			child.add_theme_stylebox_override("hover", GardenTheme.panel(Color("496454"), 6, 7))
			child.add_theme_stylebox_override("pressed", GardenTheme.panel(Color("d5deaa"), 6, 7))





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


func _focus_selected() -> void:
	if world != null and world.creatures.has(selected_id):
		camera.zoom = Vector2.ONE * 2.2
		camera.position = world.creatures[selected_id].pos + _camera_bias()
		follow = true

func _refresh_mind() -> void:
	var creature = world.creatures.get(selected_id)
	var active: bool = creature != null and creature.mind != null
	mind_enable.visible = creature != null and not active
	mind_cost.visible = creature != null and not active
	mind_intensity.visible = active
	if not active:
		object_reaction.text = Texto.texto("m1_disabled")
		object_activity.text = ""
		mind_emotion.text = Texto.texto("m1_disabled")
		mind_desire.text = Texto.texto("m1_no_selection" if creature == null else "m1_disabled")
		mind_reason.text = Texto.texto("m1_no_selection" if creature == null else "m1_inactive_reason")
		return
	var snapshot: Dictionary = creature.mind_snapshot()
	# Refresh perception once per changed simulation state, not per rendered frame.
	var sensor_key := "%d/%d/%d/%d" % [world.tick, creature.id, world.objects.size(), world.obstacles.size()]
	if sensor_key != _object_sensor_key:
		_visible_objects = world.sense(creature, false).get("objects", [])
		_object_sensor_key = sensor_key
	object_reaction.text = Texto.texto(ObjectPresenter.reaction(snapshot, _visible_objects, world.tick, creature.last_action))
	object_activity.text = Texto.texto("m2_activity", [Texto.acao(creature.last_action)])
	var dominant := Texto.mente_dominante(snapshot)
	mind_emotion.text = Texto.texto("m1_affect_" + str(dominant.key)) if dominant.value > 0.01 else Texto.texto("m1_quiet" if snapshot.affect_enabled else "m1_affect_off")
	mind_intensity.value = float(dominant.value) * 100
	mind_desire.text = Texto.mente_desejo(str(snapshot.get("objetivo_atual", "")))
	mind_reason.text = Texto.mente_causa(snapshot) if dominant.value > 0.01 else Texto.mente_motivo(str(snapshot.motivo))

func _enable_selected_mind() -> void:
	if world.enable_mind(selected_id):
		_world_dirty = true
		_notify(Texto.texto("m1_enabled"))
		_refresh()
		lab.observe(world, selected_id, true)

func _present_companion() -> void:
	var creature = world.creatures.get(selected_id)
	if creature == null or world.creatures.size() >= world.max_population:
		_notify(Texto.texto("m1_companion_fail"))
		return
	# Spawn through the simulator; never move a body or set its response.
	for radius in [40.0, 60.0, 85.0]:
		for index in range(12):
			var pos: Vector2 = creature.pos + Vector2.from_angle(index * TAU / 12) * radius
			# _spawn may relocate a blocked point; validate the largest possible body
			# first so a presentation near the selection really stays nearby.
			if not Rect2(Vector2(16, 16), world.size - Vector2(32, 32)).has_point(pos) or not world._clear(pos, 16):
				continue
			var occupied := false
			for body in world.creatures.values():
				if body.pos.distance_to(pos) < body.genome.size + 16:
					occupied = true
			if occupied:
				continue
			if world.spawn_creature(pos, Texto.NOMES_INICIAIS[world.creatures.size() % Texto.NOMES_INICIAIS.size()]) >= 0:
				_world_dirty = true
				_notify(Texto.texto("m1_companion_ok"), 10)
				_refresh()
				return
	_notify(Texto.texto("m1_companion_fail"))

func _clear_nearby_rocks() -> void:
	var creature = world.creatures.get(selected_id)
	if creature == null:
		return
	var removed := 0
	for obstacle in world.obstacles.duplicate():
		if creature.pos.distance_to(obstacle.pos) <= 120 + float(obstacle.radius):
			world.obstacles.erase(obstacle)
			removed += 1
	if removed > 0:
		world._rebuild_spatial()
		_world_dirty = true
	_notify(Texto.texto("m1_cleared", [removed]), 10)

func _build_tutorial() -> void:
	tutorial_dialog = _window("m1_tutorial", Vector2i(570, 360))
	var column := _window_column(tutorial_dialog)
	tutorial_text = _wrapped(column, "")
	tutorial_text.add_theme_font_size_override("font_size", 18)
	var row := HBoxContainer.new()
	column.add_child(row)
	_button(row, Texto.texto("m1_previous"), _tutorial_move.bind(-1))
	_button(row, Texto.texto("m1_next"), _tutorial_move.bind(1))
	_tutorial_move(0)

func _build_objects() -> void:
	object_dialog = _window("m2_catalog", Vector2i(520, 340))
	object_dialog.ok_button_text = Texto.texto("m2_place")
	var column := _window_column(object_dialog)
	_wrapped(column, Texto.texto("m2_kind"))
	object_choice = OptionButton.new()
	for kind in OBJECT_TYPES:
		object_choice.add_item(Texto.texto("m2_" + kind))
	column.add_child(object_choice)
	_wrapped(column, Texto.texto("m2_catalog_note"))
	_wrapped(column, Texto.texto("m2_place_note"))
	object_dialog.confirmed.connect(func():
		object_type = OBJECT_TYPES[object_choice.selected]
		_set_tool("object"))

func _open_objects() -> void:
	_set_tool(tool)
	object_choice.select(OBJECT_TYPES.find(object_type))
	object_dialog.popup_centered()

func _tutorial_move(direction: int) -> void:
	tutorial_step = clampi(tutorial_step + direction, 0, 7)
	var step_str := ""
	if tutorial_step == 7:
		step_str = Texto.texto("m4b_tutorial")
		tutorial_text.text = "8/8 · " + step_str
	elif tutorial_step == 6:
		step_str = Texto.texto("m3c_tutorial")
		tutorial_text.text = Texto.texto("m1_tutorial_step", [7, step_str])
	else:
		step_str = Texto.texto("m1_tutorial_" + str(tutorial_step))
		tutorial_text.text = Texto.texto("m1_tutorial_step", [tutorial_step + 1, step_str])

func _capture_m1(state: String, path: String) -> void:
	# Explicit inspection fixture with physical consequences; never normal gameplay.
	world = World.new_world(81002, {"creature_count": 1, "food_count": 0, "water_count": 0, "obstacle_count": 0, "food_regrow": false, "reproduction_enabled": false})
	selected_id = world.pet_id
	var creature = world.creatures[selected_id]
	creature.name = Texto.texto("pet_default")
	_reset_session()
	view.set_world(world)
	_show_lab(false)
	if state == "m1-frustration" or state.begins_with("m1-lab"):
		# A ring leaves no forward escape; the simulator decides and checks collisions.
		for index in range(12):
			world.place_obstacle(creature.pos + Vector2.from_angle(index * TAU / 12) * (creature.genome.size + 25), 24)
		for index in range(35):
			world.step()
	else:
		for index in range(70):
			world.step()
	if state == "m1-companion":
		_present_companion()
		for index in range(20):
			world.step()
	if state == "m1-other":
		_present_companion()
		selected_id = world.creatures.keys().back()
	_focus_selected()
	_refresh()
	if state.begins_with("m1-lab"):
		_show_lab(true)
	if state == "m1-tutorial":
		tutorial_dialog.popup_centered()
	_notify(Texto.texto("m1_demo"), 20)
	await get_tree().process_frame
	await get_tree().process_frame
	if state == "m1-lab-causes":
		lab_scroll.scroll_vertical = int(lab.mind_causes.position.y) - 40
	if state == "m1-lab-log":
		lab_scroll.scroll_vertical = int(lab.mind_logs.position.y) - 40
	if state == "m1-lab-scores":
		lab_scroll.scroll_vertical = int(lab.mind_scores.position.y) - 40
	if state == "m1-tools":
		caregiver_scroll.scroll_vertical = int(offer_button.position.y) - 40
	var until := Time.get_ticks_msec() + 800
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
	await capture_screenshot(path)


func _m2_fixture() -> void:
	# Explicit UI inspection fixture, independent of scientific TRAIN/DEV/HOLDOUT.
	world = World.new_world(81102, {"creature_count": 0, "food_count": 0, "water_count": 0, "obstacle_count": 0, "food_regrow": false, "reproduction_enabled": false})
	var genes = load("res://scripts/creature/genome.gd").new()
	genes.size = 8.0
	genes.speed = 30.0
	genes.vision_range = 180.0
	genes.vision_fov = snappedf(TAU, 0.000001)
	genes.temperament = {"curiosity": 0.9, "caution": 0.8, "sociability": 0.2, "impulsivity": 0.3}
	world.pet_id = world.spawn_creature(Vector2(300, 300), Texto.texto("pet_default"), genes)
	world.enable_mind(world.pet_id)
	selected_id = world.pet_id
	var creature = world.creatures[selected_id]
	creature.energy = creature.max_energy * 0.9
	creature.hydration = 90.0
	creature.heading = 0.0
	paused = true
	_reset_session()
	view.set_world(world)
	_show_lab(false)
	_focus_selected()

func _capture_m2(state: String, path: String) -> void:
	_m2_fixture()
	var creature = world.creatures[selected_id]
	var history := state in ["m2-habituated", "m2-aversive", "m2-memory", "m2-cautious"]
	if history:
		# Eight real local contacts; advance only clock between acquisitions.
		# Restored reserves isolate the displayed history from physiological urgency.
		var id := world.place_object(creature.pos + Vector2(-13, 0), "capsula_aversiva" if state in ["m2-aversive", "m2-cautious"] else "capsula_neutra")
		for index in range(8):
			world.tick += 181
			creature.energy = creature.max_energy * 0.9
			creature.hydration = 90.0
			assert(world.interact_object(creature, id))
		creature.energy = creature.max_energy * 0.9
		creature.hydration = 90.0
	object_type = "capsula_neutra"
	_set_tool("object")
	_apply_tool(creature.pos + Vector2(24, 0))
	var origin: Vector2 = creature.pos
	if state != "m2-new" and state != "m2-catalog" and state != "m2-tutorial":
		for index in range(80):
			world.step()
			if state != "m2-investigating" or creature.last_action == "investigate_object": break
	_refresh()
	if state in ["m2-memory", "m2-aversive", "m2-lab", "m2-ablation"]: _show_lab(true)
	if state == "m2-ablation":
		lab.memory_switch.button_pressed = false
		lab.curiosity_switch.button_pressed = false
	if state == "m2-catalog": object_dialog.popup_centered()
	if state == "m2-tutorial":
		tutorial_step = 3
		_tutorial_move(0)
		tutorial_dialog.popup_centered()
	_notify(Texto.texto("m2_demo"), 20)
	await get_tree().process_frame
	await get_tree().process_frame
	if state in ["m2-memory", "m2-aversive"]:
		lab_scroll.scroll_vertical = int(lab.object_memory.position.y) - 26
	if state == "m2-ablation":
		lab_scroll.scroll_vertical = int(lab.memory_switch.position.y) - 5
	print(JSON.stringify({"capture": state, "tick": world.tick, "action": creature.last_action, "goal": creature.mind.objetivo_atual, "reason": creature.mind.motivo, "distance_moved": origin.distance_to(creature.pos), "reaction": object_reaction.text, "objects": world.objects.size()}))
	var until := Time.get_ticks_msec() + 800
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
	await capture_screenshot(path)

func _build_demo() -> void:
	demo_dialog = _window("m3_demo_title", Vector2i(540, 470))
	demo_dialog.ok_button_text = Texto.texto("m3_demo_apply")
	var column := _window_column(demo_dialog)
	_wrapped(column, Texto.texto("m3_demo_shape"))
	demo_shape_choice = OptionButton.new()
	for shape_key in DEMO_SHAPES:
		demo_shape_choice.add_item(Texto.texto("shape_" + shape_key))
	column.add_child(demo_shape_choice)
	_wrapped(column, Texto.texto("m3_demo_scale"))
	demo_scale_input = SpinBox.new()
	demo_scale_input.min_value = 0.45
	demo_scale_input.max_value = 1.60
	demo_scale_input.step = 0.05
	demo_scale_input.value = 1.0
	column.add_child(demo_scale_input)
	var scale_menu := demo_scale_input.get_line_edit().get_menu()
	_localize_edit_menu(scale_menu)
	scale_menu.about_to_popup.connect(_localize_edit_menu.bind(scale_menu))
	var center_row := HBoxContainer.new()
	center_row.add_theme_constant_override("separation", 12)
	column.add_child(center_row)
	var cx_col := VBoxContainer.new()
	cx_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_row.add_child(cx_col)
	_wrapped(cx_col, Texto.texto("m3_demo_pos_x"))
	demo_center_x_input = SpinBox.new()
	demo_center_x_input.min_value = 10
	demo_center_x_input.max_value = 54
	demo_center_x_input.step = 2
	demo_center_x_input.value = 32
	cx_col.add_child(demo_center_x_input)
	var cx_menu := demo_center_x_input.get_line_edit().get_menu()
	_localize_edit_menu(cx_menu)
	cx_menu.about_to_popup.connect(_localize_edit_menu.bind(cx_menu))
	var cy_col := VBoxContainer.new()
	cy_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_row.add_child(cy_col)
	_wrapped(cy_col, Texto.texto("m3_demo_pos_y"))
	demo_center_y_input = SpinBox.new()
	demo_center_y_input.min_value = 10
	demo_center_y_input.max_value = 54
	demo_center_y_input.step = 2
	demo_center_y_input.value = 32
	cy_col.add_child(demo_center_y_input)
	var cy_menu := demo_center_y_input.get_line_edit().get_menu()
	_localize_edit_menu(cy_menu)
	cy_menu.about_to_popup.connect(_localize_edit_menu.bind(cy_menu))
	var preview_row := HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 12)
	column.add_child(preview_row)
	demo_preview_canvas = AtelierCanvas.new()
	preview_row.add_child(demo_preview_canvas)
	_wrapped(preview_row, Texto.texto("m3_demo_hint")).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	demo_shape_choice.item_selected.connect(func(_idx): _update_demo_preview())
	demo_scale_input.value_changed.connect(func(_val): _update_demo_preview())
	demo_center_x_input.value_changed.connect(func(_val): _update_demo_preview())
	demo_center_y_input.value_changed.connect(func(_val): _update_demo_preview())
	demo_dialog.confirmed.connect(_confirm_demo)
	_update_demo_preview()

func _demo_params() -> Dictionary:
	return {
		"scale": float(demo_scale_input.value) if demo_scale_input != null else 1.0,
		"center": [
			float(demo_center_x_input.value) if demo_center_x_input != null else 32.0,
			float(demo_center_y_input.value) if demo_center_y_input != null else 32.0
		]
	}

func _update_demo_preview() -> void:
	if demo_shape_choice == null or demo_preview_canvas == null:
		return
	demo_shape = DEMO_SHAPES[clampi(demo_shape_choice.selected, 0, DEMO_SHAPES.size() - 1)]
	var ref: Array = Atelier.build_reference_strokes(demo_shape, _demo_params())
	demo_preview_canvas.reference_strokes = ref
	demo_preview_canvas.strokes = []
	demo_preview_canvas.queue_redraw()
	if view != null:
		view.demo_preview_strokes = ref
		view.queue_redraw()

func _open_demo() -> void:
	_set_tool(tool)
	demo_shape_choice.select(maxi(0, DEMO_SHAPES.find(demo_shape)))
	_update_demo_preview()
	demo_dialog.popup_centered()

func _confirm_demo() -> void:
	_update_demo_preview()
	_set_tool("demo")
	if world != null and not world.boards.is_empty():
		var target_id := _selected_board_id
		var found := false
		for b in world.boards:
			if int(b.id) == target_id:
				found = true
				break
		if not found:
			target_id = int(world.boards.back().id)
			_selected_board_id = target_id
		var params := _demo_params()
		if world.demonstrar_forma(target_id, demo_shape, params):
			var center: Array = params.get("center", [32.0, 32.0])
			_notify(Texto.texto("m3_demo_ok_params", [
				Texto.texto("shape_" + demo_shape),
				target_id,
				Texto.numero(float(params.get("scale", 1.0)), 2),
				str(int(roundf(float(center[0])))),
				str(int(roundf(float(center[1]))))
			]), 10)
			_world_dirty = true
			_refresh()

func _demonstrate_shape(shape_key: String) -> void:
	if shape_key not in DEMO_SHAPES:
		return
	demo_shape = shape_key
	if demo_shape_choice != null:
		demo_shape_choice.select(DEMO_SHAPES.find(shape_key))
	_update_demo_preview()
	if world == null or world.boards.is_empty():
		_set_tool("board")
		_notify(Texto.texto("m3_demo_no_board"), 10)
		return
	var target_id := _selected_board_id
	var found := false
	for b in world.boards:
		if int(b.id) == target_id:
			found = true
			break
	if not found:
		target_id = int(world.boards.back().id)
		_selected_board_id = target_id
	var params := _demo_params()
	if world.demonstrar_forma(target_id, demo_shape, params):
		var center: Array = params.get("center", [32.0, 32.0])
		_notify(Texto.texto("m3_demo_ok_params", [
			Texto.texto("shape_" + demo_shape),
			target_id,
			Texto.numero(float(params.get("scale", 1.0)), 2),
			str(int(roundf(float(center[0])))),
			str(int(roundf(float(center[1]))))
		]), 10)
		_world_dirty = true
		_refresh()

func _nearest_board_id(pos: Vector2) -> int:
	if world == null or world.boards.is_empty():
		return -1
	var best_id := -1
	var best_dist := INF
	for board in world.boards:
		var dist: float = pos.distance_to(board.pos)
		if dist < best_dist:
			best_dist = dist
			best_id = int(board.id)
	return best_id

func _open_atelier_tutorial() -> void:
	tutorial_step = 5
	_tutorial_move(0)
	tutorial_dialog.popup_centered()

func _refresh_atelier() -> void:
	if world == null or board_canvas == null:
		return
	if world.boards.is_empty():
		board_canvas.setup([], [], false)
		board_status_label.text = Texto.texto("m3_board_none")
		board_live_label.text = ""
	else:
		var board: Dictionary = world.boards.back()
		for b in world.boards:
			if int(b.id) == _selected_board_id:
				board = b
				break
			if int(b.get("owner_id", 0)) == selected_id:
				board = b
		var active_strokes: Array = board.get("active_strokes", [])
		var display_strokes: Array = active_strokes
		if display_strokes.is_empty() and not board.get("artifacts", []).is_empty():
			display_strokes = board.artifacts.back().get("strokes", [])
		var drawing_creature = null
		for c in world.creatures.values():
			if c.atelier != null and int(c.atelier.active.get("board_id", -1)) == int(board.id) and str(c.atelier.active.get("status", "")) == "active":
				drawing_creature = c
				break
		var show_pen := false
		var pen_pt := Vector2(32.0, 32.0)
		if drawing_creature != null and not active_strokes.is_empty() and not active_strokes.back().is_empty():
			var last_pt = active_strokes.back().back()
			if last_pt is Array and last_pt.size() >= 2:
				show_pen = true
				pen_pt = Vector2(float(last_pt[0]), float(last_pt[1]))
		board_canvas.setup(display_strokes, board.get("reference_strokes", []), show_pen, pen_pt)
		var ref_shape: String = str(board.get("reference_shape", ""))
		if ref_shape.is_empty():
			board_status_label.text = Texto.texto("m3_board_status_free", [int(board.id)])
		else:
			var ref_params: Dictionary = board.get("reference_params", {})
			var center: Array = ref_params.get("center", [32.0, 32.0])
			var cx: int = int(roundf(float(center[0]))) if center.size() >= 2 else 32
			var cy: int = int(roundf(float(center[1]))) if center.size() >= 2 else 32
			board_status_label.text = Texto.texto("m3_board_status_ref", [
				int(board.id),
				Texto.texto("shape_" + ref_shape),
				Texto.numero(float(ref_params.get("scale", 1.0)), 2),
				str(cx),
				str(cy)
			])
		if drawing_creature != null:
			var act: Dictionary = drawing_creature.atelier.active
			board_live_label.text = Texto.texto("m3_live_drawing", [
				int(act.get("step_index", 0)),
				int(act.get("total_segments", 8)),
				int(board.id),
				Texto.nome_criatura(str(drawing_creature.name))
			])
		elif not board.get("artifacts", []).is_empty():
			board_live_label.text = Texto.texto("m3_live_done", [int(board.id), int(board.get("artifacts", []).size())])
		else:
			board_live_label.text = Texto.texto("m3_live_idle")
	var own_count := 0
	for a in world.gallery:
		if int(a.get("owner_id", -1)) == selected_id:
			own_count += 1
	gallery_title_label.text = Texto.texto("m3_gallery_count", [world.gallery.size(), own_count])
	var last_gallery_id: int = int(world.gallery.back().get("id", -1)) if not world.gallery.is_empty() else 0
	var sig := "%d:%d:%d" % [world.gallery.size(), last_gallery_id, selected_id]
	if sig != _gallery_signature:
		_gallery_signature = sig
		gallery_empty_label.visible = world.gallery.is_empty()
		for child in gallery_list.get_children():
			child.queue_free()
		for idx in range(world.gallery.size() - 1, maxi(-1, world.gallery.size() - 7), -1):
			var art: Dictionary = world.gallery[idx]
			var card := PanelContainer.new()
			card.add_theme_stylebox_override("panel", GardenTheme.panel(Color("283d33"), 6, 6))
			gallery_list.add_child(card)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			card.add_child(row)
			var mini := AtelierCanvas.new(true)
			var ref_for_mini: Array = []
			var t_shape: String = str(art.get("target_shape", "rabisco"))
			if t_shape in DEMO_SHAPES:
				var b_params := {}
				for b in world.boards:
					if int(b.id) == int(art.get("board_id", -1)) and str(b.get("reference_shape", "")) == t_shape:
						b_params = b.get("reference_params", {})
						break
				ref_for_mini = Atelier.build_reference_strokes(t_shape, b_params)
			mini.setup(art.get("strokes", []), ref_for_mini, false)
			row.add_child(mini)
			var owner_str: String = Texto.nome_criatura(str(art.get("owner_name", "")))
			var detail := Texto.texto("m3_artifact_scribble", [int(art.get("strokes", []).size())]) if t_shape == "rabisco" or t_shape.is_empty() else Texto.texto("m3_artifact_guided", [Texto.texto("shape_" + t_shape), Texto.numero(float(art.get("error", 0.0)), 3)])
			var caption := Texto.texto("m3_artifact_card", [
				str(art.get("title", "")),
				owner_str,
				int(art.get("owner_id", -1)),
				int(art.get("created_tick", 0)),
				int(art.get("board_id", -1)),
				detail
			])
			var info_label := _wrapped(row, caption)
			info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if world.gallery.size() > 6:
			_wrapped(gallery_list, Texto.texto("m3_gallery_more", [world.gallery.size() - 6]))

func _build_library() -> void:
	book_dialog = _window("m3c_catalog", Vector2i(540, 340))
	var column := _window_column(book_dialog)
	_wrapped(column, Texto.texto("m3c_catalog_note"))
	book_choice = OptionButton.new()
	book_choice.fit_to_longest_item = false
	column.add_child(book_choice)
	for key in Books.BOOKS: book_choice.add_item(Texto.texto("book_" + key))
	book_description = _wrapped(column, Texto.texto("m3c_catalog_" + book_type))
	book_choice.item_selected.connect(func(index):
		book_description.text = Texto.texto("m3c_catalog_" + Books.BOOKS.keys()[index]))
	_button(column, Texto.texto("m3c_place"), _confirm_book)
	knowledge_dialog = _window("m3c_title", Vector2i(610, 470))
	knowledge_text = _wrapped(_window_column(knowledge_dialog), "")

func _open_books() -> void:
	book_dialog.popup_centered()

func _confirm_book() -> void:
	book_type = Books.BOOKS.keys()[book_choice.selected]
	book_dialog.hide()
	_set_tool("book")

func _open_knowledge() -> void:
	knowledge_text.text = KnowledgePresenter.describe(world.creatures.get(selected_id), world.tick)
	knowledge_dialog.popup_centered()

func _open_library_tutorial() -> void:
	tutorial_step = 6
	_tutorial_move(0)
	tutorial_dialog.popup_centered()

func _refresh_library() -> void:
	if reading_text == null: return
	var creature = world.creatures.get(selected_id)
	reading_text.text = KnowledgePresenter.reading(creature)
	if knowledge_dialog != null and knowledge_dialog.visible:
		knowledge_dialog.title = Texto.texto("m3c_title") + (" · " + Texto.nome_criatura(creature.name) if creature != null else "")
		knowledge_text.text = KnowledgePresenter.describe(creature, world.tick)
	var pending: Array = world.pending_questions
	question_card.visible = not pending.is_empty()
	_question_id = ""
	_question_creature = -1
	if pending.is_empty(): return
	# Display the selected creature first, otherwise identify the actual asker.
	var q: Dictionary = pending[0]
	for candidate in pending:
		if int(candidate.creature_id) == selected_id:
			q = candidate
			break
	_question_id = q.id
	_question_creature = int(q.creature_id)
	var asker = world.creatures.get(_question_creature)
	question_text.text = Texto.texto("m3c_question", [Texto.nome_criatura(asker.name) if asker != null else str(_question_creature), q.object_id, Texto.texto("m3c_category_" + str(q.category)), q.tick])

func _answer_question(option: String) -> void:
	if _question_id.is_empty(): return
	var asker_id := _question_creature
	var accepted := world.responder_pergunta(_question_id, option)
	_world_dirty = true
	# Retain the asker in the inspector so the attributed record is reviewable.
	selected_id = asker_id
	_refresh()
	_notify(Texto.texto("m3c_answer_ignore" if option == "silencio" else ("m3c_answer_ok" if accepted else "m3c_answer_no")), 12)
	if accepted: _open_knowledge()

func _m3c_fixture() -> void:
	_m3_fixture(81303)
	var creature = world.creatures[selected_id]
	creature.genome.temperament = {"curiosity": 0.9, "caution": 0.25, "sociability": 0.7, "impulsivity": 0.8}
	creature.heading = 0.0

func _capture_m3c(state: String, path: String) -> void:
	_m3c_fixture()
	var creature = world.creatures[selected_id]
	book_type = "guia_enganoso" if state in ["m3c-contradiction", "m3c-sources"] else "guia_pedras"
	if state not in ["m3c-question", "m3c-answer", "m3c-ignore"]:
		_set_tool("book")
		_apply_tool(creature.pos + Vector2(42, 0))
		if state != "m3c-catalog":
			for _step in range(90):
				world.step()
				var r: Dictionary = creature.knowledge_snapshot().get("reading", {})
				if state == "m3c-approaching" and creature.last_action == "seek_book": break
				if state == "m3c-reading" and creature.last_action == "read_book" and int(r.get("progress", 0)) >= 3: break
				if int(r.get("page", 0)) >= 1: break
	if state in ["m3c-question", "m3c-answer", "m3c-ignore", "m3c-contradiction", "m3c-sources", "m3c-symbols"]:
		var obj := world.place_object(creature.pos + Vector2(8, 0), "capsula_aversiva")
		if state in ["m3c-question", "m3c-answer", "m3c-ignore"]:
			creature.mind.decide(creature, world.tick, world.sense(creature))
			_refresh_library()
			if state != "m3c-question": _answer_question("seguro" if state == "m3c-answer" else "silencio")
		elif state in ["m3c-contradiction", "m3c-sources"]:
			world.interact_object(creature, obj)
		elif state == "m3c-symbols":
			world.demonstrar_simbolo(creature.id, "anel", obj, true)
			world.demonstrar_simbolo(creature.id, "anel", obj, true)
	camera.position = creature.pos + Vector2(15, 0) + _camera_bias()
	_refresh()
	if state in ["m3c-knowledge", "m3c-answer", "m3c-contradiction", "m3c-sources", "m3c-symbols"]: _open_knowledge()
	if state == "m3c-catalog": _open_books()
	if state == "m3c-tutorial": _open_library_tutorial()
	if state in ["m3c-lab", "m3c-ablation"]:
		_show_lab(true)
		if state == "m3c-ablation": lab.memory_switch.button_pressed = false
	_notify(Texto.texto("m3c_banner"), 20)
	await get_tree().process_frame
	await get_tree().process_frame
	if state == "m3c-symbols": knowledge_text.get_parent().get_parent().scroll_vertical = 10000
	if state == "m3c-sources": knowledge_text.get_parent().get_parent().scroll_vertical = 280
	if state == "m3c-ablation": lab_scroll.scroll_vertical = int(lab.memory_switch.position.y) - 60
	print(JSON.stringify({"capture": state, "tick": world.tick, "action": creature.last_action, "knowledge": creature.knowledge_snapshot(), "pending": world.pending_questions.size()}))
	await capture_screenshot(path)

func _m3_fixture(fixture_seed: int = 81203) -> void:
	world = World.new_world(fixture_seed, {"creature_count": 0, "food_count": 0, "water_count": 0, "obstacle_count": 0, "food_regrow": false, "reproduction_enabled": false})
	var genes = load("res://scripts/creature/genome.gd").new()
	genes.size = 8.5
	genes.speed = 32.0
	genes.vision_range = 180.0
	genes.vision_fov = snappedf(TAU, 0.000001)
	genes.temperament = {"curiosity": 0.9, "caution": 0.25, "sociability": 0.2, "impulsivity": 0.8}
	world.pet_id = world.spawn_creature(Vector2(300, 300), Texto.texto("pet_default"), genes)
	world.enable_mind(world.pet_id)
	selected_id = world.pet_id
	var creature = world.creatures[selected_id]
	creature.energy = creature.max_energy * 0.95
	creature.hydration = 95.0
	creature.heading = 0.0
	paused = true
	_reset_session()
	view.set_world(world)
	_show_lab(false)
	_focus_selected()

func _capture_m3(state: String, path: String) -> void:
	_m3_fixture()
	var creature = world.creatures[selected_id]
	creature.heading = -PI * 0.5
	_set_tool("board")
	_apply_tool(creature.pos + Vector2(0, -28))
	var board_id: int = int(world.boards[0].id)
	if state == "m3-scribble":
		for _step in range(70):
			world.step()
			if not world.gallery.is_empty():
				break
	elif state == "m3-demo":
		demo_shape_choice.select(1)
		demo_scale_input.value = 1.15
		demo_center_x_input.value = 34
		demo_center_y_input.value = 30
		_confirm_demo()
		_open_demo()
	elif state == "m3-drawing":
		_demonstrate_shape("quadrado")
		for _step in range(45):
			world.step()
			if creature.atelier != null and str(creature.atelier.active.get("status", "")) == "active" and int(creature.atelier.active.get("step_index", 0)) >= 4:
				break
	elif state in ["m3-gallery", "m3-lab-curve", "m3-ablation"]:
		var sessions := 4 if state == "m3-lab-curve" else 2
		for shape_key in DEMO_SHAPES:
			for _session in range(sessions):
				creature.energy = creature.max_energy * 0.95
				creature.hydration = 95.0
				world.demonstrar_forma(board_id, shape_key, {"scale": 1.0, "center": [32.0, 32.0]})
				world.demonstrar_forma(board_id, shape_key, {"scale": 1.0, "center": [32.0, 32.0]})

				var before_attempts: int = creature.atelier.attempts.size() if creature.atelier != null else 0
				for _step in range(90):
					world.step()
					if creature.atelier != null and creature.atelier.attempts.size() > before_attempts:
						break
		if state == "m3-gallery":
			world.demonstrar_forma(board_id, "circulo", {"scale": 1.1, "center": [32.0, 32.0]})
	elif state == "m3-tutorial":
		_demonstrate_shape("circulo")
		for _step in range(18):
			world.step()
		_open_atelier_tutorial()
	camera.position = creature.pos + Vector2(0, -14) + _camera_bias()
	_refresh()
	if state in ["m3-lab-curve", "m3-ablation"]:
		_show_lab(true)
	if state == "m3-ablation":
		lab.atelier_learning_switch.button_pressed = false
		lab._select_atelier_policy(2)
	_notify(Texto.texto("m3_demo_banner"), 20)
	await get_tree().process_frame
	await get_tree().process_frame
	if state == "m3-drawing":
		caregiver_scroll.scroll_vertical = int(board_canvas.get_parent().position.y) - 24
	if state == "m3-gallery":
		caregiver_scroll.scroll_vertical = int(gallery_title_label.position.y) - 10
	if state == "m3-lab-curve":
		lab_scroll.scroll_vertical = int(lab.atelier_chart.position.y) - 65
	if state == "m3-ablation":
		lab_scroll.scroll_vertical = int(lab.atelier_status.position.y)
	var snap: Dictionary = creature.atelier_snapshot()
	print(JSON.stringify({
		"capture": state,
		"tick": world.tick,
		"boards": world.boards.size(),
		"gallery": world.gallery.size(),
		"attempts": snap.get("attempts", []).size(),
		"updates": snap.get("updates", 0),
		"policy_mode": snap.get("policy_mode", "trained")
	}))
	var until := Time.get_ticks_msec() + 800
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
	await capture_screenshot(path)

func _build_terminal_ui() -> void:
	terminal_dialog = _window("m4b_terminal_panel_title", Vector2i(610, 480))
	var term_col := _window_column(terminal_dialog)
	terminal_panel_text = _wrapped(term_col, "")

	terminal_console_dialog = _window("m4b_console_title", Vector2i(640, 520))
	var console_col := _window_column(terminal_console_dialog)
	console_warning_label = _wrapped(console_col, Texto.texto("m4b_console_warning"))
	var warn := console_warning_label
	warn.add_theme_color_override("font_color", Color("ffdda5"))
	_wrapped(console_col, Texto.texto("m4b_console_note"))

	var dev_row := HBoxContainer.new()
	console_col.add_child(dev_row)
	_label(dev_row, "Terminal:", 12, Color("bccc98"))
	console_device_choice = OptionButton.new()
	console_device_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dev_row.add_child(console_device_choice)

	_label(console_col, "Comandos rápidos (clique para inserir):", 12, Color("bccc98"))
	var cmd_grid := GridContainer.new()
	cmd_grid.columns = 4
	console_col.add_child(cmd_grid)
	for cmd_sample in ["OLHAR", "AJUDA", "MARCAR 3 0", "MOVER LESTE 2", "DESENHAR CIRCULO", "LER mapa", "LER livro_desenho", "REPETIR 2 { MOVER LESTE 1 }"]:
		var b := _button(cmd_grid, cmd_sample, func(): console_input.text = cmd_sample)
		b.add_theme_font_size_override("font_size", 11)

	console_input = LineEdit.new()
	console_input.placeholder_text = Texto.texto("m4b_console_placeholder")
	console_col.add_child(console_input)
	console_input.text_submitted.connect(func(_t): _run_console_command())

	var btn_row := HBoxContainer.new()
	console_col.add_child(btn_row)
	_button(btn_row, Texto.texto("m4b_console_run"), _run_console_command)
	_button(btn_row, Texto.texto("m4b_console_clear"), func(): console_output.text = "")

	_label(console_col, Texto.texto("m4b_console_virtual_out"), 12, Color("bccc98"))
	var out_scroll := ScrollContainer.new()
	out_scroll.custom_minimum_size.y = 130
	out_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	console_col.add_child(out_scroll)
	console_output = _wrapped(out_scroll, "")

	manual_dialog = _window("m4b_offer_manual_title", Vector2i(480, 260))
	var man_col := _window_column(manual_dialog)
	_wrapped(man_col, "Escolha um manual anexo para oferecer à criatura selecionada:")
	manual_choice = OptionButton.new()
	man_col.add_child(manual_choice)
	for mkey in ["mapa", "livro_desenho", "livro_repeticao"]:
		manual_choice.add_item(Texto.texto("m4b_manual_" + mkey))
	_button(man_col, Texto.texto("m4b_offer_manual_confirm"), _confirm_offer_manual)

	refuse_dialog = _window("m4b_refuse_dialog_title", Vector2i(440, 240))
	var ref_col := _window_column(refuse_dialog)
	_wrapped(ref_col, Texto.texto("m4b_refuse_duration"))
	refuse_duration_input = SpinBox.new()
	refuse_duration_input.min_value = 1
	refuse_duration_input.max_value = 10000
	refuse_duration_input.value = 180
	ref_col.add_child(refuse_duration_input)
	_button(ref_col, Texto.texto("m4b_refuse_confirm"), _confirm_refuse)

func _open_terminal_console() -> void:
	console_device_choice.clear()
	for dev in world.terminals:
		console_device_choice.add_item(Texto.texto("m4b_console_device", [int(dev.id)]), int(dev.id))
	if console_device_choice.item_count == 0:
		console_device_choice.add_item(Texto.texto("m4b_console_no_terminal"), -1)
	terminal_console_dialog.popup_centered()

func _run_console_command() -> void:
	var cmd: String = console_input.text.strip_edges()
	if cmd.is_empty(): return
	var c = world.creatures.get(selected_id)
	var term_id := -1
	if console_device_choice.selected >= 0 and console_device_choice.item_count > 0:
		term_id = console_device_choice.get_item_id(console_device_choice.selected)
	if term_id < 0 and not world.terminals.is_empty():
		term_id = int(world.terminals[0].id)

	var Pure = preload("res://scripts/terminal/terminal.gd")
	var TerminalState = preload("res://scripts/terminal/terminal_estado.gd")
	var TerminalAdapter = preload("res://scripts/terminal/terminal_mundo_real.gd")
	var TerminalFake = preload("res://scripts/terminal/terminal_mundo_falso.gd")

	var adapter = null
	if term_id >= 0 and c != null and world._terminal_ready(c, term_id):
		adapter = TerminalAdapter.new(world, c, term_id)
	else:
		adapter = TerminalFake.new()

	var state = TerminalState.new()
	state.discover("MARCAR", "manual")
	state.discover("MOVER", "manual")
	state.discover("LER", "manual")
	state.discover("DESENHAR", "livro")
	state.discover("REPETIR", "livro")

	var res: Dictionary = Pure.new().execute(cmd, adapter, state, world.tick)
	var lines: Array[String] = []
	lines.append("> " + cmd)
	lines.append("Resultado: %s (ok=%s)" % [res.get("mensagem", ""), str(res.get("ok", false))])
	var events: Array = res.get("eventos", [])
	for ev in events:
		var ev_cmd = ev.get("comando", "")
		var ev_args = ev.get("args", [])
		var ev_msg = ev.get("resultado", {}).get("mensagem", "")
		var line = "  • %s %s → %s" % [ev_cmd, str(ev_args), ev_msg]
		if ev.has("descoberto") and not str(ev.descoberto).is_empty():
			line += " [Comando descoberto: %s]" % str(ev.descoberto)
		if ev.has("dados") and not ev.dados.is_empty():
			line += " %s" % str(ev.dados)
		lines.append(line)
	if console_output.text.is_empty():
		console_output.text = "\n".join(lines)
	else:
		console_output.text = console_output.text + "\n\n" + "\n".join(lines)

func _open_terminal_panel() -> void:
	var c = world.creatures.get(selected_id)
	terminal_panel_text.text = TerminalPresenter.describe(c, world)
	terminal_dialog.title = Texto.texto("m4b_terminal_panel_title") + (" · " + Texto.nome_criatura(c.name) if c != null else "")
	terminal_dialog.popup_centered()

func _open_offer_manual() -> void:
	manual_dialog.popup_centered()

func _confirm_offer_manual() -> void:
	manual_dialog.hide()
	var c = world.creatures.get(selected_id)
	if c == null: return
	var books := ["mapa", "livro_desenho", "livro_repeticao"]
	var selected_book: String = books[clampi(manual_choice.selected, 0, books.size() - 1)]
	var nearest_id := -1
	var nearest_dist := INF
	for dev in world.terminals:
		var d = c.pos.distance_to(dev.pos)
		if d < nearest_dist:
			nearest_dist = d
			nearest_id = int(dev.id)
	if nearest_id < 0 or nearest_dist > 50.0:
		_notify(Texto.texto("m4b_offer_manual_no_terminal"), 10)
		return
	var ok: bool = world.terminal_offer_manual(c, nearest_id, selected_book)
	_notify(Texto.texto("m4b_offer_manual_ok" if ok else "m4b_offer_manual_refused"), 10)
	_refresh()

func _open_refuse_dialog() -> void:
	refuse_dialog.popup_centered()

func _confirm_refuse() -> void:
	refuse_dialog.hide()
	var c = world.creatures.get(selected_id)
	if c == null: return
	var duration: int = int(refuse_duration_input.value)
	var ok: bool = world.terminal_refuse(c, duration)
	_notify(Texto.texto("m4b_refuse_ok", [duration]) if ok else Texto.texto("m4b_refuse_failed"), 10)
	_refresh()

func _open_terminal_tutorial() -> void:
	tutorial_step = 7
	_tutorial_move(0)
	tutorial_dialog.popup_centered()

func _refresh_terminal_ui() -> void:
	if terminal_activity_label == null: return
	var creature = world.creatures.get(selected_id)
	terminal_activity_label.text = TerminalPresenter.status_line(creature, world)
	if terminal_dialog != null and terminal_dialog.visible:
		terminal_dialog.title = Texto.texto("m4b_terminal_panel_title") + (" · " + Texto.nome_criatura(creature.name) if creature != null else "")
		terminal_panel_text.text = TerminalPresenter.describe(creature, world)

func _m4b_fixture() -> void:
	_m3c_fixture()
	var creature = world.creatures[selected_id]
	creature.energy = creature.max_energy * 0.95
	creature.hydration = 95.0
	creature.genome.temperament = {"curiosity": 0.95, "caution": 0.2, "sociability": 0.8, "impulsivity": 0.8}
	creature.heading = 0.0

func _capture_m4b(state: String, path: String) -> void:
	_m4b_fixture()
	var creature = world.creatures[selected_id]
	var term_id := world.place_terminal(creature.pos + Vector2(36, 0))
	_set_tool("terminal")

	if state == "m4b-tool":
		_refresh()
	elif state == "m4b-console":
		_open_terminal_console()
		console_input.text = "AJUDA"
		_run_console_command()
		console_input.text = "MARCAR 3 0"
		_run_console_command()
	elif state == "m4b-creature":
		world.terminal_offer_manual(creature, term_id, "mapa")
		world.terminal_set_task(creature, "marcar_mover", Vector2i(3, 0))
		world.step()
		_open_terminal_panel()
	elif state == "m4b-manual":
		_open_offer_manual()
	elif state == "m4b-refusal":
		world.terminal_refuse(creature, 180)
		_refresh()
		_open_refuse_dialog()
	elif state == "m4b-lab":
		_show_lab(true)
		lab_scroll.scroll_vertical = 0
	elif state == "m4b-tutorial":
		_open_terminal_tutorial()

	camera.position = creature.pos + Vector2(15, 0) + _camera_bias()
	_notify(Texto.texto("m4b_banner"), 20)
	await get_tree().process_frame
	await get_tree().process_frame
	print(JSON.stringify({"capture": state, "tick": world.tick, "action": creature.last_action, "terminals": world.terminals.size()}))
	await capture_screenshot(path)
