# UI worker report

Status: PASS for the dispatched UI, rendering and persistence scope.

## Repository and ownership

- Workspace: `C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo-ui2`.
- Branch: `Yurtachi/evo-ui2`; starting HEAD: `64ececce8e77cf77abc0cca00a4863c57c9c7f02`.
- Read `docs/ARCHITECTURE.md`, `reports/sim.md`, and both mission documents before implementation.
- Changes are confined to `scenes/main.tscn`, `scripts/ui/`, `scripts/render/`, explicitly dispatched `scripts/persistence/save_store.gd`, `tests/unit/test_save_store.gd`, and `reports/ui*`.
- Existing local identity: Yurtachi. No push, destructive Git command, or AI trailers.
- The dispatch explicitly assigns persistence to this UI worker, overriding the architecture document's earlier wave-2 SIM ownership for that path. Simulation scripts and schema are unchanged.

## Implemented behavior

- Main scene instantiates the existing, real `SimWorld`; no replacement or stub simulation.
- Top-down garden renders actual creatures, food and circular obstacles. Creature size and hue determine body radius/color; speed changes tail length. Terrain decoration uses an independent seeded visual RNG and never consumes simulation randomness.
- Camera supports pointer-centered wheel zoom, middle-button drag, WASD pan, F to fit, Find pet and Follow. Vision overlay shows geometric sensor range/FOV and explicitly notes that rocks can occlude objects inside it.
- Native Godot controls use a consistent sage/cream theme, readable HUD and inspector, tool previews, selected-creature ring and pet marker. The inspector scrolls for longer names/reasons or smaller windows; minimum window size is 1100x680.
- HUD exposes seed, fixed tick, current FPS and counts for entities, creatures and food. Inspector reads the selected creature's real name, energy, age, action, reason and genes.
- New-world dialog collects garden name, pet name and bounded integer seed. A garden starts paused with 16 creatures and names the real pet. Cancel preserves the previous world and playback state.
- Play/Pause, Space and 1x/2x/5x drive `SimWorld.step()` at its 0.1-second tick. Rendering and simulation timing are separate; a stalled frame is capped at 0.25 seconds of catch-up input.
- Inspect, Food, Rock and Creature tools apply actual SimWorld methods at click coordinates and report placement rejection. UI-created populations are capped at 150; this is a responsiveness guard, not a performance claim.
- Save/Ctrl+S and Load/Ctrl+L use one local checkpoint slot. Loads pause and select the saved pet. The UI explicitly describes fixed foraging policy and survival/mortality; it claims no learning, reproduction or communication.

## Persistence contract

`scripts/persistence/save_store.gd` exposes `save_world(world, slot = "world", metadata = {})` and `load_world(slot = "world")`, returning dictionaries with `ok` and a user-facing `message`. Successful loads include `world`, `metadata`, `path`, and `recovered`.

Default files are `user://saves/world.json`, `.json.bak`, and same-directory temporary files. A versioned, data-only envelope contains a full-precision JSON payload and SHA-256 checksum; world loading uses `SimWorld.from_dict()` and rejects invalid schemas. Files larger than 32 MiB and unsafe slot names are rejected.

Writes flush and close the temporary file, reread and validate it, preserve a valid existing primary through backup-temp + rename, then replace the primary through rename. Corrupt primaries never overwrite a valid backup. Load tries primary then backup and reports recovery; recovery returns the backup state without overwriting disk until the next Save. Interrupted `.tmp` files are ignored. Repeated replacement and corrupt-primary recovery passed on the supplied Windows/Godot runtime. This is not a claim of power-loss durability across every filesystem or storage device.

Godot API references used: [DirAccess](https://docs.godotengine.org/en/stable/classes/class_diraccess.html) and [FileAccess](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html).

## Verification

Engine: `Godot v4.7.2.stable.official.ed1daf0bf` using the executable supplied in the dispatch.

| Command / evidence | Result |
|---|---|
| `godot --headless --path . -s tests/run_tests.gd` | Exit 0; save-store, simulation and smoke suites all report `ok`; no script errors |
| `godot --headless --path . -s scripts/ui/verify_ui.gd` | Exit 0; `UI integration: ok`; no script errors |
| `godot --headless --path . --quit-after 5` | Exit 0; main scene boots without script errors |
| Running graphical world capture | Exit 0; actual current scene captured at 1280x720 |
| Running graphical new-world dialog capture | Exit 0; actual themed naming dialog captured at 1280x720 |
| `git diff --check` | Exit 0 |

Save-store tests cover exact world/metadata round trip, deterministic continuation, atomic replacement, backup content, interrupted temporary file, checksum failure, invalid world schema, malformed JSON, backup retention after saving over corruption, invalid slot paths, missing files and failure when both primary and backup are invalid. Fixtures use unique isolated directories and remove only their own named files.

UI integration instantiates the real scene and exercises dialog confirmation, naming/seed, toolbar signals, food/rock placement, adding three creatures, picking the pet, inspector source fields, horizontal layout fit, pause, 5x stepping, save/load restoration, wheel zoom, follow/fit and Space input. It uses an isolated checkpoint directory and never writes the player's default slot.

Screenshots were opened and visually inspected after generation: [world](ui-world.png), [new world](ui-new-world.png). The final world capture shows 16 creatures, 86 food and 8 obstacles at tick 120; the HUD showed roughly 120 FPS while paused. Renderer: OpenGL 3.3, NVIDIA 610.62, GeForce RTX 2050. This is visual verification, not a live-simulation benchmark.

## Run and capture a screenshot

From the repo root in PowerShell:

```powershell
& 'C:\Users\Yurtachi\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe' --path .
```

Name the pet and create the garden, or choose Keep exploring. Press F12 while exploring to capture the current rendered viewport to `user://screenshots/evoworld-<timestamp>.png`; the resolved absolute filename appears in the console and status line. On this Windows project, `user://` normally resolves beneath `%APPDATA%/Godot/app_userdata/EvoWorld/`. Saves are in its `saves/` subdirectory.

For a reproducible capture that exits automatically, use the same engine command with:

```text
--path . -- --capture=C:/absolute/existing/folder/world.png
```

This uses the real default seed 7421, names the pet Pip, steps the actual simulation 120 times, pauses, warms up the rendered HUD and writes the PNG. Add `--show-new-world` to capture the naming dialog. The destination directory must exist. Graphical mode is required; headless runs do not produce screenshots.

## Limits and remaining integration

- No external assets were present in this checkout. Presentation uses native Godot UI, geometric resource/obstacle drawing and genuine procedural genome expression; no downloaded assets, new runtime dependencies or attribution obligations were introduced.
- One checkpoint slot with its previous valid revision; no slot browser, autosave, undo, export package or screenshot upload was requested or implemented.
- The existing simulation remains a fixed heuristic baseline. Learning, reproduction, communication, protected pets and advanced mission phases remain outside this dispatch.
- No outstanding implementation work remains within this task. Coordinator integration and independent review remain separate.
