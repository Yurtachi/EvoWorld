# Revisão dinâmica independente — P1 (memória espacial)

Base: `evo4/pet` @ `08a0c42` (merge do P1). Godot 4.7.2 console, Windows. Revisor não escreveu os patches.
Harnesses descartáveis ficaram fora do repo (pasta temporária). Nenhum avaliador fechado foi executado
e nenhum JSON de `reports/` foi regravado (`git status` limpo após as execuções).

## Veredito

**Nenhum achado Crítico ou Alto.** Três Médios (um de integridade sensorial restrito ao modo ecossistema,
dois de enquadramento/projeto do experimento) e três Baixos. O PARTIAL declarado é coerente com os dados brutos.

Suíte: `godot --headless --path . -s tests/run_tests.gd` -> 27 linhas `: ok`, `exit 0`, nenhum `SCRIPT ERROR`
(ms/tick do pet: 0,68 / 0,50 / 0,42 / 0,59, abaixo de 2 ms). No início da revisão o merge estava sem commit
(`textos.gd` UU); a árvore de trabalho já não tinha marcadores e o coordenador commitou depois. Os testes rodaram na árvore sem marcadores.

## 1. Telepatia

**Refutada no caminho de decisão (modo manual/feeder).** Leitura: `scripts/mind`, `scripts/spatial` e
`_spatial_seek`/`_personality_seek_food`/`_seek_water`/`_mind_action` só consomem `sensors`, memória e corpo.
Único acesso ao mundo na mente: `creature_mind.gd:136-137` (`world.creatures`, `world._occluded`; contato físico entre criaturas, anterior ao P1).

Harness diferencial (`tele.gd`): dois mundos idênticos (pet treinado com 8 ingestões reais em L=(1000,600), partindo de (80,80),
mundo 1200x760) diferindo só na verdade oculta; 60 ticks de `world.step()` completo; comparados `pos, heading, last_action,
last_reason, energy, mind.to_dict(), mind.spatial` e o RNG do mundo a cada tick. Pares com seeds 91001-91003:
nada x comida oculta longe; nada x alimentador; alimentador A x B (movido); nada x 10 alimentadores com intervalo 3;
alimentador A x alimentador em L; nada x comida real em L (nunca vista).

    91001 ["none","feeder_A"] -> identico por 60 ticks (rng mundo igual)    (18/18 pares idênticos)
    controle positivo (comida visivel): sensores diferem / estado diverge: true

O controle positivo mostra que o harness detecta diferença. `mind_log`, `allowed_actions` (constante) e ids de comida não vazam:
o estado serializado inteiro da mente é idêntico. A memória estava ativa no teste (`seek_place / spatial.expected`).
(Uma primeira versão do harness tinha a posição de treino fora do alcance de ingestão e testava só vagar; corrigi e refiz tudo.)

### M1 (Média) — RNG compartilhado do mundo acopla a contagem de comida oculta ao vagar (modo ecossistema)
`sim_world.gd:2007,2029,2040` usam `rng.between` (RNG do mundo) para vagar; `sim_world.gd:793` (regrow) consome o mesmo RNG
via `_free_position`, e o número de sorteios depende de `food_capacity - foods.size()`.
Harness `tele2.gd` (ecossistema, capacidade 3, 0 x 3 comidas ocultas, sensores idênticos antes de cada passo):

    train=true DIVERGE tick 105 sensores identicos; acao a=explore/spatial.explore b=explore/spatial.explore;
      rng_mundo iguais antes=false age%15=0 foods a=2 b=3

Não transmite a posição do recurso (é ruído), mas viola "mesmos sensores, mesma decisão" fora de manual/feeder. Não afeta o holdout
(sem regrow). Sugestão: RNG próprio da criatura para vagar. Não corrigido aqui.

### B1 (Baixa) — teste estático fraco
`tests/unit/test_sim_p1.gd:34`: o regex exige prefixo `world.`/`self.`; nomes nus (`foods`, `feeders`) dentro de `sim_world.gd`
não seriam detectados. Verifiquei manualmente: não há uso nu nas funções de decisão. O pet também conhece `size` do mundo
(`SpatialPolicy.choose(..., size)`): geometria da arena, não posição de recurso.

## 2. Baseline

`p1_eval.gd:10` HORIZON=180 ticks a 5,5 unidades/tick = ~990 unidades de caminho numa arena 900x600 com visão 70.
Harness `base.gd` (300 trials, seeds minhas 880000+, mesmo mundo e regras físicas, L e partida sorteados como no protocolo):

    vagar (sem memória)    energia 35: 61/300 = 20,3%
    varredura sistemática  energia 35: 64/300 = 21,3%   (hunger > 0,75 nunca ocorreu: gatilho de emergência não é confusor)
    MC analítico de pontos, faixas, teto otimista (sem FOV, sem custo de chegada):
      espaçamento 66,5 -> 20,7%; 100 -> 21,8%; 130 -> 23,2%

### M2 (Média) — o "explorador sistemático" é limitado pelo horizonte: qualquer busca cega rende ~20-25% em 180 ticks
O 14/72 (19,4%) é o teto geométrico do problema, não falha de implementação: a varredura equivale ao vagar
(21,3% x 20,3% aqui; 19,4% x 18,1% no holdout) e está perto do teto analítico. Logo H-A (+80 pp) mede "lembrar de L" contra
"busca cega em 180 ticks", resultado quase garantido por construção; não mostra superioridade sobre uma estratégia competente
em horizonte longo. Detalhe: `spatial_policy.gd:15` usa espaçamento 0,95*visão (faixas sobrepostas; a largura de detecção é ~2*visão),
o que perde ~2 pp contra espaçamento 130. A cobertura de 100% em 2000 ticks é verdadeira, mas irrelevante para T=180.

## 3. Controles e protocolo

- L sorteado por seed: `p1_eval.gd` (`Rng.new(seed*17)`, uniforme em [100,800]x[100,500]); L2 também. Não é fixo.
- Seeds holdout 271401-271424 e dev 271101-271106 não aparecem em nenhum outro arquivo (grep em reports/tests/scripts)
  nem em `historical_seeds` do freeze. Disjuntas.
- Ordem: pré-registro `2ad7ba4` 11:32:08, motor `111a576` 11:52:30, normalização `f58a85b` 11:55:05, freeze `0054d4f` 11:57:54, holdout
  `d3e881e` 12:01:03. O pré-registro tem um único commit (nunca editado). Entre freeze e holdout nada mudou em `scripts/`, `p1_eval.gd`, `p1_metrics.py`.
  `python tests/experiments/p1_verify.py` -> `P1 INTEGRITY PASS ... verdict=PARTIAL`.
- Ablação "sem memória" e "não treinado" NÃO zeram por construção (18,06% por acaso geométrico), o que é correto.

### B2 (Baixa) — braços duplicados
`sem_memoria` e `nao_treinado` têm métricas idênticas em todos os dígitos (13/72; 166,2083) e `oraculo` idêntico ao `treinado`
(69,9861; 0,9694): mesma trajetória física (mesmo RNG do mundo, mesmo vagar). Não são evidências independentes; o oráculo é o mesmo mecanismo
com memória injetada, não um teto independente.

## 4. H-B (0/24)

Confirmado nos JSON brutos (`p1_holdout.json`, `checks`): `B_failures=2` e `B_expectation=0,309529` em 24/24 seeds; falhas
acumuladas por visita: (1,1,2,2,2) em 22 seeds e (1,1,1,2,2) em 2.

### M3 (Média) — causa provável: agenda determinística de cooldown, não "nunca desiste"
`spatial_memory.gd:68`: após cada falha `retry_tick = tick + 180*consecutivas`. Cada visita do protocolo dura 180 ticks e recoloca o pet
na partida: a visita seguinte à 1a falha é consumida pelo cooldown (sem falha), a 2a falha impõe 360 ticks (duas visitas mortas), e a 3a
cairia na 6a visita, fora de K=5. Com a regra beta, duas falhas dão exatamente 0,3095 > 0,25 para todo pet igual; o limiar exige 3.
O pet abandona o lugar (3 falhas consecutivas em `Memory.best`); o critério é inalcançável nesse protocolo pela combinação cooldown x janela.
Reforça a leitura do relatório de que é problema operacional. Nada corrigido aqui.

## 5. Persistência (save v16) e fuzz

Harness `fuzz.gd`, pasta `...\Temp\rv\saves` (fora do repo; saves reais intocados):
- save/load via `SaveStore`: lugares 1/1, snapshot idêntico, continuação idêntica por 120 ticks. A memória persiste.
- Mutações do `to_dict()` v16, todas rejeitadas por `World.from_dict` (null): pos fora do mundo, negativa, "nan", INF, NAN;
  ids duplicados; 65 e 100.000 lugares; cell_size 0 e 1e30; alpha 1e9; ultimo_tick futuro; objetivo inexistente; motivo/recurso inválidos;
  campo extra; spatial string; visitas negativas; busca_indice enorme; id de 1 MB. O controle válido foi aceito.
- `mind.spatial` com `save_version` 1..15: rejeitado nos 15; v15 legítimo sem spatial: aceito.
- Gzip bomb (8 MiB de zeros, envelope v2 válido): `Compressed checkpoint exceeds the 64:1 expansion limit`, 10 ms.

### B3 (Baixa) — campo espacial inválido derruba o save inteiro; razão órfã
Por desenho (rejeita em vez de sanear), consistente com o resto; risco de perda de save se algum bug gerar `lugares` inválido.
Também `spatial.visible` está em `Memory.REASONS` mas não em `Mind.REASONS` (`creature_mind.gd`); hoje não é emitido.

## 6. Determinismo, golden, CPU, texto

- `gold.gd`: 4 mundos legados (com/sem mente, 800 ticks, seeds 11/12), hash de `to_dict()` sem `save_version`, no worktree P0 (`evo4-p0-sim`)
  e na árvore atual: **hashes idênticos** (465735c2b43a, 245e9cc2c5fb, 4e7504ed63a5, 378b86b695d8). Mundo pet 160001, 600 ticks, repetível.
- CPU: 0,42-0,68 ms/tick na suíte; sem regressão detectada.
- Texto: `Texto.acao` e `Texto.razao` devolvem pt-BR para `seek_place`, `inspect_place` e `spatial.*`; nenhum inglês visível novo.

## Resumo dos achados

| Id | Sev. | Onde | Resumo |
|---|---|---|---|
| M1 | Média | sim_world.gd:793,2007,2029,2040 | RNG do mundo acopla comida oculta ao vagar (ecossistema) |
| M2 | Média | p1_eval.gd:10; spatial_policy.gd:15 | busca cega limitada pelo horizonte (~20-25%); sweep = vagar |
| M3 | Média | spatial_memory.gd:68 | cooldown 180n x visita 180 impede a 3a falha dentro de K=5 |
| B1 | Baixa | test_sim_p1.gd:34 | regex estático só pega `world.`/`self.` |
| B2 | Baixa | p1_metrics.json | braços duplicados |
| B3 | Baixa | creature_mind.gd (REASONS) | `spatial.visible` ausente; save inteiro rejeitado por campo inválido |
