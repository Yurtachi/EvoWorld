extends RefCounted
## Data-only checkpoints. Validated temporary files replace files in the same
## directory; a corrupt primary never rotates over a known-good backup.
const World = preload("res://scripts/world/sim_world.gd")
const Data = preload("res://scripts/core/sim_data.gd")
const MAX_BYTES := 32 * 1024 * 1024
# Envelope v2 compresses losslessly before the disk limit becomes a problem.
# The world schema remains v7; v1 envelopes remain readable and writable.
const COMPRESS_AT_BYTES := 1024 * 1024
# E5 measured ~0.8 MB per save: 8 MiB allows ~10x growth, without allocating
# 128 MiB for an untrusted gzip. Ratio uses the on-disk envelope byte length.
const MAX_PAYLOAD_BYTES := 8 * 1024 * 1024
const MAX_EXPANSION_RATIO := 64
var directory: String

func _init(save_directory: String = "user://saves") -> void:
	directory = save_directory

func save_world(world: World, slot: String = "world", metadata: Dictionary = {}) -> Dictionary:
	if not _valid_slot(slot):
		return _error("Invalid checkpoint name.")
	if not Data.json_data(metadata):
		return _error("Invalid checkpoint metadata.")
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return _error("Cannot create save directory: %s" % error_string(error))
	var path := _path(slot)
	var payload := JSON.stringify({"world": world.to_dict(), "metadata": metadata}, "", true, true)
	var encoded := _encode(payload)
	if not encoded.ok:
		return encoded
	var written := _write(path + ".tmp", encoded.text)
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
		# Restore through another validated temporary file, keeping the backup
		# untouched even when repair fails (e.g. a read-only save directory).
		var repair_error := DirAccess.copy_absolute(path + ".bak", path + ".recover.tmp")
		if repair_error == OK:
			if _read(path + ".recover.tmp").ok:
				repair_error = DirAccess.rename_absolute(path + ".recover.tmp", path)
			else:
				repair_error = ERR_FILE_CORRUPT
		backup["repair_ok"] = repair_error == OK
		backup["path"] = path if repair_error == OK else path + ".bak"
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
	var file_bytes := file.get_length()
	if file_bytes > MAX_BYTES:
		file.close()
		return _error("File exceeds the 32 MiB limit.")
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return _error("Invalid checkpoint JSON.")
	var envelope: Dictionary = parser.data
	if envelope.get("format") != "evoworld-checkpoint" or not Data.integer(envelope.get("version"), 1) or int(envelope.version) not in [1, 2]:
		return _error("Unsupported checkpoint format.")
	if not envelope.get("payload") is String or not envelope.get("sha256") is String:
		return _error("Missing checkpoint payload or checksum.")
	var payload: String = envelope.payload
	if int(envelope.version) == 1 and payload.to_utf8_buffer().size() > MAX_PAYLOAD_BYTES:
		return _error("Checkpoint payload exceeds the 8 MiB decoded limit.")
	if int(envelope.version) == 2:
		if envelope.get("encoding") != "gzip-base64" or not Data.integer(envelope.get("uncompressed_bytes"), 1) or int(envelope.uncompressed_bytes) > MAX_PAYLOAD_BYTES or not envelope.get("compressed_sha256") is String:
			return _error("Invalid compressed checkpoint header.")
		# Must run before base64 decoding or calling the gzip allocator, even
		# when both checksums and the gzip trailer are completely valid.
		if int(envelope.uncompressed_bytes) > MAX_EXPANSION_RATIO * file_bytes:
			return _error("Compressed checkpoint exceeds the 64:1 expansion limit.")
		# Check canonical base64 and compressed integrity before decompression.
		if payload.length() % 4 != 0:
			return _error("Invalid compressed checkpoint encoding.")
		var b64 := RegEx.new()
		b64.compile("^[A-Za-z0-9+/]*={0,2}$")
		if b64.search(payload) == null:
			return _error("Invalid compressed checkpoint encoding.")
		var compressed := Marshalls.base64_to_raw(payload)
		if compressed.is_empty() or Marshalls.raw_to_base64(compressed) != payload or payload.sha256_text() != envelope.compressed_sha256:
			return _error("Compressed checkpoint checksum does not match.")
		if compressed.size() < 18 or compressed[0] != 0x1f or compressed[1] != 0x8b or compressed[2] != 8 or compressed.decode_u32(compressed.size() - 4) != int(envelope.uncompressed_bytes):
			return _error("Invalid compressed checkpoint size or header.")
		var expanded := _decompress(compressed, int(envelope.uncompressed_bytes))
		if expanded.size() != int(envelope.uncompressed_bytes):
			return _error("Compressed checkpoint exceeds its declared size or is corrupt.")
		payload = expanded.get_string_from_utf8()
	if payload.sha256_text() != envelope.sha256:
		return _error("Checkpoint checksum does not match.")
	if parser.parse(payload) != OK or not parser.data is Dictionary:
		return _error("Invalid checkpoint payload.")
	var data: Dictionary = parser.data
	if not data.get("world") is Dictionary or not data.get("metadata") is Dictionary:
		return _error("Missing world or metadata.")
	if not Data.json_data(data.metadata):
		return _error("Invalid checkpoint metadata.")
	var world := World.from_dict(data.world)
	if world == null:
		return _error("World data failed schema validation.")
	return {"ok": true, "world": world, "metadata": data.metadata, "path": path}

func _decompress(compressed: PackedByteArray, declared_bytes: int) -> PackedByteArray:
	return compressed.decompress_dynamic(declared_bytes, FileAccess.COMPRESSION_GZIP)

func _encode(payload: String, force_compression: bool = false) -> Dictionary:
	var bytes := payload.to_utf8_buffer()
	if bytes.size() > MAX_PAYLOAD_BYTES:
		return _error("Checkpoint payload exceeds the 8 MiB decoded limit.")
	var envelope := {"format": "evoworld-checkpoint", "version": 1,
		"sha256": payload.sha256_text(), "payload": payload}
	if force_compression or bytes.size() >= COMPRESS_AT_BYTES:
		var compressed := bytes.compress(FileAccess.COMPRESSION_GZIP)
		if compressed.is_empty():
			return _error("Cannot compress checkpoint.")
		envelope.merge({"version": 2, "encoding": "gzip-base64", "uncompressed_bytes": bytes.size(),
			"compressed_sha256": Marshalls.raw_to_base64(compressed).sha256_text(), "payload": Marshalls.raw_to_base64(compressed)}, true)
	var text := JSON.stringify(envelope)
	if int(envelope.version) == 2 and bytes.size() > MAX_EXPANSION_RATIO * text.to_utf8_buffer().size():
		# Highly repetitive valid saves can use the uncompressed v1 envelope;
		# never produce a checkpoint that our own reader would reject.
		envelope = {"format": "evoworld-checkpoint", "version": 1,
			"sha256": payload.sha256_text(), "payload": payload}
		text = JSON.stringify(envelope)
	if text.to_utf8_buffer().size() > MAX_BYTES:
		return _error("Checkpoint exceeds the 32 MiB limit.")
	return {"ok": true, "text": text}

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
