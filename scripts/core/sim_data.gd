class_name SimData
extends RefCounted
## Data-only validation shared by save readers. No resources or scripts are loaded.

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) <= 2147483647.0

static func integer(value: Variant, minimum: int = 0) -> bool:
	return number(value) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= 2147483647.0

static func vector(value: Variant) -> bool:
	return value is Array and value.size() == 2 and number(value[0]) and number(value[1])

static func integer_text(value: Variant) -> bool:
	if not value is String or not value.is_valid_int():
		return false
	var digits: String = value.trim_prefix("-")
	var limit := "9223372036854775808" if value.begins_with("-") else "9223372036854775807"
	if digits.length() > 19 or (digits.length() == 19 and digits > limit):
		return false
	return str(int(value)) == value

static func pack_vector(value: Vector2) -> Array:
	return [value.x, value.y]

static func unpack_vector(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

static func restore_precision(value: Variant) -> Variant:
	# Runtime decimal values use this same grid. Reapply it after JSON parsing,
	# which can choose the adjacent double for long decimal representations.
	if value is float:
		if value == floor(value) and absf(value) <= 2147483647.0:
			return int(value)
		return snappedf(value, 0.000001)
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(restore_precision(item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[key] = restore_precision(value[key])
		return result
	return value

static func json_data(value: Variant, depth: int = 0) -> bool:
	if depth > 12:
		return false
	if value == null or value is bool or value is String:
		return true
	if number(value):
		return true
	if value is Array:
		for item in value:
			if not json_data(item, depth + 1):
				return false
		return true
	if value is Dictionary:
		for key in value:
			if not key is String or not json_data(value[key], depth + 1):
				return false
		return true
	return false

## Closed event schema: consumers may safely access fields after load.
static func event(value: Variant, max_tick: int = 2147483647, next_id: int = 2147483647) -> bool:
	if not value is Dictionary or not value.get("type") is String:
		return false
	if not integer(value.get("tick")) or int(value["tick"]) > max_tick:
		return false
	if not integer(value.get("creature_id"), 1) or int(value["creature_id"]) >= next_id:
		return false
	match value["type"]:
		"spawn":
			return value.size() == 4 and value.get("name") is String and value["name"].length() <= 64
		"eat":
			return value.size() == 5 and integer(value.get("food_id"), 1) and int(value["food_id"]) < next_id and number(value.get("energy")) and float(value["energy"]) >= 0.0 and float(value["energy"]) <= 10000.0
		"death":
			return value.size() == 4 and value.get("reason") is String and value["reason"] == "starvation"
	return false
