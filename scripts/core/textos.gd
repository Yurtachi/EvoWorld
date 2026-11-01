class_name Textos
extends RefCounted
## Catálogo da apresentação. Identificadores e dados salvos continuam intactos.

const CATALOGO := {
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
	"dialog_intro": "Um ecossistema com semente e 16 criaturas autônomas.\nCriar um jardim substitui o mundo atual não salvo.",
	"garden_name": "Nome do jardim",
	"pet_name": "Nome do seu companheiro",
	"seed_caption": "Semente do mundo: repita-a para recriar o estado inicial",
	"seed_default": "7421",
	"pet_rules": "Seu companheiro segue as mesmas regras de sobrevivência das outras criaturas.",
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
	"action_forward": "Avan?ar",
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
	var modelo: String = CATALOGO.get(codigo, CATALOGO.text_unknown)
	return modelo if valores.is_empty() else modelo % valores

static func numero(valor: float, casas: int = 1) -> String:
	return ("%.*f" % [casas, valor]).replace(".", ",")

static func acao(codigo: String) -> String:
	return texto("action_" + codigo) if CATALOGO.has("action_" + codigo) else texto("action_unknown")

static func razao(original: String) -> String:
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
