extends RefCounted
const Texto = preload("res://scripts/core/textos.gd")
const World = preload("res://scripts/world/sim_world.gd")

func run() -> Array:
	var falhas: Array = []
	var acoes := {
		"rest": "Descansar", "seek_food": "Buscar alimento", "explore": "Explorar",
		"eat": "Comer", "avoid_obstacle": "Desviar de obstáculo", "dead": "Sem vida"
	}
	for codigo in acoes:
		_conferir(Texto.acao(codigo) == acoes[codigo], "ação: " + codigo, falhas)
	var razoes := {
		"Newly spawned": "Acabou de nascer.",
		"Satiated; conserving energy": "Sem fome; conservando energia.",
		"Brief rest; no food perceived": "Descanso breve; nenhum alimento percebido.",
		"Food 81 visible at 12.3 units": "Alimento 81 visível a 12,3 unidades.",
		"No food within vision; exploring": "Nenhum alimento à vista; explorando.",
		"Starvation: energy exhausted": "Inanição: a energia se esgotou.",
		"Ate visible food 4; gained 31.5 energy": "Comeu o alimento visível 4; ganhou 31,5 de energia.",
		"Obstacle perceived ahead; turning": "Obstáculo percebido à frente; mudando de direção.",
		"Physical boundary contact; turning": "Contato com um limite físico; mudando de direção."
	}
	for original in razoes:
		_conferir(Texto.razao(original) == razoes[original], "razão: " + original, falhas)
	_conferir(Texto.razao("Food 999 visible at 0.0 units") == "Alimento 999 visível a 0,0 unidades.", "parâmetros variáveis da busca", falhas)
	_conferir(Texto.razao("Ate visible food 999; gained 0.0 energy") == "Comeu o alimento visível 999; ganhou 0,0 de energia.", "parâmetros variáveis da alimentação", falhas)
	for desconhecido in ["", "Unknown English reason", "Food X visible at 12.3 units", "Food 1 visible at 1.0 units suffix"]:
		_conferir(Texto.razao(desconhecido) == "Razão não disponível nesta versão.", "fallback seguro de razão", falhas)
	_conferir(Texto.acao("unknown") == "Ação não reconhecida", "fallback seguro de ação", falhas)
	_conferir(Texto.numero(12.5) == "12,5" and Texto.numero(0.125, 2) == "0,13", "vírgula decimal", falhas)
	_conferir(Texto.nome_criatura("Creature 82") == "Criatura 82", "nome gerado antigo", falhas)
	_conferir(Texto.nome_criatura("Flor de Maracujá") == "Flor de Maracujá", "nome escolhido preservado", falhas)
	_conferir(Texto.nome_mundo("Moss garden") == "Jardim de Musgo", "jardim padrão antigo", falhas)
	_conferir(Texto.nome_mundo("Meu jardim") == "Meu jardim", "jardim escolhido preservado", falhas)
	_conferir(Texto.mensagem("Checkpoint saved.") == "Ponto de salvamento salvo.", "salvamento", falhas)
	_conferir(Texto.mensagem("Checkpoint loaded.") == "Ponto de salvamento carregado.", "carregamento", falhas)
	_conferir(Texto.mensagem("No valid checkpoint or backup. Invalid checkpoint JSON.") == "Nenhum ponto de salvamento ou cópia de segurança válido. O arquivo de salvamento contém JSON inválido.", "erro composto", falhas)
	_conferir(Texto.mensagem("Cannot write checkpoint: Permission denied") == "Não foi possível gravar o salvamento.", "erro de sistema sem inglês", falhas)
	_conferir(Texto.mensagem("Future English error") == Texto.texto("message_unknown"), "fallback de persistência", falhas)
	for original in Texto.MENSAGENS:
		_conferir(Texto.mensagem(original) != original, "mensagem traduzida: " + original, falhas)
	for prefixo in Texto.ERROS_PREFIXO:
		_conferir(Texto.mensagem(prefixo + "Unknown operating system error") == Texto.texto(Texto.ERROS_PREFIXO[prefixo]), "prefixo de erro", falhas)
	# A apresentação jamais reescreve o estado original ou o conteúdo do save.
	var mundo := World.new(7421)
	for i in range(20):
		mundo.step()
	var antes := mundo.to_dict()
	for criatura in mundo.creatures.values():
		Texto.acao(criatura.last_action)
		Texto.razao(criatura.last_reason)
		Texto.nome_criatura(criatura.name)
	_conferir(mundo.to_dict() == antes, "tradução não altera o save", falhas)
	return falhas

func _conferir(condicao: bool, descricao: String, falhas: Array) -> void:
	if not condicao:
		falhas.append(descricao)
