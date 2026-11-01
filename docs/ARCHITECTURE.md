# EvoWorld architecture (contracts for parallel work)

Godot 4.7.2, GDScript, GL Compatibility. Sim is pure logic (RefCounted, no Node/rendering) so it runs headless and is testable. UI/render only reads sim.

## Ownership (one writer per path)
- `scripts/core/`, `scripts/world/`, `scripts/creature/`, `scripts/behavior/`, `tests/unit/test_sim_*.gd` -> **SIM worker**
- `scenes/`, `scripts/ui/`, `scripts/render/`, `assets/procedural/` -> **UI worker**
- `docs/ASSET_PROVENANCE.md`, `assets/external/`, `docs/REUSE_MATRIX.md` -> **REUSE worker**
- `scripts/persistence/` -> SIM worker (wave 2)

## SimWorld API (scripts/world/sim_world.gd, `class_name SimWorld extends RefCounted`)
```
func _init(seed: int, config: Dictionary = {})   # config: size(Vector2), creature_count, food_regrow, ...
func step() -> void                               # one fixed tick (dt = TICK_DT = 0.1 s)
var tick: int
var seed: int
var size: Vector2                                 # world bounds, origin (0,0)
var creatures: Dictionary                         # id:int -> SimCreature (alive only)
var foods: Array                                  # of {id:int, pos:Vector2, energy:float}
var obstacles: Array                              # of {pos:Vector2, radius:float}
var events: Array                                 # ring buffer of {tick:int, type:String, ...}
var pet_id: int                                   # -1 if none
func spawn_creature(pos: Vector2, name: String = "", genome = null) -> int
func place_food(pos: Vector2) -> int
func place_obstacle(pos: Vector2, radius: float) -> void
func to_dict() -> Dictionary                      # versioned, JSON-safe
static func from_dict(d: Dictionary) -> SimWorld
```
## SimCreature (scripts/creature/sim_creature.gd)
Fields: `id:int, name:String, pos:Vector2, heading:float, energy:float, max_energy:float, age:int, alive:bool, genome:Genome, last_action:String, last_reason:String, memory:Array`.
Genome (scripts/creature/genome.gd): bounded float genes `size, speed, vision_range, vision_fov, metabolism, hue`, JSON round-trip, `id`, `parents:Array`, `generation:int`.
Render rule: body drawn procedurally from genome (size/hue/speed visible).

## Rules
- All randomness through a seeded `RandomNumberGenerator` owned by SimWorld.
- No Python at runtime. No network. No external code execution from saves.
- Tests: `tests/unit/test_*.gd` with `func run() -> Array` (failures). Run: `godot --headless --path . -s tests/run_tests.gd`.
- Commit only own paths. No AI trailers in commits (mission rule). Identity: local repo config (Yurtachi).
