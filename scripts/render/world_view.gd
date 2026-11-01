extends Node2D
## Presentation only: every organism, resource and rock comes from SimWorld.
const World = preload("res://scripts/world/sim_world.gd")
var world: World
var selected_id := -1
var tool := "select"
var pointer := Vector2.ZERO
var show_pointer := false
var show_sensors := false
var terrain := PackedVector2Array()
var command_target := Vector2.ZERO
var grass_texture: Texture2D
var food_texture: Texture2D
var rock_texture: Texture2D

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
	for y in range(0, int(world.size.y), 48):
		for x in range(0, int(world.size.x), 48):
			draw_texture_rect(grass_texture, Rect2(x, y, minf(48, world.size.x - x), minf(48, world.size.y - y)), false, Color(0.8, 0.9, 0.7, 0.12))
	for point in terrain:
		draw_line(point, point + Vector2(2, -3), Color("648166"), 1.1, true)
	for x in range(0, int(world.size.x), 100):
		draw_line(Vector2(x, 0), Vector2(x, world.size.y), Color(0.84, 0.91, 0.76, 0.035))
	for y in range(0, int(world.size.y), 100):
		draw_line(Vector2(0, y), Vector2(world.size.x, y), Color(0.84, 0.91, 0.76, 0.035))
	for obstacle in world.obstacles:
		_rock(obstacle.pos, obstacle.radius)
	for food in world.foods:
		_food(food.pos)
	for creature in world.creatures.values():
		if creature.id == selected_id and show_sensors:
			_sensor(creature)
		_creature(creature)
	if Rect2(Vector2.ZERO, world.size).has_point(command_target):
		draw_arc(command_target, 10, 0, TAU, 24, Color("8fd5dd"), 1.5, true)
		draw_line(command_target - Vector2(14, 0), command_target + Vector2(14, 0), Color("8fd5dd"), 1, true)
		draw_line(command_target - Vector2(0, 14), command_target + Vector2(0, 14), Color("8fd5dd"), 1, true)
	if show_pointer and tool != "select" and Rect2(Vector2.ZERO, world.size).has_point(pointer):
		var radius := 24.0 if tool == "obstacle" else (13.0 if tool == "creature" else 7.0)
		draw_circle(pointer, radius, Color(0.96, 0.91, 0.68, 0.18))
		draw_arc(pointer, radius, 0, TAU, 40, Color("f1dfab"), 1.5, true)

func _food(pos: Vector2) -> void:
	draw_circle(pos + Vector2(1, 3), 5.5, Color(0.12, 0.23, 0.17, 0.26))
	draw_circle(pos, 6, Color(0.96, 0.89, 0.6, 0.3))
	draw_texture_rect(food_texture, Rect2(pos - Vector2(9, 9), Vector2(18, 18)), false, Color("e5f1ab"))

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
	var selected: bool = creature.id == selected_id
	if selected:
		draw_arc(pos, radius + 6, 0, TAU, 48, Color("f3e2aa"), 2, true)
	if creature.id == world.pet_id:
		draw_circle(pos + Vector2(0, -radius - 12), 2.4, Color("f3e2aa"))
	draw_set_transform(pos + Vector2(1.5, 3), creature.heading, Vector2(1.15, 0.88))
	draw_circle(Vector2.ZERO, radius + 1, Color(0.12, 0.22, 0.18, 0.4))
	draw_set_transform(pos, creature.heading, Vector2(1.15, 0.88))
	var color := Color.from_hsv(creature.genome.hue, 0.44, 0.88)
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

func _sensor(creature) -> void:
	var points := PackedVector2Array([creature.pos])
	var start: float = creature.heading - creature.genome.vision_fov * 0.5
	for i in range(49):
		var angle: float = start + creature.genome.vision_fov * i / 48.0
		points.append(creature.pos + Vector2.from_angle(angle) * creature.genome.vision_range)
	draw_colored_polygon(points, Color(0.94, 0.91, 0.63, 0.08))
	draw_polyline(points, Color(0.94, 0.91, 0.63, 0.25), 1, true)
