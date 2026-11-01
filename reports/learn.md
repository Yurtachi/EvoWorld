# LEARN worker report (gate G2)

## 1. Pre-registration (written and committed BEFORE any full experiment run)

This section is fixed before any holdout episode is executed. Results are appended
in later sections; this section must not be edited after the first full run
(git history shows the order). Development runs before the full run use
`-- --dev`, which only executes 3 TRAIN seeds and never touches HOLDOUT seeds; they
exist only to catch crashes and measure runtime.

### Task
Simple foraging task in the existing SimWorld ecology: find and eat food to survive.
Creatures only see food/obstacles within their genome vision range/FOV and not
occluded by obstacles.

### Learner
Tabular Q-learning (`scripts/behavior/q_brain.gd`), 48 discrete states x 5 actions.
- Observation (`scripts/behavior/observation.gd`): nearest *visible* food bucket
  (none / within reach / near-left / near-ahead / near-right / far-left / far-ahead /
  far-right; near = 60 units, ahead = |angle| <= 0.25 rad), energy bucket
  (<35% / <70% / else), obstacle-or-wall ahead (bool, only perceived obstacles).
- Actions (`scripts/behavior/actions.gd`): forward, turn_left, turn_right (0.5 rad then
  move), eat (succeeds only if food within reach = size+5), rest.
- Reward: real energy change between consecutive decisions (energy gained by eating
  minus metabolic/movement cost minus damage; there is no damage source in the sim,
  so that term is 0). Death adds -25. No reward for actions, proximity or eating attempts.
- alpha 0.1, gamma 0.97, epsilon = max(0.02, 0.3 * 3000 / (3000 + steps)), Q init 0,
  first-index tie-break.

### Environment (fixed)
SimWorld default size 1200x760; config `creature_count 8, food_count 30,
food_capacity 40, food_regrow true, food_regrow_interval 10, food_regrow_batch 1,
obstacle_count 10`. Episode = up to 3000 ticks (300 s sim time) or until all 8 die.
All 8 creatures in a world use the same condition. Same seed => identical initial
world (obstacles, food, genomes, positions, headings) for every condition.

### Seeds
- TRAIN: 1001-1010. HOLDOUT: 7001-7010 (never used for training or tuning).

### Conditions
- `random`: uniform random discrete action (non-learning control, same action set/physics).
- `heuristic`: existing SIM baseline (`brain == null`; has hand-coded continuous steering
  towards food and reflexive obstacle avoidance that the discrete policies lack).
- `learner_naive`: fresh zero Q-table per creature, learning online during its single life.
- `learner_trained`: per-creature copy of the Q-table trained on TRAIN seeds, continues
  learning online (epsilon at its decayed value).
- `learner_frozen`: same checkpoint, learning disabled, greedy (ablation).

### Training
4 passes over the 10 TRAIN seeds (40 episodes). The 8 creatures of a training world
pool experience into one shared Q-table (starts at zero), carried across episodes.

### Metrics and unit of analysis
Per episode: mean food items eaten per creature and mean survival ticks per creature
(age at death, or ticks run if alive). Unit of analysis = seed (episode mean), paired
across conditions by seed. Sign test (ties count as losses), one-sided exact p.

### Success criteria (evaluated on HOLDOUT seeds only)
- **H1** (learned policy beats non-learning control): `learner_trained` has higher
  food/creature than `random` in >= 9 of 10 holdout seeds (p <= 0.011) AND mean
  survival ticks >= 1.2 x `random`.
- **H2** (the improvement comes from experience): `learner_trained` has higher
  food/creature than `learner_naive` in >= 9 of 10 holdout seeds.
- **Overall G2 learning claim = H1 AND H2.** If either fails, the claim is reported
  as failed and not reworded as success.
- Secondary / descriptive (no success claim depends on them): H3 `learner_naive` beats
  `random` in >= 8/10 holdout seeds (in-lifetime learning from scratch);
  `learner_frozen` vs `random`; `learner_trained` vs `heuristic` (no prediction made);
  training curve first vs last pass; the same tables on TRAIN seeds.

### Command
`godot --headless --path . -s tests/experiments/learn_eval.gd` (writes
`tests/experiments/results/learn_eval_results.json` and `trained_brain.json`).
