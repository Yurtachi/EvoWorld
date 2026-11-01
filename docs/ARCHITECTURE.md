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

## Contratos integrados da UI2 (01/11/2026)

O contrato inicial acima descreve a primeira etapa. O mundo integrado usa save v3 e migra versões 1 e 2; genealogia, sinais e ordens são persistidos pelo simulador. A UI não acrescenta campos ao schema do mundo.

- `world.lineage(creature_id)` e `world.descendants(creature_id)` devolvem cópias dos registros permanentes. Cada registro inclui genoma, genitores, geração, nascimento, morte e mutações. `world.genetic_diversity()` informa variância dos seis genes na população viva.
- `world.comandos` é a instância usada pela UI e pelo executor físico. A UI não a substitui ao carregar; restaura o marcador de alvo a partir de `comandos.to_dict(world).order.target`, preservando ordens de seguir no primeiro quadro.
- `Dialogo.interpretar(texto)` reconhece intenções; `Dialogo.responder(intent, criatura, world)` fornece narração e evidências sem aplicar ações. A UI chama `comandos.aplicar` e mostra o recibo separadamente.
- `world.emitir_sinal(id, symbol)` aplica custo e regras do canal. `signal_log` contém `{tick, emitter, symbol, context, receivers, action_changes}`; contexto contém `saw_food/low_energy`, e cada decisão registrada contém `receiver/tick/before/after`. A apresentação traduz ações e não infere causalidade ou semântica.
- `scripts/ui/laboratory.gd` e `population_chart.gd` guardam até 180 amostras observadas, uma a cada 50 passos. As curvas são locais à sessão, sem escrita em genes ou registros do mundo.
- A proteção da UI é pausa preventiva antes de um passo com energia do companheiro ≤15% ou idade no limite. Não altera fisiologia. A configuração pessoal não é uma promessa de proteção em execuções headless externas.
- `SaveStore` continua dono de gravação/validação. UI usa slots separados `world` e `autosave`, sem mudar o envelope. Preferências ficam em `user://ui-settings.cfg`; testes e capturas usam arquivos isolados.
- Textos novos da UI ficam em `scripts/core/textos.gd`; códigos e chaves JSON continuam intactos. `verify_ui.gd` valida a integração da cena, APIs, arquivos e resolução mínima.
