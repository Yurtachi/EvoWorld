extends Node2D
## Presentation only: every organism, resource and rock comes from SimWorld.
const Texto = preload("res://scripts/core/textos.gd")
const FoodShapes = preload("res://scripts/render/food_shapes.gd")
const World = preload("res://scripts/world/sim_world.gd")
const ObjectCatalog = preload("res://scripts/environment/object_catalog.gd")
var world: World
var teaching_snapshot: Dictionary = {}
var teaching_target := Vector2.INF
var selected_id := -1
var tool := "select"
var pointer := Vector2.ZERO
var show_pointer := false
var show_sensors := false
var terrain := PackedVector2Array()
var command_target := Vector2.ZERO
var show_command_target := false
var grass_texture: Texture2D
var food_texture: Texture2D
var rock_texture: Texture2D
var visible_names: Dictionary = {}
const AtelierCanvas = preload("res://scripts/ui/atelier_canvas.gd")
var object_styles: Dictionary = {}
var demo_preview_strokes: Array = []

func set_world(value: World) -> void:
	world = value
	if grass_texture == null:
		grass_texture = _texture("res://assets/external/kenney/roguelike-rpg-pack/tiles/terrain/grass.png")
		var atlas := _texture("res://assets/external/kenney/roguelike-rpg-pack/Spritesheet/roguelikeSheet_transparent.png")
		food_texture = _tile(atlas, Vector2i(28, 10))
		rock_texture = _tile(atlas, Vector2i(54, 21))
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Separate visual RNG never consumes the simulation's random stream.
	var decoration_rng := RandomNumberGenerator.new()
	decoration_rng.seed = world.seed
	terrain.clear()
	for i in range(60):
		terrain.append(Vector2(decoration_rng.randf_range(8, world.size.x - 8),
			decoration_rng.randf_range(8, world.size.y - 8)))
	queue_redraw()

func _draw() -> void:
	if world == null:
		return
	draw_rect(Rect2(Vector2(-10, -10), world.size + Vector2(20, 20)), Color("233c32"))
	draw_rect(Rect2(Vector2.ZERO, world.size), Color("537b64"))
	var visible := get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()
	visible = visible.intersection(Rect2(Vector2.ZERO, world.size))
	for point in terrain:
		if not visible.grow(12).has_point(point): continue
		var scale_value := 0.35 + fmod(point.x, 11.0) / 35.0
		for side in [-1, 1]:
			var end := point + Vector2(side * 3.2, -6) * scale_value
			draw_line(point, end, Color("6d956e"), 1.5, true)
			draw_circle(end, 2.0 * scale_value, Color("7ca075"))
	for water in world.waters:
		_water(water.pos, water.radius)
	for obstacle in world.obstacles:
		_rock(obstacle.pos, obstacle.radius)
	for food in world.foods:
		FoodShapes.draw(self, food.pos, food.get("food_type", "legacy"))
	for row in world.objects:
		_draw_object(ObjectCatalog.appearance(row))
	for board in world.boards:
		_draw_board(board)
	for book in world.library.books:
		_draw_book(book)
	for terminal in world.terminals:
		_draw_terminal(terminal)
	for marker in world.terminal_markers:
		_draw_terminal_marker(marker)
	if world.has_method("place_feeder"):
		for feeder in world.get("feeders"):
			_draw_feeder(feeder)
	for creature in world.creatures.values():
		if creature.id == selected_id and show_sensors:
			_sensor(creature)
		_creature(creature)
	visible_names.clear()
	var name_order: Array = []
	for id in [selected_id, world.pet_id]:
		if world.creatures.has(id) and id not in name_order:
			name_order.append(id)
	for id in world.creatures:
		if id not in name_order:
			name_order.append(id)
	var spacing: float = 3 / maxf(get_global_transform_with_canvas().get_scale().x, 0.05)
	for id in name_order:
		var creature = world.creatures[id]
		if not _show_name(creature):
			continue
		var rect := _label_rect(creature).grow(spacing)
		var overlaps := false
		for shown in visible_names.values():
			if rect.intersects(shown):
				overlaps = true
				break
		if not overlaps:
			visible_names[id] = rect
			_name_tag(creature)
	if show_command_target and Rect2(Vector2.ZERO, world.size).has_point(command_target):
		draw_arc(command_target, 10, 0, TAU, 24, Color("8fd5dd"), 1.5, true)
		draw_line(command_target - Vector2(14, 0), command_target + Vector2(14, 0), Color("8fd5dd"), 1, true)
		draw_line(command_target - Vector2(0, 14), command_target + Vector2(0, 14), Color("8fd5dd"), 1, true)
	_draw_teaching()
	if show_sensors:
		_draw_social()
		_draw_mind_marker()
	if show_pointer and tool != "select" and Rect2(Vector2.ZERO, world.size).has_point(pointer):
		var radius := 30.0 if tool == "water" else (24.0 if tool == "obstacle" else (13.0 if tool == "creature" else (12.0 if tool == "terminal" else 7.0)))
		draw_circle(pointer, radius, Color(0.96, 0.91, 0.68, 0.18))
		draw_arc(pointer, radius, 0, TAU, 40, Color("f1dfab"), 1.5, true)
		if tool in ["board", "demo"]:
			_draw_board_preview(pointer)

func _draw_book(book: Dictionary) -> void:
	var pos: Vector2 = book.pos
	draw_rect(Rect2(pos - Vector2(12, 8) + Vector2(2, 3), Vector2(24, 16)), Color("17372b"))
	draw_rect(Rect2(pos - Vector2(12, 8), Vector2(24, 16)), Color("6b4534"))
	draw_rect(Rect2(pos - Vector2(10, 7), Vector2(20, 13)), Color("fff0c7"))
	draw_line(pos + Vector2(0, -7), pos + Vector2(0, 6), Color("9c7653"), 1.4, true)
	for y in [-3, 0, 3]:
		draw_line(pos + Vector2(-8, y), pos + Vector2(-3, y), Color("9c7653"), 1, true)
		draw_line(pos + Vector2(3, y), pos + Vector2(8, y), Color("9c7653"), 1, true)
	var zoom := maxf(get_global_transform_with_canvas().get_scale().x, 0.05)
	if zoom >= 0.65:
		var text := Texto.texto("m3c_book_tag", [book.id])
		var width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_set_transform(pos + Vector2(-width / 2 / zoom, -12), 0, Vector2.ONE / zoom)
		draw_string_outline(ThemeDB.fallback_font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color("17372b"))
		draw_string(ThemeDB.fallback_font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("fff2d1"))
		draw_set_transform(Vector2.ZERO)


func _draw_terminal(terminal: Dictionary) -> void:
	var pos: Vector2 = terminal.pos
	draw_circle(pos + Vector2(1, 3), 12, Color(0.04, 0.12, 0.09, 0.45))
	draw_rect(Rect2(pos - Vector2(12, 10), Vector2(24, 20)), Color("2c3d36"))
	draw_rect(Rect2(pos - Vector2(10, 8), Vector2(20, 16)), Color("455a4e"))
	draw_rect(Rect2(pos - Vector2(7, 6), Vector2(14, 12)), Color("dbe8ba"))
	draw_line(pos + Vector2(-4, -2), pos + Vector2(4, -2), Color("3d5448"), 1.2, true)
	draw_line(pos + Vector2(-3, 1), pos + Vector2(3, 1), Color("3d5448"), 1.0, true)
	draw_circle(pos + Vector2(0, 3.5), 1.2, Color("3d5448"))
	draw_rect(Rect2(pos + Vector2(10, -6), Vector2(3, 3)), Color("9b7653"))
	draw_rect(Rect2(pos + Vector2(10, -1), Vector2(3, 3)), Color("5a7d6e"))
	draw_rect(Rect2(pos + Vector2(10, 4), Vector2(3, 3)), Color("7a6585"))
	var zoom := maxf(get_global_transform_with_canvas().get_scale().x, 0.05)
	if zoom >= 0.65:
		var text := Texto.texto("m4b_terminal_tag", [int(terminal.id)])
		var width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_set_transform(pos + Vector2(-width / 2 / zoom, -14), 0, Vector2.ONE / zoom)
		draw_string_outline(ThemeDB.fallback_font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color("17372b"))
		draw_string(ThemeDB.fallback_font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("fff2d1"))
		draw_set_transform(Vector2.ZERO)

func _draw_terminal_marker(marker: Dictionary) -> void:
	var mpos: Vector2 = Vector2(marker.pos[0], marker.pos[1])
	draw_circle(mpos, 5, Color(0.49, 0.75, 0.66, 0.35))
	draw_arc(mpos, 6, 0, TAU, 16, Color("7ebfa8"), 1.2, true)
	draw_line(mpos - Vector2(4, 0), mpos + Vector2(4, 0), Color("7ebfa8"), 1.0, true)
	draw_line(mpos - Vector2(0, 4), mpos + Vector2(0, 4), Color("7ebfa8"), 1.0, true)
	var zoom := maxf(get_global_transform_with_canvas().get_scale().x, 0.05)
	if zoom >= 0.8:
		var text := Texto.texto("m4b_marker_tag", [int(mpos.x), int(mpos.y), int(marker.owner_id)])
		var width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_set_transform(mpos + Vector2(-width / 2 / zoom, -9), 0, Vector2.ONE / zoom)
		draw_string_outline(ThemeDB.fallback_font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color("17372b"))
		draw_string(ThemeDB.fallback_font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("cbe3cf"))
		draw_set_transform(Vector2.ZERO)

func _water(pos: Vector2, radius: float) -> void:
	draw_circle(pos, radius + 3, Color("aecfc2"))
	draw_circle(pos, radius, Color("257fa6"))
	draw_circle(pos + Vector2(-radius * 0.12, -radius * 0.12), radius * 0.72, Color("379cc2"))
	for offset in [-0.35, 0.15, 0.48]:
		var origin := pos + Vector2(-radius * 0.35, radius * offset)
		draw_line(origin, origin + Vector2(radius * 0.6, 0), Color("a2e2e8"), 1.5, true)

func _draw_object(row: Dictionary) -> void:
	# Same public appearance yields identical pixels, regardless of hidden effect.
	var pos: Vector2 = row.pos
	draw_circle(pos + Vector2(1, 3), 9, Color(0.04, 0.12, 0.09, 0.5))
	if row.appearance == "lisa":
		draw_style_box(_capsule_style(Color("17372b")), Rect2(pos - Vector2(9, 6), Vector2(18, 12)))
		draw_style_box(_capsule_style(Color("efe4c6")), Rect2(pos - Vector2(7, 4), Vector2(14, 8)))
		draw_line(pos + Vector2(0, -3), pos + Vector2(0, 3), Color("8a826a"), 1, true)
	else:
		var points := PackedVector2Array([pos + Vector2(-8, 3), pos + Vector2(-6, -5), pos + Vector2(2, -7), pos + Vector2(8, -1), pos + Vector2(6, 5), pos + Vector2(-8, 3)])
		draw_colored_polygon(points, Color("b8bec0"))
		draw_polyline(points, Color("17372b"), 2, true)
		draw_line(pos + Vector2(-3, -3), pos + Vector2(3, 2), Color("737e81"), 1.5, true)
	var zoom := maxf(get_global_transform_with_canvas().get_scale().x, 0.05)
	if zoom >= 0.7:
		var text := Texto.texto("m2_object_tag", [row.id])
		var width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_set_transform(pos + Vector2(-width / 2 / zoom, -12), 0, Vector2.ONE / zoom)
		draw_string_outline(ThemeDB.fallback_font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color("17372b"))
		draw_string(ThemeDB.fallback_font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("fff2d1"))
		draw_set_transform(Vector2.ZERO)

func _capsule_style(color: Color) -> StyleBoxFlat:
	if object_styles.has(color): return object_styles[color]
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	object_styles[color] = style
	return style


func _draw_board(board: Dictionary) -> void:
	var pos: Vector2 = board.pos
	# Easel legs and drop shadow around the physical board position.
	draw_rect(Rect2(pos - Vector2(18, 16), Vector2(38, 38)), Color(0.04, 0.12, 0.09, 0.48))
	draw_line(pos + Vector2(0, -22), pos + Vector2(0, -17), Color("6e5031"), 3.0, true)
	draw_line(pos + Vector2(-10, 17), pos + Vector2(-13, 22), Color("6e5031"), 2.5, true)
	draw_line(pos + Vector2(10, 17), pos + Vector2(13, 22), Color("6e5031"), 2.5, true)
	var frame := Rect2(pos - Vector2(18, 18), Vector2(36, 36))
	draw_rect(frame, Color("c89d66"))
	draw_rect(frame, Color("17372b"), false, 1.8)
	var canvas := Rect2(pos - Vector2(15, 15), Vector2(30, 30))
	draw_rect(canvas, Color("142b23"))
	draw_rect(canvas, Color("48685a"), false, 1.0)
	draw_line(Vector2(pos.x - 14, pos.y), Vector2(pos.x + 14, pos.y), Color(0.75, 0.86, 0.78, 0.12), 1.0)
	draw_line(Vector2(pos.x, pos.y - 14), Vector2(pos.x, pos.y + 14), Color(0.75, 0.86, 0.78, 0.12), 1.0)
	var plot := canvas.grow(-1.5)
	var active_strokes: Array = board.get("active_strokes", [])
	var drawn: Array = active_strokes
	if drawn.is_empty() and not board.get("artifacts", []).is_empty():
		drawn = board.artifacts.back().get("strokes", [])
	var projected := AtelierCanvas.project_board_strokes(drawn, board.get("reference_strokes", []), plot, false)
	for pts in projected.ref:
		draw_polyline(pts, Color(0.42, 0.84, 0.95, 0.35), 2.8, true)
		draw_polyline(pts, Color("7ad7f0"), 1.4, true)
		for p in pts:
			draw_circle(p, 1.2, Color("c4f4ff"))
	for pts in projected.strokes:
		draw_polyline(pts, Color("0b1914"), 3.0, true)
		draw_polyline(pts, Color("ffe596"), 1.8, true)
	if not active_strokes.is_empty() and projected.last_pt.is_finite():
		draw_circle(projected.last_pt, 2.4, Color("17372b"))
		draw_circle(projected.last_pt, 1.5, Color("ff9e64"))
	var zoom := maxf(get_global_transform_with_canvas().get_scale().x, 0.05)
	if zoom >= 0.65:
		var ref_shape := str(board.get("reference_shape", ""))
		var text := Texto.texto("m3_board_tag_ref", [int(board.id), Texto.texto("shape_" + ref_shape)]) if not ref_shape.is_empty() else Texto.texto("m3_board_tag", [int(board.id)])
		var width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_set_transform(pos + Vector2(-width / 2.0 / zoom, -22.0), 0.0, Vector2.ONE / zoom)
		draw_string_outline(ThemeDB.fallback_font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 4, Color("17372b"))
		draw_string(ThemeDB.fallback_font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("fff2d1"))
		draw_set_transform(Vector2.ZERO)

func _draw_board_preview(pos: Vector2) -> void:
	var frame := Rect2(pos - Vector2(16, 16), Vector2(32, 32))
	draw_rect(frame, Color(0.20, 0.34, 0.28, 0.45))
	draw_rect(frame, Color("f1dfab"), false, 1.5)
	if tool == "demo":
		var plot := frame.grow(-2.0)
		var projected := AtelierCanvas.project_board_strokes([], demo_preview_strokes, plot, false)
		for pts in projected.ref:
			draw_polyline(pts, Color("7ad7f0"), 1.6, true)


func social_marker(creature) -> Dictionary:
	var recent := false
	if creature.personality != null:
		for key in creature.personality.bonds:
			var tick: int = int(creature.personality.bonds[key].last_tick)
			if key != "player" and world.tick - tick <= 20 and world.tick >= tick:
				recent = true
	return {"recent": recent, "approaching": creature.last_action in ["seek_contact", "social_approach", "social_follow"]}

func _draw_social() -> void:
	var creature = world.creatures.get(selected_id)
	if creature == null:
		return
	var state := social_marker(creature)
	var zoom: float = maxf(get_global_transform_with_canvas().get_scale().x, 0.05)
	# Skip unreadable marks at extreme zoom; draw only for the selected body.
	if zoom < 0.15:
		return
	var radius: float = creature.genome.size + 7 / zoom
	if state.recent:
		for offset in [-3.0, 3.0]:
			var point: Vector2 = creature.pos + Vector2(offset, -radius * zoom - 5) / zoom
			draw_circle(point, 3 / zoom, Color("17372b"))
			draw_circle(point, 1.8 / zoom, Color("ffe7ac"))
	if state.approaching:
		var direction := Vector2.from_angle(creature.heading)
		var tip: Vector2 = creature.pos + direction * (radius + 8 / zoom)
		for side in [-1.0, 1.0]:
			var end: Vector2 = tip - direction.rotated(side * 0.6) * 8 / zoom
			draw_line(end, tip, Color("17372b"), 4 / zoom, true)
			draw_line(end, tip, Color("ffe7ac"), 2 / zoom, true)

func _label_rect(creature) -> Rect2:
	var zoom: float = maxf(get_global_transform_with_canvas().get_scale().x, 0.05)
	var font := ThemeDB.fallback_font
	var text := Texto.nome_criatura(creature.name)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x / zoom
	return Rect2(creature.pos + Vector2(-width * 0.5, creature.genome.size + 5 / zoom), Vector2(width, 16 / zoom))

func label_hit(creature, pos: Vector2) -> bool:
	return visible_names.has(creature.id) and visible_names[creature.id].has_point(pos)

func _show_name(creature) -> bool:
	return world.creatures.size() <= 30 or get_global_transform_with_canvas().get_scale().x >= 0.8 or creature.id in [selected_id, world.pet_id]

func _name_tag(creature) -> void:
	var zoom: float = maxf(get_global_transform_with_canvas().get_scale().x, 0.05)
	var rect := _label_rect(creature)
	var baseline := rect.position + Vector2(0, 12 / zoom)
	var color := Color("ffebad") if creature.id == selected_id else Color("edf4df")
	var text := Texto.nome_criatura(creature.name)
	# Render at a constant screen font size, including when the pet is enlarged.
	draw_set_transform(baseline, 0, Vector2.ONE / zoom)
	draw_string_outline(ThemeDB.fallback_font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color("17372b"))
	draw_string(ThemeDB.fallback_font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
	draw_set_transform(Vector2.ZERO)
	if zoom > 2.0: return
	# A indicação persiste dois segundos de simulação após bebida confirmada.
	for index in range(world.events.size() - 1, -1, -1):
		var event: Dictionary = world.events[index]
		if int(event.tick) < world.tick - 20:
			break
		if event.type == "drink" and event.creature_id == creature.id and float(event.get("hydration", 0)) > 0:
			var pos: Vector2 = creature.pos + Vector2(creature.genome.size + 6 / zoom, -10 / zoom)
			draw_circle(pos, 4 / zoom, Color("92e5ff"))
			draw_colored_polygon(PackedVector2Array([pos + Vector2(-3, -1) / zoom, pos + Vector2(0, -8) / zoom, pos + Vector2(3, -1) / zoom]), Color("92e5ff"))
			draw_arc(creature.pos, creature.genome.size + 3 / zoom, 0, TAU, 32, Color("92e5ff"), 1.5 / zoom, true)
			var badge := Texto.texto("drink_badge", [Texto.numero(event.hydration, 0)])
			var badge_pos: Vector2 = creature.pos + Vector2(-25 / zoom, -creature.genome.size - 16 / zoom)
			draw_string_outline(ThemeDB.fallback_font, badge_pos, badge, HORIZONTAL_ALIGNMENT_LEFT, -1, int(ceilf(11 / zoom)), int(ceilf(3 / zoom)), Color("17372b"))
			draw_string(ThemeDB.fallback_font, badge_pos, badge, HORIZONTAL_ALIGNMENT_LEFT, -1, int(ceilf(11 / zoom)), Color("adf0ff"))
			break

func _rock(pos: Vector2, radius: float) -> void:
	draw_set_transform(pos + Vector2(0, radius * 0.25), 0, Vector2(1, 0.68))
	draw_circle(Vector2.ZERO, radius, Color("3d5c4b"))
	draw_circle(Vector2(0, -radius * 0.20), radius * 0.89, Color("82958b"))
	draw_circle(Vector2(-radius * 0.15, -radius * 0.40), radius * 0.50, Color("a2aea0"))
	draw_set_transform(Vector2.ZERO)

func _texture(path: String) -> Texture2D:
	# Também funciona em checkout novo, antes da importação do editor.
	if ResourceLoader.exists(path, "Texture2D"):
		return load(path)
	return ImageTexture.create_from_image(Image.load_from_file(path))

func _tile(atlas: Texture2D, cell: Vector2i) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2(Vector2(cell * 17), Vector2(16, 16))
	return texture

func _creature(creature) -> void:
	# Stable species silhouette. Only size/hue originate in the genome; expression
	# uses physiology, action and affect, never cosmetic random emotion.
	var r: float = creature.genome.size
	var state: Dictionary = creature.expression_state()
	var fatigue: float = creature.personality.fatigue if creature.personality != null else 0.0
	var action: String = creature.last_action
	var sleeping := action == "rest" and fatigue > 0.35
	var eating := action == "eat"
	var drinking := action == "drink"
	var investigating := action.contains("object") or action.contains("investig")
	var moving := action in ["explore", "seek_food", "seek_water", "seek_contact", "social_follow", "approach_object", "investigate_object"]
	var phase := float(world.tick) * 0.65
	var bounce := absf(sin(phase)) * r * 0.07 if moving else sin(float(world.tick) * 0.16) * r * 0.015
	var dominant := Texto.mente_dominante(creature.mind_snapshot())
	var worried: bool = dominant.key in ["receio", "frustracao", "saturacao_social"] and float(dominant.value) > 0.15
	var happy: bool = dominant.key in ["entusiasmo", "satisfacao"] and float(dominant.value) > 0.12
	var color := Color.from_hsv(creature.genome.hue, 0.39, 0.91)
	var outline := color.darkened(0.48)
	var pos: Vector2 = creature.pos
	# Upright face remains readable in every travel direction.
	draw_set_transform(pos + Vector2(0, r * 0.8), 0, Vector2(1.25, 0.28))
	_pet_disc(Vector2.ZERO, r, Color(0.08, 0.20, 0.14, 0.23))
	draw_set_transform(pos + Vector2(0, -bounce), 0, Vector2(1.08, 0.82) if sleeping else Vector2.ONE)
	# Small curled tail, with a rounded tip: no tadpole taper.
	var tail := PackedVector2Array()
	for i in range(18):
		var angle := lerpf(1.4, -1.6, i / 17.0)
		tail.append(Vector2(r * 0.83, r * 0.16) + Vector2(cos(angle) * r * 0.36, sin(angle) * r * 0.29))
	draw_polyline(tail, outline, r * 0.3, true)
	draw_polyline(tail, color.darkened(0.1), r * 0.21, true)
	_pet_disc(tail[-1], r * 0.11, color)
	for side in [-1.0, 1.0]:
		var step := sin(phase + (0 if side < 0 else PI)) * r * 0.10 if moving else 0.0
		var foot := Vector2(side * r * 0.56, r * 0.80 + step)
		_pet_disc(foot, r * 0.28, outline)
		_pet_disc(foot + Vector2(0, -r * 0.04), r * 0.23, color.darkened(0.08))
		var ear := Vector2(side * r * 0.68, -r * (0.60 if worried or fatigue > 0.65 else 0.91))
		draw_set_transform(pos + Vector2(0, -bounce) + ear, side * (0.55 if worried else 0.28), Vector2(0.60, 1.0))
		_pet_disc(Vector2.ZERO, r * 0.43, outline)
		_pet_disc(Vector2.ZERO, r * 0.35, color)
		_pet_disc(Vector2(0, r * 0.035), r * 0.22, color.lerp(Color("f8cab3"), 0.58))
		draw_set_transform(pos + Vector2(0, -bounce), 0, Vector2(1.08, 0.82) if sleeping else Vector2.ONE)
	_pet_disc(Vector2.ZERO, r * 1.02, outline)
	_pet_disc(Vector2(0, -r * 0.03), r * 0.95, color)
	_pet_disc(Vector2(-r * 0.30, -r * 0.48), r * 0.30, color.lightened(0.11))
	# Cream muzzle and belly give an immediate, mammal-like face.
	draw_set_transform(pos + Vector2(0, r * 0.43 - bounce), 0, Vector2(1.0, 0.66))
	_pet_disc(Vector2.ZERO, r * 0.64, color.lerp(Color("fff1d6"), 0.7))
	draw_set_transform(pos + Vector2(0, -bounce), 0, Vector2.ONE)
	var blink := world.tick % 53 in [49, 50]
	var gaze := Vector2.from_angle(creature.heading) * r * 0.045
	for side in [-1.0, 1.0]:
		var eye := Vector2(side * r * 0.38, -r * 0.19)
		if sleeping or blink:
			draw_arc(eye + Vector2(0, -r * 0.10), r * 0.19, 0.2, PI - 0.2, 16, outline, r * 0.055, true)
		else:
			_pet_disc(eye, r * 0.23, Color("fff9e9"))
			_pet_disc(eye + gaze, r * (0.13 if investigating else 0.105), Color("283b35"))
			_pet_disc(eye + gaze + Vector2(-r * 0.035, -r * 0.042), r * 0.037, Color("ffffff"))
			if fatigue > 0.6 or worried:
				draw_line(eye + Vector2(-r * 0.2, -r * 0.07), eye + Vector2(r * 0.2, -r * 0.12), color.darkened(0.15), r * 0.09, true)
		var cheek := Vector2(side * r * 0.60, r * 0.15)
		_pet_disc(cheek, r * 0.13, color.lerp(Color("f1b8a2"), 0.65))
	# Nose, mouth and real ingestion gestures.
	_pet_disc(Vector2(0, r * 0.10), r * 0.09, outline)
	if eating:
		_pet_disc(Vector2(0, r * 0.31), r * (0.08 + 0.04 * absf(sin(phase))), outline)
		for side in [-1.0, 1.0]:
			_pet_disc(Vector2(side * r * 0.22, r * 0.65), r * 0.16, color.darkened(0.05))
	elif drinking:
		_pet_disc(Vector2(0, r * 0.32), r * 0.09, Color("3b6370"))
		draw_line(Vector2(0, r * 0.38), Vector2(0, r * 0.54), Color("f1aaa1"), r * 0.09, true)
	else:
		var mouth := PackedVector2Array()
		for i in range(13):
			var x := float(i) / 6.0 - 1.0
			mouth.append(Vector2(x * r * 0.22, r * (0.28 + (0.07 if happy else 0.035) * (1 - x * x) * (-1 if worried or creature.hunger > 0.7 else 1))))
		draw_polyline(mouth, outline, r * 0.045, true)
	draw_set_transform(Vector2.ZERO)
	if sleeping:
		for i in range(3):
			var bubble := pos + Vector2(r * (1.05 + i * 0.30), -r * (0.55 + i * 0.32))
			draw_arc(bubble, r * (0.08 + i * 0.025), 0, TAU, 16, Color("e3e6c8"), r * 0.04, true)
	if drinking or creature.thirst > 0.65:
		var drop := pos + Vector2(-r * 1.2, -r * 0.65)
		_pet_disc(drop, r * 0.11, Color("a1e0ef"))
		draw_colored_polygon(PackedVector2Array([drop + Vector2(-r * 0.10, 0), drop + Vector2(0, -r * 0.24), drop + Vector2(r * 0.10, 0)]), Color("a1e0ef"))

func _sensor(creature) -> void:
	var points := PackedVector2Array([creature.pos])
	var start: float = creature.heading - creature.genome.vision_fov * 0.5
	for i in range(49):
		var angle: float = start + creature.genome.vision_fov * i / 48.0
		points.append(creature.pos + Vector2.from_angle(angle) * creature.genome.vision_range)
	draw_colored_polygon(points, Color(0.94, 0.91, 0.63, 0.08))
	draw_polyline(points, Color(0.94, 0.91, 0.63, 0.25), 1, true)


func _draw_teaching() -> void:
	if not world.creatures.has(selected_id):
		return
	var active: Dictionary = teaching_snapshot.get("active", {})
	var point := teaching_target
	var assisted: bool = active.get("status") == "active" and active.get("assisted", false)
	if active.get("skill") == "ir_ate_local" and active.get("status") == "active":
		point = Vector2(active.target[0], active.target[1])
	if active.get("skill") == "buscar_agua" and active.get("status") == "active":
		# No omniscient water target. The overlay labels assistance at the body.
		point = Vector2.INF
	var zoom := maxf(get_global_transform_with_canvas().get_scale().x, 0.05)
	var creature = world.creatures[selected_id]
	var color := Color("ffe29a")
	if point.is_finite():
		draw_arc(point, 12 / zoom, 0, TAU, 32, color, 2 / zoom, true)
		draw_line(point - Vector2(17, 0) / zoom, point + Vector2(17, 0) / zoom, color, 2 / zoom)
		draw_line(point - Vector2(0, 17) / zoom, point + Vector2(0, 17) / zoom, color, 2 / zoom)
		draw_string(ThemeDB.fallback_font, point + Vector2(18, -14) / zoom, Texto.texto("te_marker"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 / zoom), color)
	if assisted:
		if point.is_finite():
			draw_dashed_line(creature.pos, point, color, 2 / zoom, 8 / zoom, true)
		draw_string(ThemeDB.fallback_font, creature.pos + Vector2(-30, -30) / zoom, Texto.texto("te_route"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 / zoom), color)

static func mind_color(key: String) -> Color:
	return {"frustracao": Color("f3ad78"), "receio": Color("cec1ef"), "solidao": Color("a9d7ee"), "saturacao_social": Color("d6b7e8"), "entusiasmo": Color("ffe4a2"), "satisfacao": Color("cce6aa"), "tranquilidade": Color("b9e4d1")}.get(key, Color("edf4df"))

func _draw_mind_marker() -> void:
	var creature = world.creatures.get(selected_id)
	if creature == null or creature.mind == null:
		return
	var dominant := Texto.mente_dominante(creature.mind_snapshot())
	var intensity: float = dominant.value
	var zoom: float = maxf(get_global_transform_with_canvas().get_scale().x, 0.05)
	if intensity <= 0.01 or zoom < 0.15:
		return
	var color := mind_color(str(dominant.key))
	color.a = 0.3 + intensity * 0.7
	# A single bounded indicator, proportional to the real dominant score.
	var radius: float = creature.genome.size + 10 / zoom
	draw_arc(creature.pos, radius, -PI * 0.95, -PI * 0.95 + PI * 0.9 * intensity, 24, color, (1 + intensity * 2) / zoom, true)
	var point: Vector2 = creature.pos + Vector2(0, -radius - 8 / zoom)
	var unit: float = (2 + intensity * 3) / zoom
	if dominant.key in ["solidao", "saturacao_social"]:
		var gap: float = unit * (1.2 if dominant.key == "solidao" else 2.4)
		for side in [-1, 1]:
			draw_circle(point + Vector2(side * gap, 0), unit, color)
	elif dominant.key in ["frustracao", "receio"]:
		draw_polyline(PackedVector2Array([point + Vector2(-unit, -unit), point + Vector2(unit, 0), point + Vector2(-unit, unit)]), color, 2 / zoom, true)
	else:
		draw_circle(point, unit, color)

func _draw_feeder(feeder: Dictionary) -> void:
	var pos: Vector2 = feeder.pos
	draw_style_box(_capsule_style(Color("2c4638")), Rect2(pos - Vector2(10, 16), Vector2(20, 28)))
	draw_style_box(_capsule_style(Color("e0d4aa")), Rect2(pos - Vector2(8, 14), Vector2(16, 23)))
	draw_rect(Rect2(pos - Vector2(5, 11), Vector2(10, 13)), Color("9dba9b"))
	draw_circle(pos + Vector2(0, 10), 8, Color("415c49"))
	draw_circle(pos + Vector2(0, 10), 5, Color("d4b987"))
	var enabled: bool = feeder.get("enabled", feeder.get("ativo", true))
	draw_circle(pos + Vector2(5, -12), 2, Color("bddf91") if enabled else Color("b67d68"))

func _pet_disc(pos: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(96):
		points.append(pos + Vector2.from_angle(TAU * i / 96.0) * radius)
	draw_colored_polygon(points, color)
