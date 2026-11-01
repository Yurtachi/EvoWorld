extends VBoxContainer
const Texto = preload("res://scripts/core/textos.gd")
const Chart = preload("res://scripts/ui/teaching_chart.gd")
signal target_requested
signal changed
var world
var creature_id := -1
var target := Vector2.INF
var snapshot: Dictionary = {}
var skill: OptionButton
var mark_button: Button
var show_button: Button
var observe_button: Button
var reward_button: Button
var cancel_button: Button
var reset_button: Button
var reset_dialog: ConfirmationDialog
var heading: Label
var target_label: Label
var badge: Label
var metrics: Label
var progress: Label
var comparison: Label
var receipt: Label
var events: Label
var chart: Control
var _tick := -1
var _reset_id := -1
var _reset_world

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading = _text("")
	badge = _text("")
	badge.add_theme_font_size_override("font_size", 18)
	skill = OptionButton.new()
	skill.fit_to_longest_item = false
	add_child(skill)
	skill.item_selected.connect(func(_i): target = Vector2.INF; refresh(true))
	mark_button = _button("te_mark", func(): target_requested.emit())
	target_label = _text("")
	var row := HBoxContainer.new()
	add_child(row)
	show_button = _button("show", start.bind(true), row)
	observe_button = _button("te_observe", start.bind(false), row)
	progress = _text("")
	reward_button = _button("reward", reward)
	receipt = _text("")
	_text(Texto.texto("reward_note"))
	_text(Texto.texto("assistance_note"))
	metrics = _text("")
	_text(Texto.texto("te_criterion"))
	chart = Chart.new()
	add_child(chart)
	comparison = _text("")
	cancel_button = _button("te_cancel", cancel)
	reset_button = _button("reset", request_reset)
	_text(Texto.texto("te_events"))
	events = _text("")
	reset_dialog = ConfirmationDialog.new()
	reset_dialog.title = Texto.texto("reset")
	reset_dialog.dialog_text = ""
	reset_dialog.ok_button_text = Texto.texto("reset")
	reset_dialog.cancel_button_text = Texto.texto("te_keep")
	reset_dialog.min_size = Vector2i(480, 180)
	add_child(reset_dialog)
	reset_dialog.confirmed.connect(confirm_reset)

func _text(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	add_child(label)
	return label

func _button(key: String, action: Callable, parent: Node = self) -> Button:
	var button := Button.new()
	button.text = Texto.texto(key)
	button.add_theme_font_size_override("font_size", 13)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func observe(value, id: int) -> void:
	if world != value or creature_id != id:
		world = value
		creature_id = id
		target = Vector2.INF
		receipt.text = ""
		skill.clear()
		for item in world.ensino_habilidades():
			skill.add_item(Texto.texto(item.id))
			skill.set_item_metadata(skill.item_count - 1, item.id)
		refresh(true)
	elif _tick != world.tick:
		refresh()

func selected_skill() -> String:
	return str(skill.get_item_metadata(skill.selected)) if skill.selected >= 0 else "ir_ate_local"

func mark(pos: Vector2) -> void:
	var previous := target
	target = pos
	# Moving an active local target goes through the simulator's cancellation rule.
	var active: Dictionary = snapshot.get("active", {})
	if active.get("status") == "active" and active.get("skill") == selected_skill() and selected_skill() == "ir_ate_local":
		var result: Dictionary = world.ensino_mostrar(creature_id, target, active.get("assisted", false))
		if not result.ok:
			receipt.text = Texto.ensino_codigo(result.code)
			target = previous
		changed.emit()
	refresh(true)

func start(assisted: bool) -> void:
	var active: Dictionary = snapshot.get("active", {})
	var result: Dictionary
	if active.get("status") == "active" and active.get("skill") == selected_skill():
		result = world.ensino_mostrar(creature_id, target if selected_skill() == "ir_ate_local" else Vector2.INF, assisted)
	else:
		result = world.ensino_iniciar(creature_id, selected_skill(), target, assisted, 200, "q")
	receipt.text = Texto.texto("te_started_assisted" if assisted else "te_started_auto") if result.ok else Texto.ensino_codigo(result.code)
	changed.emit()
	refresh(true)

func reward() -> void:
	var result: Dictionary = world.ensino_recompensar(creature_id)
	receipt.text = Texto.texto("te_rewarded", [result.updates]) if result.ok else Texto.ensino_codigo(result.code)
	changed.emit()
	refresh(true)

func cancel() -> void:
	world.ensino_cancelar(creature_id)
	receipt.text = Texto.texto("te_cancelled")
	changed.emit()
	refresh(true)

func request_reset() -> void:
	_reset_id = creature_id
	_reset_world = world
	reset_dialog.dialog_text = Texto.texto("te_reset_confirm", [Texto.nome_criatura(world.creatures[creature_id].name)])
	reset_dialog.popup_centered()

func confirm_reset() -> void:
	# Bind confirmation to the creature it named, even if selection changes.
	if world == _reset_world and world.ensino_reset(_reset_id):
		receipt.text = Texto.texto("te_reset_done")
	changed.emit()
	refresh(true)

func refresh(_force := false) -> void:
	_tick = world.tick
	snapshot = world.ensino_observar(creature_id)
	var valid: bool = snapshot.get("ok", false)
	for button in [mark_button, show_button, observe_button, cancel_button, reset_button]:
		button.disabled = not valid
	reward_button.disabled = true
	if not valid:
		heading.text = Texto.texto("no_selection_e2")
		for label in [target_label, badge, metrics, progress, comparison, events]:
			label.text = ""
		chart.observe([], selected_skill())
		return
	heading.text = Texto.texto("te_heading", [Texto.nome_criatura(world.creatures[creature_id].name)])
	var local := selected_skill() == "ir_ate_local"
	mark_button.disabled = not local
	var active: Dictionary = snapshot.get("active", {})
	if local and not target.is_finite() and active.get("skill") == selected_skill():
		var packed: Array = active.get("target", [])
		if packed.size() == 2:
			target = Vector2(packed[0], packed[1])
	target_label.text = Texto.texto("te_target", [Texto.numero(target.x, 0), Texto.numero(target.y, 0)]) if local and target.is_finite() else Texto.texto("te_target_missing" if local else "te_water_target")
	show_button.disabled = local and not target.is_finite()
	observe_button.disabled = show_button.disabled
	cancel_button.disabled = active.get("status") != "active"
	progress.text = Texto.texto("te_idle") if active.is_empty() else Texto.texto("te_progress", [Texto.texto(str(active.skill)), Texto.ensino_codigo(active.status), active.steps, active.assistance])
	var creature = world.creatures[creature_id]
	reward_button.disabled = active.get("status") != "success" or active.get("rewarded", false) or creature.brain == null or not creature.brain.learning
	for data in snapshot.skills:
		if data.skill == selected_skill():
			badge.text = Texto.texto("learned" if data.learned else "not_learned")
			badge.add_theme_color_override("font_color", Color("bfe5ae") if data.learned else Color("ffe29a"))
			metrics.text = Texto.texto("te_metrics", [Texto.numero(data.success_rate * 100, 0), data.successes, data.attempts, snapshot.attempts.size(), snapshot.sessions.size()])
	chart.observe(snapshot.attempts, selected_skill())
	var pair: Dictionary = snapshot.get("before_after", {})
	comparison.text = Texto.texto("te_comparison", [Texto.numero(pair.before * 100, 0), Texto.numero(pair.after * 100, 0)]) if pair.get("skill") == selected_skill() else Texto.texto("te_comparison_empty")
	var rows: Array[String] = []
	for event in snapshot.events.slice(maxi(0, snapshot.events.size() - 10)):
		rows.append(Texto.ensino_evento(event))
	rows.reverse()
	events.text = "\n\n".join(rows) if not rows.is_empty() else Texto.texto("te_events_empty")
