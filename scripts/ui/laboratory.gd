extends VBoxContainer
signal intervention
## Consultas somente de leitura; emissão/ativação são intervenções explícitas.
const Texto = preload("res://scripts/core/textos.gd")
const Genes = preload("res://scripts/creature/genome.gd")
const Chart = preload("res://scripts/ui/population_chart.gd")
const SAMPLE_LIMIT := 180
const LIST_LIMIT := 12
var samples: Array = []
var summary: Label
var history: Label
var chart: Control
var genome: Label
var traits: Label
var mutations: Label
var ancestors: Label
var descendants: Label
var diversity: Label
var events: Label
var signals: Label
var signal_result: Label
var signal_switch: CheckButton
var symbol_input: OptionButton
var emit_button: Button
var emission_receipt: Label
var signal_controls: VBoxContainer
var _world
var _last_tick := -1
var _last_selection := -2

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text(Texto.texto("lab_intro"))
	summary = _text("")
	_heading("lab_chart")
	chart = Chart.new()
	add_child(chart)
	history = _text("")
	_heading("genome")
	genome = _text("")
	traits = _text("")
	_heading("lab_mutations")
	mutations = _text("")
	_heading("lab_ancestors")
	ancestors = _text("")
	_heading("lab_descendants")
	descendants = _text("")
	_heading("lab_diversity")
	diversity = _text("")
	_text(Texto.texto("lab_diversity_note"))
	_heading("events_title")
	events = _text("")
	_heading("signals_title")
	signal_result = _text(Texto.texto("signals_result"))
	signal_result.add_theme_color_override("font_color", Color("ffdda5"))
	signal_controls = VBoxContainer.new()
	add_child(signal_controls)
	signal_switch = CheckButton.new()
	signal_switch.text = Texto.texto("signals_enabled")
	signal_controls.add_child(signal_switch)
	signal_switch.toggled.connect(func(enabled):
		if _world != null and _world.has_method("emitir_sinal"):
			_world.signal_enabled = enabled
			intervention.emit()
			observe(_world, _last_selection, true))
	symbol_input = OptionButton.new()
	signal_controls.add_child(symbol_input)
	emit_button = Button.new()
	emit_button.text = Texto.texto("signals_emit")
	signal_controls.add_child(emit_button)
	emit_button.pressed.connect(_emit_selected)
	_text(Texto.texto("signals_manual"))
	emission_receipt = _text("")
	_heading("signals_log")
	signals = _text("")

func reset() -> void:
	samples.clear()
	_last_tick = -1
	_last_selection = -2
	emission_receipt.text = ""

func observe(world, selected_id: int, force: bool = false) -> void:
	_world = world
	# Limita o custo do histórico e das consultas genealógicas na renderização.
	if not force and _last_selection == selected_id and world.tick == _last_tick:
		return
	var variances: Dictionary = world.genetic_diversity()
	if samples.is_empty() or world.tick - int(samples.back().tick) >= 50:
		var normalized := 0.0
		for gene in Genes.BOUNDS:
			var span: float = Genes.BOUNDS[gene][1] - Genes.BOUNDS[gene][0]
			normalized += float(variances.get(gene, 0)) / (span * span)
		samples.append({"tick": world.tick, "population": world.creatures.size(), "diversity": normalized / Genes.BOUNDS.size()})
		if samples.size() > SAMPLE_LIMIT:
			samples.pop_front()
		chart.samples = samples
		chart.queue_redraw()
	_last_tick = world.tick
	_last_selection = selected_id
	if not is_visible_in_tree() and not force:
		return
	var births := 0
	var deaths := 0
	var max_generation := 0
	for entry in world.genealogy.records.values():
		births += 0 if entry.parents.is_empty() else 1
		deaths += 0 if int(entry.death_tick) < 0 else 1
		max_generation = maxi(max_generation, int(entry.generation))
	summary.text = Texto.texto("lab_summary", [world.creatures.size(), max_generation, births, deaths])
	history.text = Texto.texto("lab_history", [samples.size(), samples.front().tick, samples.back().tick])
	var rows: Array[String] = []
	for gene in Genes.BOUNDS:
		rows.append("%s: %s" % [Texto.gene(gene), Texto.numero(float(variances[gene]), 4)])
	diversity.text = "\n".join(rows)
	var lineage: Array = world.lineage(selected_id)
	var record: Dictionary = {}
	var family: Array = []
	for entry in lineage:
		if int(entry.creature_id) == selected_id:
			record = entry
		else:
			family.push_front(entry)
	if record.is_empty():
		genome.text = Texto.texto("lab_no_record")
		traits.text = ""
		mutations.text = Texto.texto("lab_none")
		ancestors.text = Texto.texto("lab_none")
		descendants.text = Texto.texto("lab_none")
	else:
		genome.text = Texto.texto("lab_genome", [int(record.genome.id), selected_id, int(record.generation), int(record.birth_tick)])
		rows.clear()
		for gene in Genes.BOUNDS:
			rows.append("%s: %s" % [Texto.gene(gene), Texto.numero(float(record.genome[gene]), 4)])
		traits.text = "\n".join(rows)
		rows.clear()
		for mutation in record.mutations:
			rows.append(Texto.texto("lab_mutation", [Texto.gene(mutation.gene), Texto.numero(float(mutation.delta), 6)]))
		mutations.text = Texto.texto("lab_none") if rows.is_empty() else "\n".join(rows)
		ancestors.text = _records(family) if not family.is_empty() else Texto.texto("lab_legacy" if record.get("legacy_root", false) else "lab_founder")
		descendants.text = _records(world.descendants(selected_id))
	var recent: Array[String] = []
	var feeding: Array[String] = []
	var signal_rows: Array[String] = []
	for i in range(world.events.size() - 1, -1, -1):
		var event = world.events[i]
		if not event is Dictionary:
			continue
		if str(event.get("type", "")).begins_with("signal"):
			if signal_rows.size() < 20:
				signal_rows.append(Texto.evento(event))
		elif event.get("type") == "eat" and feeding.size() < 4:
			feeding.append(Texto.evento(event))
		elif event.get("type") in ["birth", "death", "spawn"] and recent.size() < 12:
			recent.append(Texto.evento(event))
	recent.append_array(feeding)
	# Contrato opcional de SINAIS: o log dedicado pode sobreviver ao giro do
	# buffer geral. Sem a API, a UI conserva o gancho e os eventos existentes.
	for property in world.get_property_list():
		if property.name != "signal_log":
			continue
		var log = world.get("signal_log")
		if log is Array and not log.is_empty():
			signal_rows.clear()
			for i in range(log.size() - 1, maxi(-1, log.size() - 21), -1):
				if log[i] is Dictionary:
					signal_rows.append(Texto.sinal(log[i]))
	events.text = Texto.texto("lab_none") if recent.is_empty() else "\n\n".join(recent)
	signal_controls.visible = world.has_method("emitir_sinal")
	if signal_controls.visible:
		signal_switch.set_pressed_no_signal(world.signal_enabled)
		if symbol_input.item_count != int(world.signal_count):
			symbol_input.clear()
			for symbol in range(int(world.signal_count)):
				symbol_input.add_item(Texto.texto("signals_symbol", [symbol]))
		emit_button.disabled = not world.signal_enabled or not world.creatures.has(selected_id)
		signals.text = "\n\n".join(signal_rows) if not signal_rows.is_empty() else Texto.texto("signals_empty" if world.signal_enabled else "signals_disabled")
	else:
		signals.text = Texto.texto("signals_hook")

func _emit_selected() -> void:
	if _world == null or not _world.has_method("emitir_sinal"):
		return
	var emitted: bool = _world.emitir_sinal(_last_selection, symbol_input.selected)
	emission_receipt.text = Texto.texto("signals_emission_ok" if emitted else "signals_emission_failed")
	if emitted:
		intervention.emit()
	observe(_world, _last_selection, true)

func _records(records: Array) -> String:
	var rows: Array[String] = []
	for entry in records.slice(0, LIST_LIMIT):
		var state := Texto.texto("lab_alive") if int(entry.death_tick) < 0 else Texto.texto("lab_dead", [int(entry.death_tick)])
		rows.append(Texto.texto("lab_record", [int(entry.creature_id), Texto.nome_criatura(str(entry.name)), int(entry.generation), state]))
	if records.size() > LIST_LIMIT:
		rows.append(Texto.texto("lab_more", [records.size() - LIST_LIMIT]))
	return Texto.texto("lab_none") if rows.is_empty() else "\n".join(rows)

func _text(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("c8d6c0"))
	add_child(label)
	return label

func _heading(code: String) -> void:
	add_child(HSeparator.new())
	var label := _text(Texto.texto(code))
	label.add_theme_color_override("font_color", Color("dbe8a5"))
