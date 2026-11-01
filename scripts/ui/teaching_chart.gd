extends Control
## One point per retained autonomous attempt; no synthetic samples.
const Texto = preload("res://scripts/core/textos.gd")
var rates: Array[float] = []

func _ready() -> void:
	custom_minimum_size = Vector2(0, 90)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func observe(attempts: Array, skill: String) -> void:
	rates.clear()
	var outcomes: Array[int] = []
	for row in attempts:
		if row.skill != skill or int(row.assistance) > 0:
			continue
		outcomes.append(1 if row.status == "success" else 0)
		var recent := outcomes.slice(maxi(0, outcomes.size() - 20))
		var wins := 0
		for value in recent:
			wins += value
		rates.append(float(wins) / recent.size())
	queue_redraw()

func _draw() -> void:
	var box := Rect2(32, 8, maxf(10, size.x - 42), 54)
	draw_rect(box, Color("10291f"))
	for value in [0.0, 0.7, 1.0]:
		var y: float = box.end.y - box.size.y * value
		draw_line(Vector2(box.position.x, y), Vector2(box.end.x, y), Color("78947e"), 1)
		draw_string(ThemeDB.fallback_font, Vector2(0, y + 4), Texto.numero(value * 100, 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e8ead6"))
	var previous := Vector2.ZERO
	for index in range(rates.size()):
		var point := Vector2(box.position.x + box.size.x * index / maxi(1, rates.size() - 1), box.end.y - rates[index] * box.size.y)
		if index > 0:
			draw_line(previous, point, Color("ffe29a"), 2, true)
		draw_circle(point, 3, Color("ffe29a"))
		previous = point
	draw_string(ThemeDB.fallback_font, Vector2(2, 82), Texto.texto("te_chart_empty" if rates.is_empty() else "te_chart_axis"), HORIZONTAL_ALIGNMENT_LEFT, size.x - 4, 11, Color("e8ead6"))
