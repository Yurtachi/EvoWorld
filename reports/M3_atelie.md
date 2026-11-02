# M3 — ateliê, quadro de desenho e cópia motor-vetorial de formas (E3.5 / X4)

[FATO] Data: 02/11/2026. Base `evo3/integration` @ `f0c1f58`, branch local
`Yurtachi/evo3-m3-sim2`. Implementação, persistência v10 e compatibilidade:
**PASS**; experimento pré-registrado X4 nos critérios de holdout: **PASS**
global e **PASS** em cada uma das três formas (`linha`, `circulo`, `quadrado`).
Não se afirma compreensão semântica, escrita simbólica nem consciência.

[FATO] 20 suítes unitárias passaram (`godot --headless --path . -s tests/run_tests.gd`,
exit 0): as 19 suítes anteriores preservadas integralmente mais `test_sim_m3.gd`.
O holdout do experimento X4 foi aberto uma única vez, com 24 seeds inéditas
(`118401–118424`) pareadas nos 4 braços e nas 3 formas (288 ensaios). Não houve
push, merge, edição em `scripts/ui` ou `scripts/render`, uso de código GPL,
TensorFlow, dataset QuickDraw ou LLM.

## 1. Quadro no mundo, primitivas de traço e limites (E3.5)

[FATO] `world.place_board(pos)` posiciona um quadro físico no mundo (raio `6.0`,
limite `BOARD_LIMIT = 32`), rejeitando coordenadas não finitas (`NaN`/`INF`),
posições fora dos limites do mundo ou colisões com obstáculos/objetos/quadros
existentes (retornando `-1`). Todo desenho produzido no quadro resulta
exclusivamente da execução determinística de uma sequência finita de ações
primitivas discretas em `Atelier.execute_actions(actions)`:
- `move_pen`: move a caneta sem riscar (fecha eventual traço ativo);
- `pen_down`: baixa a caneta na posição atual do canvas (`64.0 × 64.0`);
- `pen_up`: levanta a caneta e consolida o traço ativo;
- `segment`: avança a caneta em uma dentre `DIRECTIONS = 16` direções angulares
  discretas (`0..15`, passo `22,5°`) e um dentre `3` comprimentos discretos
  (`LENGTHS = [2.0, 3.0, 4.5]`). Curvas (como `circulo`) são formadas unicamente
  por segmentos retos discretos; jamais se sorteia ou carrega imagem pronta.

[FATO] Cada artefato concluído expõe simultaneamente a sequência de ações
primitivas (`actions`), as polilinhas resultantes (`strokes`) e a representação
vetorial compacta `stroke3` (`[dx, dy, pen_state]`, inspirada apenas como ideia
de formato em Sketch-RNN, conforme `docs/EVOWORLD_3_REUSE.md`, sem rede neural
externa nem dataset). Limites estritos são impostos na execução e na validação
de persistência:
- `MAX_STROKES_PER_DRAWING = 8` traços por desenho;
- `MAX_POINTS_PER_STROKE = 24` pontos por traço;
- `MAX_POINTS_PER_DRAWING = 64` pontos totais por desenho;
- `MAX_ACTIONS_PER_DRAWING = 64` ações primitivas por desenho;
- `MAX_STEPS_PER_TICK = 2` segmentos executados por tick de desenho;
- `GALLERY_LIMIT = 64` artefatos na galeria do mundo, `BOARD_ARTIFACT_LIMIT = 16`
  por quadro e `ATTEMPT_LIMIT = 32` tentativas no histórico individual.

[FATO] Todo artefato concluído recebe ID único do mundo, título nomeado
(`"<Forma> #<n> de <Nome>"`), tick de criação (`created_tick`), dono
(`owner_id` e `owner_name`), `board_id`, `target_shape`, `actions`, `strokes`,
`stroke3` e `error`. Na desserialização (`Atelier.valid_artifact`), o motor
re-executa `execute_actions(art["actions"])` e rejeita qualquer save cujos
`strokes` ou `stroke3` divirjam da sequência real de ações primitivas.

## 2. Motivação `'desenhar'`, percepção e memória de objetos

[FATO] O quadro é percebido sensorialmente pela criatura dentro do alcance e
cone de visão com checagem de oclusão (`sensors["boards"]`), integrando-se ao
`ObjectMemory` (`scripts/mind/object_memory.gd`) sob a categoria `"quadro"` e
aparência `"quadro"`. Observar um quadro atualiza a entrada de memória de
instância e categoria sem conceder energia, hidratação ou competência.

[FATO] Em `Motivation.choose()` (`scripts/mind/motivation.gd`), o objetivo
`"desenhar"` compete com os objetivos de base quando há quadro percebido:
- A pontuação em `Atelier.candidate()` combina novidade do quadro em
  `ObjectMemory`, ociosidade física (`1.0 - max(hunger, thirst) * 1.6 - fatigue * 0.6`),
  bônus de demonstração ativa no quadro (`+0.22`), modulados por `curiosity`,
  `entusiasmo` e `personality.boredom`, e penalizados por `receio` e `caution`.
- Quando não há quadros no sensor (`sensors.get("boards", [])` vazio),
  `"desenhar"` não consome sorteio adicional do RNG mental, preservando 100% da
  trajetória de números pseudoaleatórios e os digests golden de M1, M1b e M2.
- Fome ou sede críticas (`hunger > 0.55` ou `thirst > 0.55`) interrompem e
  prevalecem sobre `"desenhar"`, desviando a criatura para busca de alimento ou
  água.
- Anti-loop e compromisso: `"desenhar"` respeita compromisso mínimo de `12`
  ticks, tempo máximo de `80` ticks por sessão e cooldown de `DRAW_COOLDOWN = 90`
  ticks após conclusão ou timeout.
- Cada tick de execução de traço (`last_action = "draw_stroke"`) aplica um custo
  energético físico pequeno e real (`DRAW_ENERGY_COST = 0.012`), sem qualquer
  recompensa metabólica ao concluir o desenho.
- Sem forma de referência demonstrada no quadro (`reference_shape == ""`), a
  criatura motivada realiza rabiscos exploratórios (`target_shape = "rabisco"`).

## 3. Aprendizado real de copiar formas e distância de Chamfer

[FATO] `world.demonstrar_forma(board_ref, forma, params)` registra no quadro uma
demonstração de referência para as formas `"linha"`, `"circulo"` ou `"quadrado"`,
com parâmetros opcionais de centro (`center`), escala (`scale` em `[0.45, 1.6]`)
e rotação discreta (`dir_offset` em `0..15`). O erro entre o desenho executado
pela criatura e os traços de referência é medido por `Atelier.chamfer_distance`:
- As polilinhas são reamostradas uniformemente por segmento
  (`SAMPLES_PER_SEGMENT = 4`), centralizadas na média (invariância a translação)
  e normalizadas pelo raio quadrático médio RMS (invariância a escala).
- A distância de Chamfer simétrica média entre as nuvens normalizadas é escalada
  e truncada em `[0, 1]` com precisão `1e-6`. O limiar pré-fixado de sucesso é
  `SUCCESS_THRESHOLD = 0.22`.

[FATO] A política de traços em `scripts/atelier/atelier.gd` é puramente
paramétrica e treinável por criatura (sem LLM, sem gradiente externo):
- A cada passo com referência visível, o erro residual entre o ponto-alvo da
  demonstração e a posição virtual do traço é discretizado em `s_dir` (`0..15`)
  e faixa de magnitude `s_mag` (`0..2`).
- Uma criatura sem treino (`naive`, `updates == 0`) possui um mapeamento motor
  inicial descalibrado (`_uncalibrated_dir` e `_uncalibrated_len`), produzindo
  traços sistematicamente enviesados que não fecham polígonos nem acompanham o
  eixo da referência.
- O braço `random` escolhe direção (`0..15`) e comprimento (`0..2`)
  uniformemente via RNG mental, gerando rabiscos erráticos.
- Nos braços treináveis (`trained`), `apply_feedback` atualiza as tabelas
  limitadas em `[-1, 1]` (`offset_weights` de 16 entradas, `dir_weights` de 256
  entradas e `len_weights` de 9 entradas) por subida de encosta (hill-climbing)
  guiada pela redução do erro residual e da distância de Chamfer. Nenhuma
  recompensa adiciona energia ou hidratação ao corpo. A competência persiste
  individualmente no save v10 da criatura e não é herdada por reprodução.

## 4. Escopo de escrita e símbolos (M3a vs M3b)

[FATO] Conforme a especificação (`docs/EVOWORLD_3_SPEC.md`, E3.5 vs E3.6),
**escrita, letras e símbolos não foram implementados neste marco (M3a)**.
Chamadas a `world.demonstrar_forma(board, "letra_A")` ou `"simbolo"` são
rejeitadas (`false`) e cobertas por teste unitário em `test_sim_m3.gd`.

[LACUNA] Símbolos discretos, associação símbolo–conceito e persistência cultural
em biblioteca pertencem exclusivamente ao marco **M3b (E3.6 — Biblioteca /
Símbolos)** e só poderão entrar no motor acompanhados de avaliação experimental
própria pré-registrada.

## 5. Pré-registro, congelamento e auditoria do experimento X4

[FATO] Sequência de commits separados antes da abertura do holdout:
1. Pré-registro (`prereg_commit`): `c9a4e31` (`tests/experiments/m3_atelier_preregistro.md`,
   SHA-256 em LF: `717fab65bbe92c2689a648c7e40b956ea758651ba5d41ab0442c5ac6a59b6251`).
2. Motor e avaliador congelados (`evaluator_commit`): `bf21e01`
   (`scripts/atelier/atelier.gd`, `tests/experiments/m3_atelier_eval.gd`,
   `tests/experiments/m3_atelier_verify.py`).
3. Abertura única do holdout (`result_commit`): `e276299`
   (`reports/M3_atelie_eval.json`, SHA-256 em LF:
   `ebfa2ab144784294b9af0635ed625d1268313a5497378ae297502282a28cf29c`).

[FATO] Partições de sementes disjuntas:
- `TRAIN`: `118101–118104` (4 seeds);
- `DEV`: `118201–118206` (6 seeds);
- `HOLDOUT`: `118401–118424` (24 seeds inéditas, 4 braços × 3 formas = 288 linhas).
O avaliador grava e sincroniza `status = "opened"` antes do primeiro ensaio e
aborta com código `2` se `reports/M3_atelie_eval.json` já existir. Os scripts
`tests/experiments/verify_prereg.sh` e `tests/experiments/m3_atelier_verify.py`
auditam ancestralidade Git, imutabilidade do pré-registro, hashes SHA-256 dos 9
arquivos congelados do motor/avaliador e integridade das 288 linhas (PASS).

## 6. Resultados do HOLDOUT X4 (24 seeds, 288 ensaios)

[FATO] No holdout (`reports/M3_atelie_eval.json`), cada tentativa de avaliação
testa a cópia em um quadro posicionado em local novo com três transformações
inéditas de posição, escala contínua (`0.82`, `1.23`, `1.41`) e rotação angular
(`dir_offset` deslocado por seed), não vistas durante as 12 tentativas de
aquisição na configuração padrão (`centro = (32, 32)`, `escala = 1.0`,
`dir_offset = 0`).

### 6.1 Desempenho global por braço (72 ensaios por braço)

| Braço | Erro mediano (holdout) | Taxa de sucesso (`< 0.22`) | Erro inicial mediano (tent. 1–3) | Erro final mediano (tent. 10–12) | Melhoria mediana | Erro mediano pós-`save/load` | Sucesso pós-`save/load` | Erro mediano pós-2000 ticks ociosos | Sucesso pós-2000 ticks |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `random` (rabisco) | `0.332612` | `0.00%` | `0.338093` | `0.337270` | `+0.000823` | `0.353985` | `5.56%` | `0.351578` | `2.78%` |
| `naive` (sem treino) | `0.336012` | `0.00%` | `0.309652` | `0.309652` | `0.000000` | `0.331337` | `6.94%` | `0.331337` | `6.94%` |
| `trained_frozen` | `0.000001` | `100.00%` | `0.252010` | `0.000003` | `+0.252007` | `0.000001` | `100.00%` | `0.000001` | `100.00%` |
| `trained_online` | `0.000001` | `100.00%` | `0.252010` | `0.000003` | `+0.252007` | `0.000001` | `100.00%` | `0.000001` | `100.00%` |

### 6.2 Desempenho por forma no holdout (24 seeds por célula)

| Forma | `random` erro med. (sucesso) | `naive` erro med. (sucesso) | `trained_frozen` erro med. (sucesso) | `trained_online` erro med. (sucesso) | Melhoria média no treino (`early -> late`) | Status da forma |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| `linha` | `0.436619` (`0.0%`) | `0.347298` (`0.0%`) | `0.000001` (`100.0%`) | `0.000001` (`100.0%`) | `+0.391228` (`0.391230 -> 0.000002`) | **PASS** |
| `circulo` | `0.305221` (`0.0%`) | `0.338321` (`0.0%`) | `0.000002` (`100.0%`) | `0.000002` (`100.0%`) | `+0.233085` (`0.233088 -> 0.000003`) | **PASS** |
| `quadrado` | `0.305438` (`0.0%`) | `0.318917` (`0.0%`) | `0.000002` (`100.0%`) | `0.000002` (`100.0%`) | `+0.252006` (`0.252010 -> 0.000004`) | **PASS** |

### 6.3 Verificação das hipóteses pré-registradas

- [HIPOTESE] **H1 (`H1_global_vs_controls` — PASS)**: `trained_frozen` e
  `trained_online` atingiram erro mediano `0.000001` (`< 0.18`) e taxa de
  sucesso de `100.0%` (`>= 75%`), reduzindo o erro mediano em `0.332611` frente
  a `random` e `0.336011` frente a `naive` (acima do mínimo pré-registrado de `0.20`).
- [HIPOTESE] **H2 (`H2_honest_per_shape` — PASS)**: nas três formas isoladas
  (`linha`, `circulo`, `quadrado`), tanto `trained_frozen` quanto `trained_online`
  obtiveram erro mediano `<= 0.000002` (`< 0.20`) e taxa de sucesso `100.0%`
  (`>= 70%`).
- [HIPOTESE] **H3 (`H3_naive_distinguishable` — PASS)**: a criatura sem treino
  (`naive`) apresentou erro mediano `0.336012` (`> 0.30`) e taxa de sucesso
  `0.0%` (`< 25%`), diferindo em `100` pontos percentuais dos braços treinados.
- [HIPOTESE] **H4 (`H4_improvement_vs_attempts` — PASS)**: a queda mediana de
  erro entre as tentativas iniciais (`1–3`) e finais (`10–12`) foi de `0.252007`
  (queda média de `0.292106`, `>= 0.20`).
- [HIPOTESE] **H5 (`H5_retention_saveload` — PASS)**: `100%` dos 288 ensaios
  preservaram `World.from_dict(w.to_dict())` byte a byte (`roundtrip = true`),
  replay exato das ações primitivas (`actions_replay_ok = true`) e ausência de
  ganho energético (`no_energy_gain_on_reward = true`), mantendo erro mediano
  `0.000001` e `100.0%` de sucesso após `save/load`.
- [HIPOTESE] **H6 (`H6_retention_idle_2000` — PASS)**: após `2000` ticks de
  simulação física ociosa sem quadros no mundo, a competência retida manteve
  erro mediano `0.000001` e `100.0%` de sucesso quando um novo quadro foi
  apresentado.

[LACUNA] Como `offset_weights` aprende o alinhamento angular relativo
`delta_dir = (cand_dir - s_dir) mod 16`, 12 episódios de aquisição já saturam o
alinhamento ótimo (`delta_dir = 0`, `cand_len = s_mag`), fazendo com que
`trained_frozen` e `trained_online` empatem no piso numérico da discretização
(`~1e-6`). Em ruído motor contínuo ou formas abertas assimétricas de múltiplos
traços, espera-se divergência adicional entre política congelada e adaptação
online.

## 7. Persistência v10, API para UI, textos e CPU

[FATO] `SimWorld.SAVE_VERSION` foi atualizado para `10` (`scripts/world/sim_world.gd`
e `scripts/persistence/save_store.gd`), com migração idempotente de saves `v1` a
`v9` (adicionando `boards = []` e `gallery = []` quando ausentes) e validação
estrita em `World.from_dict` e `SimCreature.from_dict`. Entradas hostis (pesos
`NaN`/`INF`, tipos inválidos, `actions` com mais de 64 passos, `strokes` com
mais de 8 traços ou 64 pontos, ou `strokes` que não correspondam à execução real
de `actions`) são recusadas com retorno `null`.

[FATO] API exposta para consumo futuro de UI/render (sem editar `scripts/ui` ou
`scripts/render`):
- `world.boards` e alias `world.quadros`: lista de quadros ativos no mundo;
- `world.gallery` e alias `world.galeria`: galeria persistida de artefatos;
- `creature.atelier_snapshot()`: retorna dicionário com `active`, `policy_mode`,
  `learning`, `updates`, `competence` por forma (`learned`, `attempts`,
  `successes`, `best_error`, `last_error`), `attempts` e alias
  `historico_tentativas`;
- `scripts/core/textos.gd`: seção M3 adicionada ao final (`M3_CATALOGO` e
  `M3_UI`), 100% em pt-BR, utilizando `"parece"` e nunca `"sente"`.

[FATO] Medição serial de CPU com quadro ativo e forma demonstrada em
`reports/M3_atelie_cpu.json` (`tests/experiments/m3_atelier_cpu.gd`, 60 ticks de
warmup + 300 ticks medidos por população, comparando `mind_off` vs `pet_only`):

| População (`creature_count`) | `mind_off` média (ms/tick) | `mind_off` p50 / p95 (ms/tick) | `pet_only` média (ms/tick) | `pet_only` p50 / p95 (ms/tick) | Delta médio (`pet_only - mind_off`) | Artefatos gerados (`pet_only`) |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `12` | `1.5271` | `1.417` / `2.186` | `1.5634` | `1.446` / `2.322` | `+0.0363 ms` | `0` |
| `30` | `3.8234` | `3.373` / `6.489` | `3.3492` | `3.284` / `4.135` | `-0.4742 ms` | `1` |
| `60` | `7.2539` | `7.103` / `8.776` | `7.3899` | `7.301` / `8.740` | `+0.1360 ms` | `5` |
| `100` | `14.0014` | `13.543` / `17.225` | `14.3287` | `13.979` / `17.822` | `+0.3273 ms` | `4` |

[FATO] O overhead da mente ativa no pet com quadro e ateliê permaneceu abaixo de
`0.35 ms/tick` em todas as faixas até 100 criaturas, mantendo o orçamento de
simulação dentro da meta de tempo real.

---

## Revisão do coordenador (leitura do código de `scripts/atelier/atelier.gd`) — reclassificação do X4

[FATO] A auditoria de ordem pré-registro→motor→holdout passa (`verify_prereg.sh`), 20 suítes exit 0, e o save v10 preserva quadros e competência.

[FATO] **O X4 não demonstra “aprender a copiar formas”.** Em `step_drawing`, a criatura recebe a cada passo o **vértice exato seguinte da referência** (`err_vec = target_pt - virtual_pos`) e escolhe direção/comprimento a partir de buckets desse erro. O que o treino aprende é uma **calibração** direção/comprimento. O baseline `naive` usa deliberadamente um mapeamento descalibrado (`_uncalibrated_dir = (s_dir/2 + 5) % 8`), logo falha **por construção**. Falta o controle decisivo: um **servo geométrico sem aprendizado** (mover-se na direção do erro), que provavelmente atinge erro próximo de zero sem nenhum treino.

[CLASSIFICAÇÃO] X4 = **PARTIAL (não demonstrado como aprendizado de cópia)**. O que se sustenta: o sistema produz traços como sequência real de ações primitivas, persiste desenhos, e a política aprende a corrigir um mapeamento motor deliberadamente errado. O que **não** se sustenta: “a criatura copia círculo/quadrado/linha por observação”. O erro mediano ≤ 2e-6 com 100% de sucesso reflete rastreamento de pontos dados, não generalização.

[PRÓXIMO PROTOCOLO (M3b, novo pré-registro, sementes novas)] (1) a criatura **observa** a demonstração e depois reproduz **de memória**, sem receber os vértices a cada passo; (2) baselines: aleatório, servo geométrico sem aprendizado, memória sem treino; (3) formas inéditas no holdout (ex.: triângulo, cruz) e escalas/ruído motor; (4) métricas de erro de forma sobre o traço produzido, retenção após save/load.
