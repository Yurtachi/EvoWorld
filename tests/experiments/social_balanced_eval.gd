extends SceneTree
const Protocol = preload("res://tests/experiments/social_balanced_protocol.gd")
const PREREG := "res://tests/experiments/social_balanced_preregistro.md"
const CHECKPOINT := "res://reports/M0_social_checkpoint.json"
const DEV := "res://reports/M0_social_dev.json"
const HOLDOUT := "res://reports/M0_social_holdout.json"
const OPENED := "res://reports/M0_social_holdout_opened"
const SOURCES := [PREREG, "res://tests/experiments/social_balanced_eval.gd",
	"res://tests/experiments/social_balanced_protocol.gd", "res://tests/experiments/social_fixture.gd"]

func write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write ", path)
		return false
	file.store_string(JSON.stringify(data, "\t", true, true))
	file.close()
	return true

func hashes() -> Dictionary:
	var out: Dictionary = {}
	for path in SOURCES:
		out[path] = FileAccess.get_sha256(path)
	return out

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or args[0] not in ["--dev", "--holdout"]:
		printerr("Use exactly --dev or --holdout; no implicit HOLDOUT")
		quit(1)
		return
	if DirAccess.dir_exists_absolute(OPENED) or FileAccess.file_exists(HOLDOUT):
		printerr("HOLDOUT already opened; refusing any new experiment run")
		quit(1)
		return
	if args[0] == "--dev":
		var checkpoint := Protocol.train()
		checkpoint.sources = hashes()
		checkpoint.preregister_commit = "33bc81efd77dc95e7afa4161a7a1830ad46abdbd"
		if not write_json(CHECKPOINT, checkpoint):
			quit(1)
			return
		var dev := Protocol.evaluate(Protocol.DEV_START, 8, checkpoint)
		dev.checkpoint_sha256 = FileAccess.get_sha256(CHECKPOINT)
		dev.sources = hashes()
		print("TRAIN episodes=", checkpoint.train.size(), " q=", checkpoint.q,
			" prior_counts=", checkpoint.prior_counts, " prior=", checkpoint.prior)
		print("DEV status=", dev.status, " summary=", dev.summary, " comparisons=", dev.comparisons)
		quit(0 if write_json(DEV, dev) else 1)
		return
	if not FileAccess.file_exists(CHECKPOINT) or not FileAccess.file_exists(DEV):
		printerr("Run TRAIN/DEV before opening HOLDOUT")
		quit(1)
		return
	var checkpoint: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CHECKPOINT))
	var dev: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DEV))
	if checkpoint.sources != hashes() or dev.sources != hashes() or dev.checkpoint_sha256 != FileAccess.get_sha256(CHECKPOINT):
		printerr("Frozen sources/checkpoint differ from TRAIN/DEV; HOLDOUT remains closed")
		quit(1)
		return
	# Atomic directory creation is an exclusive local opening guard, including crashes.
	if DirAccess.make_dir_absolute(OPENED) != OK:
		printerr("Cannot create exclusive HOLDOUT marker")
		quit(1)
		return
	var receipt := {"opened_utc": Time.get_datetime_string_from_system(true),
		"checkpoint_sha256": FileAccess.get_sha256(CHECKPOINT), "sources": hashes()}
	if not write_json(OPENED + "/receipt.json", receipt):
		quit(1)
		return
	var result := Protocol.evaluate(Protocol.HOLDOUT_START, 20, checkpoint)
	result.provenance = receipt
	result.preregister_commit = checkpoint.preregister_commit
	print("HOLDOUT status=", result.status, " summary=", result.summary, " comparisons=", result.comparisons)
	quit(0 if write_json(HOLDOUT, result) else 1)
