# Pré-Registro — Experimento X5 (M3b: Cópia de Formas por Observação e Memória)

## 1. Contexto e Correção Estrutural do Experimento X4

Na revisão do coordenador em `reports/M3_atelie.md`, o Experimento X4 (M3) foi reclassificado para **FAIL** no objetivo de aprendizado real de cópia por apresentar duas falhas metodológicas:
1. **Acesso indevido aos vértices da referência durante a reprodução**: `Atelier.propose_actions` lia `reference_strokes` passo a passo durante o traço e calculava o ângulo exato de cada segmento da demonstração.
2. **Baseline `naive` artificialmente descalibrado**: com acesso aos vértices, um servo geométrico sem aprendizado já copiaria a forma, e o braço `naive` só falhava porque adicionava um viés fixo (`dir_bias = 3`).

O **Experimento X5 (M3b)** corrige integralmente o desenho do ateliê em quatro fases estritas, sem acesso aos vértices da referência durante a reprodução:

1. **Fase 1 — Observação (`observe_demonstration`)**:
   - Quando uma demonstração está visível na lousa (dentro do alcance sensorial e sem oclusão), a criatura observa a sequência de traços como observação perceptual ruidosa no formato `stroke-3` (`[dx_obs, dy_obs, pen_state]`), limitada em capacidade (`MAX_MEMORY_SEGMENTS = 8` segmentos por forma, `MEMORY_SLOT_LIMIT = 6` formas na memória).
   - A criatura extrai e armazena em `shape_memory[forma]` apenas uma representação perceptual compacta invariante a translação e escala: direção inicial discretizada (`anchor_dir` em `0..15`), sequência de curvas relativas discretizadas (`rel_turns` em `-8..+8`), comprimentos relativos normalizados (`rel_lens` em `0..2`), ângulos relativos observados (`turn_rads`) e a sequência observada `stroke3`.
   - Criatura que **não observou** a demonstração (fora do campo de visão, ocluída, sem demonstração prévia ou com observação desabilitada) **não possui a forma na memória** e é incapaz de reproduzi-la.

2. **Fase 2 — Reprodução (`propose_actions` / `reproduzir_forma`) SEM acesso aos vértices da referência**:
   - `propose_actions(shape, rng)` recebe **apenas** o identificador da forma e o gerador pseudoaleatório; **não recebe** `reference_strokes` nem coordenadas da lousa.
   - O traço é produzido em malha aberta (*open-loop*) a partir de `shape_memory[shape]`, sujeito à dinâmica física do membro/pincel (deriva postural `PHYSICAL_WRIST_DRIFT = -0.26`, complacência/inércia angular em esquinas `PHYSICAL_TURN_COMPLIANCE = 0.64`) e ruído motor (`MOTOR_ANG_NOISE = 0.38`).

3. **Fase 3 — Feedback Escalar (`avaliar_quadro` / `apply_feedback`)**:
   - Após concluir a tentativa na lousa, a criatura recebe **exclusivamente o erro escalar** `error` em `[0.0, 1.0]` (distância de Chamfer simétrica normalizada por centróide e escala RMS), sem acesso aos vértices da referência e sem gradiente analítico.

4. **Fase 4 — Aprendizado Sensorimotor (`decoder_params` / `best_params`)**:
   - A criatura ajusta seus parâmetros internos persistidos (`decoder_params = [drift_comp, turn_comp, precision]`, 3 parâmetros escalares contínuos por criatura) via busca local (*hill-climbing* estocástico guiado apenas pelo erro escalar de Chamfer) e consolida a memória perceptual ao observar demonstrações repetidas durante o treino.
   - O estado aprendido é persistido por criatura em save `v11` (`Atelier.VERSION = 2`, com migração idempotente `v1..v10 -> v11`), **jamais é herdado geneticamente** na reprodução e **jamais concede energia ou hidratação**.
   - A capacidade avaliada é estritamente **cópia motora de formas geométricas simples por observação e memória** (nunca descrita como "aprendeu a escrever" ou linguagem simbólica).

---

## 2. Hipóteses Pré-Registradas (H1–H7)

- **H1 (Curva de aquisição por tentativas)**: Nas formas de treino (`linha`, `circulo`, `quadrado`), a mediana do erro de Chamfer nas tentativas finais de treino (`late_train_error`) é menor que nas tentativas iniciais (`early_train_error`), com redução mediana `(early_train_error - late_train_error) >= 0.14`.
- **H2 (Superioridade sobre baselines sem aprendizado nas formas de treino)**: Em avaliação nas formas de treino com novas posições, escalas e rotações, os braços `trained_frozen` e `trained_online` atingem mediana de erro `< 0.18`, taxa de sucesso (`erro < 0.22`) `>= 75%`, e superam os três baselines honestos sem aprendizado (`random`, `naive` / `memoria_sem_treino`, e `servo_geometrico`) por margem mediana `>= 0.10`.
- **H3 (Generalização para formas inéditas de holdout)**: Em formas **inéditas nunca vistas no treino** (`triangulo`, `cruz`, `zigue_zague`), avaliadas com novas posições, escalas, rotações e ruído motor, `trained_frozen` e `trained_online` atingem mediana de erro `< 0.20`, taxa de sucesso (`erro < 0.22`) `>= 70%`, e superam `random`, `naive` (`memoria_sem_treino`) e `servo_geometrico` por margem mediana `>= 0.08`.
- **H4 (Honestidade dos baselines e do teto oráculo)**:
  - `servo_geometrico` (cópia geométrica 1:1 da memória perceptual ruidosa sem calibração motora e sem acesso aos vértices na reprodução) apresenta erro mediano menor que `naive` (`memoria_sem_treino`), porém falha em compensar a complacência física de esquina e o ruído em malha aberta (`mediana >= 0.22`).
  - `oraculo` (observação sem ruído e inversão física exata como teto teórico) atinge erro mediano `< 0.02` e taxa de sucesso `100%`.
- **H5 (Retenção após `save/load` v11 e após `2000` ticks sem treino)**: No braço `trained_frozen`, a habilidade motora e a memória de formas persistem após serialização/desserialização completa (`save/load` v11) e após `2000` ticks de simulação sem treino na lousa, mantendo mediana de erro `< 0.20` e degradação absoluta `<= 0.05` em relação à avaliação imediata pós-treino, inclusive quando a demonstração da lousa é limpa e a criatura reproduz puramente da memória retida.
- **H6 (Dependência estrita de observação)**: Uma criatura treinada na política motora mas que **não observou** a demonstração de uma forma (ex.: ocluída/fora de visão ou sem observação prévia) não consegue reproduzir a forma (`erro mediano >= 0.28`, `has_observed == false`).
- **H7 (Isolamento metabólico e determinismo)**: O uso da lousa (observação, reprodução e feedback) altera `energy` e `water` em exatamente `0.0`, e duas execuções com a mesma seed produzem resultados bit-a-bit idênticos.

---

## 3. Braços Experimentais (6 Condições)

1. **`random` (Aleatório)**: Emite ações primitivas de pincel (`move_pen`, `pen_down`, 8 `segment` com direções `0..15` e comprimentos `0..2` uniformemente aleatórios, `pen_up`), ignorando a memória.
2. **`naive` (`memoria_sem_treino`)**: Observa a demonstração com ruído perceptual e reproduz a partir de `shape_memory` usando os parâmetros motores iniciais não calibrados da criatura (`decoder_params = [0.62, -0.44, 0.0]`, `learning = false`).
3. **`servo_geometrico` (Servo Geométrico sem Aprendizado)**: Observa a demonstração com ruído perceptual e copia a sequência da memória com mapeamento geométrico nominal 1:1 (`decoder_params = [0.0, 0.0, 0.0]`, `learning = false`), **sem acesso aos vértices da referência durante a reprodução** e sem compensação aprendida para a deriva/complacência física do traço em malha aberta.
4. **`trained_frozen` (Treinado Congelado)**: Parte da mesma inicialização de `naive`, treina por `8` tentativas em cada uma das `3` formas de treino (`linha`, `circulo`, `quadrado`) usando apenas feedback escalar de Chamfer, e em seguida tem `learning = false` (`policy_mode = "frozen"`) durante toda a avaliação de transferência, generalização para formas inéditas e retenção.
5. **`trained_online` (Treinado Online)**: Idêntico a `trained_frozen` na fase de treino, mantendo `learning = true` durante a avaliação.
6. **`oraculo` (Oráculo / Teto de Referência)**: Codifica a demonstração sem ruído perceptual e executa a reprodução com inversão exata da planta física (`decoder_params = [0.26, 0.5625, 1.0]`, ruído zero), estabelecendo o teto geométrico da discretização em 16 direções.

---

## 4. Formas de Treino e Formas Inéditas de Holdout

Todas as formas são traçadas em canvas `64.0 x 64.0` com `8` segmentos discretos (`DIRECTIONS = 16`):

### 4.1. Formas de Treino (`TRAIN_SHAPES`)
- **`linha`**: 8 segmentos colineares (`[0, 0, 0, 0, 0, 0, 0, 0]`).
- **`circulo`**: octógono regular inscrito (`[0, 2, 4, 6, 8, 10, 12, 14]`, curvas constantes de `+45°`).
- **`quadrado`**: contorno fechado de 4 lados (`[0, 0, 4, 4, 8, 8, 12, 12]`, três esquinas de `+90°`).

### 4.2. Formas Inéditas de Holdout (`HOLDOUT_SHAPES` — nunca apresentadas no treino)
- **`triangulo`**: triângulo isósceles fechado (`[0, 0, 5, 5, 5, 11, 11, 11]`, esquinas agudas de `+112.5°` e `+135°`).
- **`cruz`**: cruz simétrica de 4 braços em `+` (`[0, 8, 8, 0, 4, 12, 12, 4]`, reversões de `180°` e cruzamento central de `90°`).
- **`zigue_zague`**: onda dente-de-serra de 4 dentes (`[3, 3, 13, 13, 3, 3, 13, 13]`, alternância de esquinas `+135°` e `-135°`).

---

## 5. Divisão de Seeds e Protocolo de Avaliação

Para garantir independência estatística total em relação aos experimentos anteriores (`M1`, `M2`, `X4/M3` que usou `118101..118424`), o Experimento X5 utiliza faixas de seeds inéditas e disjuntas:

- **`TRAIN_SEEDS` (4 seeds)**: `129101, 129102, 129103, 129104`
- **`DEV_SEEDS` (6 seeds)**: `129201, 129202, 129203, 129204, 129205, 129206`
- **`HOLDOUT_SEEDS` (24 seeds inéditas)**: `129401` a `129424` (24 seeds)

### Protocolo por Seed e por Braço
1. **Fase de Aquisição (Treino nas 3 Formas de Treino)**:
   - Para cada forma em `["linha", "circulo", "quadrado"]`, a criatura realiza `8` tentativas (`24` tentativas totais de treino), variando a orientação (`dir_offset`) a cada tentativa.
   - A cada tentativa, a lousa demonstra a forma (a criatura à distância visível observa e atualiza `shape_memory`), a criatura reproduz o traço a partir da memória sem acesso a `reference_strokes`, e recebe apenas o erro escalar de Chamfer.
   - Métrica de aquisição: `early_train_error` (média da 1ª tentativa de cada forma antes de convergência ou tentativa inicial) vs `late_train_error` (média das 2 últimas tentativas de treino).
2. **Fase de Avaliação em Formas de Treino Transformadas (`train_shapes_eval`)**:
   - No braço `trained_frozen`, congela-se `learning = false` (`policy_mode = "frozen"`).
   - Cada forma de `TRAIN_SHAPES` é demonstrada em `3` configurações transformadas (novos centros `Vector2`, novas escalas `0.80..1.30` e novas rotações `dir_offset`), totalizando `9` avaliações por seed (`216` avaliações nas 24 seeds de holdout por braço).
3. **Fase de Generalização para Formas Inéditas (`holdout_shapes_eval`)**:
   - Cada forma inédita de `HOLDOUT_SHAPES` (`triangulo`, `cruz`, `zigue_zague`) é demonstrada em `3` configurações transformadas (novas posições, escalas `0.85..1.25` e rotações `dir_offset` dependentes da seed e do trial), totalizando `9` avaliações de formas inéditas por seed (`216` avaliações nas 24 seeds de holdout por braço).
4. **Fase de Controle Sem Observação (`unobserved_control_eval`)**:
   - A criatura treinada é avaliada em uma lousa cuja forma foi demonstrada fora do seu alcance visual (`observation_enabled = false` / fora de linha de visão, sem entrada prévia em `shape_memory`), verificando que sem observação não há reprodução (`H6`).
5. **Fase de Retenção (`retention_save_load` e `retention_2000_ticks`)**:
   - O mundo é serializado e recarregado via `World.from_dict(world.to_dict())` (`save_version = 11`); avalia-se a reprodução das formas a partir da memória persistida (mesmo após limpar a demonstração ativa da lousa).
   - Em seguida, o mundo avança `2000` ticks sem treino (com fome/sede desacopladas ou saciadas para isolar a retenção de memória de morte por inanição) e reavalia-se a reprodução.

---

## 6. Métricas Primárias e Critério de Decisão

- **Limiar pré-fixado de sucesso por tentativa**: `SUCCESS_THRESHOLD = 0.22` (erro de Chamfer `< 0.22`).
- **Métricas agregadas nas 24 seeds de holdout**:
  - `early_train_error_median`, `late_train_error_median`, `improvement_median`
  - `train_eval_error_median`, `train_eval_error_iqr`, `train_eval_success_rate`
  - `holdout_shapes_error_median` (agregado e separado por `triangulo`, `cruz`, `zigue_zague`), `holdout_shapes_error_iqr`, `holdout_shapes_success_rate`
  - `post_saveload_error_median`, `post_2000_ticks_error_median`, `retention_drop_median`
  - `unobserved_error_median`
  - `metabolic_delta_max`

### Regras de Classificação Final
- **PASS**: Todas as hipóteses `H1` a `H7` satisfeitas no conjunto `HOLDOUT_SEEDS` (`129401..129424`) na primeira e única abertura do holdout.
- **PARTIAL**: Aprendizado e retenção funcionam nas formas de treino (`H1`, `H2`, `H5`, `H6`, `H7`), mas a generalização para formas inéditas (`H3`) atinge sucesso entre `50%` e `70%` ou margem entre `0.04` e `0.08` sobre `servo_geometrico`.
- **FAIL**: Falha em superar `servo_geometrico` ou `naive` nas formas inéditas (`H3`), vazamento de vértices na reprodução, ou violação de `H6`/`H7`.

### Regra Anti-Vazamento
O arquivo de pré-registro (`tests/experiments/m3b_copia_preregistro.md`) e o avaliador (`tests/experiments/m3b_copia_eval.gd`) são commitados **antes** da execução de `--holdout`. O holdout (`129401..129424`) será aberto **uma única vez** para gerar `reports/M3b_copia_eval.json`, verificado criptograficamente por `tests/experiments/m3b_copia_verify.py` e `tests/experiments/verify_prereg.sh`.
