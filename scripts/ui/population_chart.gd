extends Control
## Duas curvas com escalas próprias; somente amostras observadas pela UI.
const Texto = preload("res://scripts/core/textos.gd")
var samples: Array = []

func _ready() -> void:
	custom_minimum_size = Vector2(0, 142)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var plot := Rect2(8, 48, maxf(1, size.x - 16), maxf(1, size.y - 62))
	draw_rect(plot, Color("152e25"))
	for fraction in [0.0, 0.5, 1.0]:
		var y: float = plot.end.y - fraction * plot.size.y
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color("385344"))
	if samples.is_empty():
		return
	var max_population := 1
	var max_diversity := 0.000001
	for sample in samples:
		max_population = maxi(max_population, int(sample.population))
		max_diversity = maxf(max_diversity, float(sample.diversity))
	draw_string(font, Vector2(8, 16), Texto.texto("chart_population", [max_population]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("dbe8a5"))
	draw_string(font, Vector2(8, 35), Texto.texto("chart_diversity", [Texto.numero(max_diversity, 4)]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("8fd5dd"))
	var population := PackedVector2Array()
	var diversity := PackedVector2Array()
	var first_tick: int = samples.front().tick
	var tick_span := maxi(1, int(samples.back().tick) - first_tick)
	for sample in samples:
		var x := plot.position.x + plot.size.x * (int(sample.tick) - first_tick) / tick_span
		population.append(Vector2(x, plot.end.y - plot.size.y * float(sample.population) / max_population))
		diversity.append(Vector2(x, plot.end.y - plot.size.y * float(sample.diversity) / max_diversity))
	if population.size() > 1:
		draw_polyline(population, Color("dbe8a5"), 2, true)
		draw_polyline(diversity, Color("8fd5dd"), 2, true)
	else:
		draw_circle(population[0], 3, Color("dbe8a5"))
		draw_circle(diversity[0], 3, Color("8fd5dd"))
