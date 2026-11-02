extends Control
## Plots Chamfer distance error in [0, 1] across guided attempts per shape.
## Strictly read-only presentation of creature.atelier_snapshot().attempts.

const Texto = preload("res://scripts/core/textos.gd")
const SHAPES := ["linha", "circulo", "quadrado"]
const COLORS := {
	"linha": Color("ffe29a"),
	"circulo": Color("7ad7f0"),
	"quadrado": Color("b8e994")
}

var series: Dictionary = {"linha": [], "circulo": [], "quadrado": []}
var total_points: int = 0
var attempts: Array = []:
	set(value):
		attempts = value
		observe(value)

func _ready() -> void:
	custom_minimum_size = Vector2(0, 116)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func observe(attempts: Array) -> void:
	series = {"linha": [], "circulo": [], "quadrado": []}
	total_points = 0
	for row in attempts:
		if not row is Dictionary:
			continue
		var shape := str(row.get("shape", ""))
		if shape in SHAPES:
			series[shape].append(clampf(float(row.get("error", 1.0)), 0.0, 1.0))
			total_points += 1
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var box := Rect2(36, 22, maxf(10.0, size.x - 46.0), 64.0)
	draw_rect(box, Color("10291f"))
	# Legend row at the top of the chart.
	var lx := 36.0
	for shape in SHAPES:
		var col: Color = COLORS[shape]
		draw_circle(Vector2(lx + 4.0, 11.0), 3.5, col)
		var lbl := Texto.texto("shape_" + shape)
		draw_string(font, Vector2(lx + 11.0, 15.0), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e8ead6"))
		lx += font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 22.0
	for level in [0.0, 0.22, 0.5, 1.0]:
		var y: float = box.end.y - box.size.y * float(level)
		var grid_col := Color("f3a683") if is_equal_approx(level, 0.22) else Color("688570")
		draw_line(Vector2(box.position.x, y), Vector2(box.end.x, y), grid_col, 1.0)
		if level in [0.0, 0.22, 1.0]:
			draw_string(font, Vector2(0.0, y + 4.0), Texto.numero(level, 2 if is_equal_approx(level, 0.22) else 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("e8ead6"))
	for shape in SHAPES:
		var pts: Array = series[shape]
		if pts.is_empty():
			continue
		var col: Color = COLORS[shape]
		var prev := Vector2.ZERO
		for i in range(pts.size()):
			var x_ratio := float(i) / float(maxi(1, pts.size() - 1)) if pts.size() > 1 else 0.5
			var pt := Vector2(box.position.x + box.size.x * x_ratio, box.end.y - float(pts[i]) * box.size.y)
			if i > 0:
				draw_line(prev, pt, col, 2.0, true)
			draw_circle(pt, 3.0, col)
			prev = pt
	var footer := Texto.texto("m3_chart_empty" if total_points == 0 else "m3_chart_axis")
	draw_string(font, Vector2(2.0, 106.0), footer, HORIZONTAL_ALIGNMENT_LEFT, size.x - 4.0, 11, Color("e8ead6"))
