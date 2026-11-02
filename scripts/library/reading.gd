extends RefCounted
const Books = preload("res://scripts/library/book_catalog.gd")
const Knowledge = preload("res://scripts/library/knowledge.gd")

static func candidate(mind, creature, sensors: Dictionary) -> Dictionary:
	var best := {"id": 0, "score": -4.0}
	for row in sensors.get("books", []):
		var s := Knowledge.state(mind)
		var r: Dictionary = s.reading
		if not r.is_empty() and int(r.id) == int(row.id) and int(r.page) >= Books.BOOKS[row.book_id].size(): continue
		var curiosity: float = mind.traits(creature).curiosity
		var boredom: float = creature.personality.boredom if creature.personality != null else 0.0
		if curiosity < 0.15 and boredom < 0.5: continue
		var score := 0.7 + curiosity * 0.65 + boredom * 0.3
		if score > float(best.score): best = {"id": row.id, "score": score}
	return best

## Called by the world only after physical reach/occlusion checks.
static func page_tick(mind, book: Dictionary, tick: int) -> bool:
	var s := Knowledge.state(mind)
	if s.reading.is_empty() or int(s.reading.id) != int(book.id):
		s.reading = {"id": book.id, "book_id": book.book_id, "page": 0, "progress": 0, "last_tick": -1}
	var r: Dictionary = s.reading
	if int(r.last_tick) >= tick or int(r.page) >= Books.BOOKS[book.book_id].size(): return false
	r.last_tick = tick
	r.progress += 1
	if int(r.progress) >= Books.PAGE_TICKS:
		var content: Dictionary = Books.BOOKS[book.book_id][int(r.page)]
		r.page += 1
		r.progress = 0
		Knowledge.add(mind, content, "livro:" + str(book.book_id) + ":" + str(r.page), 0.8, tick)
	return true
