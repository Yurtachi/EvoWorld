extends RefCounted
## Presentation boundary: accepts memory and sensory data, never a world.
const Texto = preload("res://scripts/core/textos.gd")

static func present(snapshot: Dictionary, sensors: Dictionary = {}, active: bool = true, action: String = "") -> Dictionary:
	var result := {"remembered": [], "perceived": [], "target": {}, "status": "", "legend": Texto.texto("p1_legend")}
	for row in snapshot.get("lugares", []):
		var marker: Dictionary = row.duplicate(true)
		marker["position"] = Vector2(row.pos[0], row.pos[1])
		marker["strength"] = clampf(float(row.expectativa) * float(row.confianca), 0, 1)
		marker["caption"] = Texto.texto("p1_remember_" + str(row.recurso))
		if int(row.falhas) > 0:
			marker.caption += " · " + (Texto.texto("p1_failure_one") if int(row.falhas) == 1 else Texto.texto("p1_failures", [int(row.falhas)]))
		result.remembered.append(marker)
		if active and str(row.id) == str(snapshot.get("objetivo_atual", "")) and action in ["seek_place", "inspect_place"]:
			result.target = marker.duplicate(true)
			result.status = Texto.texto("p1_seeking_" + str(row.recurso))
			result.status += "\n" + Texto.texto(str(snapshot.get("motivo", "")))
	for pair in [["foods", "comida"], ["waters", "agua"]]:
		for row in sensors.get(pair[0], []):
			result.perceived.append({"position": row.pos, "resource": pair[1]})
	if not active:
		result.legend += "\n" + Texto.texto("p1_memory_off")
	elif result.remembered.is_empty():
		result.legend += "\n" + Texto.texto("p1_no_places")
	return result

static func details(snapshot: Dictionary, tick: int) -> String:
	var lines: Array[String] = [Texto.texto("p1_lab_note")]
	for row in snapshot.get("lugares", []):
		lines.append(Texto.texto("p1_detail", [Texto.texto("p1_resource_" + str(row.recurso)),
			Texto.numero(float(row.expectativa) * 100, 0), Texto.numero(float(row.confianca) * 100, 0),
			int(row.visitas), int(row.achados), int(row.falhas), maxi(0, tick - int(row.ultimo_tick))]))
	if snapshot.get("lugares", []).is_empty(): lines.append(Texto.texto("p1_no_places"))
	return "\n\n".join(lines)
