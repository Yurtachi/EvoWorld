extends Control
## Renders a 64x64 atelier board canvas from persisted or live primitive strokes.
## Strictly read-only presentation: never fabricates or mutates simulation state.

const Data = preload("res://scripts/core/sim_data.gd")
const CANVAS_SIZE := 64.0

var strokes: Array = []
var reference_strokes: Array = []
var show_pen: bool = false
var active_pen: bool = false
var pen_pos: Vector2 = Vector2(32.0, 32.0)
var compact: bool = false

func _init(is_compact: bool = false) -> void:
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	set_compact(is_compact)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_compact(is_compact: bool) -> void:
	compact = is_compact
	var side := 56.0 if compact else 88.0
	custom_minimum_size = Vector2(side, side)
	size = Vector2(side, side)
	queue_redraw()

func setup(p_strokes: Array, p_reference: Array = [], p_show_pen: bool = false, p_pen_pos: Vector2 = Vector2(32.0, 32.0)) -> void:
	strokes = p_strokes
	reference_strokes = p_reference
	show_pen = p_show_pen
	pen_pos = p_pen_pos
	queue_redraw()

static func _unpack(pt: Variant) -> Vector2:
	return (pt as Vector2) if (pt is Vector2) else Data.unpack_vector(pt)

static func project_board_strokes(p_strokes: Array, p_reference: Array, plot: Rect2, is_compact: bool = false) -> Dictionary:
	var ref_lines: Array = []
	var ref_flat: Array[Vector2] = []
	for ref in p_reference:
		if not ref is Array or ref.size() < 2:
			continue
		var row: Array[Vector2] = []
		for raw in ref:
			var v := _unpack(raw)
			row.append(v)
			ref_flat.append(v)
		ref_lines.append(row)
	var stroke_lines: Array = []
	var stroke_flat: Array[Vector2] = []
	for stroke in p_strokes:
		if not stroke is Array or stroke.size() < 2:
			continue
		var row: Array[Vector2] = []
		for raw in stroke:
			var v := _unpack(raw)
			row.append(v)
			stroke_flat.append(v)
		stroke_lines.append(row)
	var has_ref := not ref_flat.is_empty()
	var has_stroke := not stroke_flat.is_empty()
	var ref_center := Vector2(32.0, 32.0)
	var ref_start := Vector2(32.0, 32.0)
	var ref_scale := 1.0
	var ref_max_extent := 1.0
	if has_ref:
		var sum_ref := Vector2.ZERO
		for v in ref_flat:
			sum_ref += v
		ref_center = sum_ref / float(ref_flat.size())
		ref_start = ref_flat[0]
		for v in ref_flat:
			ref_max_extent = maxf(ref_max_extent, maxf(absf(v.x - ref_center.x), absf(v.y - ref_center.y)))
		if ref_lines[0].size() >= 2:
			var seg_sum := 0.0
			var seg_count: int = ref_lines[0].size() - 1
			for i in range(seg_count):
				seg_sum += ref_lines[0][i].distance_to(ref_lines[0][i + 1])
			ref_scale = clampf((seg_sum / float(seg_count)) / 3.0, 0.45, 1.65)
	var stroke_start := stroke_flat[0] if has_stroke else Vector2(32.0, 32.0)
	var stroke_center := Vector2(32.0, 32.0)
	if has_stroke:
		var sum_s := Vector2.ZERO
		for v in stroke_flat:
			sum_s += v
		stroke_center = sum_s / float(stroke_flat.size())
	var out_ref: Array = []
	var out_strokes: Array = []
	var last_pt := Vector2.INF
	if is_compact:
		var aligned_all: Array[Vector2] = []
		for v in ref_flat:
			aligned_all.append(v)
		for v in stroke_flat:
			var av := (ref_start + (v - stroke_start) * ref_scale) if has_ref else v
			aligned_all.append(av)
		var min_v := Vector2(32.0, 32.0)
		var max_v := Vector2(32.0, 32.0)
		if not aligned_all.is_empty():
			min_v = aligned_all[0]
			max_v = aligned_all[0]
			for v in aligned_all:
				min_v = min_v.min(v)
				max_v = max_v.max(v)
		var mid := (min_v + max_v) * 0.5
		var span := maxf(maxf(max_v.x - min_v.x, max_v.y - min_v.y) * 1.42, 8.5)
		for row: Array in ref_lines:
			var pts := PackedVector2Array()
			for v: Vector2 in row:
				var norm: Vector2 = ((v - mid) / span + Vector2(0.5, 0.5)).clamp(Vector2.ZERO, Vector2.ONE)
				pts.append(plot.position + norm * plot.size)
			out_ref.append(pts)
		for row: Array in stroke_lines:
			var pts := PackedVector2Array()
			for v: Vector2 in row:
				var av: Vector2 = (ref_start + (v - stroke_start) * ref_scale) if has_ref else v
				var norm: Vector2 = ((av - mid) / span + Vector2(0.5, 0.5)).clamp(Vector2.ZERO, Vector2.ONE)
				var mapped: Vector2 = plot.position + norm * plot.size
				pts.append(mapped)
				last_pt = mapped
			out_strokes.append(pts)
	else:
		var mag := 2.15 if ref_max_extent <= 7.0 else 1.25
		var mag_ref_start: Vector2 = (ref_center + (ref_start - ref_center) * mag).clamp(Vector2(3.0, 3.0), Vector2(61.0, 61.0))
		for row: Array in ref_lines:
			var pts := PackedVector2Array()
			for v: Vector2 in row:
				var lv: Vector2 = (ref_center + (v - ref_center) * mag).clamp(Vector2(2.5, 2.5), Vector2(61.5, 61.5))
				pts.append(plot.position + (lv / CANVAS_SIZE) * plot.size)
			out_ref.append(pts)
		for row: Array in stroke_lines:
			var pts := PackedVector2Array()
			for v: Vector2 in row:
				var lv: Vector2
				if has_ref:
					lv = (mag_ref_start + (v - stroke_start) * ref_scale * mag).clamp(Vector2(2.5, 2.5), Vector2(61.5, 61.5))
				else:
					lv = (stroke_center + (v - stroke_center) * 2.1).clamp(Vector2(2.5, 2.5), Vector2(61.5, 61.5))
				var mapped: Vector2 = plot.position + (lv / CANVAS_SIZE) * plot.size
				pts.append(mapped)
				last_pt = mapped
			out_strokes.append(pts)
	return {
		"ref": out_ref,
		"strokes": out_strokes,
		"last_pt": last_pt
	}

func _draw() -> void:
	var outer := Rect2(Vector2.ZERO, size)
	var border_color := Color("7a6345") if not compact else Color("587564")
	draw_rect(outer, border_color)
	draw_rect(outer, Color("17372b"), false, 1.5)
	var pad := 3.0 if compact else 4.0
	var inner := Rect2(Vector2(pad, pad), (size - Vector2(pad * 2.0, pad * 2.0)).max(Vector2(8.0, 8.0)))
	draw_rect(inner, Color("142b23"))
	var mid := inner.get_center()
	draw_line(Vector2(inner.position.x + 2.0, mid.y), Vector2(inner.end.x - 2.0, mid.y), Color(0.78, 0.88, 0.80, 0.10), 1.0)
	draw_line(Vector2(mid.x, inner.position.y + 2.0), Vector2(mid.x, inner.end.y - 2.0), Color(0.78, 0.88, 0.80, 0.10), 1.0)
	var plot := inner.grow(-4.0 if compact else -5.0)
	var projected := project_board_strokes(strokes, reference_strokes, plot, compact)
	for pts in projected.ref:
		draw_polyline(pts, Color(0.42, 0.84, 0.95, 0.34), 3.2 if not compact else 2.4, true)
		draw_polyline(pts, Color("7ad7f0"), 1.8 if not compact else 1.3, true)
		for p in pts:
			draw_circle(p, 1.7 if not compact else 1.2, Color("c4f4ff"))
	for pts in projected.strokes:
		draw_polyline(pts, Color("0b1914"), 3.8 if not compact else 3.2, true)
		draw_polyline(pts, Color("ffe596"), 2.3 if not compact else 2.0, true)
		for p in pts:
			draw_circle(p, 1.5 if not compact else 1.2, Color("ffe596"))
	if (show_pen or active_pen) and projected.last_pt.is_finite():
		draw_circle(projected.last_pt, 3.6, Color("17372b"))
		draw_circle(projected.last_pt, 2.3, Color("ff9e64"))
