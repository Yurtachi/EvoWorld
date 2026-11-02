extends RefCounted
const World = preload("res://scripts/world/sim_world.gd")
const Store = preload("res://scripts/persistence/save_store.gd")
const Main = preload("res://scripts/ui/main.gd")
const Commands = preload("res://scripts/communication/comandos.gd")

class ObservedStore extends Store:
	var decompressed := false
	func _decompress(compressed: PackedByteArray, declared_bytes: int) -> PackedByteArray:
		decompressed = true
		return super._decompress(compressed, declared_bytes)

class FaultStore extends Store:
	var mode := "truncated"
	func _write(path: String, contents: String) -> Dictionary:
		var result := super._write(path, contents.left(contents.length() / 2))
		return {"ok": false, "message": "Injected disk failure"} if mode == "error" else result

func run() -> Array:
	var failures: Array = []
	_hostile_versions(failures)
	_nested_mutation_fuzz(failures)
	_migration_roundtrips(failures)
	_bound_trait_roundtrip(failures)
	_atomic_failures(failures)
	_compressed_envelopes(failures)
	_capture_flags(failures)
	_hostile_order_ttl(failures)
	_new_world_generations(failures)
	_hostile_types_regression(failures)
	return failures

func _check(ok: bool, message: String, failures: Array) -> void:
	if not ok: failures.append(message)

func _snapshot(world) -> String:
	return JSON.stringify(world.to_dict(), "", true, true)

func _fixture(version: int) -> Dictionary:
	var source := version if version in [1, 3, 4, 5] else (3 if version == 2 else 5)
	if version == 7:
		return World.new_world(715, {"creature_count": 2}).to_dict()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/world_v%d.json" % source))
	data.save_version = version
	if version == 2:
		data.erase("signal_log")
		data.erase("commands")
	return data

func _reject(data: Dictionary, version: int, label: String, failures: Array) -> void:
	_check(World.from_dict(data) == null, "v%d aceitou %s" % [version, label], failures)

func _hostile_versions(f: Array) -> void:
	var cases := 0
	for version in range(1, 8):
		var good := _fixture(version)
		_check(World.from_dict(good) != null, "fixture base v%d invalido" % version, f)
		for field in ["tick", "next_id", "pet_id", "world_seed", "size", "rng_state", "config", "creatures", "foods", "obstacles", "events"]:
			var missing := good.duplicate(true)
			missing.erase(field)
			_reject(missing, version, "campo ausente " + field, f)
			cases += 1
			for wrong in [null, true, "hostil", [], {"evil": 1}]:
				if typeof(wrong) == typeof(good[field]): continue
				var bad := good.duplicate(true)
				bad[field] = wrong
				_reject(bad, version, "tipo errado " + field, f)
				cases += 1
		for scalar in [NAN, INF, -INF]:
			for field in ["energy", "heading", "age", "max_energy"]:
				var bad := good.duplicate(true)
				bad.creatures[0][field] = scalar
				_reject(bad, version, "NaN/inf " + field, f)
				cases += 1
		var bad := good.duplicate(true)
		bad.creatures.append(bad.creatures[0].duplicate(true))
		_reject(bad, version, "ID de criatura duplicado", f)
		bad = good.duplicate(true)
		bad.foods[0].id = bad.creatures[0].id
		_reject(bad, version, "ID compartilhado alimento/corpo", f)
		for position in [[-99999, 0], [999999, 999999], [NAN, 5], [INF, 5], [0], "0,0"]:
			for field in ["creatures", "foods", "obstacles"]:
				bad = good.duplicate(true)
				bad[field][0].pos = position
				_reject(bad, version, "vetor invalido " + field, f)
				cases += 1
		bad = good.duplicate(true)
		bad.creatures[0].memory = []
		bad.creatures[0].memory.resize(100001)
		_reject(bad, version, "memoria enorme", f)
		bad = good.duplicate(true)
		bad.creatures[0].personality = {"episodes": []}
		bad.creatures[0].personality.episodes.resize(100001)
		_reject(bad, version, "episodios enormes", f)
		bad = good.duplicate(true)
		bad.genealogy = []
		bad.genealogy.resize(100001)
		_reject(bad, version, "genealogia enorme antes da migracao", f)
		for log_value in [[null], [{"type": "eat"}], [{"type": "spawn", "tick": 0, "creature_id": 1, "name": []}]]:
			bad = good.duplicate(true)
			bad.events = log_value
			_reject(bad, version, "eventos malformados", f)
		if version >= 3:
			for log_value in [null, {}, [null], [{"tick": 0, "emitter": 1}]]:
				bad = good.duplicate(true)
				bad.signal_log = log_value
				_reject(bad, version, "log de sinais malformado", f)
		bad = good.duplicate(true)
		var deep: Dictionary = {}
		var cursor := deep
		for i in 30:
			cursor["nested"] = {}
			cursor = cursor.nested
		bad["unknown"] = deep
		_reject(bad, version, "profundidade hostil em campo desconhecido", f)
		cases += 11
	print("E5 hostis: %d+ casos, versoes 1-7" % cases)

func _migration_roundtrips(f: Array) -> void:
	var store := Store.new("user://e5_migrations")
	for version in [1, 3, 5]:
		var data := _fixture(version)
		var original := JSON.stringify(data, "", true, true)
		var migrated := World.from_dict(data)
		_check(migrated != null, "migracao real v%d falhou" % version, f)
		if migrated == null: continue
		var expected := _snapshot(migrated)
		_check(JSON.stringify(data, "", true, true) == original, "migracao alterou fixture v%d" % version, f)
		_check(migrated.rng.to_dict() == data.rng_state and migrated.ids.next_id == int(data.next_id), "migracao consumiu RNG/ID v%d" % version, f)
		_check(store.save_world(migrated, "legacy_%d" % version).ok, "salvar legado v%d" % version, f)
		var loaded := store.load_world("legacy_%d" % version)
		_check(loaded.ok and _snapshot(loaded.world) == expected, "v%d -> v7 -> arquivo -> v7 divergiu" % version, f)
		if not loaded.ok: continue
		var again := World.from_dict(loaded.world.to_dict())
		_check(again != null and _snapshot(again) == expected, "migracao v%d nao idempotente" % version, f)
		for i in 25:
			migrated.step()
			loaded.world.step()
		_check(_snapshot(migrated) == _snapshot(loaded.world), "continuacao apos migracao v%d divergiu" % version, f)

func _nested_mutation_fuzz(f: Array) -> void:
	# Fixed seed gives repeatable nested mutations beyond the top-level corpus.
	var rng := RandomNumberGenerator.new()
	rng.seed = 92026
	var cases := 0
	for version in range(1, 8):
		var good := _fixture(version)
		for i in 160:
			var bad := good.duplicate(true)
			var target: Dictionary = bad.creatures[0] if i % 2 == 0 else bad.creatures[0].genome
			var fields := ["id", "name", "energy", "age", "max_energy", "alive", "memory", "pos", "heading", "genome"] if i % 2 == 0 else ["id", "size", "speed", "vision_range", "vision_fov", "metabolism", "hue", "generation", "parents"]
			var field: String = fields[rng.randi_range(0, fields.size() - 1)]
			var wrong_values: Array = [null, true, "hostil", [], {}, NAN, INF, -INF]
			var wrong: Variant = wrong_values[rng.randi_range(0, wrong_values.size() - 1)]
			if typeof(wrong) == typeof(target[field]):
				wrong = null
			target[field] = wrong
			_reject(bad, version, "fuzz aninhado " + field, f)
			cases += 1
		for text in ["9223372036854775808", "-9223372036854775809", "9".repeat(4096), "+1", "01", "-0"]:
			for field in ["world_seed", "rng_state"]:
				var bad := good.duplicate(true)
				if field == "world_seed":
					bad.world_seed = text
				else:
					bad.rng_state.state = text
				_reject(bad, version, "inteiro textual hostil " + field, f)
				cases += 1
	print("M0 fuzz aninhado: %d casos deterministas, versoes 1-7" % cases)

func _put(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()

func _bound_trait_roundtrip(f: Array) -> void:
	var world := World.new_world(60, {"creature_count": 1})
	var creature = world.creatures[world.pet_id]
	creature.genome.temperament.caution = 1.0
	creature.genome.temperament.curiosity = 0.0
	world.genealogy.records[creature.id].genome = creature.genome.to_dict()
	var snapshot := _snapshot(world)
	var restored := World.from_dict(JSON.parse_string(snapshot))
	_check(restored != null and _snapshot(restored) == snapshot, "temperamento nos limites 0/1 muda de float para int no roundtrip", f)

func _atomic_failures(f: Array) -> void:
	var folder := "user://e5_atomic_%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var store := Store.new(folder)
	var fault := FaultStore.new(folder)
	var world := World.new_world(751, {"creature_count": 2})
	_check(store.save_world(world, "atomic").ok, "primeiro checkpoint atomico", f)
	var previous := _snapshot(world)
	world.step()
	_check(store.save_world(world, "atomic").ok, "segundo checkpoint atomico", f)
	var committed := _snapshot(world)
	var path := folder.path_join("atomic.json")
	var primary := FileAccess.get_file_as_string(path)
	var backup := FileAccess.get_file_as_string(path + ".bak")
	world.step()
	for mode in ["truncated", "error"]:
		fault.mode = mode
		_check(not fault.save_world(world, "atomic").ok, "escrita interrompida deve falhar: " + mode, f)
		_check(FileAccess.get_file_as_string(path) == primary and FileAccess.get_file_as_string(path + ".bak") == backup, "falha rotacionou primario/backup: " + mode, f)
		var loaded := store.load_world("atomic")
		_check(loaded.ok and not loaded.recovered and _snapshot(loaded.world) == committed, "temporario truncado mascarou checkpoint: " + mode, f)
	# Even a complete but uncommitted temporary file must never be promoted.
	_put(path + ".tmp", primary)
	_put(path + ".bak.tmp", primary)
	_put(path, "{autosave interrupted")
	var recovered := store.load_world("atomic")
	_check(recovered.ok and recovered.recovered and recovered.get("repair_ok", false), "backup nao reparou primario automaticamente", f)
	if recovered.ok:
		_check(_snapshot(recovered.world) == previous, "rollback nao retornou checkpoint anterior", f)
	_check(FileAccess.get_file_as_string(path) == backup and FileAccess.get_file_as_string(path + ".bak") == backup, "reparo alterou backup ou nao restaurou primario", f)
	DirAccess.remove_absolute(path + ".bak")
	recovered = store.load_world("atomic")
	_check(recovered.ok and not recovered.recovered, "reparo nao persistiu sem o backup", f)
	_check(not store.save_world(world, "atomic", {"number": NAN}).ok, "metadado NaN aceito", f)
	_check(FileAccess.get_file_as_string(path) == backup, "metadado invalido alterou checkpoint", f)
	# Oversized files are rejected by length, before allocating/parsing their JSON.
	var oversized := FileAccess.open(folder.path_join("oversized.json"), FileAccess.WRITE)
	oversized.seek(Store.MAX_BYTES)
	oversized.store_8(0)
	oversized.close()
	_check(not store.load_world("oversized").ok, "arquivo maior que 32 MiB aceito", f)
	for slot in ["atomic", "oversized"]:
		for suffix in ["", ".bak", ".tmp", ".bak.tmp", ".recover.tmp"]:
			var candidate := folder.path_join(slot + ".json" + suffix)
			if FileAccess.file_exists(candidate): DirAccess.remove_absolute(candidate)
	DirAccess.remove_absolute(folder)

func _compressed_envelopes(f: Array) -> void:
	var folder := "user://e5_compressed_%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var store := Store.new(folder)
	var world := World.new_world(817, {"creature_count": 2})
	var payload := JSON.stringify({"world": world.to_dict(), "metadata": {"unicode": "agua e memoria: ação"}}, "", true, true)
	var encoded := store._encode(payload, true)
	_check(encoded.ok, "codificacao gzip falhou", f)
	if not encoded.ok: return
	var path := folder.path_join("compressed.json")
	_put(path, encoded.text)
	var loaded := store.load_world("compressed")
	_check(loaded.ok and _snapshot(loaded.world) == _snapshot(world) and loaded.metadata.unicode == "agua e memoria: ação", "envelope v2 perdeu estado/UTF-8", f)
	var header: Dictionary = JSON.parse_string(encoded.text)
	for field in ["encoding", "uncompressed_bytes", "compressed_sha256"]:
		var bad := header.duplicate(true)
		bad.erase(field)
		_put(path, JSON.stringify(bad))
		_check(not store.load_world("compressed").ok, "cabecalho comprimido incompleto aceito: " + field, f)
	for declared_size in [0, -1, 1, null, Store.MAX_PAYLOAD_BYTES + 1]:
		var bad := header.duplicate(true)
		bad.uncompressed_bytes = declared_size
		_put(path, JSON.stringify(bad))
		_check(not store.load_world("compressed").ok, "limite descomprimido invalido aceito", f)
	for contents in ["!bad", "A", "AAAA", header.payload.left(header.payload.length() - 4)]:
		var bad := header.duplicate(true)
		bad.payload = contents
		_put(path, JSON.stringify(bad))
		_check(not store.load_world("compressed").ok, "payload comprimido adulterado aceito", f)
	# Deterministic legal JSON whitespace, with realistic compression ratio.
	var rng := RandomNumberGenerator.new()
	rng.seed = 712
	var padding := PackedByteArray()
	padding.resize(Store.COMPRESS_AT_BYTES)
	var whitespace := [32, 9, 10, 13]
	for i in padding.size():
		padding[i] = whitespace[rng.randi_range(0, 3)]
	var padded := padding.get_string_from_utf8() + payload
	encoded = store._encode(padded)
	_check(encoded.ok and int(JSON.parse_string(encoded.text).version) == 2 and encoded.text.length() < Store.MAX_BYTES, "limiar automatico de compressao falhou", f)
	if encoded.ok:
		_put(path, encoded.text)
		loaded = store.load_world("compressed")
		_check(loaded.ok and _snapshot(loaded.world) == _snapshot(world), "checkpoint grande comprimido nao carrega", f)
	# A complete, valid gzip bomb: real schema, matching plaintext/base64 SHA256,
	# correct gzip CRC/ISIZE, below the decoded cap but far above the ratio cap.
	var bomb := " ".repeat(2 * 1024 * 1024) + payload
	var compressed := bomb.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
	var b64 := Marshalls.raw_to_base64(compressed)
	var bomb_header := {"format": "evoworld-checkpoint", "version": 2, "encoding": "gzip-base64",
		"uncompressed_bytes": bomb.to_utf8_buffer().size(), "sha256": bomb.sha256_text(),
		"compressed_sha256": b64.sha256_text(), "payload": b64}
	var bomb_text := JSON.stringify(bomb_header)
	_check(bomb_header.uncompressed_bytes > Store.MAX_EXPANSION_RATIO * bomb_text.to_utf8_buffer().size(), "fixture gzip bomb nao excede razao", f)
	_put(path, bomb_text)
	var observed := ObservedStore.new(folder)
	var rejected := observed._read(path)
	_check(not rejected.ok and "64:1" in rejected.get("message", "") and not observed.decompressed, "gzip bomb chegou ao descompressor apesar dos checksums validos", f)
	# The writer must never emit that unreadable envelope; uncompressed fallback
	# retains compatibility for highly repetitive but valid payloads.
	encoded = store._encode(bomb, true)
	_check(encoded.ok and int(JSON.parse_string(encoded.text).version) == 1, "writer criou envelope acima da razao permitida", f)
	if encoded.ok:
		_put(path, encoded.text)
		_check(store.load_world("compressed").ok, "fallback v1 repetitivo nao carrega", f)
	_check(not store._encode(" ".repeat(Store.MAX_PAYLOAD_BYTES + 1)).ok, "limite de 8 MiB nao aplicado na escrita", f)
	# The same decoded limit applies to v1, regardless of the 32 MiB disk cap.
	var oversized_payload := " ".repeat(Store.MAX_PAYLOAD_BYTES) + payload
	_put(path, JSON.stringify({"format": "evoworld-checkpoint", "version": 1, "payload": oversized_payload, "sha256": oversized_payload.sha256_text()}))
	_check(not store._read(path).ok, "envelope v1 contornou teto de payload", f)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(folder)

func _capture_flags(f: Array) -> void:
	for path in ["user://m0.png", "C:/temp/m0.png", "C:\\temp\\m0.png", "/tmp/m0.png"]:
		var args := PackedStringArray(["--capture=" + path, "--fps-benchmark=30"])
		var options := Main._capture_options(args, true)
		_check(not options.path.is_empty() and options.population == 30 and options.benchmark, "debug rejeitou captura absoluta/user: " + path, f)
		options = Main._capture_options(args, false)
		_check(options.path.is_empty() and not options.benchmark and options.population == 12, "release ativou flag de desenvolvimento", f)
	for path in ["reports/m0.png", "res://m0.png", "user://../m0.png", "user://a/../../m0.png", "user:///tmp/m0.png", "user://C:/m0.png", "", "user://", "/tmp/m0.json", "/tmp/m0.png\n"]:
		var options := Main._capture_options(PackedStringArray(["--capture=" + path, "--fps-benchmark=30"]), true)
		_check(options.path.is_empty(), "captura aceitou caminho hostil: " + path, f)
	for count in ["", "0", "101", "-1", "abc", "30=extra", "999999999999999999999999"]:
		_check(Main._capture_options(PackedStringArray(["--fps-benchmark=" + count]), true).path.is_empty(), "benchmark aceitou populacao invalida: " + count, f)
	_check(Main._capture_options(PackedStringArray(["--fps-benchmark=12"]), true).path == "user://E4-fps-12.png", "benchmark sem caminho nao usa user://", f)

func _hostile_order_ttl(f: Array) -> void:
	var cases := 0
	for version in range(3, 8):
		var good := _fixture(version)
		for intent in Commands.TICKS_ORDEM:
			for ttl in [null, true, false, "7", [], {}, 0, -1, 1.5, NAN, INF, -INF, Commands.TICKS_ORDEM[intent] + 1, 2147483648]:
				var bad := good.duplicate(true)
				bad.commands = {"order": {"intent": intent, "target": good.creatures[0].pos, "remaining_ticks": ttl}, "protection_requested": false}
				_reject(bad, version, "TTL hostil", f)
				cases += 1
			for ttl in [1, Commands.TICKS_ORDEM[intent]]:
				var valid := good.duplicate(true)
				valid.commands = {"order": {"intent": intent, "target": good.creatures[0].pos, "remaining_ticks": ttl}, "protection_requested": false}
				_check(World.from_dict(valid) != null, "v%d TTL valido rejeitado" % version, f)
	print("M0 TTL hostis: %d casos, versoes 3-7 (v1/v2 nao tinham ordens)" % cases)

func _new_world_generations(f: Array) -> void:
	for seed_value in [7421, 9181]:
		var world := World.new_world(seed_value, {"signal_enabled": true})
		for i in 1800: world.step()
		var deepest := 0
		for record in world.genealogy.records.values(): deepest = maxi(deepest, record.generation)
		print("E5 geracoes seed=%d ticks=1800 generation=%d births=%d alive=%d" % [seed_value, deepest, world.genealogy.records.size() - 12, world.creatures.size()])
		_check(deepest >= 3, "mundo novo E1-E4 sem tres geracoes seed=%d" % seed_value, f)
	# Acquired state is deliberately distinguishable from hereditary temperament.
	var world := World.new_world(713, {"creature_count": 1, "obstacle_count": 0, "food_count": 0})
	var parent = world.creatures[world.pet_id]
	parent.age = world.min_reproduction_age
	parent.energy = parent.max_energy
	parent.personality.preferences["fruta"] = 0.75
	parent.personality.conditioning["fruta:2:2"] = 0.5
	parent.personality.stimulus("player", world.tick)
	world.interagir_jogador(parent.id, parent.pos)
	parent.remember({"type": "eat", "tick": 0, "creature_id": parent.id, "food_id": world.ids.take(), "energy": 1.0})
	var child_id := world.reproduce(parent.id)
	_check(child_id != -1, "reproducao E1-E4 falhou", f)
	if child_id == -1: return
	var child = world.creatures[child_id]
	_check(not parent.personality.episodes.is_empty() and not parent.memory.is_empty(), "fixture sem memoria adquirida", f)
	_check(child.personality != parent.personality and child.personality.episodes.is_empty() and child.personality.preferences.is_empty() and child.personality.conditioning.is_empty() and child.personality.habituation.is_empty() and child.personality.bonds.is_empty() and child.ensino == null and child.brain == null, "experiencia adquirida herdada", f)
	for event in child.memory:
		_check(event.type == "birth" and event.creature_id == child_id, "filhote herdou memoria do genitor", f)
	_check(child.genome.temperament.size() == 4 and child.genome.parents == [parent.id] and child.genome.generation == 1, "novos tracos/ancestralidade nao herdados", f)

func _hostile_types_regression(f: Array) -> void:
	var cases := 0
	# F4: library/version com tipos hostis (sim_world.gd:1400)
	var w1 = World.new_world(140010, {"creature_count": 1})
	w1.place_book(w1.creatures[w1.pet_id].pos + Vector2(20, 0), "guia_capsulas")
	var base_lib: Dictionary = w1.to_dict()
	_check(World.from_dict(base_lib) != null, "base library fixture invalido", f)
	for bad_val in [[], {}, "str", true, false, -1, 0, 1.5, NAN, INF]:
		var bad := base_lib.duplicate(true)
		bad.library.version = bad_val
		_reject(bad, int(bad.save_version), "library.version hostil " + str(bad_val), f)
		cases += 1

	# F4: terminal_estado conhecidos com tipos hostis (terminal_estado.gd:84,96)
	var w2 = World.new_world(154004, {"creature_count": 1})
	var c2 = w2.creatures[w2.pet_id]
	var device: int = w2.place_terminal(c2.pos)
	for i in range(3):
		w2.tick += 1
		w2.terminal_offer_manual(c2, device)
	var base_term: Dictionary = w2.to_dict()
	_check(World.from_dict(base_term) != null, "base terminal fixture invalido", f)
	for cmd in ["OLHAR", "AJUDA", "REPETIR", "MOVER", "DESENHAR"]:
		for bad_val in [[], {}, -1, true, false, 0, NAN, INF, "desconhecido"]:
			var bad := base_term.duplicate(true)
			bad.creatures[0].mind.terminal.state.conhecidos[cmd] = bad_val
			_reject(bad, int(bad.save_version), "conhecidos[%s] hostil %s" % [cmd, str(bad_val)], f)
			cases += 1
		var bad_cmd := base_term.duplicate(true)
		bad_cmd.creatures[0].mind.terminal.state.conhecidos[123] = "inicial"
		_reject(bad_cmd, int(bad_cmd.save_version), "conhecidos chave int", f)
		cases += 1

	# F4: knowledge questions com tipos hostis (knowledge.gd:147)
	var w3 = World.new_world(140012, {"creature_count": 1})
	var c3 = w3.creatures[w3.pet_id]
	w3.place_object(c3.pos + Vector2(8, 0), "capsula_aversiva")
	c3.mind.decide(c3, w3.tick, w3.sense(c3))
	var base_k: Dictionary = w3.to_dict()
	_check(World.from_dict(base_k) != null, "base knowledge fixture invalido", f)
	_check(not base_k.creatures[0].mind.knowledge.questions.is_empty(), "knowledge sem questoes para teste", f)
	for field in ["goal", "text_key", "category"]:
		for bad_val in [[], {}, -1, true, false, 0, NAN, INF, "desconhecido"]:
			var bad := base_k.duplicate(true)
			bad.creatures[0].mind.knowledge.questions[0][field] = bad_val
			_reject(bad, int(bad.save_version), "knowledge questions[%s] hostil %s" % [field, str(bad_val)], f)
			cases += 1
	print("F4 tipos hostis regressao: %d casos sem SCRIPT ERROR" % cases)
