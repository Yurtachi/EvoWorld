extends RefCounted
## E5: performance changes must not alter the simulation. The golden digests were
## recorded before optimising Personality.advance/record and verified equal after.
## A change here means simulated behaviour changed: update only on purpose.
const World = preload("res://scripts/world/sim_world.gd")

const GOLDEN := {
	"new_world_7421_n30_t600": "f271c2bdc7b378d2d173cf0f0082ab3238cf9bb844ae1709605665c8c92e77b0",
	"legacy_5_n16_t600": "efcaad800053211b4f08f71ea4ddd74f7c31bc21c83011f0f1fe75e241db9be9",
}

static func digest(world) -> String:
	return JSON.stringify(world.to_dict(), "", true, true).sha256_text()

func run() -> Array:
	var failures: Array = []
	var product = World.new_world(7421, {"creature_count": 30, "max_population": 100, "signal_enabled": true})
	var legacy = World.new(5, {"creature_count": 16})
	for i in 600:
		product.step()
		legacy.step()
	var actual := {"new_world_7421_n30_t600": digest(product), "legacy_5_n16_t600": digest(legacy)}
	for key in GOLDEN:
		if actual[key] != GOLDEN[key]:
			failures.append("determinismo mudou em %s: %s" % [key, actual[key]])
	# Round trip at an arbitrary tick keeps stepping identical (no hidden perf caches).
	var restored = World.from_dict(JSON.parse_string(JSON.stringify(product.to_dict(), "", true, true)))
	if restored == null:
		failures.append("roundtrip do mundo medido falhou")
	else:
		for i in 50:
			product.step()
			restored.step()
		if digest(product) != digest(restored):
			failures.append("continuacao apos roundtrip divergiu")
	return failures
