# Independent review: SIM core (commit fb94c48)

Reviewer: read-only review worker, branch `Yurtachi/evo-review-sim` (HEAD 64ececc, which merges fb94c48 and has no further code changes).
Scope: `scripts/core/*`, `scripts/creature/*`, `scripts/world/sim_world.gd`, `tests/unit/test_sim_world.gd`, `reports/sim.md`, against `docs/ARCHITECTURE.md` and `docs/mission/*.md`.
Only this report was added. No source was modified.

## Test results

| Command | Exit | Output |
|---|---|---|
| `godot --headless --path . -s tests/run_tests.gd` (Godot 4.7.2 console) | **0** | `test_sim_world.gd: ok`, `test_smoke.gd: ok`, no script errors, ~8.7 s wall |

Two scratch probe scripts (kept outside the repo) were run with `godot --headless --path . -s <probe>`. Both exited 0, but they print engine `SCRIPT ERROR` lines (see F2). Numbers below are measured on this machine in a headless debug run.

## Summary

| Severity | Count | IDs |
|---|---|---|
| HIGH | 1 | F1 |
| MEDIUM | 4 | F2, F3, F4, F5 |
| LOW | 7 | F6-F12 |
| INFO | 3 | I1-I3 |

Determinism is clean: I found no leaks (I1). The main gaps are load-time validation of numeric ranges and schemas, and quadratic cost in `sense()`.

## Findings

### F1 [HIGH] Save validation accepts overflowing energy values, giving inf energy, NaN hunger and an immortal creature
- Files: `scripts/creature/sim_creature.gd:42-45` (range check), `:61-62` (`snappedf`), `scripts/core/sim_data.gd:5-6` (`number()` only checks finiteness), `scripts/world/sim_world.gd:168`.
- `from_dict` requires `0 <= energy <= max_energy` and `max_energy > 0`, but sets no upper bound. `snappedf(1e308, 0.000001)` overflows to `inf`.
- Repro (probe2, Godot 4.7.2):
  ```gdscript
  var w := SimWorld.new(3); for i in 30: w.step()
  var d = JSON.parse_string(JSON.stringify(w.to_dict()))
  d["creatures"][0]["max_energy"] = 1e308; d["creatures"][0]["energy"] = 1e308
  var r = SimWorld.from_dict(d)   # ACCEPTED, energy=inf max=inf
  r.step()                        # energy=inf hunger=nan alive=true
  # after 51 steps the creature is still alive
  ```
- Consequences:
  - The creature never starves, and `hunger` is NaN.
  - Re-saving emits `"energy":1e99999`, which is not valid JSON and is only read back because Godot's parser is lenient.
  - This breaks the invariant `0 <= energy <= max_energy` that `_energy_bounds` tests.
  - It contradicts the claim in `reports/sim.md` that malformed snapshots return null.
- Related: `max_energy=1e-9` is accepted. It snaps to 0 and the creature dies on the next step, so this one is only a harmless oddity.
- Fix:
  - Bound `max_energy` and `energy` (for example `max_energy <= 1e4`), or require `max_energy == snappedf(80 + genome.size*2, 1e-6)`.
  - Re-validate after snapping.
  - Add an upper bound to the generic `number()` helper.
  - Bound food `energy` too (`sim_world.gd:326-332`). It is currently accepted at 1e308, and is also not snapped to the 1e-6 grid like other values.

### F2 [MEDIUM] `from_dict` raises engine SCRIPT ERRORs on wrong-typed `save_version` instead of returning null
- File: `scripts/world/sim_world.gd:274` (`data.get("save_version") != SAVE_VERSION`).
- Comparing a non-numeric Variant to int is a runtime error. Probe results:
  - `save_version = "1"`: `Invalid operands 'String' and 'int' in operator '!='`, returns null.
  - `[1]` and `{}`: the same error with `Array`/`Dictionary`.
  - `true`: the same error with `bool`.
- The function aborts and returns null, but only after an error. In the editor or a debug build this stops at the debugger and spams the console, so the contract "invalid input returns null" does not hold cleanly.
- Fix: use `Data.integer(data.get("save_version")) and int(...) == SAVE_VERSION`. `sim_creature.gd:38` and `genome.gd:37` use the same `!= 1` / `!= VERSION` pattern. They are only reachable with a non-dict genome or creature version, but should be fixed the same way.
- The `from_dict(d: Dictionary)` signature also makes `from_dict(null)` or `from_dict([])` a type error at the call site. The persistence layer must check `typeof(parsed) == TYPE_DICTIONARY` before calling. Document or guard this.
- All the other top-level and creature field type mutations I tried were rejected cleanly:
  - `null`, `"x"`, `true`, `[]`, `{}` for tick, ids, size, config, rng_state and the lists.
  - Non-dict list entries.
  - Missing keys.

### F3 [MEDIUM] O(N^2) hotspot in `sense()`; quadratic cost is reachable through the config and the load limits
- File: `scripts/world/sim_world.gd:123-134`, called per creature from `:139`.
- Per creature, per tick:
  - Lines 125-127 scan all foods, run `_occluded` (O(obstacles)) on each visible food, and `duplicate(true)` each visible food.
  - Lines 128-130 build a list of all other creatures, running `_occluded` for each. **The baseline policy never reads `sensors["creatures"]`** (only `"foods"` and `"obstacles"` are used at `:142`/`:163`).
- That is O(C·(F·O + C·O)) per tick, plus `_eat` linear scans and `remove_at` (`:177-182`).
- Measured (default 1200x760, 100 food cap, 8 obstacles, `step()` average over 20 ticks):

  | Creatures | ms/step |
  |---|---|
  | 16 | 1.3 |
  | 30 | 2.6 |
  | 100 | 13 |
  | 300 | 73.5 |
  | 1000 | **1305** |
  | 300 creatures + 1860 food + 200 obstacles (4000x4000) | **838** |

  - The 30-creature goal is fine.
  - The 1000-creature config limit (`sim_world.gd:46`) and the 10000-creature load limit (`:297`) are not usable. 10000 creatures extrapolates to about 2 min per tick.
  - The mission asks for "protection against unnecessary O(N^2) cost" (`02_EVOWORLD_ORCA_GOAL_SONNET.md:65`).
- Fixes:
  - Drop the creature sensor, or make it lazy or optional until a behavior needs it.
  - Add a uniform grid (spatial hash) over foods, creatures and obstacles.
  - Avoid `duplicate(true)` in the hot path.
  - Lower the save-load caps, or at least `creatures.size()`, to values that are actually playable (for example 200), and clamp `creature_count`/`food_capacity`/`obstacle_count` to the tested range.

### F4 [MEDIUM] Event and memory schema are not validated, so consumers can crash on loaded data
- Files: `scripts/world/sim_world.gd:299` and `:338` (events), `scripts/creature/sim_creature.gd:51` and `:68` (memory).
- Only `json_data()` is checked (any JSON-like value, depth <= 12, no size limit).
- Probe results:
  - `events = [1, "x"]` and `events = [{}]` are accepted.
  - `creature.memory = [1, null, "a"]` is accepted.
  - A single event of ~100 KB, a 1 MB creature name, and 1 MB `last_reason` strings are accepted. The strings are unbounded and `sim_creature.gd:46-48` only checks `is String`.
- Anything that does `event["type"]` crashes. The test suite itself does this at `tests/unit/test_sim_world.gd:51`, and so will the UI event log.
- Fix: validate `events[i]` and `memory[i]` as dictionaries with `type` (known enum), `tick` (int, `<= tick`) and typed fields per type. Bound string lengths (name <= 64, reason <= 256) and entry sizes.
- Other fields are also accepted loosely:
  - `last_action` is any string (probed `"teleport"`).
  - `heading` is unbounded (see F7).
  - `pet_id` can point at any creature.
  - `genome.parents` may contain the creature itself or ids `>= next_id`.
  - Two creatures, or two foods, can share a position (harmless in this sim).
  - Unknown extra keys are silently ignored (fine, but this means no strict schema).

### F5 [MEDIUM] Pet identity silently transfers to the next spawned creature after the pet dies
- File: `scripts/world/sim_world.gd:79-80` (`if pet_id == -1: pet_id = creature.id`), with `:117-118` clearing `pet_id` on death.
- Repro (probe1):
  ```gdscript
  var w := SimWorld.new(1, {"creature_count":1,"food_count":0,"obstacle_count":0,"food_regrow":false})
  # pet_id==2; after 5000 ticks it starved: pet_id == -1
  w.spawn_creature(Vector2(100,100), "Newcomer")  # -> pet_id == 4
  ```
- Any player-added creature or future birth becomes "the pet" without consent. This conflicts with the GDD ("adopted persistent pet with identity", and care mode: never silently change or delete a favorite creature).
- The doc comment `pet_id: -1 if none` does not describe auto-adoption.
- Fix: assign the pet only during world setup, or through an explicit `adopt_pet(id)`.

### F6 [LOW] Energy is not conserved, and there is no energy accounting
- File: `scripts/world/sim_world.gd:176-188` (`_eat`), `:84-92`, `:119-121`.
- Eating removes the whole 32-energy food item but credits only `min(food, max_energy - energy)`. Probe: a creature at 90/100 eats and gains **10**, so 22 of 32 energy (69%) vanishes. The event reports `"energy": 10.0`.
- The eat condition `hunger > 0.05` means up to ~27 of 32 can be wasted.
- Food creation (initial food, regrowth, `place_food`) is a free source, and starvation or death leaves no corpse sink. That is acceptable as an open ecosystem, but the energy ledger is not auditable.
- Nothing is wrong with bounds: `0 <= energy <= max_energy` is enforced every tick (`:138`, `:168`).
- Fix: either leave the remainder on the map as a partial food item (reduce `food.energy` instead of removing it), or document the waste. Consider a debug `total_energy()` helper plus a test that checks `sum(energy) + sum(food.energy)` changes only by basal and move costs, regrowth and spawns.

### F7 [LOW] `heading` is accepted unbounded
- File: `scripts/creature/sim_creature.gd:40,60`.
- Probe: `heading = 1e300` is accepted. After one step it silently becomes `0.0`, because `wrapf` and `snappedf` on a huge value lose all precision. There is no crash or NaN, but the loaded value is meaningless. Validate `|heading| <= TAU*2`, or wrap it on load.

### F8 [LOW] Loaded events and memory change numeric type (float to int)
- Files: `scripts/core/sim_data.gd:33-34`, `scripts/world/sim_world.gd:338`, `scripts/creature/sim_creature.gd:68`.
- `restore_precision` converts integral floats to int, for example an `energy: 32.0` event becomes `32`. Live worlds hold floats, while reloaded worlds hold ints (`to_dict()` normalises both, which is why the snapshot tests pass).
- Typed readers with `float` annotations are fine. `typeof` or `is float` checks will differ after a load.
- The round-trip tests compare serialised text, not in-memory types, so they cannot see this difference.

### F9 [LOW] Adjacent food outside the field of view cannot be eaten
- File: `scripts/world/sim_world.gd:148,214` (eating uses `sense()` output only).
- Probe: food 5 units behind a creature with `vision_fov = PI/3` is not perceived, and the creature rests (`last_action == "rest"`). This is a design limit rather than a crash, but it can cause starvation next to food. Consider an always-on contact radius for eating.
- Related (design observation): a food item can be "perceived" by a zero-width ray (`_occluded` margin 0 at `:126`) while the creature's body is blocked (`_move` uses margin `size`, `:202`). The creature turns 90 degrees, loses sight, and wanders. Probe: creature at (200,200) heading 0, obstacle r=10 at (240,212), food at (300,200). With a 180-degree FOV the creature wandered off and was at 3.4 energy after 400 ticks with the food 100 units away. With a 360-degree FOV it ate after about 33 seek ticks. This is not a livelock, only inefficient.

### F10 [LOW] API deviations from `docs/ARCHITECTURE.md`

| Doc | Code | Impact |
|---|---|---|
| `_init(seed: int, config)` | `_init(world_seed: int = 1, config = {})` (`sim_world.gd:30`) | Positional calls are fine. Named-argument calls (`seed=`) break. The `seed` field is correct. |
| `spawn_creature(pos, name, genome)` | param named `creature_name` (`:49`) | Named-argument calls break. Positional is fine. |
| Genome "bounded float genes" | `spawn_creature` with an out-of-range genome returns `-1` (`:58-62`, via `Genes.from_dict` range rejection at `genome.gd:45`) instead of clamping, although `bound_genes()` exists | Surprising: the UI or editor gets -1 for a slightly out-of-range gene instead of a clamped creature. |
| `place_obstacle(...) -> void`, `place_food -> int` | Matches. `place_obstacle` silently rejects (overlap, non-finite) with no signal | The UI cannot tell a placement failed. |
| `to_dict()` "JSON-safe" | True, but floats use the lenient `1e99999` form when infinite (F1), and `from_dict` requires a Dictionary (F2) | |
| `events` "ring buffer" | An array with `pop_front` (O(n) on 256), fine | |

All documented fields exist with the right types: creature fields, genome fields, `hunger` as an extra property, and event types spawn/eat/death.

### F11 [LOW] Integer caps in `Data.integer` limit ids and ticks to 2^31-1
- File: `scripts/core/sim_data.gd:9`.
- A tick or id above 2147483647 makes the save unloadable (`to_dict` writes it, `from_dict` rejects it).
- At 50 ticks/s (5x speed) the tick limit is reached after about 497 days, which is unlikely. The id limit (`next_id` up to 2^31) is also remote. Document the limit, or use the same text encoding as the seed.

### F12 [LOW] Test gaps
`tests/unit/test_sim_world.gd` is good at determinism and round trips but misses:
- Numeric-overflow and extreme-value saves (F1).
- Wrong-typed `save_version` (F2) and non-dict events or memory (F4).
- Pet reassignment (F5).
- Energy accounting (F6).
- Any performance or large-population smoke test (F3).
- Sensor output for other creatures, which is also dead code in the policy.
- Creature `from_dict` and `to_dict` as unit tests.
- Genome `from_dict` rejection cases other than lineage.

## Informational (verified OK)

- **I1 Determinism, no leaks found.**
  - All randomness goes through the single `RandomNumberGenerator` owned by `SimRng` (`sim_rng.gd:5-11`). There is no `randi`, `randf`, `randomize`, `Time`, `OS` or `shuffle` anywhere in `scripts/`.
  - Iteration order is fixed. `step()` sorts creature ids (`:110-111`) and `to_dict()` sorts them too (`:253-254`). Other Dictionary iterations read in insertion order, which is monotonic by id before and after a load, and they do not affect state. The `Genes.BOUNDS` iteration is a const dictionary in a fixed order.
  - Energy, heading, traits and radii are snapped to a 1e-6 grid every tick, which controls float drift. Positions are float32 `Vector2`, so the save round-trip through double text is exact. This would break on a `precision=double` engine build, which is not claimed.
  - The RNG state is stored as a decimal string, and `seed`/`rng_state` handle signed 64-bit values.
  - Same-seed equality, save/load continuation and spawn-after-load are tested and pass. I did not run a cross-process hash comparison.
- **I2 Save validation positives.**
  - Rejected cleanly: wrong top-level types, duplicate ids (creatures, genomes and foods share one namespace), `next_id` not above all used ids, positions outside bounds or inside obstacles, out-of-range genes, overflowing seed or RNG-state text (checked as text before int conversion), non-JSON event values, list-size caps, and food over capacity.
  - Saves are data-only. There is no script or resource loading from save content (`load()` only targets fixed `res://` scripts).
- **I3 Ecology note.** A default 16-creature world run for 3000 ticks is fully saturated: 16 alive, food stays at the 100 cap, and no creature dies. Food regrowth is about 4x consumption, so the baseline shows no selection pressure yet. Tune the scarcity before evolution work.

## Recommended order of fixes
1. F1: bound energy and numeric ranges on load.
2. F2: make the version check type-safe.
3. F4: add an event and memory schema.
4. F3: remove the unused creature sensor and add a spatial index. Cap the load size.
5. F5: make pet adoption explicit.
