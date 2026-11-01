# EvoWorld — relatório consolidado (G0–G5)

Status: **PARTIAL** — G0, G1, G3, G5 comprovados; G2 comprovado contra baseline aleatório (não contra a heurística); G4 implementado, mas a **ablação do canal de sinais foi negativa**. G6 (Colab) não executado, por decisão justificada abaixo.

## Fatos (comandos e exit codes reproduzidos pelo coordenador)
- Repositório: `git@github-personal:Yurtachi/EvoWorld.git`, branch `main`, identidade local Yurtachi. Commits sem trailers de IA (regra da missão).
- Testes: `godot --headless --path . -s tests/run_tests.gd` → **exit 0**, 9 suítes ok (aprendizado, diálogo, evolução, save, sinais, revisão do sim, mundo, smoke, textos).
- Build: preset `export_presets.cfg` (Windows, `all_resources`, sem tests/reports/docs). `godot --headless --path . --export-release "Windows Desktop" builds/EvoWorld.exe` → **exit 0** (109 MB, PCK embutido). `builds/EvoWorld.exe --quit-after 300` → **exit 0**, 0 SCRIPT ERROR, GPU NVIDIA RTX 2050 (OpenGL Compatibility). O primeiro export (filtro `scenes`) falhou ao rodar por omitir scripts carregados via `preload`; corrigido para `all_resources`.
- Performance da simulação (`tests/experiments/perf_bench.gd`, headless, 600 ticks, seed 7421, i5-13420H):

| criaturas iniciais | ms/tick médio | ms/tick p95 | ticks/s |
|---|---|---|---|
| 10 | 4,56 | 16,7 | 219 |
| 30 | 7,01 | 26,5 | 143 |
| 60 | 8,25 | 15,7 | 121 |
| 100 | 7,77 | 15,3 | 129 |

  A população cresce por reprodução (teto 100 no teste). O jogo precisa de 10 ticks/s a 1× e 50 a 5×: folga ampla. FPS gráfico observado nas capturas: 114 FPS (16 criaturas) e 49 FPS (84 criaturas) com o HUD; não há benchmark gráfico sistemático [LACUNA].

## Gates
- **G1 PASS**: mundo, pet nomeável, alimentar, criar criaturas/rochas, save/load atômico com backup, UI em pt-BR (`reports/ui.md`, `reports/ui2.md`, capturas `reports/*.png`).
- **G2 PARTIAL**: Q-learning tabular real. Critério pré-registrado H1/H2 **passou** no holdout (10/10 vitórias vs aleatório, p≈0,001; sobrevivência 1,82×). **Não** supera a heurística fixa em sobrevivência/energia (2/10); H3 falhou. Experimento reexecutado pelo coordenador (exit 0). Ver `reports/learn.md`.
- **G3 PASS**: reprodução assexuada com custo de energia, herança + mutação limitada, genealogia persistente (save v2/v3 com migração), geração 4 em 3 seeds, zero nascimentos sem alimento. Sem alegação de adaptação. Ver `reports/evolucao.md`.
- **G4 PARTIAL**: canal de 4–8 sinais com custo/alcance/ruído, log, persistência; diálogo por intents ancorado em estado; comandos do pet persistentes. **Ablação ligado×desligado: 0/10 vitórias, critério reprovado** — nenhum significado atribuído aos símbolos. Ver `reports/sinais.md`, `reports/dialogo.md`.
- **G5 PARTIAL**: build jogável exportado e verificado; UI completa (Cuidador/Laboratório, genealogia, gráfico, ajustes, ajuda); performance da sim medida. Falta benchmark gráfico sistemático e a revisão final independente (cota dos agentes esgotada).
- **G6**: não executado. Nenhum experimento exige GPU; treino Q roda em CPU local em minutos; nenhuma CCU gasta.

## Orquestração (fatos)
Orca 1.4.245, Run `run_70673bbe1d7a`. Workers: Codex (SIM, UI, I18N, LEARN continuação, GEN, DIALOGO, SINAIS, UI2), Antigravity (REUSE com Gemini 3.8 Flash; REVIEW do sim com Claude Sonnet 5.5). Revisão independente do sim (`reports/review_sim.md`) gerou F1–F5, todos corrigidos. Limites: AGY esgotou a cota (Gemini 4 Argon e Claude Opus travaram o UI e o LEARN iniciais, reatribuídos ao Codex); Codex esgotou a cota ao final (revisão final e benchmark gráfico ficaram sem executar).

## [HIPÓTESE] ainda não demonstrada
Comunicação útil entre criaturas; adaptação evolutiva medida; superar a heurística com aprendizado.

## Próxima ação segura
Quando houver cota: rodar a revisão final independente (`reports/review_final.md`), benchmark gráfico de FPS (30/60/100) e experimento de comunicação com tarefa que realmente exija coordenação.

## Revisão final independente (subagente Claude, somente leitura)
Executada porque Codex e AGY estavam sem cota. 2 graves, 8 médios, 4 menores.
- **Corrigido** (commit "fix: ordens do jogador…", teste `test_comandos_sobrevivencia.gd`, comprovado que falha sem o fix): ordens `parar/chamar/seguir/brincar` impediam o pet de comer e podiam prendê-lo em obstáculo até morrer. Agora a fome acima de 0,6 suspende a ordem e todas expiram (chamar 600, brincar/parar 300, seguir 3000 ticks).
- **Abertos (não corrigidos)**:
  - Gate H1/H2 do G2 usa o braço `learner_trained` que continua aprendendo no holdout (adaptação online; o relatório já declara isso); o braço congelado vence o aleatório em alimento 10/10, mas o critério não foi reescrito após ver resultados.
  - Contador de comida do experimento conta ingestões com ganho 0 (energia cheia).
  - Save: limite de 32 MiB pode ser atingido antes do teto de 100000 registros de genealogia; saves são confiáveis apenas localmente (checksum detecta corrupção, não adulteração; `max_energy` não amarrado ao genoma).
  - `proteger` não persiste na UI; recibo de `chamar/seguir` não mostra o alvo; `descendants()` O(n) a cada 0,5 s no Laboratório; teto de 150 criaturas fixo na UI; RegEx recompilada por frame em `Textos.razao`.
  - Proveniência: `dirt.png` e `water.png` são idênticos (provável erro de fatiamento); hashes de `white01/10/20` duplicados.
