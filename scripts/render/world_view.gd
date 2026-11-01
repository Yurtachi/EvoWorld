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

func set_world(value: World) -> void:
	world = value
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
	if show_pointer and tool != "select" and Rect2(Vector2.ZERO, world.size).has_point(pointer):
		var radius := 24.0 if tool == "obstacle" else (13.0 if tool == "creature" else 7.0)
		draw_circle(pointer, radius, Color(0.96, 0.91, 0.68, 0.18))
		draw_arc(pointer, radius, 0, TAU, 40, Color("f1dfab"), 1.5, true)

func _food(pos: Vector2) -> void:
	draw_circle(pos + Vector2(1, 3), 5.5, Color(0.12, 0.23, 0.17, 0.26))
	draw_line(pos, pos + Vector2(1, -7), Color("a9c37a"), 1.6, true)
	draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -3), pos + Vector2(-7, -7),
		pos + Vector2(-5, -1)]), Color("bbce83"))
	draw_circle(pos + Vector2(2, -1), 3.4, Color("e3b86a"))
	draw_circle(pos + Vector2(3, -2), 1.0, Color("fae2a3"))

func _rock(pos: Vector2, radius: float) -> void:
	draw_circle(pos + Vector2(3, 5), radius, Color(0.12, 0.22, 0.17, 0.32))
	var points := PackedVector2Array()
	for i in range(7):
		var angle := TAU * i / 7.0
		points.append(pos + Vector2.from_angle(angle) * radius * (0.9 + 0.1 * sin(i * 4.0)))
	draw_colored_polygon(points, Color("89988a"))
	draw_colored_polygon(PackedVector2Array([points[3], points[4], points[5],
		pos + Vector2(radius * 0.25, -radius * 0.1)]), Color("a4afa0"))
	draw_line(points[1], points[2], Color("697f70"), 2, true)

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
