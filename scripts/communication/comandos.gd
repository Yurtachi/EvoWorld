class_name Comandos
extends RefCounted
## Adaptador por mundo. Ordens persistidas pelo SimWorld passam pela física normal.
## Não teleporta, não injeta energia e não substitui cérebros.
const SimCreature = preload("res://scripts/creature/sim_creature.gd")
const DialogoAPI = preload("res://scripts/communication/dialogo.gd")
const Textos = preload("res://scripts/communication/dialogo_textos.gd")
const Actions = preload("res://scripts/behavior/actions.gd")
const Data = preload("res://scripts/core/sim_data.gd")

var _mundo: WeakRef
var _ordens: Dictionary = {}
var _protecao: Dictionary = {}

## Sobrevivência prevalece: com fome acima do limite a ordem fica suspensa e o
## comportamento autônomo assume. Ordens expiram para não prender o pet em obstáculos.
const FOME_SUSPENDE_ORDEM := 0.6
const TICKS_ORDEM := {"chamar": 600, "brincar": 300, "parar": 300, "seguir": 3000}

## alvo é uma posição no mundo, fornecida pela UI, nunca extraída de texto livre.
## aplicado=true confirma apenas colocação real de alimento ou consulta sem efeito.
func aplicar(pedido: Variant, mundo, alvo: Vector2 = Vector2.INF) -> Dictionary:
	var intent := DialogoAPI.codigo_intent(pedido)
	if intent not in DialogoAPI.INTENTS:
		return _resultado(false, false, "desconhecido")
	if not _vincular(mundo) or not mundo.creatures.has(mundo.pet_id):
		return _resultado(false, false, "sem_pet")
	var pet: SimCreature = mundo.creatures[mundo.pet_id]
	if not pet.alive:
		return _resultado(false, false, "sem_pet")
	if intent == "perguntar_estado" or intent in DialogoAPI.CONSULTAS:
		return _resultado(true, true, "consulta")
	if intent == "oferecer_comida":
		# Busca determinística de posições próximas; respeita capacidade e geometria.
		for indice in range(8):
			var posicao := pet.pos + Vector2.from_angle(pet.heading + indice * TAU / 8.0) * (pet.genome.size + 3.0)
			var id: int = mundo.place_food(posicao)
			if id != -1:
				var resultado := _resultado(true, true, "alimento_colocado")
				resultado["food_id"] = id
				return resultado
		return _resultado(false, false, "alimento_bloqueado")
	if intent == "proteger":
		_protecao[pet.id] = true
		return _resultado(true, false, "protecao_pendente")
	if intent == "brincar":
		alvo = (pet.pos + Vector2.from_angle(pet.heading) * 40.0).clamp(Vector2.ONE * pet.genome.size, mundo.size - Vector2.ONE * pet.genome.size)
	if intent in ["chamar", "seguir", "brincar"] and not _alvo_valido(alvo, mundo):
		return _resultado(false, false, "alvo_invalido")
	mundo.ensino_cancelar(pet.id)
	_ordens[pet.id] = {"intent": intent, "alvo": alvo if intent != "parar" else pet.pos, "restante": int(TICKS_ORDEM[intent])}
	return _resultado(true, false, "ok")

## Atualiza o alvo móvel de seguir sem reaplicar comandos ou consumir RNG.
func atualizar_alvo(mundo, alvo: Vector2) -> bool:
	if not _mesmo_mundo(mundo) or not _alvo_valido(alvo, mundo):
		return false
	var ordem: Dictionary = _ordens.get(mundo.pet_id, {})
	if ordem.get("intent") != "seguir":
		return false
	ordem["alvo"] = alvo
	return true

## Hook de decisão: ler antes de brain.decide/heurística e aplicar a ação pelos
## mesmos custos, sensores e colisões. Retorna ativo=false ao não haver ordem.
func acao_pendente(criatura: SimCreature, mundo) -> Dictionary:
	if not _mesmo_mundo(mundo) or criatura == null or not criatura.alive or criatura.id != mundo.pet_id or mundo.creatures.get(criatura.id) != criatura:
		return {"ativo": false}
	var ordem: Dictionary = _ordens.get(criatura.id, {})
	if ordem.is_empty():
		return {"ativo": false}
	var intent: String = ordem["intent"]
	ordem["restante"] = int(ordem.get("restante", TICKS_ORDEM[intent])) - 1
	if ordem["restante"] <= 0:
		_ordens.erase(criatura.id)
		return {"ativo": false}
	if criatura.hunger > FOME_SUSPENDE_ORDEM:
		return {"ativo": false}
	if intent == "parar":
		return {"ativo": true, "acao": Actions.REST, "razao": "dialogo.stop"}
	var deslocamento: Vector2 = ordem["alvo"] - criatura.pos
	if deslocamento.length() <= maxf(criatura.genome.size + 2.0, criatura.genome.speed * float(mundo.TICK_DT)):
		if intent != "seguir":
			_ordens.erase(criatura.id)
		return {"ativo": true, "acao": Actions.REST, "razao": "dialogo.arrived"}
	var angulo := wrapf(deslocamento.angle() - criatura.heading, -PI, PI)
	var acao := Actions.FORWARD
	if absf(angulo) > 0.25:
		acao = Actions.TURN_LEFT if angulo < 0.0 else Actions.TURN_RIGHT
	return {"ativo": true, "acao": acao, "razao": "dialogo." + intent}

## Solicitação, não comprovação de proteção biológica. O integrador deve aplicar
## uma política explícita e registrar suas intervenções antes de anunciá-la ativa.
func protecao_solicitada(mundo) -> bool:
	return _mesmo_mundo(mundo) and mundo.creatures.has(mundo.pet_id) and mundo.creatures[mundo.pet_id].alive and bool(_protecao.get(mundo.pet_id, false))

## Cancela ordens e proteção solicitada, por exemplo ao carregar/abrir um mundo.
func limpar() -> void:
	_ordens.clear()
	_protecao.clear()
	_mundo = null

## Explicit control supersedes teaching; a player order cannot count as autonomy.
func cancelar_ordem(creature_id: int) -> void:
	_ordens.erase(creature_id)

## JSON-safe state, bound to this world's pet only. Protection remains a request.
func to_dict(mundo) -> Dictionary:
	if not _mesmo_mundo(mundo) or not mundo.creatures.has(mundo.pet_id):
		return {"order": {}, "protection_requested": false}
	var ordem: Dictionary = _ordens.get(mundo.pet_id, {})
	return {"order": {} if ordem.is_empty() else {"intent": ordem["intent"], "target": Data.pack_vector(ordem["alvo"])},
		"protection_requested": bool(_protecao.get(mundo.pet_id, false))}

func restore(data: Variant, mundo) -> bool:
	if not data is Dictionary or data.size() != 2 or not data.get("order") is Dictionary or not data.get("protection_requested") is bool:
		return false
	var order: Dictionary = data["order"]
	if not order.is_empty():
		if order.size() != 2 or order.get("intent") not in ["seguir", "parar", "chamar", "brincar"] or not Data.vector(order.get("target")):
			return false
		if not _alvo_valido(Data.unpack_vector(order["target"]), mundo):
			return false
	if (not order.is_empty() or data["protection_requested"]) and not mundo.creatures.has(mundo.pet_id):
		return false
	limpar()
	_vincular(mundo)
	if not order.is_empty():
		_ordens[mundo.pet_id] = {"intent": order["intent"], "alvo": Data.unpack_vector(order["target"]), "restante": int(TICKS_ORDEM[order["intent"]])}
	if data["protection_requested"]:
		_protecao[mundo.pet_id] = true
	return true

func _mesmo_mundo(mundo) -> bool:
	return mundo != null and _mundo != null and _mundo.get_ref() == mundo

func _vincular(mundo) -> bool:
	if mundo == null:
		return false
	if _mundo == null or _mundo.get_ref() == null:
		limpar()
		_mundo = weakref(mundo)
	return _mesmo_mundo(mundo)

static func _alvo_valido(alvo: Vector2, mundo) -> bool:
	return alvo.is_finite() and alvo.x >= 0.0 and alvo.y >= 0.0 and alvo.x <= mundo.size.x and alvo.y <= mundo.size.y

static func _resultado(aceito: bool, aplicado: bool, codigo: String) -> Dictionary:
	return {"aceito": aceito, "aplicado": aplicado, "codigo": codigo, "texto": Textos.texto(codigo)}
