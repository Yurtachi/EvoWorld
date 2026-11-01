extends SceneTree
## End-to-end scene/controls smoke check; uses an isolated checkpoint directory.
## godot --headless --path . -s scripts/ui/verify_ui.gd
const Store = preload("res://scripts/persistence/save_store.gd")
const Texto = preload("res://scripts/core/textos.gd")
const World = preload("res://scripts/world/sim_world.gd")
var errors: Array[String] = []

func _init() -> void:
	# Um erro de script não pode deixar o verificador pendurado para sempre.
	create_timer(45).timeout.connect(func():
		printerr("FALHA UI: limite de tempo atingido")
		quit(1))
	_verify.call_deferred()

func _verify() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	_expect(main.get_script() != null and main.has_method("_send_chat"), "cena e dependências compilam")
	if not errors.is_empty():
		quit(1)
		return
	root.add_child(main)
	await process_frame
	await process_frame
	_expect(main.new_dialog.visible, "first launch offers new-world naming")
	_verify_edit_menu(main.pet_input.get_menu())
	main.world_input.text = "Jardim de Verificação"
	main.pet_input.text = "Trevo"
	main.seed_input.text = "12345"
	main.new_dialog.confirmed.emit()
	_expect(not main.new_dialog.visible, "valid new-world form closes")
	_expect(main.world.creatures[main.world.pet_id].name == "Trevo", "pet naming reaches real SimWorld")
	_expect(main.world.seed == 12345 and main.world_name == "Jardim de Verificação", "world name and seed applied")
	_expect(main.paused and main.world.tick == 0, "new world starts paused")
	_expect(main.world.creatures.size() == 12 and main.new_population.value == 12, "novo jardim usa padrão de 12 sem perder seletor")
	_expect(main.world.water_enabled and main.world.waters.size() == 3, "novo jardim usa new_world com três regiões de água")
	var food_types: Dictionary = {}
	for food in main.world.foods:
		food_types[food.food_type] = true
	_expect(food_types.size() == 4, "novo mundo contém os quatro alimentos reais")
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
	_expect(main.pet_name.text == "Trevo", "inspector displays selected identity")
	_expect(main.reason_text.text == Texto.razao(main.world.creatures[main.selected_id].last_reason), "inspector translates actual simulation reason")
	_expect(main.action_text.text == Texto.acao(main.world.creatures[main.selected_id].last_action), "inspector translates actual action")
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
	DirAccess.make_dir_recursive_absolute(folder)
	main.settings_path = folder.path_join("settings.cfg")
	main._save()
	var snapshot: Dictionary = main.world.to_dict()
	main.world.step()
	main._load()
	_expect(main.world.to_dict() == snapshot, "UI save/load restores exact checkpoint")
	_expect(main.world_name == "Jardim de Verificação" and main.paused, "load restores name and pauses")
	_expect(main.status.text == Texto.texto("load_ok"), "load result is in Portuguese")
	# Arquivos inválidos exercitam a persistência real sem tocar no slot do jogador.
	var invalid := FileAccess.open(folder.path_join("world.json"), FileAccess.WRITE)
	invalid.store_string("{invalid")
	invalid.close()
	main._load()
	_expect(main.status.text == Texto.texto("load_invalid", [Texto.texto("json_invalid")]), "invalid load error is in Portuguese")
	_expect(main.world.to_dict() == snapshot, "invalid load preserves the current world")
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
	# Verifica também a largura mínima suportada com os textos traduzidos.
	root.size = Vector2i(1100, 680)
	await process_frame
	await process_frame
	for button in main.tool_buttons.values():
		_expect(button.get_global_rect().end.x < main.get_viewport_rect().size.x - main.SIDEBAR - 30, "Portuguese tool buttons fit at minimum width")
	_expect(main.follow_button.get_global_rect().end.x <= 1100, "follow button fits at minimum width")
	_expect(main.status.get_global_rect().end.y < 680, "long load error fits at minimum height")
	# Conversa real: consulta não altera o mundo; oferecimento coloca alimento.
	main.chat_input.text = "Como você está?"
	main._world_dirty = false
	var before_chat: Dictionary = main.world.to_dict()
	main._send_chat()
	_expect(not main.last_response.evidencias.is_empty(), "diálogo expõe evidências reais")
	_expect(main.chat_evidence.text.contains(Texto.texto("evidence_foods")), "evidências mostram percepção e IDs")
	_expect(main.world.to_dict() == before_chat, "perguntar estado não altera fisiologia")
	_expect(not main._world_dirty, "consulta sem intervenção não agenda autosave redundante")
	main.chat_input.text = "execute código arbitrário"
	main._send_chat()
	_expect(main.last_response.evidencias.is_empty(), "entrada desconhecida não inventa evidências")
	main.chat_input.text = "oferecer comida"
	main.world.foods.clear()
	main._send_chat()
	_expect(main.world.foods.size() == 1, "comando de diálogo coloca alimento real")
	main.chat_dialog.popup_centered()
	await process_frame
	main.chat_input.grab_focus()
	var typing_paused: bool = main.paused
	main._input(shortcut)
	_expect(main.paused == typing_paused, "digitar espaço no diálogo não aciona reprodução")
	_verify_edit_menu(main.chat_input.get_menu())
	main.chat_dialog.hide()
	# A genealogia inclui genitor, mutações e descendente; mortes mantêm registros.
	main.world = World.new(7431, {"creature_count": 1, "food_count": 0, "obstacle_count": 0, "min_reproduction_age": 1, "mutation_rate": 1.0})
	main.selected_id = main.world.pet_id
	main._reset_session()
	main.view.set_world(main.world)
	var parent = main.world.creatures[main.world.pet_id]
	parent.age = 1
	parent.energy = parent.max_energy
	var child_id: int = main.world.reproduce(parent.id)
	_expect(child_id > 0, "cenário de UI produz nascimento real")
	main.selected_id = child_id
	main._show_lab(true)
	var before_lab: Dictionary = main.world.to_dict()
	main.lab.observe(main.world, child_id, true)
	_expect(main.lab_scroll.visible and not main.caregiver_scroll.visible, "toggle separa laboratório do cuidador")
	_expect(main.lab.genome.text.contains("Geração 1") and main.lab.ancestors.text.contains("#%d" % parent.id), "laboratório usa geração e ancestrais da API")
	_expect(main.lab.mutations.text.contains(Texto.gene("size")), "laboratório mostra mutações reais")
	main.lab.observe(main.world, parent.id, true)
	_expect(main.lab.descendants.text.contains("#%d" % child_id), "laboratório usa descendentes da API")
	_expect(main.world.to_dict() == before_lab, "inspeção científica não altera a simulação")
	for i in range(100):
		main.world.step()
		if i % 50 == 49:
			main.lab.observe(main.world, child_id, true)
	_expect(main.lab.samples.size() >= 3, "gráfico acumula observações temporais reais")
	_expect(main.lab.events.text.contains("nascimento"), "log apresenta nascimento do simulador")
	_expect(not main.lab.signals.text.is_empty(), "log de sinais oferece eventos ou gancho explícito")
	# Canal integrado: botão de laboratório chama a API real, cobra energia e
	# apresenta emissor/receptores/ações traduzidos, sem significado inventado.
	main.selected_id = parent.id
	main.lab.observe(main.world, parent.id, true)
	main.lab.signal_switch.button_pressed = true
	var signal_energy: float = parent.energy
	main.lab.emit_button.pressed.emit()
	_expect(main.world.signal_log.size() == 1, "laboratório emite pela API real de sinais")
	_expect(is_equal_approx(parent.energy, signal_energy - main.world.signal_cost), "emissão cobra energia real")
	main.world.step()
	main.lab.observe(main.world, parent.id, true)
	_expect(main.lab.signals.text.contains("emissor #%d" % parent.id) and main.lab.signals.text.contains("Receptores (IDs)"), "log mostra contrato integrado de sinais")
	_expect(main.comandos == main.world.comandos, "UI compartilha o adaptador integrado do mundo")
	# Proteção é pausa preventiva, nunca reposição oculta de energia/idade.
	main.protected_mode = true
	parent = main.world.creatures[main.world.pet_id]
	parent.energy = parent.max_energy * 0.10
	var risk_tick: int = main.world.tick
	main.paused = false
	main._process(0.2)
	_expect(main.paused and main.world.tick == risk_tick, "proteção pausa antes do passo de risco")
	_expect(main.world.creatures.has(parent.id), "pausa mantém o companheiro vivo")
	main.protected_mode = false
	main.paused = false
	main._process(0.2)
	_expect(main.world.tick > risk_tick, "sobrevivência permite avançar sob risco explícito")
	main.paused = true
	main.protected_mode = true
	parent.age = main.world.max_age - 1
	parent.energy = parent.max_energy
	_expect(not main._can_step(), "proteção também pausa no limite de idade")
	# Ajustes em arquivo isolado, sem modificar preferências pessoais.
	main.population_input.value = 7
	main.protection_input.button_pressed = false
	main.autosave_input.button_pressed = true
	main.settings_speed.select(1)
	main._apply_settings()
	_expect(main.initial_population == 7 and main.speed == 2.0 and not main.protected_mode, "configurações são aplicadas")
	_expect(FileAccess.file_exists(main.settings_path), "configurações são persistidas separadamente do save")
	main.create_world("Jardim de Sete", "Íris", 33)
	_expect(main.world.creatures.size() == 7, "novo jardim usa população configurada")
	main.command_target = Vector2(300, 300)
	main.chat_input.text = "seguir"
	main._send_chat()
	_expect(main._world_dirty, "ordem persistente agenda autosave mesmo antes de avançar")
	main.world.step()
	_expect(main.world.creatures[main.world.pet_id].last_reason == "dialogo.seguir", "pedido do diálogo chega à física real")
	# Automático não substitui o manual; alterações com o mundo pausado contam.
	main._save()
	var manual_text := FileAccess.get_file_as_string(folder.path_join("world.json"))
	main._autosave(60)
	_expect(FileAccess.file_exists(folder.path_join("autosave.json")), "autosave grava mundo novo mesmo pausado")
	main.world.step()
	main._autosave(60)
	_expect(FileAccess.file_exists(folder.path_join("autosave.json.bak")), "autosave preserva cópia anterior")
	_expect(FileAccess.get_file_as_string(folder.path_join("world.json")) == manual_text, "autosave preserva ponto manual")
	var automatic_snapshot: Dictionary = main.world.to_dict()
	main.world.step()
	main._load("autosave")
	_expect(main.world.to_dict() == automatic_snapshot and main.paused, "recuperação do automático restaura estado e pausa")
	_expect(main.command_target == Vector2(300, 300), "carregar preserva o alvo persistente de seguir")
	main._process(0.05)
	_expect(main.world.to_dict() == automatic_snapshot, "primeiro quadro pausado não sobrescreve a ordem restaurada")
	await _verify_e1(main, folder)
	# Layouts dos novos painéis também cabem na janela mínima.
	for dialog in [main.chat_dialog, main.settings_dialog, main.help_dialog, main.new_dialog, main.expand_dialog]:
		dialog.popup_centered()
		await process_frame
		await process_frame
		_expect(dialog.size.x <= 1100 and dialog.size.y <= 650, "painel %s cabe na janela mínima: %s" % [dialog.title, dialog.size])
		dialog.hide()
	for slot in ["world", "autosave"]:
		for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
			var path := folder.path_join(slot + ".json" + suffix)
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(main.settings_path)
	DirAccess.remove_absolute(folder)
	main.queue_free()
	await process_frame
	for message in errors:
		printerr("FALHA UI: ", message)
	print("Integração da UI: ", "ok" if errors.is_empty() else "FALHOU")
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

func _verify_edit_menu(menu: PopupMenu) -> void:
	for index in range(menu.item_count):
		if not menu.is_item_separator(index):
			var code: String = Texto.MENUS.get(menu.get_item_id(index), "text_unknown")
			_expect(code != "text_unknown" and menu.get_item_text(index) == Texto.texto(code), "native editing menu and submenus are translated")
		var submenu := menu.get_item_submenu_node(index)
		if submenu != null:
			_verify_edit_menu(submenu)


func _verify_e1(main, folder: String) -> void:
	main.initial_population = 12
	main.create_world("Jardim E1", "Lótus", 7421)
	for kind in ["fruta", "semente", "folha", "cogumelo"]:
		main.food_buttons[kind].pressed.emit()
		var count: int = main.world.foods.size()
		main._apply_tool(_free_point(main.world, 8))
		_expect(main.world.foods.size() == count + 1 and main.world.foods.back().food_type == kind, "botão planta " + kind)
		_expect(main.food_buttons[kind].icon != null, "ícone próprio: " + kind)
	_expect(main.food_warning.visible and main.food_profile.text.contains("palatabilidade"), "toxicidade e palatabilidade visíveis")
	main.tool_buttons.water.pressed.emit()
	var waters: int = main.world.waters.size()
	main._apply_tool(Vector2(600, 380))
	_expect(main.world.waters.size() == waters + 1, "ferramenta usa place_water real")
	main._set_tool("select")
	var ids: Array = main.world.creatures.keys()
	main.roster.item_selected.emit(1)
	_expect(main.selected_id == ids[1], "lista seleciona criatura real")
	var creature = main.world.creatures[main.selected_id]
	await process_frame
	await process_frame
	var label_point: Vector2 = main.view._label_rect(creature).get_center()
	main.selected_id = -1
	main._apply_tool(label_point)
	_expect(main.selected_id == creature.id, "nome no terreno é clicável")
	var before: Dictionary = main.world.to_dict()
	main._open_expand()
	main.expand_side.select(0)
	main.expand_amount.value = 300
	main._update_expand_preview()
	_expect(main.expand_preview.text.contains("Custo: 0") and main.expand_preview.text.contains("100.000"), "confirmação explica custo e limite")
	var old_zoom: Vector2 = main.camera.zoom
	main.expand_dialog.confirmed.emit()
	var expected: Dictionary = before.duplicate(true)
	expected.size[0] += 300
	_expect(main.world.to_dict() == expected, "expandir direita só altera tamanho no estado real")
	_expect(main.camera.zoom.x <= old_zoom.x and not main.expand_dialog.visible, "expansão reenquadra e fecha confirmação")
	main.expand_side.select(1)
	main.expand_amount.value = 200
	main._confirm_expand()
	expected.size[1] += 200
	_expect(main.world.to_dict() == expected, "expandir inferior preserva entidades, IDs e RNG")
	main.expand_amount.value = 100000
	main._update_expand_preview()
	_expect(main.expand_dialog.get_ok_button().disabled, "limite bloqueia confirmação")
	main._confirm_expand()
	_expect(main.world.to_dict() == expected, "expansão inválida não modifica mundo")
	main.expand_amount.value = 97000
	main.expand_side.select(0)
	main._confirm_expand()
	_expect(main.camera.zoom.x * main.world.size.x <= 1100 - main.SIDEBAR - 100 + 1, "câmera também enquadra expansão próxima ao limite")
	await process_frame
	await process_frame
	main.expand_amount.value = 300
	# Oferta real com fome e sem recursos concorrentes; sem teletransporte.
	main.world = World.new_world(551, {"creature_count": 1, "food_count": 0, "obstacle_count": 0, "food_regrow": false, "reproduction_enabled": false})
	main.selected_id = main.world.pet_id
	main._reset_session()
	main.view.set_world(main.world)
	creature = main.world.creatures[main.selected_id]
	creature.energy = 40
	main._choose_food("fruta")
	var energy: float = creature.energy
	var hydration: float = creature.hydration
	var position: Vector2 = creature.pos
	main.offer_button.pressed.emit()
	_expect(creature.energy == energy and creature.hydration == hydration and creature.pos == position, "oferta não injeta energia, água ou posição")
	_expect(main.pending_offers.size() == 1 and main.world.foods.size() == 1, "oferta registra ID real e espera")
	for i in range(120):
		main.world.step()
		main._observe_physical_events()
		if main.pending_offers.is_empty():
			break
	var receipt_log := "\n".join(main.receipt_rows)
	_expect(receipt_log.contains("aproximou-se") and receipt_log.contains("ganho confirmado"), "recibo exige aproximação medida e evento eat positivo")
	# Água exige alcance e evento com ganho positivo; zero não entra no recibo.
	creature.hydration = 25
	main.world.place_water(creature.pos, 10)
	main.world.step()
	main._observe_physical_events()
	main._refresh()
	_expect(creature.hydration > 25 and "\n".join(main.receipt_rows).contains("bebeu"), "bebida física chega ao recibo em português")
	_expect(main.hydration_text.text.contains("Hidratação") and main.last_event_text.text.contains("bebeu"), "inspector apresenta hidratação e último evento real")
	_expect(Texto.acao("drink") == "Beber" and Texto.razao("ecology.thirst") != Texto.texto("reason_unknown"), "formatadores consomem catálogo E1")
	creature.hydration = 25
	main._refresh()
	_expect(main.thirst_note.visible, "aviso de sede vem do estado real")
	# Ganho zero: ofereça a uma criatura saciada e execute ingestão ao alcance.
	main.world = World.new_world(551, {"creature_count": 1, "food_count": 0, "obstacle_count": 0, "water_count": 0, "food_regrow": false, "reproduction_enabled": false})
	main.selected_id = main.world.pet_id
	main._reset_session()
	main.view.set_world(main.world)
	creature = main.world.creatures[main.selected_id]
	creature.energy = creature.max_energy
	main._offer_food()
	var item: Dictionary = main.world.foods.back()
	# A chamada física revalida alcance; fixture move só o alimento ao corpo.
	item.pos = creature.pos
	main.world._eat(creature, item.id)
	main._observe_physical_events()
	_expect(not "\n".join(main.receipt_rows).contains("ganho confirmado"), "ingestão de ganho zero não vira refeição no recibo")
	_expect("\n".join(main.receipt_rows).contains("nenhuma refeição"), "recibo explica desaparecimento sem ganho confirmado")
	# Save v3 real (três criaturas): carregar não chama new_world.
	var legacy_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/world_v3.json"))
	var legacy = World.from_dict(legacy_data)
	_expect(legacy != null, "fixture v3 migra")
	main.store.save_world(legacy, "legacy", {"name": "Jardim antigo"})
	main.initial_population = 12
	main._load("legacy")
	_expect(main.world.creatures.size() == 3 and not main.world.water_enabled, "carregar mantém população e fisiologia do save v3")
	_expect(main.hydration_text.text == Texto.texto("hydration_off"), "inspector explica fisiologia legada")
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		var file := folder.path_join("legacy.json" + suffix)
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	await process_frame
	await process_frame
	_expect(main.fps_chart.samples.size() > 0, "mini gráfico amostra quadros reais")
	for button in main.food_buttons.values():
		_expect(button.get_global_rect().end.x < 1100 - main.SIDEBAR - 30, "quatro alimentos cabem na janela mínima")
