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
	for i in range(650):
		terrain.append(Vector2(decoration_rng.randf_range(8, world.size.x - 8),
			decoration_rng.randf_range(8, world.size.y - 8)))
	queue_redraw()

func _draw() -> void:
	if world == null:
		return
	draw_rect(Rect2(Vector2(-10, -10), world.size + Vector2(20, 20)), Color("233c32"))
	draw_rect(Rect2(Vector2.ZERO, world.size), Color("54745b"))
	# Leve textura CC0 de terreno; as entidades permanecem contrastantes.
	# Só rasteriza os ladrilhos visíveis, inclusive no limite máximo de expansão.
	var visible := get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()
	visible = visible.intersection(Rect2(Vector2.ZERO, world.size))
	# Ladrilhos subpixel são dispensados ao enquadrar expansões muito grandes.
	if get_global_transform_with_canvas().get_scale().x >= 0.08:
		for y in range(maxi(0, int(visible.position.y / 48) * 48), int(visible.end.y) + 1, 48):
			for x in range(maxi(0, int(visible.position.x / 48) * 48), int(visible.end.x) + 1, 48):
				draw_texture_rect(grass_texture, Rect2(x, y, minf(48, world.size.x - x), minf(48, world.size.y - y)), false, Color(0.8, 0.9, 0.7, 0.12))
	for point in terrain:
		draw_line(point, point + Vector2(2, -3), Color("648166"), 1.1, true)
	if get_global_transform_with_canvas().get_scale().x >= 0.08:
		for x in range(maxi(0, int(visible.position.x / 100) * 100), int(visible.end.x) + 1, 100):
			draw_line(Vector2(x, 0), Vector2(x, world.size.y), Color(0.84, 0.91, 0.76, 0.035))
		for y in range(maxi(0, int(visible.position.y / 100) * 100), int(visible.end.y) + 1, 100):
			draw_line(Vector2(0, y), Vector2(world.size.x, y), Color(0.84, 0.91, 0.76, 0.035))
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
	_draw_social()
	_draw_mind_marker()
	if show_pointer and tool != "select" and Rect2(Vector2.ZERO, world.size).has_point(pointer):
		var radius := 30.0 if tool == "water" else (24.0 if tool == "obstacle" else (13.0 if tool == "creature" else 7.0))
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
	draw_circle(pos + Vector2(3, 5), radius, Color(0.12, 0.22, 0.17, 0.32))
	draw_texture_rect(rock_texture, Rect2(pos - Vector2.ONE * radius * 1.2, Vector2.ONE * radius * 2.4), false)

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
	var radius: float = creature.genome.size
	var pos: Vector2 = creature.pos
	var state: Dictionary = creature.expression_state()
	var valence := float(state.valence)
	var arousal := float(state.arousal)
	var enabled: bool = creature.personality != null
	# Tick time freezes the sway when paused; no random or cosmetic emotion state.
	var sway := sin(float(world.tick) * (0.18 + arousal * 0.4) + creature.id) * arousal * 0.12 if enabled else 0.0
	var posture := Vector2(1.15 + valence * 0.12, 0.88 - valence * 0.08)
	var dominant := Texto.mente_dominante(creature.mind_snapshot()) if creature.mind != null else {"key": "", "value": 0.0}
	var intensity: float = dominant.value
	if dominant.key in ["frustracao", "receio", "saturacao_social"]:
		posture += Vector2(0.10, -0.12) * intensity
	elif dominant.key in ["entusiasmo", "satisfacao"]:
		posture += Vector2(-0.08, 0.12) * intensity
	var selected: bool = creature.id == selected_id
	if selected:
		draw_arc(pos, radius + 6, 0, TAU, 48, Color("f3e2aa"), 2, true)
	if creature.id == world.pet_id:
		draw_circle(pos + Vector2(0, -radius - 12), 2.4, Color("f3e2aa"))
	draw_set_transform(pos + Vector2(1.5, 3), creature.heading, Vector2(1.15, 0.88))
	draw_circle(Vector2.ZERO, radius + 1, Color(0.12, 0.22, 0.18, 0.4))
	draw_set_transform(pos, creature.heading + sway, posture)
	var color := Color.from_hsv(creature.genome.hue, 0.44, clampf(0.88 + valence * 0.16, 0.65, 1.0))
	color = color.lerp(mind_color(str(dominant.key)), intensity * 0.28)
	# A faster genome has a longer visible tail; body radius is the size gene.
	var tail: float = 4.0 + creature.genome.speed * 0.11
	draw_colored_polygon(PackedVector2Array([Vector2(-radius + 2, -radius * 0.45),
		Vector2(-radius - tail, 0), Vector2(-radius + 2, radius * 0.45)]), color.darkened(0.2))
	draw_circle(Vector2.ZERO, radius, color.darkened(0.12))
	draw_circle(Vector2(1, -1), radius * 0.82, color)
	draw_circle(Vector2(-radius * 0.26, -radius * 0.35), radius * 0.25, color.lightened(0.18))
	for side in [-1, 1]:
		var eye := Vector2(radius * 0.55, radius * 0.38 * side)
		draw_circle(eye, maxf(2.1, radius * 0.23), Color("f9f3db"))
		draw_circle(eye + Vector2(0.8, 0), maxf(1.0, radius * 0.11), Color("263d35"))
	draw_set_transform(Vector2.ZERO)
	if enabled and (selected or _show_name(creature)):
		var zoom := get_viewport().get_camera_2d().zoom.x
		var center := pos + Vector2(0, -radius - 21 / zoom)
		var tint := Color("f2d3a0") if valence < -0.25 else Color("c8e8cd")
		draw_circle(center, 5.5 / zoom, Color("193329"))
		var points := PackedVector2Array()
		for index in range(9):
			var x := float(index) / 8.0 * 2.0 - 1.0
			points.append(center + Vector2(x * 3.5, valence * (1.0 - x * x) * 4.0) / zoom)
		draw_polyline(points, tint, 1.4 / zoom, true)

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
