extends SceneTree
## End-to-end scene/controls smoke check; uses an isolated checkpoint directory.
## godot --headless --path . -s scripts/ui/verify_ui.gd
const Store = preload("res://scripts/persistence/save_store.gd")
const Texto = preload("res://scripts/core/textos.gd")
const World = preload("res://scripts/world/sim_world.gd")
const ObjectMemory = preload("res://scripts/mind/object_memory.gd")
const ObjectPresenter = preload("res://scripts/ui/object_presenter.gd")
const ObjectCatalog = preload("res://scripts/environment/object_catalog.gd")
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
	# Keep graphical verification independent of personal launch preferences.
	main.settings_path = "user://ui_test_launch_%d.cfg" % OS.get_process_id()
	root.add_child(main)
	await process_frame
	await process_frame
	_expect(not main.new_dialog.visible, "first launch opens coexistence directly")
	_expect(main.world.creatures.size() == 1 and not main.world.reproduction_enabled, "one pet without reproduction by default")
	_expect(main.follow and main.camera.zoom.x >= 3.4, "camera follows expressive pet on launch")
	_expect(not main.tools_dialog.visible and not main.lab_scroll.is_visible_in_tree(), "science hidden on launch")
	main._open_new_world()
	_verify_edit_menu(main.pet_input.get_menu())
	main.world_input.text = "Jardim de Verificação"
	main.pet_input.text = "Trevo"
	main.seed_input.text = "12345"
	main.new_dialog.confirmed.emit()
	_expect(not main.new_dialog.visible, "valid new-world form closes")
	_expect(main.world.creatures[main.world.pet_id].name == "Trevo", "pet naming reaches real SimWorld")
	_expect(main.world.seed == 12345 and main.world_name == "Jardim de Verificação", "world name and seed applied")
	_expect(main.paused and main.world.tick == 0, "new world starts paused")
	_expect(main.world.creatures.size() == 1 and main.new_mode.selected == 0, "novo jardim usa um pet por padrao")
	_expect(main.world.water_enabled and main.world.waters.size() == 9, "novo pet usa o preset integrado com nove fontes fisicas de agua")
	var food_types: Dictionary = {}
	for food in main.world.foods:
		food_types[food.food_type] = true
	_expect(food_types.size() >= 1, "novo mundo contem alimentos reais do catalogo")
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
	_expect(main.action_text.text == Texto.pet_acao(main.world.creatures[main.selected_id]), "inspector translates actual action")
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
	main.follow = false
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
	main._refresh_pet_needs()
	_expect(main.needs.size() == 4, "four needs backed by physiology")
	main._focus_selected()
	main.camera.force_update_scroll()
	await process_frame
	await process_frame
	var pet = main.world.creatures[main.selected_id]
	var pet_screen: Vector2 = main.view.get_global_transform_with_canvas() * pet.pos
	var pet_radius: float = pet.genome.size * main.camera.zoom.x
	var pet_rect := Rect2(pet_screen - Vector2.ONE * pet_radius, Vector2.ONE * pet_radius * 2)
	_expect(not main.intro_card.get_global_rect().intersects(pet_rect), "tutorial does not cover the pet at minimum width")
	for key in main.feeding_buttons:
		_expect(main.caregiver_scroll.get_global_rect().encloses(main.feeding_buttons[key].get_global_rect()), "feeding mode fits without scrolling")
	var water_before: float = pet.hydration
	var energy_before: float = pet.energy
	var position_before: Vector2 = pet.pos
	main._offer_water()
	_expect(pet.hydration == water_before and pet.energy == energy_before and pet.pos == position_before, "offering water places a resource without changing the body")
	_expect(main.offer_button.is_visible_in_tree(), "feed action remains visible")
	main._set_feeding_mode("manual")
	_expect(not main.world.food_regrow, "manual feeding disables regrowth")
	main._set_feeding_mode("ecosystem")
	_expect(main.world.food_regrow, "ecosystem feeding enables regrowth")
	main._open_tools(0)
	await process_frame
	_expect(main.tools_dialog.visible and main.tools_tabs.get_tab_count() == 4, "contextual tools retain environment, activities, teaching and science")
	main.tools_dialog.hide()
	if main.world.has_method("place_feeder"):
		var feeders_before: int = main.pet_adapter.feeders(main.world).size()
		main._set_tool("feeder")
		main._apply_tool(_free_point(main.world, 18))
		_expect(main.pet_adapter.feeders(main.world).size() == feeders_before + 1, "feeder tool places a physical feeder")
		var body_energy: float = main.world.creatures[main.selected_id].energy
		var feeder: Dictionary = main.pet_adapter.feeders(main.world).back()
		var stock_before: int = int(feeder.get("estoque", feeder.get("stock", 0)))
		main._refill_feeder()
		feeder = main.pet_adapter.feeders(main.world).back()
		_expect(int(feeder.get("estoque", feeder.get("stock", 0))) == stock_before + 20, "refill reaches the physical stock")
		main._set_feeding_mode("feeder")
		_expect(main.feeder_dialog.visible and main.pet_adapter.current_mode(main.world) == "feeder", "feeder switch reaches the world and opens its controls")
		main._toggle_feeder()
		_expect(main.world.creatures[main.selected_id].energy == body_energy, "feeder controls do not refill the body directly")
		main.feeder_dialog.hide()
		var selected_before: int = main.selected_id
		main._set_tool("select")
		main._apply_tool(feeder.pos)
		_expect(main.feeder_dialog.visible and main.selected_id == selected_before, "clicking the feeder opens its controls and preserves the pet selection")
		main.feeder_dialog.hide()
		main._set_feeding_mode("ecosystem")
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
	_expect(main.tools_dialog.visible and main.tools_tabs.current_tab == 3, "toggle separa laboratório do cuidador")
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
	main._open_new_world()
	main.world_input.text = "Jardim de Sete"
	main.pet_input.text = "Trevo"
	main.seed_input.text = "33"
	main.new_mode.select(1)
	main.new_mode.item_selected.emit(1)
	main.new_population.value = 7
	main._confirm_new_world()
	_expect(main.world.reproduction_enabled and main.new_population.visible, "advanced ecosystem mode is explicit in the new-world dialog")
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
	await _verify_e2(main, folder)
	await _verify_e3(main, folder)
	await _verify_e4(main, folder)
	await _verify_m1(main, folder)
	await _verify_m2(main, folder)
	await _verify_m3(main, folder)
	await _verify_m3c(main, folder)
	await _verify_m4b(main, folder)
	main.tools_dialog.hide()
	# Layouts dos novos painéis também cabem na janela mínima.
	for dialog in [main.chat_dialog, main.settings_dialog, main.help_dialog, main.new_dialog, main.expand_dialog, main.object_dialog, main.demo_dialog, main.terminal_dialog, main.terminal_console_dialog, main.manual_dialog, main.refuse_dialog]:
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

func _verify_e2(main, folder: String) -> void:
	main.create_world("Jardim E2", "Mel escolhida", 7421)
	var creature = main.world.creatures[main.selected_id]
	_expect(main.world.personality_enabled and main.personality_inspector.get_tab_count() == 5, "E2 real com cinco abas")
	_expect(creature.name == "Mel escolhida", "nome escolhido para o pet prevalece")
	for other in main.world.creatures.values():
		_expect(not other.name.begins_with("Creature "), "fundadores recebem nomes naturais")
	_expect(Texto.acao("seek_contact") == "Aproximar-se de outra criatura" and Texto.razao("personality.fatigue").contains("Fadiga"), "lookup integra E2")
	creature.personality.fatigue = 0.82
	creature.personality.boredom = 0.33
	creature.personality.loneliness = 0.41
	main._refresh()
	_expect(is_equal_approx(main.personality_inspector.need_bars.fatigue.value, 82), "barra de fadiga usa estado real")
	_expect(main.roster.get_item_text(0).contains("Fadiga 82%"), "lista mostra necessidade mais urgente")
	_expect(main.personality_inspector.traits.text.contains("Curiosidade"), "temperamento herdado é legível")
	_expect(main.personality_inspector.preferences.text.contains("sem experiência"), "sem ingestão não inventa preferência")
	var before: Dictionary = creature.to_dict()
	main.tool_buttons.attention.pressed.emit()
	main._apply_tool(creature.pos + (main.world.size * 0.5 - creature.pos).normalized() * 60)
	_expect(creature.to_dict() == before and main.receipt_rows.back().contains("recusado"), "carinho distante falha sem mudar criatura")
	var energy: float = creature.energy
	var hydration: float = creature.hydration
	var position: Vector2 = creature.pos
	main._apply_tool(creature.pos)
	_expect(creature.personality.bonds.player.count == 1, "contato pelo controle cria vínculo real")
	_expect(creature.energy == energy and creature.hydration == hydration and creature.pos == position, "carinho não cria recursos físicos")
	main._apply_tool(creature.pos)
	_expect(creature.personality.bonds.player.count == 1 and main.receipt_rows.back().contains("aguarde 30"), "repetição gera recibo de intervalo")
	main._refresh()
	_expect(main.personality_inspector.memory.text.contains("Contato com o cuidador"), "episódio traduz o que fez e aconteceu")
	_expect(main.personality_inspector.bonds.text.contains("Você (cuidador)"), "vínculo mostra cuidador e familiaridade")
	_expect(main.personality_inspector.expression.text.contains("Aparenta") and not main.personality_inspector.expression.text.contains("sente"), "expressão usa aparência observada")
	main.world.place_food(creature.pos, "fruta")
	var item: Dictionary = main.world.foods.back()
	creature.energy = 45
	main.world._eat(creature, item.id)
	main._refresh()
	_expect(main.personality_inspector.preferences.text.contains(Texto.numero(creature.personality.preferences.fruta, 3)), "preferência vem de ingestão real")
	main.store.save_world(main.world, "e2", {"name": "E2 salvo"})
	var snapshot: Dictionary = main.world.to_dict()
	main._load("e2")
	_expect(main.world.to_dict() == snapshot, "UI preserva save v5 completo e nomes")
	main.selected_id = -1
	main._refresh()
	_expect(main.personality_inspector.memory.text.is_empty(), "sem seleção apaga memória da criatura anterior")
	# Percorre todas as abas na menor janela sem cortar largura.
	main.selected_id = main.world.pet_id
	main._refresh()
	for index in range(5):
		main.personality_inspector.current_tab = index
		await process_frame
		await process_frame
		var tab: Control = main.personality_inspector.get_child(index)
		_expect(tab.size.x <= main.caregiver_scroll.size.x, "aba E2 cabe na largura mínima")
		_expect(tab.get_child(0).size.x <= tab.size.x, "conteúdo E2 quebra linhas dentro da aba")
	main.personality_inspector.current_tab = 0
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		var path := folder.path_join("e2.json" + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

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

func _verify_e3(main, folder: String) -> void:
	# Same open-terrain fixture as SIM tests; never runs the efficacy experiments.
	main.world = preload("res://tests/unit/test_sim_e3.gd").new().scene(51)
	main.selected_id = main.world.pet_id
	main._reset_session()
	main.view.set_world(main.world)
	main._refresh()
	main.teaching_button.pressed.emit()
	var panel = main.teaching
	var creature = main.world.creatures[main.selected_id]
	_expect(main.tools_dialog.visible and main.tools_tabs.current_tab == 2, "Ensinar acessível no painel real")
	_expect(panel.skill.item_count == 2 and panel.show_button.disabled and panel.reward_button.disabled, "duas habilidades; local exige alvo e conclusão")
	var original: Dictionary = main.world.to_dict()
	panel.refresh(true)
	_expect(main.world.to_dict() == original, "snapshot de ensino é somente leitura")
	panel.mark_button.pressed.emit()
	main._apply_tool(Vector2(500, 300))
	_expect(panel.target == Vector2(500, 300) and main.view.teaching_target == panel.target, "clique marca alvo próprio de ensino")
	panel.show_button.pressed.emit()
	_expect(creature.ensino.active.assisted and creature.ensino.active.policy == "q", "Mostrar usa assistência real com política Q")
	_expect(creature.pos == Vector2(400, 300) and panel.reward_button.disabled, "Mostrar não teleporta e não permite prêmio antecipado")
	panel.mark(Vector2(-1, -1))
	_expect(panel.target == Vector2(500, 300) and panel.receipt.text.contains("Alvo recusado"), "alvo recusado preserva marcador físico anterior")
	main.world.step()
	panel.refresh(true)
	panel.observe_button.pressed.emit()
	_expect(not creature.ensino.active.assisted and creature.ensino.active.assistance > 0, "Observar desliga guia sem apagar assistência anterior")
	panel.show_button.pressed.emit()
	panel.mark(Vector2(510, 300))
	_expect(creature.ensino.attempts.back().status == "cancelled" and creature.ensino.active.target == [510.0, 300.0], "novo alvo cancela evidência anterior pela API")
	for i in range(200):
		main.world.step()
		if not creature.ensino.running():
			break
	panel.refresh(true)
	_expect(creature.ensino.active.status == "success" and not panel.reward_button.disabled, "chegada física libera Recompensar")
	var energy: float = creature.energy
	var hydration: float = creature.hydration
	var position: Vector2 = creature.pos
	panel.reward_button.pressed.emit()
	_expect(creature.ensino.active.rewarded and panel.reward_button.disabled and creature.brain.goal_updates > 0, "recompensa atualiza aprendizado uma única vez")
	_expect(creature.energy == energy and creature.hydration == hydration and creature.pos == position, "recompensa não repõe recursos nem posição")
	_expect(panel.badge.text == Texto.texto("not_learned") and panel.chart.rates.is_empty(), "assistência não conta como sucesso autônomo")
	_expect(panel.events.text.contains("Recompensa registrada") and panel.comparison.text.contains("Antes da sessão"), "eventos e comparação traduzidos")
	panel.reset_button.pressed.emit()
	_expect(panel.reset_dialog.visible and creature.brain.goal_updates > 0, "reinício espera confirmação")
	panel.reset_dialog.hide()
	_expect(creature.brain.goal_updates > 0, "fechar confirmação preserva aprendizado")
	panel.reset_button.pressed.emit()
	panel.reset_dialog.confirmed.emit()
	panel.reset_dialog.hide()
	_expect(creature.brain.goal_updates == 0 and panel.snapshot.attempts.is_empty(), "confirmação limpa só ensino")
	# Real autonomous attempts at nearby targets exercise the statistical badge.
	# This fixture verifies presentation, not generalization or efficacy.
	for i in range(5):
		panel.mark(creature.pos)
		panel.observe_button.pressed.emit()
		main.world.step()
		panel.refresh(true)
	_expect(panel.badge.text == Texto.texto("learned") and panel.chart.rates.size() == 5 and panel.metrics.text.contains("100%"), "selo e gráfico vêm de cinco desfechos reais sem assistência")
	main.store.save_world(main.world, "e3", {"name": "E3 salvo"})
	var saved: Dictionary = main.world.to_dict()
	main._load("e3")
	_expect(main.world.to_dict() == saved and panel.badge.text == Texto.texto("learned"), "UI restaura ensino e selo no save v6")
	creature = main.world.creatures[main.selected_id]
	panel.skill.select(1)
	panel.skill.item_selected.emit(1)
	creature.hydration = 65
	main.world.place_water(creature.pos + Vector2(55, 0), 20)
	panel.show_button.pressed.emit()
	for i in range(200):
		main.world.step()
		if not creature.ensino.running():
			break
	panel.refresh(true)
	_expect(creature.ensino.active.status == "success" and panel.events.text.contains("Bebida confirmada"), "Buscar água exige bebida física e exibe evento")
	main.selected_id = -1
	main._refresh()
	_expect(panel.reward_button.disabled and panel.events.text.is_empty(), "seleção ausente apaga dados anteriores e bloqueia ações")
	main.selected_id = main.world.pet_id
	main._refresh()
	main._show_teaching()
	await process_frame
	await process_frame
	_expect(panel.size.x <= main.teaching_scroll.size.x, "painel Ensinar cabe na largura mínima")
	for button in [panel.show_button, panel.observe_button, main.teaching_button, main.lab_button]:
		_expect(button.get_global_rect().end.x <= 1100 - 20, "botões Ensinar cabem na janela mínima")
	_expect(Texto.razao("teaching.assisted") == Texto.texto("assisted"), "razão E3 traduzida")
	panel.skill.select(0)
	panel.skill.item_selected.emit(0)
	panel.mark(creature.pos + Vector2(80, 0))
	panel.show_button.pressed.emit()
	main.chat_input.text = "parar"
	main._send_chat()
	_expect(panel.snapshot.active.status == "cancelled", "ordem de diálogo atualiza cancelamento mesmo no mundo pausado")
	var legacy := World.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/world_v3.json")))
	main.world = legacy
	main.selected_id = legacy.pet_id
	main._reset_session()
	main.view.set_world(legacy)
	main._refresh()
	panel.skill.select(1)
	panel.skill.item_selected.emit(1)
	panel.show_button.pressed.emit()
	_expect(panel.receipt.text.contains("sede desativada") and panel.reward_button.disabled, "save legado recusa habilidade hídrica sem inventar fisiologia")
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		var path := folder.path_join("e3.json" + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	main._show_lab(false)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)

func _verify_e4(main, folder: String) -> void:
	main._e4_inspection_fixture()
	var pet = main.world.creatures[main.world.pet_id]
	var inspector = main.personality_inspector
	_expect(inspector.bonds.text.contains("Bento") and inspector.bonds.text.contains("afinidade") and inspector.bonds.text.contains("aversão"), "Social usa vínculos reais e nomes naturais")
	_expect(inspector.bonds.text.contains("1 encontro ·") and not inspector.bonds.text.contains("1 encontros"), "contagem de encontros concorda em número")
	_expect(inspector.encounters.text.contains("Encontro próximo") and not inspector.encounters.text.contains(Texto.texto("text_unknown")), "histórico traduz episódios E4")
	_expect(main.view.social_marker(pet).recent, "encontro recente gera indicador da seleção")
	var before: Dictionary = main.world.to_dict()
	for row in main.chat_input.get_parent().get_children():
		if row is HBoxContainer:
			for button in row.get_children():
				button.pressed.emit()
				_expect(main.chat_input.text == button.text, "atalho de consulta usa sua própria pergunta")
	for question in ["Do que você gosta?", "O que aprendeu?", "Onde está a água?"]:
		main._world_dirty = false
		main.chat_input.text = question
		main._send_chat()
		_expect(main.chat_response.text.begins_with("Não sei"), "sem evidência responde não sei: " + question)
		_expect(main.chat_evidence.text.contains("Fonte interna:") and not main.chat_evidence.text.contains("Evento próprio registrado"), "fontes E4 não viram evento genérico")
		_expect(main.world.to_dict() == before and not main._world_dirty, "consulta E4 preserva mundo e autosave")
	pet.energy = pet.max_energy * 0.5
	main.world._eat(pet, main.world.place_food(pet.pos, "fruta"))
	main.chat_input.text = "Do que você gosta?"
	main._send_chat()
	_expect(main.chat_response.text.contains("Fruta") and main.chat_evidence.text.contains("personality.preferences") and main.chat_evidence.text.contains("Fruta:"), "gosto mostra valor aprendido por ingestão e fonte")
	main.world.place_water(pet.pos + Vector2(30, 0), 18)
	main.chat_input.text = "Onde está a água?"
	main._send_chat()
	_expect(main.chat_response.text.contains("Vejo") and main.chat_evidence.text.contains("sense.waters") and main.chat_evidence.text.contains("margem"), "água vem da percepção presente")
	main.world.waters.clear()
	main._send_chat()
	_expect(main.chat_response.text.begins_with("Não sei"), "água retirada não é localizada pelo mapa global")
	for index in range(5):
		main.teaching.mark(pet.pos)
		main.teaching.observe_button.pressed.emit()
		main.world.step()
		main.teaching.refresh(true)
	main.chat_input.text = "O que aprendeu?"
	main._send_chat()
	_expect(not main.chat_response.text.begins_with("Não sei") and main.chat_evidence.text.contains("5/5") and main.chat_evidence.text.contains("ensino.statistics"), "aprendizado mostra cinco conclusões reais e fonte")
	for action in ["social_approach", "social_follow", "social_avoid", "social_share", "social_compete"]:
		_expect(Texto.acao(action) != Texto.texto("action_unknown") and Texto.razao("social." + action.trim_prefix("social_")) != Texto.texto("reason_unknown"), "ação e razão E4 traduzidas: " + action)
	main.world.signal_enabled = true
	main.world.emitir_sinal(pet.id, 0)
	main.world.step()
	main.lab.observe(main.world, pet.id, true)
	_expect(main.lab.signals.text.contains("Receptor #") and main.lab.signals.text.contains("Contexto:"), "sinal mostra receptor, contexto e decisão traduzida")
	_expect(main.lab.signal_result.text.contains("18/20") and main.lab.signal_result.text.contains("encoder fixo") and Texto.texto("signals_title").contains("EXPERIMENTAL"), "resultado pré-registrado tem escopo e selo experimental")
	main.store.save_world(main.world, "e4", {"name": "E4 salvo"})
	var saved: Dictionary = main.world.to_dict()
	main._load("e4")
	_expect(main.world.to_dict() == saved and inspector.bonds.text.contains("afinidade"), "carregar v7 restaura painel social")
	main._e4_inspection_fixture(false, true)
	pet = main.world.creatures[main.world.pet_id]
	var relation: Dictionary = main.world.social_observar(pet.id).relations[0]
	_expect(relation.aversion > 0.0 and inspector.encounters.text.contains("disputa por alimento"), "aversão e consequência vêm de encontro físico com disputa")
	main.selected_id = -1
	main._refresh()
	_expect(inspector.bonds.text.is_empty() and inspector.encounters.text.is_empty(), "sem seleção limpa vínculos e encontros")
	main._e4_inspection_fixture(true)
	pet = main.world.creatures[main.world.pet_id]
	_expect(main.view.social_marker(pet).approaching, "aproximação social real gera seta corporal")
	main._show_lab(false)
	await process_frame
	await process_frame
	var tab: Control = inspector.get_child(4)
	_expect(tab.get_child(0).size.x <= tab.size.x and tab.size.x <= main.caregiver_scroll.size.x, "Social quebra linhas na janela mínima")
	main.chat_dialog.popup_centered()
	await process_frame
	await process_frame
	_expect(main.chat_dialog.size.x <= 1100 and main.chat_dialog.size.y <= 650, "conversa E4 cabe na janela mínima")
	main.chat_dialog.hide()
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		var path := folder.path_join("e4.json" + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func _verify_edit_menu(menu: PopupMenu) -> void:
	for index in range(menu.item_count):
		if not menu.is_item_separator(index):
			var code: String = Texto.MENUS.get(menu.get_item_id(index), "text_unknown")
			_expect(code != "text_unknown" and menu.get_item_text(index) == Texto.texto(code), "native editing menu and submenus are translated")
		var submenu := menu.get_item_submenu_node(index)
		if submenu != null:
			_verify_edit_menu(submenu)


func _verify_e1(main, folder: String) -> void:
	main.ecosystem_mode = true
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
	_expect(main.world.to_dict() == legacy.to_dict(), "carregar legado preserva snapshot e nomes sem aplicar catálogo de fundadores")
	_expect(main.hydration_text.text == Texto.texto("hydration_off"), "inspector explica fisiologia legada")
	_expect(main.personality_inspector.traits.text == Texto.texto("legacy_personality"), "UI não inventa temperamento ao carregar legado")
	main._give_attention(main.world.creatures[main.selected_id].pos)
	_expect(main.receipt_rows.back() == Texto.texto("attention_legacy"), "carinho legado retorna recusa explícita")
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		var file := folder.path_join("legacy.json" + suffix)
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	await process_frame
	await process_frame
	_expect(main.fps_chart.samples.size() > 0, "mini gráfico amostra quadros reais")
	for button in main.food_buttons.values():
		_expect(button.get_combined_minimum_size().x < 260, "quatro alimentos cabem na janela mínima")

func _verify_m2(main, folder: String) -> void:
	main._m2_fixture()
	var creature = main.world.creatures[main.selected_id]
	var original: Dictionary = creature.to_dict()
	main.tool_buttons.object.pressed.emit()
	_expect(main.object_dialog.visible and main.object_choice.item_count == 4, "M2 catálogo real com quatro objetos")
	var shortcut := InputEventKey.new()
	shortcut.pressed = true
	shortcut.keycode = KEY_SPACE
	main._input(shortcut)
	_expect(main.paused and main.tool == "select" and not main.tool_buttons.object.button_pressed, "M2 catálogo suspende atalhos e só muda ferramenta ao confirmar")
	for index in range(4):
		main.object_choice.select(index)
		main.object_dialog.confirmed.emit()
		main.object_dialog.hide()
		main._apply_tool(creature.pos + Vector2(24 + 25 * index, 0))
		_expect(main.world.objects.back().tipo == main.OBJECT_TYPES[index], "M2 ferramenta alcança place_object para cada lote")
		var label: String = main.object_choice.get_item_text(index)
		_expect(not label.contains("aversiv") and not label.contains("agradável") and not label.contains("neutra"), "M2 catálogo não revela consequência oculta")
	_expect(main.world.objects.size() == 4 and creature.to_dict() == original, "M2 colocação preserva corpo, mente e seleção")
	var first: Dictionary = ObjectCatalog.appearance(main.world.objects[0])
	for row in main.world.objects.slice(1, 3):
		var appearance: Dictionary = ObjectCatalog.appearance(row)
		_expect(appearance.category == first.category and appearance.appearance == first.appearance, "M2 cápsulas compartilham aparência pública")
	var world_before: Dictionary = main.world.to_dict()
	main._refresh()
	main.lab.observe(main.world, creature.id, true)
	_expect(main.world.to_dict() == world_before, "M2 inspeção não inicializa nem modifica memória")
	# Fresh fixture: decision, movement and contact only through real step().
	main._m2_fixture()
	creature = main.world.creatures[main.selected_id]
	main.object_type = "capsula_neutra"
	main._set_tool("object")
	main._apply_tool(creature.pos + Vector2(24, 0))
	var object_id: int = main.world.objects.back().id
	var origin: Vector2 = creature.pos
	main.world.step()
	main._refresh()
	main.lab.observe(main.world, creature.id, true)
	_expect(creature.last_action == "seek_object" and origin.distance_to(creature.pos) > 0, "M2 aproximação real sem comando")
	_expect(main.object_reaction.text.contains("curioso") and main.object_activity.text.contains("Aproximando"), "M2 convivência traduz interesse e movimento real")
	_expect(main.lab.object_memory.text.contains("fonte: observado") and main.lab.object_memory.text.contains("Sem evidência"), "M2 observar não inventa contato")
	_expect(main.lab.mind_logs.text.contains("novidade"), "M2 mind.iniciativa traduzido no laboratório")
	var public_row: Dictionary = main.world.sense(creature).objects[0]
	_expect(is_equal_approx(ObjectPresenter.novelty(creature.mind_snapshot(), public_row, main.world.tick), ObjectMemory.novelty(creature.mind, public_row, main.world.tick)), "M2 projeção de novidade coincide com simulador")
	for index in range(40):
		main.world.step()
		if creature.last_action == "investigate_object": break
	main._refresh()
	main.lab.observe(main.world, creature.id, true)
	_expect(creature.last_action == "investigate_object" and main.object_activity.text.contains("Investigando"), "M2 contato físico aparece na convivência")
	_expect(main.lab.object_memory.text.contains("fonte: interagido") and main.lab.object_memory.text.contains("Δenergia") and main.lab.object_memory.text.contains("Confiança: 1,00"), "M2 prova de contato, confiança e validade")
	# Repeated genuine contacts at the acquired position teach habituation.
	for index in range(7):
		main.world.tick += 181
		_expect(main.world.interact_object(creature, object_id), "M2 aquisição local de familiaridade")
	main._refresh()
	_expect(main.object_reaction.text.contains("perdeu o interesse"), "M2 familiaridade real produz expressão de habituação")
	main._show_lab(true)
	main.lab.memory_switch.button_pressed = false
	main.lab.curiosity_switch.button_pressed = false
	_expect(not creature.mind.memory_enabled and not creature.mind.objects.curiosity_enabled, "M2 ablações pela UI")
	_expect(main.lab.object_memory.text.contains("históricos") and main.lab.object_memory.text.contains("Curiosidade desligada"), "M2 registros retidos identificados como inativos")
	main.store.save_world(main.world, "m2", {"name": "M2 UI"})
	var saved: Dictionary = main.world.to_dict()
	main._load("m2")
	_expect(main.world.to_dict() == saved, "M2 save real preserva objetos, memória e ablações")
	# Adverse history learned only via physical contact, never by hidden type lookup.
	main._m2_fixture()
	creature = main.world.creatures[main.selected_id]
	var adverse: int = main.world.place_object(creature.pos, "capsula_aversiva")
	for index in range(3):
		main.world.tick += 181
		_expect(main.world.interact_object(creature, adverse), "M2 contatos aversivos reais")
	main._refresh()
	main.lab.observe(main.world, creature.id, true)
	_expect(main.object_reaction.text.contains("cauteloso") and main.lab.object_memory.text.contains(Texto.numero(-4.6)), "M2 cautela e evidência derivadas do histórico físico")
	main.tutorial_step = 3
	main._tutorial_move(0)
	_expect(main.tutorial_text.text.contains("objeto novo") and main.tutorial_text.text.contains("espere sem comandar"), "M2 roteiro de iniciativa não comandada")
	for reason in ["mind.iniciativa.novidade", "mind.iniciativa.lacuna", "mind.iniciativa.evento"]:
		_expect(Texto.razao(reason) != Texto.texto("reason_unknown"), "M2 motivo traduzido: " + reason)
	main._show_lab(true)
	await process_frame
	await process_frame
	_expect(main.lab.object_memory.size.x <= main.lab_scroll.size.x, "M2 memória quebra linhas na largura mínima")
	_expect(main.tool_buttons.object.get_combined_minimum_size().x < 260, "M2 seis ferramentas cabem na largura mínima")
	main.selected_id = -1
	main._refresh()
	main.lab.observe(main.world, -1, true)
	_expect(main.lab.object_memory.text.is_empty() and main.lab.curiosity_switch.disabled and main.object_activity.text.is_empty(), "M2 troca de seleção limpa conhecimento anterior")
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		var path := folder.path_join("m2.json" + suffix)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

func _verify_m1(main, folder: String) -> void:
	main.ecosystem_mode = true
	main.initial_population = 12
	main.create_world("M1", "Mel", 81002)
	var pet = main.world.creatures[main.world.pet_id]
	_expect(main.caregiver_scroll.visible and not main.lab_scroll.visible and main.care_button.text == "Convivência", "M1 convivência padrão e separada do laboratório")
	_expect(main.follow and main.camera.zoom.x >= 2, "M1 pet em destaque e acompanhado")
	_expect(main.world.mind_enabled_ids == [pet.id] and main.mind_enable.visible == false, "M1 só pet ativo por padrão")
	var before: Dictionary = main.world.to_dict()
	main._refresh()
	main.lab.observe(main.world, pet.id, true)
	_expect(main.world.to_dict() == before, "M1 leitura de UI e laboratório não altera o mundo")
	var ids: Array = main.world.creatures.keys()
	main.roster.item_selected.emit(1)
	main._refresh()
	var other = main.world.creatures[ids[1]]
	_expect(main.selected_id == other.id and main.follow and other.mind == null, "M1 seguir organismo não ativa mente")
	_expect(main.mind_emotion.text == "Sem mente ativa" and main.mind_enable.visible and main.mind_cost.text.contains("CPU"), "M1 ausência de mente e custo explícitos")
	var pos: Vector2 = other.pos
	var energy: float = other.energy
	main.mind_enable.pressed.emit()
	_expect(other.mind != null and other.pos == pos and other.energy == energy, "M1 ativação usa API sem alterar corpo")
	main.lab_button.pressed.emit()
	_expect(main.tools_dialog.visible and main.tools_tabs.current_tab == 3 and main.roster.visible and main.lab.affect_switch.button_pressed, "M1 laboratório e seletor acessíveis")
	main.lab.affect_switch.button_pressed = false
	main.lab.memory_switch.button_pressed = false
	_expect(not other.mind.affect_enabled and not other.mind.memory_enabled, "M1 ablações da seleção pela UI real")
	_expect(pet.mind.affect_enabled and pet.mind.memory_enabled, "M1 ablação preserva outra criatura")
	main._refresh()
	_expect(main.mind_emotion.text == Texto.texto("m1_affect_off") and main.lab.mind_values.text.contains("históricos"), "M1 afeto desligado não apresenta histórico como expressão ativa")
	main.selected_id = pet.id
	main._refresh()
	main.lab.observe(main.world, pet.id, true)
	main.lab.affect_switch.button_pressed = false
	main.lab.memory_switch.button_pressed = false
	_expect(not pet.mind.affect_enabled and not pet.mind.memory_enabled, "M1 permite ablação no pet")
	main.store.save_world(main.world, "m1", {"name": "M1"})
	main._load("m1")
	pet = main.world.creatures[main.world.pet_id]
	_expect(not pet.mind.affect_enabled and not pet.mind.memory_enabled, "M1 ablações persistem no save real")
	main.lab.observe(main.world, pet.id, true)
	main.lab.affect_switch.button_pressed = true
	main.lab.memory_switch.button_pressed = true
	var count: int = main.world.creatures.size()
	var selected: int = main.selected_id
	pos = pet.pos
	main._present_companion()
	_expect(main.world.creatures.size() == count + 1 and main.selected_id == selected and pet.pos == pos, "M1 companhia física preserva seleção e corpo")
	main.world.place_obstacle(pet.pos + Vector2(60, 0), 24)
	main._clear_nearby_rocks()
	_expect(main.world.obstacles.all(func(o): return pet.pos.distance_to(o.pos) > 120 + o.radius), "M1 retira rochas locais para observar recuperação")
	# Isolated physical fixture: trapped body produces real blocked-motion causes.
	main.world = World.new_world(81002, {"creature_count": 1, "food_count": 0, "water_count": 0, "obstacle_count": 0, "food_regrow": false, "reproduction_enabled": false})
	main.selected_id = main.world.pet_id
	pet = main.world.creatures[main.selected_id]
	for index in range(12):
		main.world.place_obstacle(pet.pos + Vector2.from_angle(index * TAU / 12) * (pet.genome.size + 25), 24)
	for index in range(35): main.world.step()
	main._reset_session()
	main.view.set_world(main.world)
	main._refresh()
	main._show_lab(true)
	_expect(main.mind_emotion.text.contains("frustrado") and main.mind_reason.text.contains("bloqueado"), "M1 frustração e motivo derivam de bloqueio físico")
	_expect(main.lab.mind_causes.text.contains("Passo") and main.lab.mind_scores.text.contains("Parece") and main.lab.mind_logs.text.contains("Passo"), "M1 causas, scores e mind_log traduzidos")
	for goal in ["comer", "beber", "descansar", "explorar", "buscar_companhia", "buscar_privacidade", "brincar", "investigar_objeto"]:
		_expect(Texto.razao("mind." + goal) != Texto.texto("reason_unknown"), "M1 razão traduzida: " + goal)
	main._show_lab(false)
	main.tutorial_dialog.popup_centered()
	for index in range(5):
		main.tutorial_step = index
		main._tutorial_move(0)
		_expect(main.tutorial_text.text.contains("min") and not main.tutorial_text.text.contains(Texto.texto("text_unknown")), "M1 roteiro cobre etapa " + str(index))
	await process_frame
	await process_frame
	_expect(main.tutorial_dialog.size.x <= 1100 and main.tutorial_dialog.size.y < 680, "M1 tutorial cabe na janela mínima")
	main.tutorial_dialog.hide()
	await process_frame
	await process_frame
	for label in [main.mind_emotion, main.mind_desire, main.mind_reason]:
		_expect(label.size.x <= main.caregiver_scroll.size.x, "M1 texto quebra linhas na largura mínima")
	main.selected_id = -1
	main._refresh()
	main.lab.observe(main.world, -1, true)
	_expect(main.mind_desire.text == Texto.texto("m1_no_selection") and main.lab.mind_scores.text.is_empty(), "M1 seleção ausente limpa dados antigos")
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		var path := folder.path_join("m1.json" + suffix)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)


func _verify_m3c(main, folder: String) -> void:
	main._m3c_fixture()
	var c = main.world.creatures[main.selected_id]
	main.tool_buttons.book.pressed.emit()
	_expect(main.book_dialog.visible and main.book_choice.item_count == 3, "M3c catálogo acessível pelo botão Livro")
	var tick: int = main.world.tick
	var space := InputEventKey.new()
	space.pressed = true
	space.keycode = KEY_SPACE
	main._input(space)
	main._process(0.2)
	_expect(main.paused and main.world.tick == tick, "M3c catálogo suspende atalhos")
	main.book_choice.select(2)
	main._confirm_book()
	main._apply_tool(c.pos + Vector2(42, 0))
	_expect(main.world.library.books.size() == 1 and main.world.library.books[0].book_id == "guia_enganoso", "M3c coloca o livro escolhido pela API real")
	var approached := false
	var reading := false
	for i in range(90):
		main.world.step()
		main._refresh()
		approached = approached or c.last_action == "seek_book" and main.reading_text.text.contains("aproximando")
		reading = reading or c.last_action == "read_book" and main.reading_text.text.contains("página 1/1")
		if not c.knowledge_snapshot().get("facts", []).is_empty(): break
	_expect(approached and reading, "M3c aproximação e página vêm de passos reais")
	main._open_knowledge()
	_expect(main.knowledge_text.text.contains("FONTE: livro") and main.knowledge_text.text.contains("CONFIANÇA") and main.knowledge_text.text.contains("validade até") and main.knowledge_text.text.contains("HIPÓTESE"), "M3c fato do livro tem proveniência, confiança, validade e estatuto")
	main.knowledge_dialog.hide()
	_expect(not main.knowledge_text.text.contains("perdeu credibilidade"), "M3c arredondamento de 0,80 não inventa contradição")
	var object_id: int = main.world.place_object(c.pos + Vector2(8, 0), "capsula_aversiva")
	_expect(main.world.interact_object(c, object_id), "M3c contradição usa contato real")
	main._open_knowledge()
	_expect(main.knowledge_text.text.contains("perdeu credibilidade") and main.knowledge_text.text.contains("0,35") and main.knowledge_text.text.contains("EVIDÊNCIA de contato"), "M3c fonte corrigida sem apagar proveniência")
	main.knowledge_dialog.hide()
	main._show_lab(true)
	main.lab.knowledge_open.button_pressed = true
	main.lab.memory_switch.button_pressed = false
	_expect(not c.mind.memory_enabled and main.lab.knowledge.text.contains("Memória em ablação"), "M3c ablação marca registros como históricos")
	main.store = Store.new(folder.path_join("m3c"))
	main._save()
	main._load()
	_expect(not main.world.creatures[main.selected_id].mind.memory_enabled and main.world.library.books.size() == 1, "M3c livros e ablação persistem pela UI")
	main._m3c_fixture()
	c = main.world.creatures[main.selected_id]
	object_id = main.world.place_object(c.pos + Vector2(8, 0), "capsula_aversiva")
	c.mind.decide(c, main.world.tick, main.world.sense(c))
	main._refresh()
	_expect(main.question_card.visible and main.question_text.text.contains("viu um objeto desconhecido"), "M3c lacuna mostra pergunta contextual discreta")
	await process_frame
	await process_frame
	for button in main.question_buttons.values():
		_expect(button.get_global_rect().end.x <= 1100 and button.get_global_rect().end.y <= 650, "M3c todas as opções cabem na área inicial")
	main.question_buttons.seguro.pressed.emit()
	_expect(main.knowledge_dialog.visible and main.knowledge_text.text.contains("O cuidador disse:") and main.knowledge_text.text.contains("FONTE: cuidador") and main.knowledge_text.text.contains("HIPÓTESE"), "M3c resposta fechada vira afirmação atribuída")
	_expect(main.world.pending_questions.is_empty() and not main.question_card.visible, "M3c pergunta respondida encerra")
	main.knowledge_dialog.hide()
	main.world.demonstrar_simbolo(c.id, "anel", object_id, true)
	main.world.demonstrar_simbolo(c.id, "anel", object_id, true)
	main._open_knowledge()
	_expect(main.knowledge_text.text.contains("anel → cápsula") and main.knowledge_text.text.contains("onda → associação desconhecida") and main.knowledge_text.text.contains("Não demonstram escrita"), "M3c glifos conhecidos e desconhecidos sem alegar escrita")
	await process_frame
	await process_frame
	_expect(main.knowledge_dialog.size.x <= 1100 and main.knowledge_dialog.size.y < 680 and main.knowledge_text.size.x <= 610, "M3c Conhecimento cabe e quebra texto na janela mínima")
	_expect(main.tool_buttons.book.get_global_rect().end.x < 1100 - main.SIDEBAR - 30, "M3c Livro cabe no rodapé mínimo")
	main.knowledge_dialog.hide()
	main._open_library_tutorial()
	_expect(main.tutorial_text.text.contains("7/7") and main.tutorial_text.text.contains("Não sei / ignorar"), "M3c roteiro cobre livro e dúvida")
	main.tutorial_dialog.hide()
	main._m3c_fixture()
	c = main.world.creatures[main.selected_id]
	main.world.place_object(c.pos + Vector2(8, 0), "pedra")
	c.mind.decide(c, main.world.tick, main.world.sense(c))
	main._refresh()
	main.question_buttons.silencio.pressed.emit()
	_expect(main.world.pending_questions.is_empty() and c.knowledge_snapshot().get("facts", []).is_empty(), "M3c ignorar encerra sem fato")
	main.selected_id = -1
	main._refresh()
	main._open_knowledge()
	_expect(main.reading_text.text.is_empty() and not main.knowledge_text.text.contains("O cuidador disse"), "M3c troca de seleção limpa conhecimento")
	main.knowledge_dialog.hide()

func _verify_m4b(main, folder: String) -> void:
	main._m4b_fixture()
	var c = main.world.creatures[main.selected_id]
	# 1. Ferramenta Terminal
	main.tool_buttons.terminal.pressed.emit()
	var term_pos: Vector2 = c.pos + Vector2(6, 0)
	main._apply_tool(term_pos)
	_expect(main.world.terminals.size() == 1, "M4b ferramenta terminal coloca dispositivo no mundo")
	var term_id: int = int(main.world.terminals[0].id)
	_expect(main.status.text.contains("Terminal #"), "M4b status informa colocação do terminal com ID")

	# 2. Console fictício do jogador
	main._open_terminal_console()
	_expect(main.terminal_console_dialog.visible, "M4b console do jogador abre quando solicitado")
	_expect(main.console_warning_label != null and main.console_warning_label.text.contains("terminal fictício: não executa comandos do computador"), "M4b console possui aviso explícito de terminal fictício")

	# Testar execução de comandos fictícios no console
	main.console_input.text = "AJUDA"
	main._run_console_command()
	_expect(main.console_output.text.contains("Resultado:") and main.console_output.text.contains("A ação virtual foi concluída"), "M4b console executa AJUDA e mostra resposta virtual em pt-BR")

	main.console_input.text = "MARCAR 3 0"
	main._run_console_command()
	_expect(main.console_output.text.contains("MARCAR"), "M4b console registra evento de MARCAR")

	# Testar rejeição de comandos hostis / shell
	main.console_input.text = "powershell -Command Get-Process"
	main._run_console_command()
	_expect(main.console_output.text.contains("não existe") or main.console_output.text.contains("não pertence") or main.console_output.text.contains("recusou"), "M4b console recusa comando de shell/OS sem executar no host")
	main.terminal_console_dialog.hide()

	# 3. Painel Terminal da criatura
	main._refresh()
	main._open_terminal_panel()
	_expect(main.terminal_dialog.visible, "M4b painel terminal da criatura abre")
	_expect(main.terminal_panel_text.text.contains("COMANDOS CONHECIDOS") and main.terminal_panel_text.text.contains("OLHAR") and main.terminal_panel_text.text.contains("AJUDA"), "M4b painel lista comandos conhecidos iniciais")
	_expect(main.terminal_panel_text.text.contains("AVALIAÇÃO EXPERIMENTAL X7") and main.terminal_panel_text.text.contains("prova científica") and main.terminal_panel_text.text.contains("FAIL global"), "M4b painel contém texto honesto do X7 com limites e FAIL global")
	main.terminal_dialog.hide()

	# 4. Oferecer manual à criatura
	main._open_offer_manual()
	_expect(main.manual_dialog.visible and main.manual_choice.item_count == 3, "M4b diálogo oferecer manual abre com 3 opções")
	main.manual_choice.select(0)
	main._confirm_offer_manual()
	_expect(main.world.terminal_snapshot(c).state.conhecidos.has("MARCAR"), "M4b oferecer manual revela novo comando (MARCAR)")

	# 5. Adiar / recusar terminal
	main._open_refuse_dialog()
	_expect(main.refuse_dialog.visible, "M4b diálogo de recusa/adiamento abre")
	main.refuse_duration_input.value = 240
	main._confirm_refuse()
	var snap = main.world.terminal_snapshot(c)
	_expect(int(snap.refusal_until) >= main.world.tick + 200, "M4b criatura adia terminal e status reflete recusa")
	_expect(main.terminal_activity_label.text.contains("Recusa / adiamento ativo"), "M4b inspector indica recusa/adiamento ativo")

	# 6. Laboratório: M4b seções
	main._show_lab(true)
	_expect(main.lab.terminal_history != null and main.lab.terminal_memory_status != null, "M4b componentes de terminal presentes no Laboratório")
	main.lab.terminal_history_open.button_pressed = true
	_expect(main.lab.terminal_history.visible and main.lab.terminal_history.text.contains("COMANDOS CONHECIDOS"), "M4b histórico de terminal expansível no Laboratório")
	_expect(main.lab.terminal_memory_status.text.contains("Memória ativa") or main.lab.terminal_memory_status.text.contains("Memória em ablação"), "M4b ablação e status de memória do terminal visíveis no Laboratório")

	# 7. Tutorial: passo 8
	main._open_terminal_tutorial()
	_expect(main.tutorial_dialog.visible and main.tutorial_step == 7 and main.tutorial_text.text.contains("8/8"), "M4b tutorial atualizado com passo 8 sobre terminal")
	main.tutorial_dialog.hide()

	# 8. Teste de save/load com terminal no mundo
	var m4b_dir := folder.path_join("m4b")
	DirAccess.make_dir_recursive_absolute(m4b_dir)
	main.store = Store.new(m4b_dir)
	main.settings_path = m4b_dir.path_join("settings.cfg")
	main._save()
	var saved_dict: Dictionary = main.world.to_dict()
	main._load()
	_expect(main.world.terminals.size() == 1 and main.world.to_dict() == saved_dict, "M4b save/load v13 restaura terminais e estado pela UI")

	# Limpeza de seleção
	main.selected_id = -1
	main._refresh()
	_expect(main.terminal_activity_label.text.is_empty(), "M4b desmarcar seleção limpa atividade do terminal")

func _verify_m3(main, folder: String) -> void:
	main._m3_fixture()
	var creature = main.world.creatures[main.selected_id]
	var before: Dictionary = main.world.to_dict()
	main._refresh()
	main.lab.observe(main.world, creature.id, true)
	_expect(main.world.to_dict() == before, "M3 inspeção de UI e laboratório não altera o mundo")
	main.tool_buttons.board.pressed.emit()
	main._apply_tool(creature.pos + Vector2(20, 0))
	_expect(main.world.boards.size() == 1 and main.status.text.contains("Quadro #"), "M3 ferramenta Quadro coloca quadro real via place_board")
	main._refresh()
	_expect(main.board_status_label.text.contains("Quadro #") and main.board_status_label.text.contains("livre"), "M3 painel mostra quadro livre recém-colocado")
	for _step in range(70):
		main.world.step()
		if not main.world.gallery.is_empty():
			break
	main._refresh()
	await process_frame
	_expect(not main.world.gallery.is_empty() and str(main.world.gallery[0].get("target_shape", "")) == "rabisco", "M3 criatura realiza rabisco livre espontâneo sem referência")
	_expect(main.gallery_list.get_child_count() >= 1 and not main.gallery_empty_label.visible, "M3 galeria exibe criação com miniatura em Convivência")
	main.tool_buttons.demo.pressed.emit()
	_expect(main.demo_dialog.visible and main.demo_shape_choice.item_count == 3, "M3 diálogo Demonstrar abre com linha, círculo e quadrado")
	main.demo_shape_choice.select(1)
	main.demo_scale_input.value = 1.2
	main.demo_center_x_input.value = 36
	main.demo_center_y_input.value = 28
	main.demo_dialog.confirmed.emit()
	main.demo_dialog.hide()
	var board_id: int = int(main.world.boards[0].id)
	_expect(str(main.world.boards[0].get("reference_shape", "")) == "circulo" and not main.world.boards[0].get("reference_strokes", []).is_empty(), "M3 Demonstrar aplica forma, escala e posição via demonstrar_forma")
	_expect(not main.board_canvas.reference_strokes.is_empty() and main.board_status_label.text.contains("Círculo"), "M3 guia de referência visível no quadro e no painel")
	var saw_live_drawing := false
	for _step in range(50):
		main.world.step()
		if creature.atelier != null and str(creature.atelier.active.get("status", "")) == "active" and not main.world.boards[0].get("active_strokes", []).is_empty():
			main._refresh()
			if creature.last_action == "draw_stroke" and main.board_live_label.text.contains("Traço em tempo real"):
				saw_live_drawing = true
			break
	_expect(saw_live_drawing, "M3 traços da criatura aparecem em tempo real durante draw_stroke")
	for shape_key in ["circulo", "circulo", "circulo", "circulo", "linha"]:
		creature.energy = creature.max_energy * 0.95
		creature.hydration = 95.0
		main.world.demonstrar_forma(board_id, shape_key, {"scale": 1.0, "center": [32.0, 32.0]})
		var prev_attempts: int = creature.atelier.attempts.size() if creature.atelier != null else 0
		for _step in range(90):
			main.world.step()
			if creature.atelier != null and creature.atelier.attempts.size() > prev_attempts:
				break
	main.world.demonstrar_forma(board_id, "quadrado", {"scale": 1.0, "center": [32.0, 32.0]})
	main._refresh()
	main._show_lab(true)
	_expect(main.lab.atelier_warning.text.contains("Superar controles sem treino") and main.lab.atelier_warning.text.contains("apenas o erro final"), "M3b Laboratório explicita retorno escalar e limites experimentais")
	_expect(main.lab.atelier_competence.text.contains("demonstrado") and main.lab.atelier_competence.text.contains("praticado") and not main.lab.atelier_competence.text.contains("aprendeu calibração guiada"), "M3b competência distingue demonstração e prática sem alegar domínio geral")
	_expect(main.lab.atelier_chart.total_points >= 4 and not main.lab.atelier_attempts.text.is_empty(), "M3 curva de erro e histórico de tentativas alimentados por dados reais")
	_expect(main.lab.atelier_status.text.contains("Treino do ateliê: ativo") and main.lab.atelier_status.text.contains("competência experimental"), "M3b status mostra treino ativo e competência experimental")
	main.lab.atelier_learning_switch.button_pressed = false
	main.lab._select_atelier_policy(2)
	_expect(not creature.atelier.learning and creature.atelier.policy_mode == "naive", "M3 ablação de treino e política no Laboratório altera estado real")
	main.store.save_world(main.world, "m3", {"name": "M3 UI"})
	var saved_m3: Dictionary = main.world.to_dict()
	main._load("m3")
	await process_frame
	_expect(main.world.to_dict() == saved_m3 and main.gallery_list.get_child_count() >= 1, "M3b save/load v11 preserva quadros, galeria, ateliê e ablações")
	main._open_atelier_tutorial()
	_expect(main.tutorial_dialog.visible and main.tutorial_step == 5 and main.tutorial_text.text.contains("6/7") and main.tutorial_text.text.contains("competência é experimental"), "M3b roteiro do ateliê acessível e honesto")
	main.tutorial_dialog.hide()
	await process_frame
	await process_frame
	_expect(main.tool_buttons.board.get_global_rect().end.x < 1100 - main.SIDEBAR - 30 and main.tool_buttons.demo.get_global_rect().end.x < 1100 - main.SIDEBAR - 30, "M3 ferramentas Quadro e Demonstrar cabem na largura mínima")
	_expect(main.lab.atelier_competence.size.x <= main.lab_scroll.size.x, "M3 texto de competência quebra linhas na largura mínima")
	main.selected_id = -1
	main._refresh()
	main.lab.observe(main.world, -1, true)
	_expect(main.lab.atelier_learning_switch.disabled and main.lab.atelier_policy_select.disabled, "M3 sem seleção desabilita controles de ablação do ateliê")
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		var path := folder.path_join("m3.json" + suffix)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
