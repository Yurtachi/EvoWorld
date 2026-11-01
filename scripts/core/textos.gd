class_name Textos
extends RefCounted
## Catálogo da apresentação. Identificadores e dados salvos continuam intactos.

const CATALOGO := {
	"caregiver": "Cuidador",
	"laboratory": "Laboratório",
	"chat_open": "Conversar com o companheiro",
	"chat_title": "Conversa com o companheiro",
	"chat_intro": "Respostas descrevem dados observados, sem atribuir consciência. Pedidos só têm efeito quando confirmados pelo recibo.",
	"chat_placeholder": "Como você está?",
	"chat_examples": "Experimente: como você está? · oferecer comida · chamar · seguir · parar · brincar · proteger",
	"chat_send": "Enviar",
	"chat_target": "Alvo dos pedidos: marcador no jardim. Clique com o botão direito para escolher; seguir usa esse marcador.",
	"target_set": "Alvo do diálogo marcado no jardim.",
	"chat_empty": "Digite uma pergunta ou um pedido acima.",
	"chat_pending": "Pedido registrado; execução de movimento depende da integração com o simulador.",
	"evidence_title": "EVIDÊNCIAS DA RESPOSTA",
	"evidence_snapshot": "Consulta no passo %d · companheiro ID %d",
	"evidence_value": "%s: %s",
	"evidence_energy": "Energia observada",
	"evidence_hunger": "Fome (fração de 0 a 1)",
	"evidence_age": "Idade em passos",
	"evidence_last_action": "Ação registrada",
	"evidence_last_reason": "Razão registrada",
	"evidence_foods": "Alimentos percebidos (IDs)",
	"evidence_events": "Evento próprio registrado",
	"evidence_none": "Nenhuma evidência de estado foi produzida para esta entrada.",
	"close": "Fechar",
	"apply": "Aplicar",
	"settings": "Ajustes",
	"help": "Ajuda",
	"settings_title": "Configurações do jardim",
	"settings_speed": "Velocidade da simulação",
	"initial_population": "População inicial (vale para o próximo jardim)",
	"protected_mode": "Modo protegido: pausa preventiva",
	"protected_info": "No modo protegido, o jardim pausa antes de avançar com energia do companheiro abaixo de 15% ou perto do limite de idade. A pausa não repõe energia nem rejuvenesce: ofereça comida ou mantenha o jardim pausado.",
	"survival_warning": "SOBREVIVÊNCIA: com a proteção desligada, o companheiro pode morrer de fome ou idade. A morte é permanente neste mundo; só um ponto salvo anterior permite voltar.",
	"protection_paused": "Proteção: pausa preventiva por energia baixa ou idade limite. Ofereça alimento; para continuar assumindo o risco, desligue a proteção nos Ajustes.",
	"protection_active": "PROTEGIDO · pausa preventiva por energia/idade. Esta intervenção interrompe a seleção natural enquanto o jardim fica pausado.",
	"protection_off": "SOBREVIVÊNCIA · proteção desligada. O companheiro pode morrer de fome ou idade.",
	"autosave": "Salvamento automático a cada 60 segundos",
	"autosave_info": "O automático usa um ponto separado, validado com soma de verificação e cópia de segurança. Só grava após mudanças no mundo e preserva o ponto manual.",
	"autosave_load": "Recuperar automático",
	"autosave_ok": "Salvamento automático concluído.",
	"autosave_failed": "Falha no salvamento automático: %s",
	"settings_saved": "Configurações aplicadas.",
	"settings_failed": "Não foi possível gravar as configurações; os ajustes continuam ativos nesta sessão.",
	"help_title": "Seu primeiro jardim",
	"help_body": "1. Crie um jardim com nomes, semente e população inicial. Ele começa pausado.\n\n2. Use Iniciar, selecione uma criatura ou encontre seu companheiro pelo Cuidador.\n\n3. Escolha + Alimento e clique no terreno livre. A criatura precisa percebê-lo e alcançá-lo para comer.\n\n4. Converse pelo Cuidador. Para chamar/seguir, marque um alvo com o botão direito no jardim. Confira o recibo e as evidências.\n\n5. Laboratório mostra genes, famílias, curvas e eventos. O canal de sinais permite uma emissão manual com custo de energia, sem significado presumido.\n\n6. Ctrl+S salva; Ctrl+L carrega e pausa. Ajustes permite recuperar o automático e escolher velocidade/proteção.\n\nRoda: ampliar · botão do meio/WASD: mover · F: enquadrar · Espaço: pausar · F12: capturar.\n\nAtenção: sobrevivência permite morte permanente. A proteção pausa por energia baixa ou idade limite; não repõe energia nem rejuvenesce.",
	"lab_intro": "Observações do mundo real. Variação genética e nascimentos não demonstram adaptação ou linguagem por si só.",
	"lab_summary": "%d organismos vivos · geração máxima %d\n%d nascimentos · %d mortes no registro permanente",
	"lab_chart": "POPULAÇÃO E DIVERSIDADE NO TEMPO",
	"lab_history": "Últimas %d amostras desta sessão · passo %d a %d. Cada curva tem sua própria escala.",
	"chart_population": "População · máximo %d",
	"chart_diversity": "Diversidade normalizada · máximo %s",
	"lab_genome": "Genoma ID %d · criatura ID %d\nGeração %d · nascimento no passo %d",
	"lab_no_record": "Selecione uma criatura com registro de nascimento.",
	"lab_ancestors": "ANCESTRAIS (mais próximos primeiro)",
	"lab_descendants": "DESCENDENTES",
	"lab_mutations": "MUTAÇÕES DE NASCIMENTO",
	"lab_none": "Nenhum registro.",
	"lab_founder": "Fundador: sem genitores registrados.",
	"lab_legacy": "Origem migrada: parentesco anterior não verificado.",
	"lab_record": "#%d · %s · geração %d · %s",
	"lab_alive": "viva",
	"lab_dead": "morte no passo %d",
	"lab_more": "… mais %d registros (lista resumida)",
	"lab_mutation": "%s: variação %s",
	"lab_diversity": "DIVERSIDADE · VARIÂNCIA POR GENE",
	"lab_diversity_note": "A curva usa a média das variâncias divididas pelo intervalo de cada gene ao quadrado. População vazia ou única tem variância zero.",
	"gene_size": "Tamanho",
	"gene_speed": "Velocidade",
	"gene_vision_range": "Alcance de visão",
	"gene_vision_fov": "Campo de visão (radianos)",
	"gene_metabolism": "Metabolismo",
	"gene_hue": "Matiz",
	"events_title": "NASCIMENTOS, MORTES E ALIMENTAÇÃO",
	"signals_title": "SINAIS E REAÇÕES OBSERVADAS",
	"signals_log": "LOG DE EMISSÕES E DECISÕES",
	"signals_enabled": "Canal de sinais ligado",
	"signals_emit": "Emitir pela seleção",
	"signals_symbol": "Símbolo %d",
	"signals_manual": "Intervenção de laboratório: emitir cobra energia do organismo selecionado. A heurística padrão não emite sozinha. Uma ação após a recepção não comprova que o sinal a causou.",
	"signals_disabled": "Canal desligado. Ative-o para emitir símbolos; nenhum significado é associado a eles.",
	"signals_empty": "Ainda não há emissões registradas neste mundo.",
	"signals_emission_ok": "Emissão registrada. Avance a simulação para observar as decisões dos receptores.",
	"signals_emission_failed": "Emissão recusada: confira canal, seleção viva e energia disponível.",
	"signals_row": "Passo %d · símbolo %d · emissor #%d\nContexto: alimento visível %s; energia baixa %s.\nReceptores (IDs): %s",
	"signals_change": "#%d · passo %d · %s → %s",
	"yes": "sim",
	"no": "não",
	"signals_hook": "Sem eventos de sinais nesta versão/sessão. Este painel lê os eventos do simulador quando o canal estiver disponível; símbolos não recebem significado presumido.",
	"event_spawn": "Passo %d · introdução de %s (#%d)",
	"event_birth": "Passo %d · nascimento #%d, genitor #%d, geração %d",
	"event_death": "Passo %d · morte #%d: %s",
	"event_eat": "Passo %d · #%d comeu alimento #%d, energia +%s",
	"event_mutation": "Passo %d · #%d: mutação em %s (%s)",
	"event_unknown": "Passo %d · evento registrado",
	"event_signal": "Passo %d · sinal %s · emissor #%d · receptor #%d · reação %s",
	"death_starvation": "falta de energia",
	"death_age": "limite de idade",
	"death_external": "intervenção externa",
	"death_unknown": "causa não informada",
	"reason_command_stop": "Pedido do jogador: permanecer parado.",
	"reason_command_arrived": "Chegou ao alvo pedido pelo jogador.",
	"reason_command_move": "Movimento solicitado pelo jogador.",
	"reason_signal_emitted": "Emitiu um símbolo pelo canal de sinais; seu significado não é presumido.",
	"reason_signal_rejected": "A emissão de sinal foi recusada pelas regras do canal.",
	"action_emit_signal_0": "Emitir sinal 0",
	"action_emit_signal_1": "Emitir sinal 1",
	"action_emit_signal_2": "Emitir sinal 2",
	"action_emit_signal_3": "Emitir sinal 3",
	"action_emit_signal_4": "Emitir sinal 4",
	"action_emit_signal_5": "Emitir sinal 5",
	"action_emit_signal_6": "Emitir sinal 6",
	"action_emit_signal_7": "Emitir sinal 7",
	"reason_age": "Morte por idade: chegou ao limite de vida deste mundo.",
	"reason_external": "A criatura foi marcada como sem vida por uma intervenção externa.",
	"evolution_generations": "Gerações alcançadas",
	"evolution_diversity": "Diversidade genética (variância por gene)",
	"evolution_population": "População",
	"evolution_births": "Nascimentos",
	"evolution_ancestry": "Linhagem",
	"evolution_sample": "Cenário %s | semente %d | passo %d | geração máxima %d | população %d | nascimentos %d | diversidade %s",
	"evolution_result": "Resultados do experimento de evolução: %s",
	"evolution_ticks_invalid": "Use --ticks seguido de um inteiro entre 1 e 100000.",
	"evolution_save_invalid": "O mundo do experimento divergiu após salvar e carregar.",
	"world_default": "Jardim de Musgo",
	"world_restored": "Jardim restaurado",
	"pet_default": "Pip",
	"creature_default": "Criatura %s",
	"title": "EVO WORLD   /   %s",
	"welcome": "Conheça %s. Coloque alimento por perto e pressione Iniciar para observar.",
	"new_world": "Novo mundo",
	"save": "Salvar",
	"load": "Carregar",
	"new_tooltip": "Dê nome ao seu companheiro e crie um jardim com semente. Substitui o mundo atual não salvo.",
	"save_tooltip": "Salva o mundo, o companheiro e o estado aleatório em um ponto de salvamento local. Ctrl+S",
	"load_tooltip": "Substitui este mundo pelo ponto salvo ou recupera sua cópia de segurança. Ctrl+L",
	"field_notes": "DIÁRIO DE CAMPO",
	"energy": "Energia",
	"current_action": "AÇÃO ATUAL",
	"genome": "GENOMA",
	"find_pet": "Encontrar",
	"follow": "Acompanhar",
	"vision": "Mostrar alcance da visão",
	"vision_tooltip": "Alcance e campo de visão geométricos. Rochas podem ocultar objetos dentro desta área.",
	"survival_note": "JARDIM DE SOBREVIVÊNCIA\nAs criaturas seguem regras fixas de busca de alimento. A energia pode acabar; seu companheiro pode morrer.",
	"tool_select": "Inspecionar",
	"tool_food": "+ Alimento",
	"tool_obstacle": "+ Rocha",
	"tool_creature": "+ Criatura",
	"place_food": "alimento",
	"place_obstacle": "uma rocha",
	"place_creature": "uma criatura",
	"play": "Iniciar",
	"pause": "Pausar",
	"speed": "%d×",
	"shortcuts": "Roda: ampliar/reduzir  /  Arraste com o botão do meio ou WASD: mover\nF: enquadrar  /  Espaço: pausar  /  Esc: inspecionar  /  F12: capturar tela",
	"dialog_title": "Um pequeno mundo, um novo companheiro",
	"create_garden": "Criar jardim",
	"keep_exploring": "Continuar explorando",
	"begin_name": "Tudo começa com um nome.",
	"dialog_intro": "Um ecossistema com semente e população configurável.\nCriar um jardim substitui o mundo atual não salvo.",
	"garden_name": "Nome do jardim",
	"pet_name": "Nome do seu companheiro",
	"seed_caption": "Semente do mundo: repita-a para recriar o estado inicial",
	"seed_default": "7421",
	"pet_rules": "Ajustes permite escolher proteção por pausa preventiva ou sobrevivência, com risco de morte permanente. Confira o modo no Cuidador.",
	"names_required": "Dê um nome ao jardim e ao seu companheiro.",
	"seed_invalid": "Use uma semente inteira entre 0 e 2147483647.",
	"inside_boundary": "Escolha um ponto dentro dos limites do jardim.",
	"food_placed": "Alimento plantado. As criaturas precisam percebê-lo antes de procurá-lo.",
	"food_blocked": "Não foi possível plantar: local bloqueado ou limite de alimento atingido.",
	"rock_placed": "Rocha colocada.",
	"rock_blocked": "Deixe espaço ao redor das criaturas e do alimento para colocar uma rocha.",
	"population_limit": "Este jardim comporta até 150 criaturas para manter a observação fluida.",
	"creature_placed": "Nova criatura introduzida.",
	"creature_blocked": "Não há espaço livre para uma criatura.",
	"stats": "SEMENTE %d  •  PASSO %d  •  %d quadros/s  •  %d entidades / %d criaturas / %d alimentos",
	"inspect_hint": "Clique em uma criatura para inspecioná-la.",
	"place_hint": "Clique no jardim para colocar %s. Esc volta a Inspecionar.",
	"no_selection": "Nenhuma criatura selecionada",
	"select_hint": "Clique em uma criatura ou use Encontrar.",
	"no_energy": "Energia —",
	"observe": "Observe o jardim",
	"selected_dead": "A criatura selecionada não está mais viva.",
	"reason_hint": "Selecione um organismo para ver sua ação atual e a razão registrada.",
	"identity": "%s / ID %d / geração %d",
	"your_pet": "SEU COMPANHEIRO",
	"organism": "ORGANISMO",
	"energy_value": "Energia     %s / %s",
	"age_value": "Idade  %s segundos / %d passos",
	"genes": "Tamanho  %s   Velocidade  %s\nVisão  %s   Metabolismo  %s\nMatiz  %s / expresso na cor do corpo",
	"pet_dead": "Seu companheiro não está mais vivo neste jardim. Carregue um ponto salvo ou crie um novo mundo.",
	"screenshot_graphics": "A captura de tela requer uma janela gráfica.",
	"screenshot_saved": "Captura de tela salva: %s",
	"screenshot_failed": "Não foi possível salvar a captura de tela (código %d).",
	"action_forward": "Avançar",
	"action_turn_left": "Virar à esquerda",
	"action_turn_right": "Virar à direita",
	"reason_q_explore": "Experimentando uma ação para aprender com seu resultado.",
	"reason_q_greedy": "Escolhendo a ação mais valorizada pela experiência.",
	"reason_q_frozen": "Seguindo a experiência salva, com aprendizado pausado.",
	"reason_random": "Experimentando uma ação aleatória, sem aprender.",
	"reason_eat_empty": "Tentou comer, mas não há alimento percebido ao alcance.",
	"reason_blocked": "O movimento foi bloqueado por contato físico.",
	"action_rest": "Descansar",
	"action_seek_food": "Buscar alimento",
	"action_explore": "Explorar",
	"action_eat": "Comer",
	"action_avoid_obstacle": "Desviar de obstáculo",
	"action_dead": "Sem vida",
	"action_unknown": "Ação não reconhecida",
	"reason_new": "Acabou de nascer.",
	"reason_satiated": "Sem fome; conservando energia.",
	"reason_rest": "Descanso breve; nenhum alimento percebido.",
	"reason_seek": "Alimento %s visível a %s unidades.",
	"reason_explore": "Nenhum alimento à vista; explorando.",
	"reason_dead": "Inanição: a energia se esgotou.",
	"reason_eat": "Comeu o alimento visível %s; ganhou %s de energia.",
	"reason_obstacle": "Obstáculo percebido à frente; mudando de direção.",
	"reason_boundary": "Contato com um limite físico; mudando de direção.",
	"reason_unknown": "Razão não disponível nesta versão.",
	"save_ok": "Ponto de salvamento salvo.",
	"load_ok": "Ponto de salvamento carregado.",
	"load_recovered": "Arquivo principal indisponível ou inválido; ponto anterior recuperado da cópia de segurança.",
	"load_invalid": "Nenhum ponto de salvamento ou cópia de segurança válido. %s",
	"slot_invalid": "Nome de ponto de salvamento inválido.",
	"save_directory": "Não foi possível criar a pasta de salvamentos.",
	"save_too_large": "O ponto de salvamento excede o limite de 32 MiB.",
	"save_temporary_invalid": "O ponto temporário falhou na validação; o salvamento anterior foi preservado.",
	"save_backup_failed": "Não foi possível preservar a cópia de segurança.",
	"save_replace_failed": "Não foi possível substituir o ponto de salvamento.",
	"file_missing": "O arquivo não existe.",
	"file_open_failed": "Não foi possível abrir o arquivo.",
	"file_too_large": "O arquivo excede o limite de 32 MiB.",
	"json_invalid": "O arquivo de salvamento contém JSON inválido.",
	"format_invalid": "Formato de salvamento não suportado.",
	"payload_missing": "Dados ou soma de verificação do salvamento ausentes.",
	"checksum_invalid": "A soma de verificação do salvamento não confere.",
	"payload_invalid": "Dados de salvamento inválidos.",
	"world_missing": "Mundo ou metadados ausentes.",
	"schema_invalid": "Os dados do mundo falharam na validação da estrutura.",
	"temporary_open_failed": "Não foi possível abrir o salvamento temporário.",
	"write_failed": "Não foi possível gravar o salvamento.",
	"message_unknown": "Não foi possível concluir a operação de salvamento ou carregamento.",
	"text_unknown": "Texto indisponível.",
	"edit_cut": "Recortar",
	"edit_copy": "Copiar",
	"edit_paste": "Colar",
	"edit_clear": "Limpar",
	"edit_select_all": "Selecionar tudo",
	"edit_undo": "Desfazer",
	"edit_redo": "Refazer",
	"edit_direction": "Direção da escrita",
	"edit_direction_layout": "Igual à direção da interface",
	"edit_direction_auto": "Detectar direção automaticamente",
	"edit_direction_ltr": "Da esquerda para a direita",
	"edit_direction_rtl": "Da direita para a esquerda",
	"edit_display_controls": "Exibir caracteres de controle",
	"edit_insert_control": "Inserir caractere de controle",
	"edit_lrm": "Marca da esquerda para a direita (LRM)",
	"edit_rlm": "Marca da direita para a esquerda (RLM)",
	"edit_lre": "Início de incorporação da esquerda para a direita (LRE)",
	"edit_rle": "Início de incorporação da direita para a esquerda (RLE)",
	"edit_lro": "Início de substituição da esquerda para a direita (LRO)",
	"edit_rlo": "Início de substituição da direita para a esquerda (RLO)",
	"edit_pdf": "Encerrar formatação de direção (PDF)",
	"edit_alm": "Marca de letra árabe (ALM)",
	"edit_lri": "Isolamento da esquerda para a direita (LRI)",
	"edit_rli": "Isolamento da direita para a esquerda (RLI)",
	"edit_fsi": "Isolamento pela primeira direção forte (FSI)",
	"edit_pdi": "Encerrar isolamento de direção (PDI)",
	"edit_zwj": "União de largura zero (ZWJ)",
	"edit_zwnj": "Não união de largura zero (ZWNJ)",
	"edit_wj": "União de palavras (WJ)",
	"edit_shy": "Hífen opcional (SHY)",
	"edit_emoji": "Emojis e símbolos"
}

# IDs nativos de LineEdit.MenuItems; os atalhos continuam a cargo do Godot.
const MENUS := {
	0: "edit_cut", 1: "edit_copy", 2: "edit_paste", 3: "edit_clear",
	4: "edit_select_all", 5: "edit_undo", 6: "edit_redo", 7: "edit_direction",
	8: "edit_direction_layout", 9: "edit_direction_auto", 10: "edit_direction_ltr",
	11: "edit_direction_rtl", 12: "edit_display_controls", 13: "edit_insert_control",
	14: "edit_lrm", 15: "edit_rlm", 16: "edit_lre", 17: "edit_rle", 18: "edit_lro",
	19: "edit_rlo", 20: "edit_pdf", 21: "edit_alm", 22: "edit_lri", 23: "edit_rli",
	24: "edit_fsi", 25: "edit_pdi", 26: "edit_zwj", 27: "edit_zwnj",
	28: "edit_wj", 29: "edit_shy", 30: "edit_emoji"
}

const RAZOES := {
	"signal.emitted": "reason_signal_emitted",
	"signal.rejected": "reason_signal_rejected",
	"dialogo.stop": "reason_command_stop",
	"dialogo.arrived": "reason_command_arrived",
	"dialogo.chamar": "reason_command_move",
	"dialogo.seguir": "reason_command_move",
	"dialogo.brincar": "reason_command_move",
	"evolution.age": "reason_age",
	"evolution.external": "reason_external",
	"brain.q_explore": "reason_q_explore",
	"brain.q_greedy": "reason_q_greedy",
	"brain.q_frozen": "reason_q_frozen",
	"brain.random": "reason_random",
	"brain.eat_empty": "reason_eat_empty",
	"brain.blocked": "reason_blocked",
	"Newly spawned": "reason_new",
	"Satiated; conserving energy": "reason_satiated",
	"Brief rest; no food perceived": "reason_rest",
	"No food within vision; exploring": "reason_explore",
	"Starvation: energy exhausted": "reason_dead",
	"Obstacle perceived ahead; turning": "reason_obstacle",
	"Physical boundary contact; turning": "reason_boundary"
}
const MENSAGENS := {
	"Checkpoint saved.": "save_ok",
	"Checkpoint loaded.": "load_ok",
	"Primary unavailable or invalid; recovered the previous checkpoint from backup.": "load_recovered",
	"Invalid checkpoint name.": "slot_invalid",
	"Checkpoint exceeds the 32 MiB limit.": "save_too_large",
	"Temporary checkpoint failed validation; previous save preserved.": "save_temporary_invalid",
	"File does not exist.": "file_missing",
	"File cannot be opened.": "file_open_failed",
	"File exceeds the 32 MiB limit.": "file_too_large",
	"Invalid checkpoint JSON.": "json_invalid",
	"Unsupported checkpoint format.": "format_invalid",
	"Missing checkpoint payload or checksum.": "payload_missing",
	"Checkpoint checksum does not match.": "checksum_invalid",
	"Invalid checkpoint payload.": "payload_invalid",
	"Missing world or metadata.": "world_missing",
	"World data failed schema validation.": "schema_invalid"
}
const ERROS_PREFIXO := {
	"Cannot create save directory: ": "save_directory",
	"Cannot preserve backup: ": "save_backup_failed",
	"Cannot replace checkpoint: ": "save_replace_failed",
	"Cannot open temporary checkpoint: ": "temporary_open_failed",
	"Cannot write checkpoint: ": "write_failed"
}

static func texto(codigo: String, valores: Array = []) -> String:
	var modelo: String = E2_UI.get(codigo, E2_CATALOGO.get(codigo, E1_UI.get(codigo, E1_CATALOGO.get(codigo, CATALOGO.get(codigo, CATALOGO.text_unknown)))))
	return modelo if valores.is_empty() else modelo % valores

static func numero(valor: float, casas: int = 1) -> String:
	return ("%.*f" % [casas, valor]).replace(".", ",")

static func gene(codigo: String) -> String:
	return texto("gene_" + codigo)

static func sinal(row: Dictionary) -> String:
	var context: Dictionary = row.get("context", {})
	var receivers: Array = row.get("receivers", [])
	var ids := str(receivers.slice(0, 12))
	if receivers.size() > 12:
		ids += " " + texto("lab_more", [receivers.size() - 12])
	var result := texto("signals_row", [int(row.get("tick", 0)), int(row.get("symbol", 0)), int(row.get("emitter", -1)),
		texto("yes" if context.get("saw_food", false) else "no"), texto("yes" if context.get("low_energy", false) else "no"), ids])
	var changes: Array = row.get("action_changes", [])
	for change in changes.slice(0, 12):
		result += "\n" + texto("signals_change", [int(change.get("receiver", -1)), int(change.get("tick", 0)), acao(str(change.get("before", ""))), acao(str(change.get("after", "")))])
	if changes.size() > 12:
		result += "\n" + texto("lab_more", [changes.size() - 12])
	return result

static func evento(event: Dictionary) -> String:
	var tick := int(event.get("tick", 0))
	var id := int(event.get("creature_id", -1))
	match str(event.get("type", "")):
		"spawn":
			return texto("event_spawn", [tick, nome_criatura(str(event.get("name", ""))), id])
		"birth":
			return texto("event_birth", [tick, id, int(event.get("parent_id", -1)), int(event.get("generation", 0))])
		"death":
			var cause := "death_" + str(event.get("reason", "unknown"))
			return texto("event_death", [tick, id, texto(cause if CATALOGO.has(cause) else "death_unknown")])
		"drink":
			return texto("event_drink", [tick, id, int(event.get("water_id", -1)), numero(float(event.get("hydration", 0)))])
		"eat":
			return texto("event_eat", [tick, id, int(event.get("food_id", -1)), numero(float(event.get("energy", 0)))])
		"mutation":
			return texto("event_mutation", [tick, id, gene(str(event.get("gene", ""))), numero(float(event.get("delta", 0)), 4)])
	# Gancho de apresentação para eventos de comunicação; nunca mostra códigos
	# internos como português nem atribui significado humano aos símbolos.
	if str(event.get("type", "")).begins_with("signal"):
		return texto("event_signal", [tick, str(event.get("symbol", event.get("token", "—"))),
			int(event.get("sender_id", event.get("emitter_id", id))), int(event.get("receiver_id", -1)), acao(str(event.get("action", "")))])
	return texto("event_unknown", [tick])

static func acao(codigo: String) -> String:
	return texto("action_" + codigo) if CATALOGO.has("action_" + codigo) or E1_CATALOGO.has("action_" + codigo) or E2_CATALOGO.has("action_" + codigo) else texto("action_unknown")

static func razao(original: String) -> String:
	if E2_RAZOES.has(original):
		return texto(E2_RAZOES[original])
	if E1_RAZOES.has(original):
		return texto(E1_RAZOES[original])
	if RAZOES.has(original):
		return texto(RAZOES[original])
	var busca := RegEx.new()
	busca.compile("^Food ([0-9]+) visible at ([0-9]+(?:\\.[0-9]+)?) units$")
	var resultado := busca.search(original)
	if resultado != null:
		return texto("reason_seek", [resultado.get_string(1), resultado.get_string(2).replace(".", ",")])
	busca.compile("^Ate visible food ([0-9]+); gained ([0-9]+(?:\\.[0-9]+)?) energy$")
	resultado = busca.search(original)
	if resultado != null:
		return texto("reason_eat", [resultado.get_string(1), resultado.get_string(2).replace(".", ",")])
	return texto("reason_unknown")

static func mensagem(original: String) -> String:
	if MENSAGENS.has(original):
		return texto(MENSAGENS[original])
	var prefixo := "No valid checkpoint or backup. "
	if original.begins_with(prefixo):
		return texto("load_invalid", [mensagem(original.trim_prefix(prefixo))])
	for inicio in ERROS_PREFIXO:
		if original.begins_with(inicio):
			return texto(ERROS_PREFIXO[inicio])
	return texto("message_unknown")

static func nome_criatura(original: String) -> String:
	var padrao := RegEx.new()
	padrao.compile("^Creature ([0-9]+)$")
	var resultado := padrao.search(original)
	return texto("creature_default", [resultado.get_string(1)]) if resultado != null else original

static func nome_mundo(original: String) -> String:
	if original == "Moss garden":
		return texto("world_default")
	if original == "Restored garden":
		return texto("world_restored")
	return original


# E1-SIM — chaves aditivas; integração nos formatadores pertence à UI.
const E1_CATALOGO := {
	"food_legacy": "Alimento tradicional", "food_fruta": "Fruta", "food_semente": "Semente",
	"food_folha": "Folha", "food_cogumelo": "Cogumelo",
	"action_drink": "Beber", "action_seek_water": "Buscar água",
	"hydration": "Hidratação", "thirst": "Sede",
	"event_drink": "Passo %d: criatura %d bebeu na água %d; recuperou %s de hidratação.",
	"reason_seek_water": "Água percebida; aproximando-se da margem.",
	"reason_drink": "Bebeu água ao alcance.",
	"reason_drink_empty": "Nenhuma água percebida ao alcance para beber.",
	"reason_no_water": "Com sede e sem água percebida; explorando.",
	"reason_thirst": "Decisão condicionada pela sede e pela água percebida.",
	"reason_food_toxic": "Ingeriu alimento com toxicidade; houve perda líquida de energia."
}
const E1_RAZOES := {
	"ecology.seek_water": "reason_seek_water", "ecology.drink": "reason_drink",
	"ecology.drink_empty": "reason_drink_empty", "ecology.no_water": "reason_no_water",
	"ecology.thirst": "reason_thirst", "ecology.food_toxic": "reason_food_toxic"
}


# Apresentação E1: valores e eventos observados no mundo.
const E1_UI := {
 "tool_water": "+ Água", "tool_expand": "Expandir terreno", "place_water": "água",
 "tool_fruta": "Fruta", "tool_semente": "Semente", "tool_folha": "Folha", "tool_cogumelo": "Cogumelo",
 "water_placed": "Água colocada. Beber exige alcançar a margem; nenhum ganho é imediato.",
 "water_blocked": "Água recusada: mantenha a região dentro do terreno (máximo de 256 regiões).",
 "water_legacy": "Save legado: água visível não ativa sede retroativamente.",
 "hydration_value": "Hidratação %s / 100 · Sede %s%%", "hydration_off": "Sede desativada neste mundo legado.",
 "thirst_warning": "Sede alta: buscar água tem prioridade sobre pedidos. Coloque água ao alcance da visão.",
 "food_warning": "Cogumelo: toxicidade 8; pode reduzir energia. Valores fictícios da simulação.",
 "food_profile": "%s · palatabilidade %s\nNutrição %s · hidratação %s · toxicidade %s\nSem preferência individual registrada nesta etapa.",
 "food_choice": "Alimento para plantar ou oferecer", "roster": "Criaturas do jardim (%d)",
 "offer": "Oferecer alimento à seleção", "offer_none": "Selecione uma criatura viva para oferecer alimento.",
 "offer_placed": "Passo %d: oferta #%d de %s para %s; aguardando aproximação e ingestão.",
 "offer_blocked": "Oferta recusada: sem posição livre próxima ou limite de alimento.",
 "offer_approached": "Passo %d: %s aproximou-se da oferta #%d (distância %s → %s).",
 "offer_eaten": "Passo %d: %s comeu a oferta #%d; ganho confirmado de %s de energia.",
 "offer_no_meal": "Passo %d: oferta #%d indisponível; nenhuma refeição com ganho positivo confirmada para o destinatário.",
 "receipt_title": "RECIBOS E EVENTOS FÍSICOS", "receipt_empty": "Nenhuma oferta nesta sessão. Colocar não significa consumir.",
 "last_event": "Último evento: %s", "last_event_none": "Último evento: nenhum registrado para esta criatura.",
 "expand_title": "Expandir terreno", "expand_side": "Borda", "expand_right": "Direita", "expand_bottom": "Inferior",
 "expand_amount": "Quantidade (unidades)", "expand_confirm": "Confirmar expansão", "expand_preview": "Atual: %s × %s → %s × %s\nÁrea acrescentada: %s unidades². Custo: 0 (sem moeda nesta etapa).\nLimite: 100.000 por eixo. Posições e recursos existentes são preservados.",
 "expand_ok": "Terreno expandido para %s × %s; câmera reenquadrada.", "expand_invalid": "Expansão recusada: quantidade inválida ou limite de 100.000 por eixo.",
 "protection_active": "Proteção: pausa preventiva por energia/idade.", "care_notes": "SEU JARDIM", "garden_stats": "%d criaturas · %d alimentos · %d águas · passo %d · %d quadros/s",
 "drink_badge": "Bebeu +%s", "fps_unit": "quadros/s", "fps_title": "Quadros/s · últimos 120 quadros", "fps_sample": "%d criaturas · média %s · mínimo %s quadros/s",
 "help_body": "1. Crie o jardim e nomeie o companheiro. O padrão é 12 criaturas e três águas; você pode escolher outra população. Começa pausado.\n\n2. Use Iniciar e selecione por clique, nome no terreno ou lista do Cuidador. Confira energia, hidratação, sede e último evento.\n\n3. Escolha Fruta, Semente, Folha ou Cogumelo e clique no terreno. Cogumelo tem toxicidade. + Água coloca uma região: beber exige alcançar a margem.\n\n4. Oferecer alimento à seleção coloca o tipo escolhido perto dela. O recibo acompanha aproximação e refeição; só ganho positivo confirma refeição.\n\n5. Expandir terreno permite direita ou inferior. Confira quantidade, custo zero e limite antes de confirmar. A câmera reenquadra. Laboratório mantém genes, famílias e sinais.\n\n6. Ctrl+S salva; Ctrl+L carrega e pausa. Ajustes controla população do próximo jardim, proteção e automático. Saves antigos preservam população e fisiologia.\n\nRoda: ampliar · botão do meio/WASD: mover · F: enquadrar · Espaço: pausar · F12: capturar.\n\nA proteção pausa por energia baixa ou idade limite; não repõe reservas. Sobrevivência permite morte permanente."
}

# E2-SIM — chaves aditivas; integração nos formatadores pertence à UI.
const E2_CATALOGO := {
	"fatigue": "Fadiga", "boredom": "Necessidade de estímulo", "loneliness": "Necessidade de contato",
	"gene_curiosity": "Curiosidade", "gene_caution": "Cautela",
	"gene_sociability": "Sociabilidade", "gene_impulsivity": "Impulsividade",
	"action_seek_contact": "Aproximar-se de outra criatura", "action_social_contact": "Contato com outra criatura",
	"action_player_contact": "Contato com o cuidador",
	"reason_fatigue": "Fadiga elevada; descansa e reduz o gasto de energia.",
	"reason_curiosity": "Busca estímulo por movimento e exploração do ambiente.",
	"reason_contact": "Busca contato com uma criatura percebida.",
	"reason_survival": "Fome ou sede crítica; prioriza recursos físicos.",
	"expression_valence": "Valência observada", "expression_arousal": "Ativação observada",
	"expression_note": "A expressão aparente deriva das necessidades e dos eventos registrados.",
	"episodic_memory": "Memória episódica", "familiarity": "Familiaridade",
	"food_preference": "Preferência alimentar aprendida"
}
const E2_RAZOES := {
	"personality.fatigue": "reason_fatigue", "personality.curiosity": "reason_curiosity",
	"personality.contact": "reason_contact", "personality.survival": "reason_survival"
}


# Apresentação E2: chaves persistidas permanecem estáveis.
const NOMES_INICIAIS := ["Mel", "Bento", "Tica", "Juca", "Lola", "Zeca", "Nina", "Dora", "Caju", "Bia", "Chico", "Lia"]
const E2_UI := {
	"pet_default": "Mel",
	"tab_needs": "Corpo", "tab_traits": "Traços", "tab_memory": "Memória", "tab_preferences": "Comida", "tab_bonds": "Vínculos",
	"needs_note": "Estado atual · barras maiores indicam maior necessidade.",
	"need_hunger": "Fome", "need_thirst": "Sede", "need_fatigue": "Fadiga", "need_boredom": "Estímulo", "need_loneliness": "Contato",
	"need_value": "%s · %s%%", "need_disabled": "%s · desativada", "urgent": "%s %s%%", "urgent_none": "necessidades baixas",
	"traits_note": "Traço herdado · tendências do genoma. Não é o estado atual; necessidades variam durante a vida.",
	"trait_value": "%s · %s%%", "learned_note": "Aprendido · vem de experiências individuais. Preferências, episódios e familiaridade não são herdados.",
	"legacy_personality": "Personalidade desativada neste mundo legado. Nenhum perfil foi criado ao carregar.",
	"memory_note": "Últimos episódios registrados: ação e consequência medida. A memória é limitada e esquece com o tempo.",
	"memory_empty": "Ainda não há episódios registrados.", "episode": "Passo %d · %s\n%s\nEnergia %s · água %s · fadiga %s",
	"episode_metabolism": "Custo corporal medido.", "episode_food": "Ingeriu %s.", "episode_toxic_food": "Ingeriu %s com toxicidade.",
	"episode_water": "Bebeu água ao alcance.", "episode_rest": "Descansou; fadiga medida.", "episode_exploration": "Explorou com deslocamento real.",
	"episode_contact": "Encontrou outra criatura ao alcance.", "episode_collision": "Movimento bloqueado.", "episode_player_contact": "Contato com o cuidador registrado.",
	"preferences_note": "Preferência aprendida por ingestão: −1 aversão, 0 neutra, +1 preferência. Oferecer ou ver não ensina a preferência.",
	"preference_value": "%s · %s", "preference_unknown": "%s · sem experiência", "bonds_note": "Quem conhece · familiaridade cresce com encontros ao alcance e diminui com o tempo.",
	"bonds_empty": "Nenhum vínculo registrado.", "bond_player": "Você (cuidador)", "bond_unknown": "Criatura #%d (fora do jardim)",
	"bond_row": "%s\nFamiliaridade %s%% · encontros: %d\nÚltimo contato: passo %d", "no_selection_e2": "Selecione uma criatura para examinar.",
	"expression_calm": "Aparenta baixa ativação", "expression_active": "Aparenta maior ativação", "expression_strained": "Aparenta tensão corporal",
	"expression_scores": "%s\nValência %s · ativação %s%%", "expression_legend": "Expressão: brilho e postura = valência; balanço = ativação. Ícone: arco baixo, reto ou alto. Aparência derivada de necessidades e eventos; não indica consciência.",
	"tool_attention": "Carinho", "place_attention": "contato no corpo da seleção", "attention_help": "Carinho/atenção: selecione uma criatura e clique sobre seu corpo. Exige alcance e intervalo de 30 passos (3 s de simulação).",
	"attention_none": "Carinho recusado: selecione uma criatura viva.", "attention_legacy": "Carinho recusado: personalidade desativada neste mundo legado.",
	"attention_far": "Carinho recusado: o clique precisa alcançar o corpo da seleção; nenhum contato foi registrado.",
	"attention_wait": "Carinho recusado: aguarde %d passos de simulação para outro contato. Pausado, o intervalo não avança.",
	"attention_blocked": "Carinho recusado pelo simulador: contato sem alcance ou obstruído; nenhum encontro foi registrado.",
	"attention_ok": "Passo %d: contato com %s registrado. Familiaridade atualizada; energia, água e posição preservadas.",
	"food_profile": "%s · palatabilidade %s\nNutrição %s · hidratação %s · toxicidade %s\nPreferências individuais na aba Comida.",
	"receipt_empty": "Nenhuma intervenção nesta sessão. Oferecer não significa consumir.",
	"help_body": "Crie um jardim, nomeie o companheiro e escolha a população (padrão: 12). Começa pausado.\n\nSelecione por clique, nome ou lista do Cuidador, que mostra a necessidade mais urgente. Corpo: estado atual. Traços: temperamento herdado. Memória, Comida e Vínculos: experiências individuais.\n\nPostura e brilho representam valência; balanço representa ativação. A criatura aparenta ativação ou tensão corporal. A expressão não indica consciência.\n\nCarinho: selecione e clique no corpo. Exige alcance e intervalo de 30 passos (3 segundos de simulação). Confira o recibo, inclusive nas recusas.\n\nFruta, Semente, Folha e Cogumelo são físicos; cogumelo tem toxicidade. + Água permite beber na margem. Oferecer coloca comida próxima; só ingerir ensina preferências.\n\nExpandir: direita/inferior, custo zero, limite 100.000 por eixo. Laboratório: genes, famílias e sinais.\n\nRoda: zoom · botão do meio/WASD: mover · F: enquadrar · Espaço: pausar · F12: captura. Ctrl+S salva; Ctrl+L carrega.\n\nSaves antigos preservam nomes e população, com personalidade desativada. Proteção pausa por energia baixa/idade; não repõe reservas. Morte é permanente naquele mundo."
}

static func episodio(item: Dictionary) -> String:
	var effect: Dictionary = item["consequence"]
	var event: String = effect["event"]
	var result := texto("episode_" + event, [texto("food_" + str(item["context"]["food_type"]))]) if event in ["food", "toxic_food"] else texto("episode_" + event)
	return texto("episode", [int(item["tick"]), acao(str(item["action"])), result, numero(float(effect["energy"]), 2), numero(float(effect["hydration"]), 2), numero(float(effect["fatigue"]), 3)])

static func expressao(state: Dictionary) -> String:
	return texto("expression_strained" if float(state["valence"]) < -0.25 else ("expression_active" if float(state["arousal"]) >= 0.5 else "expression_calm"))

# E3-SIM — seção aditiva; os formatadores de UI podem consultar estas chaves.
const E3_CATALOGO := {
	"ir_ate_local": "Ir até o local marcado", "buscar_agua": "Buscar água e beber",
	"not_learned": "Ainda não aprendeu", "learned": "Aprendizado observado",
	"show": "Mostrar", "reward": "Recompensar", "observe": "Observar",
	"reset": "Reiniciar treinamento", "assisted": "Rota assistida pelo cuidador",
	"goal": "Tentativa autônoma da habilidade ativa",
	"not_completed": "A tarefa ainda não foi concluída; nenhuma recompensa foi aplicada.",
	"already_rewarded": "Esta conclusão já recebeu recompensa.",
	"frozen": "Política congelada; nenhuma atualização foi aplicada.",
	"reward_note": "Recompensa é sinal de aprendizado. Não repõe energia nem hidratação.",
	"success": "Conclusão verificada pela simulação", "timeout": "Não concluiu no prazo",
	"assistance_note": "Conclusões assistidas não comprovam aprendizado autônomo."
}
const E3_RAZOES := {"teaching.assisted": "assisted", "teaching.goal": "goal"}
