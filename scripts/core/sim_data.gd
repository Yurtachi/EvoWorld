class_name SimData
extends RefCounted
## Data-only validation shared by save readers. No resources or scripts are loaded.

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

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
