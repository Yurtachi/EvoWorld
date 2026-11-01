class_name Genome
extends RefCounted

const Data = preload("res://scripts/core/sim_data.gd")
const VERSION := 1
const BOUNDS := {
	"size": [6.0, 16.0], "speed": [18.0, 65.0],
	"vision_range": [45.0, 240.0], "vision_fov": [PI / 3.0, TAU],
	"metabolism": [0.5, 1.8], "hue": [0.0, 1.0]
}

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
		set(gene, clampf(snappedf(value, 0.000001), limits[0], limits[1]))

func to_dict() -> Dictionary:
	var result := {"version": VERSION, "id": id, "parents": parents.duplicate(), "generation": generation}
	for gene in BOUNDS:
		result[gene] = get(gene)
	return result

static func from_dict(data: Dictionary) -> Genome:
	if data.get("version") != VERSION or not Data.integer(data.get("id")) or not Data.integer(data.get("generation")):
		return null
	if not data.get("parents") is Array or data["parents"].size() > 2:
		return null
	for parent in data["parents"]:
		if not Data.integer(parent, 1):
			return null
	for gene in BOUNDS:
		if not Data.number(data.get(gene)) or float(data[gene]) < BOUNDS[gene][0] or float(data[gene]) > BOUNDS[gene][1]:
			return null
	var result = load("res://scripts/creature/genome.gd").new()
	result.id = int(data["id"])
	result.generation = int(data["generation"])
	for parent in data["parents"]:
		result.parents.append(int(parent))
	for gene in BOUNDS:
		result.set(gene, float(data[gene]))
	result.bound_genes()
	return result
