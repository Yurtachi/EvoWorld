extends RefCounted
const World = preload("res://scripts/world/sim_world.gd")
const Store = preload("res://scripts/persistence/save_store.gd")

class FaultStore extends Store:
	var mode := "truncated"
	func _write(path: String, contents: String) -> Dictionary:
		var result := super._write(path, contents.left(contents.length() / 2))
		return {"ok": false, "message": "Injected disk failure"} if mode == "error" else result

func run() -> Array:
	var failures: Array = []
	_hostile_versions(failures)
	_migration_roundtrips(failures)
	_bound_trait_roundtrip(failures)
	_atomic_failures(failures)
	_compressed_envelopes(failures)
	_new_world_generations(failures)
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
	# Legal JSON padding exercises the real >24 MiB threshold without discarding
	# genealogy or inventing non-schema world fields. The decoded cap is enforced.
	var padded := " ".repeat(Store.COMPRESS_AT_BYTES) + payload
	encoded = store._encode(padded)
	_check(encoded.ok and int(JSON.parse_string(encoded.text).version) == 2 and encoded.text.length() < Store.MAX_BYTES, "limiar automatico de compressao falhou", f)
	if encoded.ok:
		_put(path, encoded.text)
		loaded = store.load_world("compressed")
		_check(loaded.ok and _snapshot(loaded.world) == _snapshot(world), "checkpoint grande comprimido nao carrega", f)
	_check(not store._encode(" ".repeat(Store.MAX_PAYLOAD_BYTES + 1)).ok, "limite de 128 MiB nao aplicado na escrita", f)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(folder)

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
