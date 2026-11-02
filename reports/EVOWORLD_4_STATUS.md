# EvoWorld 4.0 — estado na pausa (pet autônomo)

Branch: `evo4/pet` @ ver `git log` (base `evo3/integration` @ `efb7810`). Sem Colab, sem LLM, offline. Verificado na pausa: árvore limpa, **28 suítes exit 0, 0 SCRIPT ERROR**, `verify_prereg.sh` exit 0, nenhum segredo rastreado.

## Entregue e integrado
- **P0 pet individual:** novo mundo com exatamente 1 criatura, mente avançada ativa, reprodução desligada por padrão; modo ecossistema (12 criaturas) como alternativa avançada; saves v1–v16 migram. Alimentação manual / **alimentador físico** (estoque, intervalo, capacidade; nunca dá energia) / ecossistema. Padrão do pet: 24 alimentos + 9 fontes de água, 4/4 seeds vivas aos 5000 ticks. Interface de convivência e corpo novo (capturas `reports/P0-*.png`).
- **P1/P1b memória espacial:** lugares lembrados com expectativa e confiança, separados de percepção e da verdade do mundo (telepatia refutada por revisor independente). P1b (24 seeds novas, holdout aberto uma vez): recordação 72/72 vs 14–16/72 dos controles sem memória; **revisão da expectativa 22/24** (mínimo 90%) vs 5 entradas do controle "volta sempre ao último lugar"; retenção após salvar 100%; preferência por local mais rico 24/24. Mapa mental opcional na UI (`reports/P1-*.png`).

## Resultado científico (honesto)
P1: PARTIAL (revisão falhou 0/24 no desenho original; corrigida em novo protocolo). P1b: **PASS estreito** (duas seeds falharam individualmente e foram mantidas). Revisão independente do P1: sem alto/crítico; o 14/72 do explorador sistemático é o teto geométrico da busca cega (~21–23% em 180 ticks).

## Em andamento / pendente
- **P2 (obstáculos e planejamento): CHECKPOINT NÃO VALIDADO** na branch `Yurtachi/evo4-p2-sim` (commit `wip(p2)`): pré-registro commitado antes de qualquer resultado; planejador A\*, obstáculos tipados e seguidor de parede escritos; **suíte e experimento não rodados/validados; holdout NÃO aberto.** Não integrar sem validar.
- P3 (materiais e ferramentas), P4 (desenvolvimento corporal e polimento visual), P5 (integração, revisão independente, aceite manual): não iniciados.
- Revisão independente do P1b não executada (só P1).

## Cotas
Codex volta às 15:53 do dia 2026-11-02; AGY Argon/Sonnet/Opus sem cota; Flash disponível.

## Retomar
`git checkout evo4/pet`; `godot --headless --path . -s tests/run_tests.gd` (28 suítes). Para o P2: `git checkout Yurtachi/evo4-p2-sim`, rodar a suíte, completar e só então abrir o holdout conforme o pré-registro.
