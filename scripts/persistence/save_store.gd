extends RefCounted
## Data-only checkpoints. Validated temporary files replace files in the same
## directory; a corrupt primary never rotates over a known-good backup.
const World = preload("res://scripts/world/sim_world.gd")
const MAX_BYTES := 32 * 1024 * 1024
var directory: String

func _init(save_directory: String = "user://saves") -> void:
	directory = save_directory

func save_world(world: World, slot: String = "world", metadata: Dictionary = {}) -> Dictionary:
	if not _valid_slot(slot):
		return _error("Invalid checkpoint name.")
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return _error("Cannot create save directory: %s" % error_string(error))
	var path := _path(slot)
	var payload := JSON.stringify({"world": world.to_dict(), "metadata": metadata}, "", true, true)
	var envelope := JSON.stringify({"format": "evoworld-checkpoint", "version": 1,
		"sha256": payload.sha256_text(), "payload": payload})
	if envelope.to_utf8_buffer().size() > MAX_BYTES:
		return _error("Checkpoint exceeds the 32 MiB limit.")
	var written := _write(path + ".tmp", envelope)
	if not written.ok:
		return written
	if not _read(path + ".tmp").ok:
		return _error("Temporary checkpoint failed validation; previous save preserved.")
	if _read(path).ok:
		error = DirAccess.copy_absolute(path, path + ".bak.tmp")
		if error == OK:
			error = DirAccess.rename_absolute(path + ".bak.tmp", path + ".bak")
		if error != OK:
			return _error("Cannot preserve backup: %s" % error_string(error))
	error = DirAccess.rename_absolute(path + ".tmp", path)
	if error != OK:
		return _error("Cannot replace checkpoint: %s" % error_string(error))
	return {"ok": true, "path": path, "message": "Checkpoint saved."}

func load_world(slot: String = "world") -> Dictionary:
	if not _valid_slot(slot):
		return _error("Invalid checkpoint name.")
	var path := _path(slot)
	var primary := _read(path)
	if primary.ok:
		primary["recovered"] = false
		primary["message"] = "Checkpoint loaded."
		return primary
	var backup := _read(path + ".bak")
	if backup.ok:
		backup["recovered"] = true
		backup["message"] = "Primary unavailable or invalid; recovered the previous checkpoint from backup."
		return backup
	return _error("No valid checkpoint or backup. %s" % primary.message)

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _error("File does not exist.")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error("File cannot be opened.")
	if file.get_length() > MAX_BYTES:
		file.close()
		return _error("File exceeds the 32 MiB limit.")
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return _error("Invalid checkpoint JSON.")
	var envelope: Dictionary = parser.data
	if envelope.get("format") != "evoworld-checkpoint" or envelope.get("version") != 1:
		return _error("Unsupported checkpoint format.")
	if not envelope.get("payload") is String or not envelope.get("sha256") is String:
		return _error("Missing checkpoint payload or checksum.")
	var payload: String = envelope.payload
	if payload.sha256_text() != envelope.sha256:
		return _error("Checkpoint checksum does not match.")
	if parser.parse(payload) != OK or not parser.data is Dictionary:
		return _error("Invalid checkpoint payload.")
	var data: Dictionary = parser.data
	if not data.get("world") is Dictionary or not data.get("metadata") is Dictionary:
		return _error("Missing world or metadata.")
	var world := World.from_dict(data.world)
	if world == null:
		return _error("World data failed schema validation.")
	return {"ok": true, "world": world, "metadata": data.metadata, "path": path}

func _write(path: String, text: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _error("Cannot open temporary checkpoint: %s" % error_string(FileAccess.get_open_error()))
	file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return _error("Cannot write checkpoint: %s" % error_string(error))
	return {"ok": true}

func _path(slot: String) -> String:
	return directory.path_join(slot + ".json")

func _valid_slot(slot: String) -> bool:
	return not slot.is_empty() and slot.length() <= 64 and slot.is_valid_identifier()

func _error(message: String) -> Dictionary:
	return {"ok": false, "message": message}
