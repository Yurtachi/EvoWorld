extends RefCounted
const World = preload("res://scripts/world/sim_world.gd")
const Store = preload("res://scripts/persistence/save_store.gd")

func run() -> Array:
	var failures: Array = []
	_hostile_versions(failures)
	_migration_roundtrips(failures)
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
