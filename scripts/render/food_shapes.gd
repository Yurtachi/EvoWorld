extends RefCounted
## Ícones e alimentos próprios, gerados sem assets de terceiros.
const COLORS := {"legacy": Color("d9e8a2"), "fruta": Color("ff856e"), "semente": Color("f7d873"), "folha": Color("a4ec92"), "cogumelo": Color("dab0fa")}

static func draw(canvas: CanvasItem, pos: Vector2, kind: String) -> void:
	var color: Color = COLORS.get(kind, COLORS.legacy)
	canvas.draw_circle(pos + Vector2(1, 2), 7, Color(0.07, 0.17, 0.12, 0.7))
	match kind:
		"fruta":
			canvas.draw_circle(pos, 5.5, color)
			canvas.draw_line(pos + Vector2(0, -3), pos + Vector2(2, -8), Color("d2f2ad"), 2, true)
		"semente":
			canvas.draw_colored_polygon(PackedVector2Array([pos + Vector2(-4, 4), pos + Vector2(-4, -2), pos + Vector2(0, -6), pos + Vector2(4, -2), pos + Vector2(4, 4), pos + Vector2(0, 6)]), color)
			canvas.draw_line(pos + Vector2(0, -3), pos + Vector2(0, 4), Color("936d37"), 1, true)
		"folha":
			canvas.draw_colored_polygon(PackedVector2Array([pos + Vector2(-6, 5), pos + Vector2(-4, -3), pos + Vector2(6, -6), pos + Vector2(4, 3)]), color)
			canvas.draw_line(pos + Vector2(-5, 5), pos + Vector2(4, -4), Color("477c4d"), 1, true)
		"cogumelo":
			canvas.draw_rect(Rect2(pos + Vector2(-2, 0), Vector2(4, 6)), Color("ffeed4"))
			canvas.draw_colored_polygon(PackedVector2Array([pos + Vector2(-7, 0), pos + Vector2(-5, -5), pos + Vector2(0, -7), pos + Vector2(5, -5), pos + Vector2(7, 0)]), color)
			canvas.draw_circle(pos + Vector2(-2, -3), 1.2, Color("faf1e0"))
		_:
			canvas.draw_circle(pos, 5, color)

static func icon(kind: String) -> Texture2D:
	var img := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	var color: Color = COLORS.get(kind, COLORS.legacy)
	for y in range(18):
		for x in range(18):
			var dx := float(x - 9)
			var dy := float(y - 9)
			var inside := false
			match kind:
				"fruta": inside = dx * dx + dy * dy < 33
				"semente": inside = absf(dx) / 4 + absf(dy) / 7 < 1
				"folha": inside = absf(dx + dy) < 5 and absf(dx - dy) < 11
				"cogumelo": inside = (dy < 1 and dx * dx + dy * dy < 45) or (dy >= 1 and dy < 6 and absf(dx) < 2)
			if inside:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)
