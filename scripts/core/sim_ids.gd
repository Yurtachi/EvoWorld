class_name SimIds
extends RefCounted
## A shared monotonic namespace for creatures, genomes and food.

var next_id: int = 1

func take() -> int:
	var result := next_id
	next_id += 1
	return result
