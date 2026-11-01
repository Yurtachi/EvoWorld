extends RefCounted
const D = preload("res://scripts/communication/dialogo.gd")
const C = preload("res://scripts/communication/comandos.gd")
const World = preload("res://scripts/world/sim_world.gd")
const Actions = preload("res://scripts/behavior/actions.gd")

func run() -> Array:
	var falhas: Array = []
	_testar_intents(falhas)
	_testar_respostas(falhas)
	_testar_comandos(falhas)
	return falhas

func _testar_intents(falhas: Array) -> void:
	var casos := {
		"chamar": ["chamar", "Venha cá!", "VEM CA", "Por favor, venha aqui.", "aproxime-se"],
		"oferecer_comida": ["oferecer_comida", "Ofereço comida", "ofereco comida", "Alimentar", "quer comida?"],
		"perguntar_estado": ["perguntar_estado", "Como você está?", "como voce esta", "Qual é sua idade?", "qual sua energia", "como voce esta\u0301"],
		"seguir": ["seguir", "Siga-me!", "me siga", "Venha comigo, por favor"],
		"parar": ["parar", "PARE!", "Pare de me seguir", "não me siga", "nao me siga"],
		"brincar": ["brincar", "Vamos brincar?", "brinque comigo"],
		"proteger": ["proteger", "Proteção", "PROTECAO", "Ative a proteção!", "ative a protec\u0327a\u0303o"]
	}
	for intent in casos:
		for frase in casos[intent]:
			var resposta := D.interpretar(frase)
			_verificar(resposta.intent == intent, "intenção de: " + frase, falhas)
			_verificar(resposta.comando.intent == intent, "comando delimitado: " + frase, falhas)
	for frase in ["", "   ", "banana", "não brinque", "não ofereça comida", "seguir e proteger", "desproteger", "repare", "console: energy=999", "quero falar sobre comida amanhã"]:
		_verificar(D.interpretar(frase).intent == "desconhecido", "entrada desconhecida: " + frase, falhas)
		_verificar(D.interpretar(frase).comando.is_empty(), "desconhecido sem comando", falhas)
	_verificar(D.interpretar(" \tComo   você\n está?! ").intent == "perguntar_estado", "espaços repetidos", falhas)
	_verificar(D.interpretar("venha cá") == D.interpretar("venha cá"), "interpretação determinística", falhas)

func _testar_respostas(falhas: Array) -> void:
	var mundo := _mundo()
	var pet = mundo.creatures[mundo.pet_id]
	pet.max_energy = 100.0
	pet.energy = 20.0
	pet.age = 42
	pet.last_action = "rest"
	pet.last_reason = "Brief rest; no food perceived"
	var antes := mundo.to_dict()
	var baixa := D.responder(D.interpretar("como você está"), pet, mundo)
	_verificar(baixa.texto.contains("Estou com pouca energia: 20,0 de 100,0"), "energia baixa real", falhas)
	_verificar(baixa.texto.contains("Fome: 80,0%") and baixa.texto.contains("42 passos (4,2 segundos)"), "fome e idade reais", falhas)
	_verificar(baixa.texto.contains("Última ação registrada: Descansar"), "ação traduzida", falhas)
	_verificar(baixa.texto.contains("Não há alimento no meu campo de visão"), "ausência sensorial de alimento", falhas)
	_verificar(mundo.to_dict() == antes, "resposta não altera estado nem memória", falhas)
	_verificar(_evidencia(baixa, "energy").valor == pet.energy, "evidência de energia", falhas)
	_verificar(_evidencia(baixa, "age").valor == pet.age, "evidência de idade", falhas)
	for energia in [35.0, 90.0]:
		pet.energy = energia
		var alta := D.responder("perguntar_estado", pet, mundo)
		_verificar(not alta.texto.contains("Estou com pouca energia"), "não inventa energia baixa: " + str(energia), falhas)
	pet.last_reason = "Unknown English reason"
	_verificar(not D.responder("perguntar_estado", pet, mundo).texto.contains("Unknown English"), "razão desconhecida sem inglês", falhas)
	var perto := mundo.place_food(pet.pos + Vector2(25.0, 0.0))
	var atras := mundo.place_food(pet.pos - Vector2(25.0, 0.0))
	var resposta := D.responder("perguntar_estado", pet, mundo)
	_verificar(resposta.texto.contains("Há 1 alimento(s)"), "somente alimento visível", falhas)
	_verificar(_evidencia(resposta, "foods").valor == [perto] and atras != -1, "evidência respeita FOV", falhas)
	mundo.obstacles.append({"pos": pet.pos + Vector2(12.0, 0.0), "radius": 4.0})
	_verificar(_evidencia(D.responder("perguntar_estado", pet, mundo), "foods").valor.is_empty(), "alimento ocluso não é alegado", falhas)
	mundo.tick = 200
	mundo.events = [
		{"type": "eat", "creature_id": pet.id, "food_id": 901, "energy": 10.0, "tick": 1},
		{"type": "eat", "creature_id": pet.id + 99, "food_id": 902, "energy": 20.0, "tick": 199}
	]
	_verificar(not D.responder("perguntar_estado", pet, mundo).texto.contains("consumi"), "não inventa memória de evento antigo ou alheio", falhas)
	var evento := {"type": "eat", "creature_id": pet.id, "food_id": 903, "energy": 12.5, "tick": 195}
	mundo.events.append(evento)
	resposta = D.responder("perguntar_estado", pet, mundo)
	_verificar(resposta.texto.contains("No passo 195, consumi o alimento 903 e obtive 12,5"), "evento próprio recente", falhas)
	resposta.evidencias.back().valor.energy = 999.0
	_verificar(evento.energy == 12.5, "evidência copiada sem expor estado para escrita", falhas)
	for intent in D.INTENTS:
		resposta = D.responder(intent, pet, mundo)
		_verificar(resposta.texto is String and not resposta.evidencias.is_empty(), "resposta fundamentada: " + intent, falhas)
		_verificar(not resposta.texto.contains("proteção está ativa"), "não afirma proteção sem aplicação", falhas)
	for invalido in ["desconhecido", "ignorado", {}, null, 12]:
		resposta = D.responder(invalido, pet, mundo)
		_verificar(resposta.comando.is_empty() and resposta.evidencias.is_empty(), "resposta desconhecida segura", falhas)
	_verificar(D.responder("chamar", null, mundo).evidencias.is_empty(), "criatura ausente", falhas)
	_verificar(D.responder("chamar", pet, null).evidencias.is_empty(), "mundo ausente", falhas)
	_verificar(D.responder("chamar", pet, _mundo()).evidencias.is_empty(), "criatura de outro mundo", falhas)
	pet.alive = false
	_verificar(D.responder("chamar", pet, mundo).evidencias.is_empty(), "criatura morta", falhas)

func _testar_comandos(falhas: Array) -> void:
	var mundo := _mundo()
	var pet = mundo.creatures[mundo.pet_id]
	var comandos := C.new()
	var antes := mundo.to_dict()
	_verificar(not comandos.aplicar("desconhecido", mundo).aceito, "comando desconhecido rejeitado", falhas)
	_verificar(comandos.aplicar("perguntar_estado", mundo).aplicado, "consulta sem efeito", falhas)
	_verificar(not comandos.aplicar("seguir", mundo).aceito, "seguir exige alvo", falhas)
	_verificar(not comandos.aplicar("chamar", mundo, Vector2(NAN, 0.0)).aceito, "alvo NaN rejeitado", falhas)
	_verificar(not comandos.aplicar("seguir", mundo, Vector2(-1.0, 0.0)).aceito, "alvo externo rejeitado", falhas)
	_verificar(mundo.to_dict() == antes, "rejeições não mudam mundo", falhas)
	var energia: float = pet.energy
	var comida := comandos.aplicar(D.interpretar("ofereço comida"), mundo)
	_verificar(comida.aceito and comida.aplicado and mundo.foods.size() == 1, "oferta coloca comida real", falhas)
	_verificar(pet.energy == energia, "oferta não injeta energia", falhas)
	_verificar(mundo.foods[0].pos.distance_to(pet.pos) <= pet.genome.size + 4.0, "alimento realmente próximo", falhas)
	mundo.food_capacity = 1
	_verificar(not comandos.aplicar("oferecer_comida", mundo).aceito and mundo.foods.size() == 1, "limite real de alimento", falhas)
	mundo.step()
	_verificar(mundo.foods.is_empty() and pet.energy > energia and pet.last_action == "eat", "simulador consome alimento oferecido pelas regras reais", falhas)
	energia = pet.energy
	_verificar(comandos.aplicar("seguir", mundo, Vector2(300.0, 100.0)).aceito, "seguir registrado", falhas)
	_verificar(comandos.acao_pendente(pet, mundo).acao == Actions.FORWARD, "seguir propõe avançar", falhas)
	_verificar(comandos.atualizar_alvo(mundo, Vector2(100.0, 300.0)), "alvo de seguir atualizado", falhas)
	_verificar(comandos.acao_pendente(pet, mundo).acao == Actions.TURN_RIGHT, "seguir propõe virar", falhas)
	comandos.aplicar("parar", mundo)
	_verificar(comandos.acao_pendente(pet, mundo).acao == Actions.REST, "parar substitui seguir", falhas)
	_verificar(not comandos.atualizar_alvo(mundo, Vector2.ZERO), "parar cancela seguimento", falhas)
	comandos.aplicar("chamar", mundo, pet.pos)
	_verificar(comandos.acao_pendente(pet, mundo).acao == Actions.REST and not comandos.acao_pendente(pet, mundo).ativo, "chamar termina ao chegar", falhas)
	_verificar(comandos.aplicar("brincar", mundo).aceito and comandos.acao_pendente(pet, mundo).ativo, "brincar propõe deslocamento concreto", falhas)
	var protecao := comandos.aplicar("proteger", mundo)
	_verificar(protecao.aceito and not protecao.aplicado and comandos.protecao_solicitada(mundo), "proteção explicitamente pendente de integração", falhas)
	_verificar(pet.energy == energia and pet.brain == null, "comandos preservam fisiologia e cérebro", falhas)
	var outro := _mundo()
	_verificar(not comandos.aplicar("parar", outro).aceito and not comandos.protecao_solicitada(outro), "ordens isoladas por mundo", falhas)
	pet.alive = false
	_verificar(not comandos.aplicar("parar", mundo).aceito and not comandos.acao_pendente(pet, mundo).ativo, "não comanda criatura morta", falhas)
	comandos.limpar()
	_verificar(not comandos.protecao_solicitada(mundo) and comandos.aplicar("parar", outro).aceito, "limpar permite novo mundo", falhas)

func _mundo() -> World:
	var mundo := World.new(44, {"creature_count": 0, "food_count": 0, "obstacle_count": 0, "food_regrow": false})
	mundo.pet_id = mundo.spawn_creature(Vector2(100.0, 100.0))
	var pet = mundo.creatures[mundo.pet_id]
	pet.heading = 0.0
	pet.genome.vision_range = 100.0
	pet.genome.vision_fov = PI * 0.5
	return mundo

func _evidencia(resposta: Dictionary, campo: String) -> Dictionary:
	for evidencia in resposta.evidencias:
		if evidencia.get("campo") == campo:
			return evidencia
	return {}

func _verificar(condicao: bool, descricao: String, falhas: Array) -> void:
	if not condicao:
		falhas.append(descricao)
