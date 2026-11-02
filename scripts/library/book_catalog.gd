extends RefCounted
## Authored offline. Numeric statements are conservative approach/avoid advice,
## not identification of hidden capsule variants. Text belongs to Textos.
const VERSION := 1
const LIMIT := 32
const PAGE_TICKS := 8
const BOOKS := {
	"guia_capsulas": [{"capsula": -1.0}, {"pedra": 0.0}],
	"guia_pedras": [{"pedra": 0.0}],
	"guia_enganoso": [{"capsula": 1.0}]}

static func valid_source(source: Variant) -> bool:
	if not source is String: return false
	if source in ["observado", "interagido", "cuidador", "inferido"]: return true
	var parts: PackedStringArray = source.split(":")
	return parts.size() == 3 and parts[0] == "livro" and BOOKS.has(parts[1]) and parts[2].is_valid_int() and str(int(parts[2])) == parts[2] and int(parts[2]) >= 1 and int(parts[2]) <= BOOKS[parts[1]].size()

static func source_key(source: String) -> String:
	return ":".join(source.split(":").slice(0, 2)) if source.begins_with("livro:") else source
