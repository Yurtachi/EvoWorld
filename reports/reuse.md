# REUSE worker report

Status: PASS for external asset/library verification and provenance audit.

## Repository and scope

- Workspace: `C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo-reuse2`.
- Branch: `Yurtachi/evo-reuse2`.
- Read `docs/ARCHITECTURE.md`, `reports/sim.md`, `docs/mission/01_EVOWORLD_VISAO_ARQUITETURA_GDD.md`, and `docs/mission/02_EVOWORLD_ORCA_GOAL_SONNET.md` before execution.
- Changed only REUSE-owned paths: `docs/ASSET_PROVENANCE.md`, `docs/REUSE_MATRIX.md`, `assets/external/kenney/`, and `reports/reuse.md`.
- Obeyed local Git identity `Yurtachi` (`diegorodriguesny@gmail.com`); no identity modification, no remote push, no reset/clean, and no AI trailers in commits.

## Verified facts and findings

### 1. External Code Libraries (Read-Mostly & Verified via Official Git Remotes)
- **`godot_rl_agents`:**
  - URL: `https://github.com/edbeeching/godot_rl_agents`
  - License: MIT (SPDX: `MIT`)
  - Latest Tag: `v0.8.2` (commit `f4b53921f0f6602d930b7b174a3ba7b8aed361aa`, 2025-01-22T09:53:46Z)
  - Latest Commit on main: `207b6f476f5846f33d08b92c7a350147e7b78bf5` (2026-06-13T19:16:31Z)
  - Files in repo: None incorporated (No runtime libraries rule; reserved for offline Phase 6 Colab experiments).
- **`godot_rl_agents_plugin`:**
  - URL: `https://github.com/edbeeching/godot_rl_agents_plugin`
  - License: MIT (SPDX: `MIT`)
  - Latest Tag: `[LACUNA: No release tags published in repository]`
  - Latest Commit on main: `998c357a0cd09b37f40a36d70c7867fc9f682338` (2026-06-13T19:17:26Z)
  - Files in repo: None incorporated. Rejected for runtime because it requires network socket synchronization (TCP/WebSocket) and tight SceneTree Node coupling, which violates the offline `RefCounted` pure simulation contract.
- **`neat-python`:**
  - URL: `https://github.com/CodeReclaimers/neat-python`
  - License: BSD-3-Clause (SPDX: `BSD-3-Clause`)
  - Latest Tag: `v2.0.1` (commit `043cddfcb83012d145095915d903790c556dda2a`, 2026-03-14T21:56:00Z)
  - Latest Commit on master: `7d9acae0a1e5d7ed6199ffbd525dd15c5c87a86f` (2026-05-23T10:30:55Z)
  - Files in repo: None incorporated. Evaluated as ADAPT: forward inference for EvoWorld will be implemented directly in pure GDScript or via static JSON model imports.

### 2. Downloaded and Verified CC0 Assets
- **`Kenney Roguelike/RPG Pack`:**
  - URL: `https://kenney.nl/assets/roguelike-rpg-pack`
  - License: CC0 1.0 Universal (verified from official download `License.txt`)
  - Zip Archive SHA256: `8E7D2378F8F794245645F6D7DC7AEEB246791410A7E512293C594B46A5A9524B` (715,373 bytes)
  - Installed into `assets/external/kenney/roguelike-rpg-pack/`:
    - Full official transparent spritesheet (94,579 bytes, SHA256: `808C8D734480BC949B284F3BCC252E87E1EE53B24178791A6838CFF1A5EC2C63`)
    - Official `spritesheetInfo.txt` and `License.txt`
    - Curated sliced subset:
      - Terrain: `grass.png`, `dirt.png`, `sand.png`, `water.png`
      - Food: `apple.png`, `berry.png`, `seed.png`, `meat.png`, `leaf.png`
      - Obstacles: `rock.png`, `rock_small.png`, `tree_top.png`, `tree_trunk.png`, `bush.png`
- **`Kenney Animal Pack Remastered`:**
  - URL: `https://kenney.nl/assets/animal-pack-remastered`
  - License: CC0 1.0 Universal (verified from official download `License.txt`)
  - Zip Archive SHA256: `25C51AE89D0AF358D60B75CFCEBB76A72E9CB20E38453D90F0DFDDD29234069A` (3,600,298 bytes)
  - Installed into `assets/external/kenney/animal-pack-remastered/`:
    - Official `License.txt`
    - Small useful subset of 8 round animal reference sprites: `bear.png`, `chicken.png`, `cow.png`, `dog.png`, `duck.png`, `frog.png`, `pig.png`, `rabbit.png`
- **`Kenney Pixel Pack`:**
  - URL: `https://kenney.nl/assets/pixel-pack`
  - License: CC0 1.0 Universal (verified from official download `License.txt`)
  - Zip Archive SHA256: `8A147F84D25CD3D2192837D9418822C2A61F889FC4F3A05F03230E7E2046944E` (38,315 bytes)
  - Installed into `assets/external/kenney/pixel-pack/`:
    - Official `License.txt`, `Spritesheet/pixelSpritesheet.png`, 4 sample 1x1 pixels (`black01.png`, `white01.png`, `white10.png`, `white20.png`), and `README.md`
    - Documented factual audit: this pack was released by Kenney on April Fools' Day 2019 containing 1x1 colored pixel tiles. It serves as utility textures for solid tinting, but does not provide multi-pixel environment tiles.

### 3. Documentation
- Written `docs/REUSE_MATRIX.md` detailing Make/Adapt/Use decisions, trade-offs, supply-chain risks, and implementation costs for all 8 candidates.
- Filled `docs/ASSET_PROVENANCE.md` with complete provenance rows, URLs, licenses, commit tags, dates, sha256 hashes, file listings, and `[LACUNA]` markings for unverifiable release tags.

## Verification

Engine: `Godot v4.7.2.stable.official.ed1daf0bf` (`C:\Users\Yurtachi\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`).

Required verification command:
```text
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/run_tests.gd
```

Execution result:
- Exit code: **0**
- Test output:
  - `test_sim_world.gd: ok`
  - `test_smoke.gd: ok`
  - Zero errors or script warnings emitted.

## Limits and integration notes

- No Python runtime libraries or binary DLLs were vendorized, keeping the repository 100% compliant with offline local execution.
- Kenney spritesheets and cropped tiles are ready for consumption by the UI worker (`scenes/`, `scripts/ui/`, `scripts/render/`).
- Morphology rendering rule remains intact: animal sprites serve as visual guidelines for procedural body generation (`assets/procedural/`).
