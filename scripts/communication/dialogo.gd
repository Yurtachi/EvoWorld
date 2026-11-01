class_name Dialogo
extends RefCounted
## Intenções delimitadas e narração somente de fatos observáveis. Sem rede ou RNG.
const SimCreature = preload("res://scripts/creature/sim_creature.gd")
const SimWorld = preload("res://scripts/world/sim_world.gd")
const Textos = preload("res://scripts/communication/dialogo_textos.gd")
const Base = preload("res://scripts/core/textos.gd")
const BAIXA_ENERGIA := 0.35
const EVENTOS_RECENTES := 100 # dez segundos simulados
const INTENTS := ["chamar", "oferecer_comida", "perguntar_estado", "seguir", "parar", "brincar", "proteger"]
const VARIACOES := {
	"chamar": ["chamar", "vem", "venha", "vem aqui", "venha aqui", "vem ca", "venha ca", "chega perto", "aproxime se", "aproximar"],
	"oferecer_comida": ["oferecer comida", "oferecer alimento", "ofereco comida", "te ofereco comida", "dar comida", "dar alimento", "alimentar", "coma", "comida", "tome comida", "quer comida"],
	"perguntar_estado": ["perguntar estado", "estado", "como esta", "como voce esta", "como voce ta", "como vai", "tudo bem", "esta com fome", "voce esta com fome", "esta com pouca energia", "qual sua energia", "qual e sua idade"],
	"seguir": ["seguir", "siga", "siga me", "me siga", "segue", "me segue", "seguir me", "acompanhe", "me acompanhe", "venha comigo"],
	"parar": ["parar", "pare", "para", "pare de seguir", "pare de me seguir", "nao me siga", "fique aqui", "fique parado"],
	"brincar": ["brincar", "brinque", "vamos brincar", "brinca comigo", "brinque comigo", "quero brincar"],
	"proteger": ["proteger", "protecao", "proteja", "ativar protecao", "ative a protecao", "modo protegido", "quero te proteger"]
}

static func interpretar(texto: String) -> Dictionary:
	var normalizado := _normalizar(texto)
	for intent in INTENTS:
		if normalizado in VARIACOES[intent]:
			return {"intent": intent, "comando": {"intent": intent}}
	return {"intent": "desconhecido", "comando": {}}

static func _normalizar(texto: String) -> String:
	var resultado := texto.to_lower().strip_edges()
	var acentos := {"á": "a", "à": "a", "â": "a", "ã": "a", "ä": "a", "é": "e", "ê": "e", "è": "e", "ë": "e", "í": "i", "ì": "i", "î": "i", "ï": "i", "ó": "o", "ô": "o", "õ": "o", "ò": "o", "ö": "o", "ú": "u", "ü": "u", "ù": "u", "û": "u", "ç": "c"}
	for acento in acentos:
		resultado = resultado.replace(acento, acentos[acento])
	# Também aceita acentos decompostos (NFD), espaços repetidos e pontuação.
	for marca in ["\u0300", "\u0301", "\u0302", "\u0303", "\u0308", "\u0327"]:
		resultado = resultado.replace(marca, "")
	var separadores := RegEx.new()
	separadores.compile("[^a-z0-9]+")
	resultado = separadores.sub(resultado, " ", true).strip_edges()
	resultado = resultado.trim_prefix("por favor ").trim_suffix(" por favor").strip_edges()
	return resultado

## Aceita o dicionário de interpretar ou um identificador já validado pela UI.
## Não aplica comandos nem altera estado, memória ou eventos.
static func responder(intent: Variant, criatura: SimCreature, mundo: SimWorld) -> Dictionary:
	var codigo := codigo_intent(intent)
	if codigo not in INTENTS:
		return {"texto": Textos.texto("desconhecido"), "evidencias": [], "comando": {}}
	if mundo == null or criatura == null or not criatura.alive or mundo.creatures.get(criatura.id) != criatura:
		return {"texto": Textos.texto("indisponivel"), "evidencias": [], "comando": {}}
	var evidencias: Array = []
	var frases: Array[String] = []
	if codigo != "perguntar_estado":
		frases.append(Textos.texto("pedido_" + codigo))
	var fracao := criatura.energy / criatura.max_energy
	frases.append(Textos.texto("energia_baixa" if fracao < BAIXA_ENERGIA else "energia_regular", [Base.numero(criatura.energy), Base.numero(criatura.max_energy)]))
	evidencias.append({"fonte": "creature", "creature_id": criatura.id, "campo": "energy", "valor": criatura.energy, "max_energy": criatura.max_energy, "limiar_baixo": BAIXA_ENERGIA, "tick": mundo.tick})
	frases.append(Textos.texto("fome", [Base.numero(criatura.hunger * 100.0), criatura.age, Base.numero(criatura.age * SimWorld.TICK_DT)]))
	evidencias.append({"fonte": "creature", "campo": "hunger", "valor": criatura.hunger})
	evidencias.append({"fonte": "creature", "campo": "age", "valor": criatura.age})
	frases.append(Textos.texto("acao", [Textos.acao(criatura.last_action), Base.razao(criatura.last_reason)]))
	evidencias.append({"fonte": "creature", "campo": "last_action", "valor": criatura.last_action})
	evidencias.append({"fonte": "creature", "campo": "last_reason", "valor": criatura.last_reason})
	var visiveis: Array = mundo.sense(criatura, false)["foods"]
	frases.append(Textos.texto("sem_comida") if visiveis.is_empty() else Textos.texto("comida", [visiveis.size()]))
	var ids: Array = []
	for comida in visiveis:
		ids.append(comida["id"])
	evidencias.append({"fonte": "sense", "campo": "foods", "valor": ids, "tick": mundo.tick})
	# Somente o evento próprio mais recente, dentro de uma janela explícita.
	for indice in range(mundo.events.size() - 1, -1, -1):
		var evento: Dictionary = mundo.events[indice]
		var passo: int = int(evento.get("tick", -1))
		if evento.get("type") == "eat" and evento.get("creature_id") == criatura.id and passo >= maxi(0, mundo.tick - EVENTOS_RECENTES) and passo <= mundo.tick:
			frases.append(Textos.texto("evento_comer", [passo, evento["food_id"], Base.numero(evento["energy"])]))
			evidencias.append({"fonte": "events", "valor": evento.duplicate(true)})
			break
	return {"texto": " ".join(frases), "evidencias": evidencias, "comando": {"intent": codigo} if codigo != "perguntar_estado" else {}}

static func codigo_intent(pedido: Variant) -> String:
	if pedido is String:
		return pedido
	if pedido is Dictionary and pedido.get("intent") is String:
		return pedido["intent"]
	return "desconhecido"
