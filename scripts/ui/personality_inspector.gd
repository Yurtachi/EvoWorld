extends TabContainer
## Read-only presentation of the real E2 lifetime state.
const Texto = preload("res://scripts/core/textos.gd")
const ThemeAPI = preload("res://scripts/ui/garden_theme.gd")
var need_bars: Dictionary = {}
var need_labels: Dictionary = {}
var traits: Label
var memory: Label
var preferences: Label
var bonds: Label
var encounters: Label
var expression: Label
var legacy: Label

func _ready() -> void:
	custom_minimum_size.y = 326
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	get_tab_bar().add_theme_font_size_override("font_size", 12)
	add_theme_font_size_override("font_size", 12)
	get_tab_bar().add_theme_constant_override("h_separation", 6)
	for style in ["tab_selected", "tab_unselected", "tab_hovered", "tab_disabled"]:
		var box := ThemeAPI.panel(Color("344f42") if style == "tab_selected" else Color("10291f"), 4, 5)
		get_tab_bar().add_theme_stylebox_override(style, box)
		add_theme_stylebox_override(style, box)
	add_theme_stylebox_override("panel", ThemeAPI.panel(Color("193329"), 8, 8))
	for kind in ["tab_needs", "tab_traits", "tab_memory", "tab_preferences", "tab_bonds"]:
		var scroll := ScrollContainer.new()
		scroll.name = Texto.texto(kind)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		add_child(scroll)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 5)
		scroll.add_child(col)
		match kind:
			"tab_needs":
				legacy = _text(col, "")
				_text(col, Texto.texto("needs_note"))
				for key in ["hunger", "thirst", "fatigue", "boredom", "loneliness"]:
					need_labels[key] = _text(col, "")
					var bar := ProgressBar.new()
					bar.show_percentage = false
					bar.custom_minimum_size.y = 7
					col.add_child(bar)
					need_bars[key] = bar
				expression = _text(col, "")
				_text(col, Texto.texto("expression_legend"))
			"tab_traits":
				_text(col, Texto.texto("traits_note"))
				traits = _text(col, "")
				_text(col, Texto.texto("learned_note"))
			"tab_memory":
				_text(col, Texto.texto("memory_note"))
				memory = _text(col, "")
			"tab_preferences":
				_text(col, Texto.texto("preferences_note"))
				preferences = _text(col, "")
			"tab_bonds":
				_text(col, Texto.texto("bonds_note"))
				bonds = _text(col, "")
				_text(col, Texto.texto("social_history"))
				_text(col, Texto.texto("social_history_note"))
				encounters = _text(col, "")
				_text(col, Texto.texto("social_legend"))

func _text(parent: Node, value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 13)
	parent.add_child(label)
	return label

static func needs(creature, world) -> Dictionary:
	return {"hunger": creature.hunger, "thirst": creature.thirst if world.water_enabled else 0.0,
		"fatigue": creature.personality.fatigue if creature.personality != null else 0.0,
		"boredom": creature.personality.boredom if creature.personality != null else 0.0,
		"loneliness": creature.personality.loneliness if creature.personality != null else 0.0}

static func urgent(creature, world) -> String:
	var values := needs(creature, world)
	var key := "hunger"
	for candidate in values:
		if float(values[candidate]) > float(values[key]):
			key = candidate
	return Texto.texto("urgent", [Texto.texto("need_" + key), Texto.numero(float(values[key]) * 100, 0)]) if float(values[key]) >= 0.1 else Texto.texto("urgent_none")

func observe(creature, world) -> void:
	if creature == null:
		legacy.text = Texto.texto("no_selection_e2")
		legacy.show()
		for bar in need_bars.values():
			bar.value = 0
		for label in need_labels.values():
			label.text = "—"
		for label in [traits, memory, preferences, bonds, encounters, expression]:
			label.text = ""
		return
	var enabled: bool = creature.personality != null
	legacy.text = "" if enabled else Texto.texto("legacy_personality")
	legacy.visible = not enabled
	var values := needs(creature, world)
	for key in values:
		var active: bool = (key != "thirst" or world.water_enabled) and (key in ["hunger", "thirst"] or enabled)
		need_bars[key].value = float(values[key]) * 100
		need_labels[key].text = Texto.texto("need_value", [Texto.texto("need_" + key), Texto.numero(float(values[key]) * 100, 0)]) if active else Texto.texto("need_disabled", [Texto.texto("need_" + key)])
	var state: Dictionary = creature.expression_state()
	expression.text = Texto.texto("expression_scores", [Texto.expressao(state), Texto.numero(float(state.valence), 2), Texto.numero(float(state.arousal) * 100, 0)]) if enabled else ""
	if not enabled:
		for label in [traits, memory, preferences, bonds, encounters]:
			label.text = Texto.texto("legacy_personality")
		return
	var rows: Array[String] = []
	for key in ["curiosity", "caution", "sociability", "impulsivity"]:
		rows.append(Texto.texto("trait_value", [Texto.gene(key), Texto.numero(float(creature.temperament[key]) * 100, 0)]))
	traits.text = "\n\n".join(rows)
	rows.clear()
	var episodes: Array = creature.personality.episodes
	for index in range(episodes.size() - 1, maxi(-1, episodes.size() - 9), -1):
		rows.append(Texto.episodio(episodes[index]))
	memory.text = "\n\n".join(rows) if not rows.is_empty() else Texto.texto("memory_empty")
	rows.clear()
	for kind in ["fruta", "semente", "folha", "cogumelo", "legacy"]:
		var known: bool = creature.personality.preferences.has(kind)
		rows.append(Texto.texto("preference_value", [Texto.texto("food_" + kind), Texto.numero(float(creature.personality.preferences[kind]), 3)]) if known else Texto.texto("preference_unknown", [Texto.texto("food_" + kind)]))
	preferences.text = "\n\n".join(rows)
	rows.clear()
	for item in world.social_observar(creature.id).relations:
		var who: String = Texto.nome_criatura(world.creatures[item.id].name) if world.creatures.has(item.id) else Texto.texto("bond_unknown", [item.id])
		rows.append(Texto.texto("social_row", [who, item.id, Texto.numero(item.familiarity * 100, 1), Texto.numero(item.affinity * 100, 1), Texto.numero(item.aversion * 100, 1), Texto.texto("encounter_count_one") if int(item.encounters) == 1 else Texto.texto("encounter_count", [int(item.encounters)]), item.last_tick]))
	if creature.personality.bonds.has("player"):
		var item: Dictionary = creature.personality.bonds.player
		rows.append(Texto.texto("bond_row", [Texto.texto("bond_player"), Texto.numero(item.familiarity * 100, 1), item.count, item.last_tick]))
	bonds.text = "\n\n".join(rows) if not rows.is_empty() else Texto.texto("bonds_empty")
	rows.clear()
	for index in range(episodes.size() - 1, -1, -1):
		if episodes[index].reward_source == "encounter":
			rows.append(Texto.episodio(episodes[index]))
			if rows.size() == 8:
				break
	encounters.text = "\n\n".join(rows) if not rows.is_empty() else Texto.texto("social_history_empty")
