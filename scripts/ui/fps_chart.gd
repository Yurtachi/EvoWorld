extends Control
## Medidas de quadros renderizados; não substituem um benchmark da simulação.
const Texto = preload("res://scripts/core/textos.gd")
var samples: Array[float] = []

func _ready() -> void:
	custom_minimum_size = Vector2(130, 28)
	tooltip_text = Texto.texto("fps_title")
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func reset() -> void:
	samples.clear()

func sample(delta: float) -> void:
	if delta > 0:
		samples.append(1.0 / delta)
		if samples.size() > 120:
			samples.pop_front()
	queue_redraw()

func _draw() -> void:
	draw_style_box(_background(), Rect2(Vector2.ZERO, size))
	if samples.size() < 2:
		return
	var peak: float = maxf(60, samples.max())
	var points := PackedVector2Array()
	for index in range(samples.size()):
		points.append(Vector2(index * (size.x - 4) / 119.0 + 2, size.y - 2 - samples[index] / peak * (size.y - 5)))
	draw_polyline(points, Color("aadcb6"), 1.2, true)
	var current := Texto.numero(samples.back(), 0)
	draw_rect(Rect2(3, 1, 94, 14), Color("10281f"))
	draw_string(ThemeDB.fallback_font, Vector2(5, 13), current + " " + Texto.texto("fps_unit"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f5f3dd"))

func _background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("10281f")
	return style
