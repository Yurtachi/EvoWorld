extends RefCounted
const World = preload("res://scripts/world/sim_world.gd")
const Store = preload("res://scripts/persistence/save_store.gd")

func run() -> Array:
	var errors: Array = []
	var folder := "user://saves/test_%s_%s" % [OS.get_process_id(), Time.get_ticks_usec()]
	var store := Store.new(folder)
	var world := World.new(7421, {"creature_count": 4})
	world.creatures[world.pet_id].name = "Fern"
	for i in range(55):
		world.step()
	var snapshot := world.to_dict()
	var saved := store.save_world(world, "roundtrip", {"name": "Fern garden"})
	_expect(saved.ok, "first save succeeds", errors)
	var loaded := store.load_world("roundtrip")
	_expect(loaded.ok, "saved world loads", errors)
	if loaded.ok:
		_expect(loaded.world.to_dict() == snapshot, "world round trip is exact", errors)
		_expect(loaded.metadata.get("name") == "Fern garden", "world name survives", errors)
		for i in range(30):
			world.step()
			loaded.world.step()
		_expect(world.to_dict() == loaded.world.to_dict(), "resumed RNG and steps match", errors)
	_expect(store.save_world(world, "roundtrip").ok, "atomic replacement succeeds", errors)
	_expect(FileAccess.file_exists(folder.path_join("roundtrip.json.bak")), "backup exists", errors)
	var interrupted := FileAccess.open(folder.path_join("roundtrip.json.tmp"), FileAccess.WRITE)
	interrupted.store_string("interrupted write")
	interrupted.close()
	loaded = store.load_world("roundtrip")
	_expect(loaded.ok and not loaded.get("recovered", true), "interrupted temp never masks valid primary", errors)
	var primary := FileAccess.open(folder.path_join("roundtrip.json"), FileAccess.READ)
	var envelope: Dictionary = JSON.parse_string(primary.get_as_text())
	primary.close()
	envelope.sha256 = "tampered"
	var changed := FileAccess.open(folder.path_join("roundtrip.json"), FileAccess.WRITE)
	changed.store_string(JSON.stringify(envelope))
	changed.close()
	loaded = store.load_world("roundtrip")
	_expect(loaded.ok and loaded.get("recovered", false), "checksum mismatch recovers backup", errors)
	_expect(store.save_world(world, "roundtrip").ok, "save repairs checksum-corrupt primary", errors)
	# Even a correctly checksummed payload must pass the actual SimWorld schema.
	var invalid_payload := JSON.stringify({"world": {"version": 999}, "metadata": {}})
	envelope.payload = invalid_payload
	envelope.sha256 = invalid_payload.sha256_text()
	changed = FileAccess.open(folder.path_join("roundtrip.json"), FileAccess.WRITE)
	changed.store_string(JSON.stringify(envelope))
	changed.close()
	loaded = store.load_world("roundtrip")
	_expect(loaded.ok and loaded.get("recovered", false), "invalid world schema recovers backup", errors)
	var corrupt := FileAccess.open(folder.path_join("roundtrip.json"), FileAccess.WRITE)
	corrupt.store_string("{interrupted checkpoint")
	corrupt.close()
	loaded = store.load_world("roundtrip")
	_expect(loaded.ok and loaded.get("recovered", false), "corrupt primary recovers backup", errors)
	if loaded.ok:
		_expect(loaded.world.to_dict() == snapshot, "backup contains previous valid checkpoint", errors)
	_expect(store.save_world(world, "roundtrip").ok, "save after corruption succeeds", errors)
	corrupt = FileAccess.open(folder.path_join("roundtrip.json"), FileAccess.WRITE)
	corrupt.store_string("[]")
	corrupt.close()
	loaded = store.load_world("roundtrip")
	_expect(loaded.ok and loaded.get("recovered", false), "valid backup survives corrupt-primary save", errors)
	if loaded.ok:
		_expect(loaded.world.to_dict() == snapshot, "recovery preserves known-good backup", errors)
	_expect(not store.save_world(world, "../escape").ok, "path traversal rejected", errors)
	_expect(not store.load_world("missing").ok, "missing checkpoint returns error", errors)
	DirAccess.remove_absolute(folder.path_join("roundtrip.json.bak"))
	_expect(not store.load_world("roundtrip").ok, "both-invalid returns error", errors)
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		var path := folder.path_join("roundtrip.json" + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(folder)
	return errors

func _expect(value: bool, message: String, errors: Array) -> void:
	if not value:
		errors.append(message)
