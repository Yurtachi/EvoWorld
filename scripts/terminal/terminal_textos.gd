extends RefCounted
# Catálogo interno do mundo virtual; a integração de UI usará Textos em M4b.
const MESSAGES := {
	"ok": "A ação virtual foi concluída.",
	"entrada": "A entrada virtual excede o limite ou tem tipo inválido.",
	"simbolo": "Esse símbolo não pertence à linguagem virtual.",
	"sintaxe": "A sequência virtual parece incompleta ou tem argumentos extras.",
	"comando": "Esse comando não existe no terminal virtual.",
	"argumento": "O argumento está fora do catálogo ou do limite virtual.",
	"limite": "A sequência excede o limite de complexidade virtual.",
	"passos": "A sequência excede o orçamento de passos virtual.",
	"tempo": "O orçamento de tempo virtual terminou.",
	"desconhecido": "Esse comando ainda não foi descoberto.",
	"estado": "O estado do terminal virtual é inválido.",
	"adaptador": "O mundo virtual não está disponível.",
	"recusado": "O mundo virtual recusou essa ação.",
}

static func message(code: String) -> String:
	return MESSAGES.get(code, MESSAGES.recusado)

static func result(code: String) -> Dictionary:
	return {"ok": code == "ok", "erro": "" if code == "ok" else code, "mensagem": message(code)}
