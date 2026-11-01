# Relatório LEARN — gate G2

## 1. Pré-registro (fixado antes do experimento completo)

O protocolo original foi registrado no commit `3992edf`, antes de qualquer execução
completa. Esta tradução para pt-BR preserva o ambiente, as sementes, os parâmetros,
as métricas e os critérios originais; foi feita antes da primeira execução completa
desta continuação. Acentos corrompidos pela codificação do terminal foram reparados
durante o treinamento, sem alteração de conteúdo. Os resultados serão acrescentados sem alterar esta seção.
Execuções `-- --dev` usam somente as três primeiras sementes TRAIN, nunca HOLDOUT,
para verificar erros e duração.

### Tarefa e observação

Buscar e consumir alimento para sobreviver na ecologia SimWorld. Cada criatura
percebe somente alimentos e obstáculos dentro do alcance/campo visual do genoma,
com oclusão por obstáculos. O estado discretizado tem 48 possibilidades: oito
categorias do alimento visível mais próximo (nenhum, ao alcance, perto à esquerda,
perto à frente, perto à direita, longe à esquerda, longe à frente, longe à direita),
três faixas de energia (<35%, <70%, demais) e obstáculo/parede à frente (sim/não).
Perto significa até 60 unidades; à frente significa ângulo absoluto <=0,25 rad;
ao alcance significa tamanho+5 unidades.

### Aprendiz

Q-learning tabular, 48 estados × 5 ações: avançar, virar à esquerda ou à direita
(0,5 rad e então avançar), comer e descansar. A recompensa é a variação real de
energia entre decisões: ganho ao comer menos metabolismo, movimento e dano
(a simulação atual não tem fonte de dano). A morte acrescenta -25. Não há recompensa
por proximidade, tentativas de comer ou pela escolha de uma ação.

Parâmetros: alpha=0,1; gamma=0,97;
epsilon=max(0,02; 0,3×3000/(3000+passos)); tabela inicial zero; desempate pelo
primeiro índice. A precisão numérica de execução/salvamento é 0,000001.

### Ambiente fixo

Mundo 1200×760; `creature_count=8`, `food_count=30`, `food_capacity=40`,
`food_regrow=true`, `food_regrow_interval=10`, `food_regrow_batch=1`,
`obstacle_count=10`. Episódio de até 3000 passos (300 segundos simulados), ou até
morrerem as oito criaturas. Todas usam a mesma condição. Para cada semente,
todas as condições partem dos mesmos obstáculos, alimentos, genomas, posições e
direções iniciais.

### Sementes e treinamento

- TRAIN: 1001–1010.
- HOLDOUT: 7001–7010, sem uso em treinamento ou ajustes.

Treinar quatro passagens sobre as dez sementes TRAIN (40 episódios). As oito
criaturas de cada mundo compartilham a tabela Q, inicialmente zero, preservada
entre episódios. Cada corpo mantém sua própria transição anterior.

### Condições

- `random`: ação discreta uniforme, sem aprendizado, mesma física/conjunto de ações.
- `heuristic`: política SIM existente (`brain == null`), com orientação contínua
  para alimento e desvio reflexivo de obstáculos ausentes das políticas discretas.
- `learner_naive`: tabela zero por criatura, aprende durante uma única vida.
- `learner_trained`: cópia por criatura da tabela treinada em TRAIN; continua
  aprendendo, com epsilon decaído.
- `learner_frozen`: mesmo ponto treinado, guloso, aprendizado desativado (ablação).

### Métricas e unidade de análise

Média por episódio de itens comidos/criatura e passos de sobrevivência/criatura
(idade na morte ou no encerramento). Unidade: semente, com comparação pareada
entre condições. Teste dos sinais exato unilateral; empates contam como derrotas.

### Critérios de sucesso (somente HOLDOUT)

- **H1:** `learner_trained` supera `random` em alimento/criatura em >=9 das 10
  sementes HOLDOUT (p<=0,011), E a média de sobrevivência é >=1,2× a de `random`.
- **H2:** `learner_trained` supera `learner_naive` em alimento/criatura em >=9 das
  10 sementes HOLDOUT.
- **Alegação global de aprendizado G2 = H1 E H2.** Se qualquer um falhar, a
  alegação será declarada reprovada, sem reformular o critério como sucesso.
- Resultados secundários/descritivos, sem influenciar a aprovação: H3
  `learner_naive` supera `random` em >=8/10 sementes HOLDOUT; `learner_frozen`
  versus `random`; `learner_trained` versus `heuristic` (sem previsão);
  primeira versus última passagem de treino; mesmas tabelas em TRAIN.

### Comando

`godot --headless --path . -s tests/experiments/learn_eval.gd`

Produz `tests/experiments/results/learn_eval_results.json` e `trained_brain.json`.
Energia real obtida ao comer é uma métrica descritiva adicional herdada da edição
pendente do worker anterior e não participa de H1/H2.
