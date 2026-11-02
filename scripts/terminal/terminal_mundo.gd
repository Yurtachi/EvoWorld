extends RefCounted
# Interface de capacidade confiável: apenas ações do mundo virtual.
func olhar() -> Dictionary:
	return {"ok": false}

func marcar(_pos: Vector2i) -> Dictionary:
	return {"ok": false}

func mover(_dir: String, _n: int) -> Dictionary:
	return {"ok": false}

func desenhar(_forma: String) -> Dictionary:
	return {"ok": false}

func ler(_id: String) -> Dictionary:
	return {"ok": false}
