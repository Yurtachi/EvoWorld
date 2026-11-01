# Relat?rio LEARN ? gate G2

## 1. Pr?-registro (fixado antes do experimento completo)

O protocolo original foi registrado no commit `3992edf`, antes de qualquer execu??o
completa. Esta tradu??o para pt-BR preserva o ambiente, as sementes, os par?metros,
as m?tricas e os crit?rios originais; foi feita antes da primeira execu??o completa
desta continua??o. Os resultados ser?o acrescentados sem alterar esta se??o.
Execu??es `-- --dev` usam somente as tr?s primeiras sementes TRAIN, nunca HOLDOUT,
para verificar erros e dura??o.

### Tarefa e observa??o

Buscar e consumir alimento para sobreviver na ecologia SimWorld. Cada criatura
percebe somente alimentos e obst?culos dentro do alcance/campo visual do genoma,
com oclus?o por obst?culos. O estado discretizado tem 48 possibilidades: oito
categorias do alimento vis?vel mais pr?ximo (nenhum, ao alcance, perto ? esquerda,
perto ? frente, perto ? direita, longe ? esquerda, longe ? frente, longe ? direita),
tr?s faixas de energia (<35%, <70%, demais) e obst?culo/parede ? frente (sim/n?o).
Perto significa at? 60 unidades; ? frente significa ?ngulo absoluto <=0,25 rad;
ao alcance significa tamanho+5 unidades.

### Aprendiz

Q-learning tabular, 48 estados ? 5 a??es: avan?ar, virar ? esquerda ou ? direita
(0,5 rad e ent?o avan?ar), comer e descansar. A recompensa ? a varia??o real de
energia entre decis?es: ganho ao comer menos metabolismo, movimento e dano
(a simula??o atual n?o tem fonte de dano). A morte acrescenta -25. N?o h? recompensa
por proximidade, tentativas de comer ou pela escolha de uma a??o.

Par?metros: alpha=0,1; gamma=0,97;
epsilon=max(0,02; 0,3?3000/(3000+passos)); tabela inicial zero; desempate pelo
primeiro ?ndice. A precis?o num?rica de execu??o/salvamento ? 0,000001.

### Ambiente fixo

Mundo 1200?760; `creature_count=8`, `food_count=30`, `food_capacity=40`,
`food_regrow=true`, `food_regrow_interval=10`, `food_regrow_batch=1`,
`obstacle_count=10`. Epis?dio de at? 3000 passos (300 segundos simulados), ou at?
morrerem as oito criaturas. Todas usam a mesma condi??o. Para cada semente,
todas as condi??es partem dos mesmos obst?culos, alimentos, genomas, posi??es e
dire??es iniciais.

### Sementes e treinamento

- TRAIN: 1001?1010.
- HOLDOUT: 7001?7010, sem uso em treinamento ou ajustes.

Treinar quatro passagens sobre as dez sementes TRAIN (40 epis?dios). As oito
criaturas de cada mundo compartilham a tabela Q, inicialmente zero, preservada
entre epis?dios. Cada corpo mant?m sua pr?pria transi??o anterior.

### Condi??es

- `random`: a??o discreta uniforme, sem aprendizado, mesma f?sica/conjunto de a??es.
- `heuristic`: pol?tica SIM existente (`brain == null`), com orienta??o cont?nua
  para alimento e desvio reflexivo de obst?culos ausentes das pol?ticas discretas.
- `learner_naive`: tabela zero por criatura, aprende durante uma ?nica vida.
- `learner_trained`: c?pia por criatura da tabela treinada em TRAIN; continua
  aprendendo, com epsilon deca?do.
- `learner_frozen`: mesmo ponto treinado, guloso, aprendizado desativado (abla??o).

### M?tricas e unidade de an?lise

M?dia por epis?dio de itens comidos/criatura e passos de sobreviv?ncia/criatura
(idade na morte ou no encerramento). Unidade: semente, com compara??o pareada
entre condi??es. Teste dos sinais exato unilateral; empates contam como derrotas.

### Crit?rios de sucesso (somente HOLDOUT)

- **H1:** `learner_trained` supera `random` em alimento/criatura em >=9 das 10
  sementes HOLDOUT (p<=0,011), E a m?dia de sobreviv?ncia ? >=1,2? a de `random`.
- **H2:** `learner_trained` supera `learner_naive` em alimento/criatura em >=9 das
  10 sementes HOLDOUT.
- **Alega??o global de aprendizado G2 = H1 E H2.** Se qualquer um falhar, a
  alega??o ser? declarada reprovada, sem reformular o crit?rio como sucesso.
- Resultados secund?rios/descritivos, sem influenciar a aprova??o: H3
  `learner_naive` supera `random` em >=8/10 sementes HOLDOUT; `learner_frozen`
  versus `random`; `learner_trained` versus `heuristic` (sem previs?o);
  primeira versus ?ltima passagem de treino; mesmas tabelas em TRAIN.

### Comando

`godot --headless --path . -s tests/experiments/learn_eval.gd`

Produz `tests/experiments/results/learn_eval_results.json` e `trained_brain.json`.
Energia real obtida ao comer ? uma m?trica descritiva adicional herdada da edi??o
pendente do worker anterior e n?o participa de H1/H2.
