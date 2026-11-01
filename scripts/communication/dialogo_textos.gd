extends RefCounted
## Catálogo exclusivo do diálogo; não altera identificadores ou dados salvos.
const Base = preload("res://scripts/core/textos.gd")
const CATALOGO := {
	"indisponivel": "Não há uma criatura viva neste mundo para consultar.",
	"desconhecido": "Não reconheci o pedido. Você pode chamar, oferecer comida, perguntar sobre o estado, seguir, parar, brincar ou proteger.",
	"energia_baixa": "Estou com pouca energia: %s de %s.",
	"energia_regular": "Minha energia está em %s de %s.",
	"fome": "Fome: %s%%. Idade: %d passos (%s segundos).",
	"acao": "Última ação registrada: %s. Razão registrada: %s",
	"action_forward": "Avançar",
	"sem_comida": "Não há alimento no meu campo de visão agora.",
	"comida": "Há %d alimento(s) no meu campo de visão agora.",
	"evento_comer": "No passo %d, consumi o alimento %d e obtive %s de energia.",
	"pedido_chamar": "Pedido de aproximação recebido; o deslocamento depende da aplicação do comando no simulador.",
	"pedido_oferecer_comida": "Pedido de alimento recebido; a colocação precisa ser confirmada pelo simulador.",
	"pedido_seguir": "Pedido para seguir recebido; é necessário um alvo no jardim e a aplicação do comando no simulador.",
	"pedido_parar": "Pedido para parar recebido; o simulador precisa aplicar a pausa de movimento.",
	"pedido_brincar": "Pedido de brincadeira recebido; o comando propõe um deslocamento curto, com custo normal de energia.",
	"pedido_proteger": "Pedido de proteção recebido; esta resposta não confirma que a proteção esteja ativa.",
	"ok": "Comando registrado.",
	"consulta": "Consulta de estado; nenhum comando foi aplicado.",
	"alimento_colocado": "Alimento colocado perto do companheiro. Isso ainda não significa que ele tenha comido.",
	"alimento_bloqueado": "Não foi possível colocar alimento perto: local bloqueado ou limite atingido.",
	"alvo_invalido": "Defina um alvo válido dentro do jardim.",
	"sem_pet": "Não há um companheiro vivo neste mundo para receber o comando.",
	"protecao_pendente": "Solicitação de proteção registrada; sua aplicação depende do simulador."
}

static func texto(chave: String, valores: Array = []) -> String:
	var modelo: String = CATALOGO.get(chave, CATALOGO.desconhecido)
	return modelo if valores.is_empty() else modelo % valores

static func acao(codigo: String) -> String:
	return texto("action_forward") if codigo == "forward" else Base.acao(codigo)
