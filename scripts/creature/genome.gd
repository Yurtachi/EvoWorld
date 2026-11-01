class_name Genome
extends RefCounted

const Data = preload("res://scripts/core/sim_data.gd")
const VERSION := 1
const TEMPERAMENT_KEYS := ["curiosity", "caution", "sociability", "impulsivity"]
const BOUNDS := {
	"size": [6.0, 16.0], "speed": [18.0, 65.0],
	"vision_range": [45.0, 240.0], "vision_fov": [PI / 3.0, TAU],
	"metabolism": [0.5, 1.8], "hue": [0.0, 1.0]
}

## Optional inherited predispositions; empty in legacy worlds (no RNG changes).
var temperament: Dictionary = {}

var id: int = 0
var parents: Array = []
var generation: int = 0
var size: float = 10.0
var speed: float = 40.0
var vision_range: float = 160.0
var vision_fov: float = snappedf(PI * 1.5, 0.000001)
var metabolism: float = 1.0
var hue: float = 0.35

func bound_genes() -> void:
	for gene in BOUNDS:
		var limits: Array = BOUNDS[gene]
		var value := float(get(gene))
		if not is_finite(value):
			value = float(limits[0])
		# Keep values on the save precision grid even at irrational FOV bounds.
		var low := ceilf(float(limits[0]) * 1000000.0) / 1000000.0
		var high := floorf(float(limits[1]) * 1000000.0) / 1000000.0
		set(gene, clampf(snappedf(value, 0.000001), low, high))

func to_dict() -> Dictionary:
	var result := {"version": VERSION, "id": id, "parents": parents.duplicate(), "generation": generation}
	for gene in BOUNDS:
		result[gene] = get(gene)
	if not temperament.is_empty():
		result["temperament"] = temperament.duplicate()
	return result

static func valid_temperament(value: Variant) -> bool:
	if not value is Dictionary or value.size() != TEMPERAMENT_KEYS.size():
		return false
	for key in TEMPERAMENT_KEYS:
		if not Data.number(value.get(key)) or float(value[key]) < 0.0 or float(value[key]) > 1.0:
			return false
	return true

static func from_dict(data: Dictionary) -> Genome:
	if not Data.integer(data.get("version")) or int(data["version"]) != VERSION or not Data.integer(data.get("id")) or not Data.integer(data.get("generation")):
		return null
	if not data.get("parents") is Array or data["parents"].size() > 2:
		return null
	for parent in data["parents"]:
		if not Data.integer(parent, 1):
			return null
	for gene in BOUNDS:
		if not Data.number(data.get(gene)) or float(data[gene]) < BOUNDS[gene][0] or float(data[gene]) > BOUNDS[gene][1]:
			return null
	if data.has("temperament") and not valid_temperament(data["temperament"]):
		return null
	var result = load("res://scripts/creature/genome.gd").new()
	result.temperament = Data.restore_precision(data.get("temperament", {}))
	result.id = int(data["id"])
	result.generation = int(data["generation"])
	for parent in data["parents"]:
		result.parents.append(int(parent))
	for gene in BOUNDS:
		result.set(gene, float(data[gene]))
	result.bound_genes()
	return result
