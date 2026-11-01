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

## 2. Implementação e revisão independente

A `main` foi integrada antes das alterações. O ponto de partida `3992edf` já tinha
o contrato de cérebro substituível, a tabela Q, os sensores discretizados e o
experimento; a continuação preservou esse mecanismo e acrescentou verificações.
Não houve ajuste do aprendiz a partir de resultados HOLDOUT.

- **Aprendizado real:** a tabela muda com transições de estado/ação e variações
  fisiológicas de energia. Tentar comer sem alimento não rende bônus. A morte
  aplica a penalidade terminal. O controle aleatório não atualiza tabela; a ablação
  congelada mantém seus valores Q intactos.
- **Persistência:** `to_dict/from_dict` guardam tabela, parâmetros, passos,
  transição pendente e recompensa acumulada. A primeira rodada revelou que o
  alpha inicial 0,1 tinha representação diferente do alpha após carregar; alinhei
  a inicialização à precisão do carregamento. O teste compara JSON e mais 400
  passos após carregar, além de repetir a mesma semente.
- **F1:** números genéricos têm módulo limitado a 2147483647; energia máxima de
  criatura e energia de alimento ficam entre 0,000001 e 10000. A energia da
  criatura continua entre zero e seu máximo, com nova validação após arredondar.
  Os casos `1e308`, infinito, NaN e máximos que virariam zero são rejeitados.
- **F2:** versões são verificadas como inteiros antes de comparações, em mundo,
  criatura, genoma e cérebros. Valores `null`, texto, lista, dicionário e booleano
  retornam `null`, sem `SCRIPT ERROR`.
- **F3:** grade uniforme de 128 unidades indexa alimentos, criaturas e obstáculos.
  A grade é reconstruída uma vez por passo; movimento/morte e consumo atualizam
  suas entradas durante o passo. Consultas ordenam IDs para preservar desempates.
  As políticas atuais dispensam a consulta a criaturas vizinhas; a API pública
  ainda a oferece. A oclusão e o contato físico mantêm a geometria original.
  Consultas muito amplas examinam células ocupadas para evitar varrer milhões de
  células vazias. Fora de `step`, `sense` reconstrói a grade para respeitar as
  coleções públicas mutáveis. Resultados dos sensores não expõem os dicionários
  originais de alimentos/obstáculos para escrita.
- **F4:** eventos e memória exigem dicionários de tipo conhecido (`spawn`, `eat`,
  `death`), passos e IDs válidos e campos específicos tipados, sem campos extras.
  O passo não pode estar no futuro; memória pertence à própria criatura. Nome
  tem limite de 64 caracteres; ação e razão, 256. Eventos históricos de criaturas
  já mortas continuam válidos, sem exigir que seus IDs estejam vivos.
- **F5:** a adoção automática ocorre somente na configuração inicial. Quando o
  companheiro morre, introduzir outra criatura preserva `pet_id == -1`, inclusive
  após salvar/carregar.
- **pt-BR:** os novos códigos `brain.q_explore`, `brain.q_greedy`,
  `brain.q_frozen`, `brain.random`, `brain.eat_empty` e `brain.blocked` são estáveis;
  sua apresentação e os rótulos das ações discretas ficam em `textos.gd`.

Da edição pendente anterior, mantive a métrica de energia efetivamente obtida e
os testes úteis de percepção, atualização Q, determinismo e persistência. Corrigi
o teste que colocava alimento exatamente na borda arredondada do campo visual e
o teste de alimentação controlada que deixava o alimento atrás da criatura após
uma curva. O cenário controlado repõe alimento visível a cada passo; não faz parte
do experimento. Substituí o suposto teste de aprender a virar na parede, cuja
simulação não isolava essa hipótese, por verificações de recompensa, morte e
congelamento da tabela. Nenhuma alegação de aprender a evitar paredes depende
daquele teste.

## 3. Validação automatizada

Executável utilizado: Godot 4.7.2 console em
`C:\Users\Yurtachi\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`.

`godot --headless --path . -s tests/run_tests.gd` terminou com **exit 0**:
`test_behavior_learn`, `test_save_store`, `test_sim_review`, `test_sim_world`,
`test_smoke` e `test_textos`, todos `ok`, sem erros de script. A primeira rodada
tinha exit 1 e identificou os problemas de precisão e de preparação dos testes
descritos acima; a versão corrigida passou. Evidência: `learn-unit-output.txt`.

O teste de percepção compara a grade com a geometria exaustiva, incluindo a
oclusão indexada. O benchmark `tests/experiments/sense_bench.gd` também compara
snapshots completos após 20 passos, para 30/100/300/1000 criaturas. Sua referência
reproduz a percepção exaustiva anterior; conserva o restante da implementação
atual, incluindo o pequeno custo de manutenção de posições no passo.

Na medição final, sem outro processo Godot do experimento em execução:

| Criaturas | Grade: ms/passo | Referência exaustiva: ms/passo | Snapshot idêntico |
|---|---:|---:|---|
| 30 | 2,656 | 5,414 | sim |
| 100 | 7,955 | 29,833 | sim |
| 300 | 11,433 | 171,899 | sim |
| 1000 | 37,291 | 2668,927 | sim |

`godot --headless --path . -s tests/experiments/sense_bench.gd` terminou com
**exit 0**. São tempos locais de depuração, não garantias de FPS; evidência em
`learn-sense-output.txt`. Uma medição exploratória anterior rodou em paralelo com
o experimento e não foi usada nesta tabela. A proteção final contra consultas
que atravessam muitas células vazias foi incluída durante o experimento, depois
que ele já havia carregado os scripts; ela preserva a ordenação dos candidatos e
não altera observações, ações ou consumo de aleatoriedade. A suíte final e os
snapshots completos deste benchmark validam a versão com essa proteção.

## 4. Resultado do experimento

**O critério pré-registrado G2 passou: H1=true e H2=true em HOLDOUT.**
O comando completo terminou com **exit 0**, sem erros de script, em 372144 ms.
Foram 40 episódios de treinamento e 100 de avaliação: cinco condições × dez
sementes × dois conjuntos. `learn-eval-output.txt` contém a saída completa;
`tests/experiments/results/learn_eval_results.json` contém todas as linhas por
semente, condições, curva de treino, configuração e comparações pareadas.

São médias entre as dez sementes; os desvios entre parênteses são amostrais das
médias por episódio, não estimativas baseadas em tratar cada criatura como amostra
independente. Sobrevivência é limitada ao horizonte de 3000 passos.

### TRAIN (descritivo)

| Condição | Itens/criatura (DP) | Sobrevivência em passos (DP) | Energia obtida/criatura | Sobreviventes/8 |
|---|---:|---:|---:|---:|
| `random` | 2,388 (0,869) | 1597,9 (219,7) | 65,12 | 1,30 |
| `heuristic` | 14,900 (1,686) | 2861,4 (109,8) | 259,56 | 7,30 |
| `learner_naive` | 1,038 (0,752) | 1234,4 (165,7) | 22,21 | 0,60 |
| `learner_trained` | 35,275 (2,096) | 2702,4 (197,5) | 248,91 | 6,30 |
| `learner_frozen` | 20,138 (7,490) | 2345,0 (418,0) | 170,36 | 4,50 |

Em TRAIN, o treinado vence o aleatório e o ingênuo em itens nas dez sementes
(p=0,0009765625 em cada comparação), e sua sobrevivência é 1,691× a do aleatório.
A primeira passagem de treino obteve 30,425 itens e 2612,9 passos; a última,
35,438 itens e 2682,8 passos. Essa curva é descritiva; o aprendizado já ocorre
dentro da primeira passagem, e o treino não foi monotônico em todas as sementes.

### HOLDOUT (decisão do gate)

| Condição | Itens/criatura (DP) | Sobrevivência em passos (DP) | Energia obtida/criatura | Sobreviventes/8 |
|---|---:|---:|---:|---:|
| `random` | 2,263 (1,178) | 1473,7 (348,1) | 61,58 | 1,20 |
| `heuristic` | 15,725 (1,292) | 2930,5 (132,6) | 282,33 | 7,50 |
| `learner_naive` | 0,975 (0,935) | 1181,1 (191,7) | 24,73 | 0,40 |
| `learner_trained` | 33,475 (4,726) | 2682,1 (305,6) | 260,17 | 6,10 |
| `learner_frozen` | 14,688 (9,012) | 2188,0 (383,0) | 147,28 | 3,20 |

- **H1 passou:** treinado > aleatório em itens em **10/10** sementes,
  p=**0,0009765625**; sobrevivência **1,820×**, acima do limiar 1,2×.
- **H2 passou:** treinado > ingênuo em itens em **10/10** sementes,
  p=**0,0009765625**. A vantagem depende de experiência anterior em TRAIN.
- A energia realmente obtida pelo treinado também supera a do aleatório em
  **10/10**, p=0,0009765625, com diferença média de **198,59** por criatura.
- A ablação congelada supera o aleatório em itens em **10/10**,
  p=0,0009765625; portanto a tabela salva carrega uma política útil. Sua média de
  sobrevivência é inferior à do aprendiz que continua atualizando a tabela.
- **H3 falhou:** ingênuo > aleatório em apenas **2/10**, p=0,9892578125.
  Em média, aprender do zero durante uma única vida foi pior que agir ao acaso.
- Contra a **heurística**, o treinado ganha em itens em **10/10**, mas ganha em
  sobrevivência e energia obtida em somente **2/10** cada. As diferenças médias
  são **-248,4 passos** e **-22,16 energia**. Não há evidência de superioridade
  geral sobre essa política manual.

### Ponto de treinamento salvo

`tests/experiments/results/trained_brain.json` contém 237 valores Q não nulos de
240 e 861919 decisões acumuladas. SHA-256, conferido independentemente com o
arquivo de resultados:

`a1c83a19f05ac2f54b16fbfb051480794747a919777bc9314e4694338fa9b7db`

A política gulosa salva prefere comer quando o alimento está ao alcance, virar
na direção do alimento nas categorias laterais e girar para explorar quando não
há alimento. Nem todas as categorias à frente resultaram em avançar; a política
continua grosseira. A saída registra as escolhas por estado de energia média.

## 5. Limites e conclusão

O resultado sustenta a alegação definida no pré-registro: experiência em TRAIN
produziu uma política que generaliza melhor que o controle aleatório e que o
aprendiz de tabela zero nessas dez sementes HOLDOUT. A avaliação do treinado
permite aprendizado online, como registrado; a ablação congelada separa parte da
contribuição da experiência já salva.

O número de itens não mede eficiência nutricional: a regra SIM remove um alimento
inteiro mesmo se quase não couber energia no corpo. Por isso o treinado come
muito mais itens que a heurística, mas obtém menos energia e vive menos. Esse
desperdício existente não foi corrigido ou usado como bônus de recompensa; foi
medido separadamente. O fracasso de H3 impede afirmar que o aprendiz ingênuo
tenha desempenho útil em uma única vida sem treino anterior.

O experimento tem ambiente e genomas distribuídos pelo mesmo gerador, horizonte
fixo e dez sementes reservadas. Não demonstra reprodução, evolução, vínculos,
diálogo, consciência ou aprendizado universal. O jardim criado pela interface
continua usando a heurística quando `brain == null`; este gate não integra um
seletor de políticas na interface. Um consumidor pode atribuir `QBrain.new()` ou
`QBrain.from_dict(...)` a `creature.brain`; o salvamento do mundo preserva esse
cérebro e sua transição pendente.

A grade reduz o custo das consultas locais, mas mundos densos, muitos alimentos
ou obstáculos gigantes ainda podem ter custo alto. Os limites antigos de
quantidade não são uma promessa de fluidez para qualquer configuração. Consultas
externas repetidas a `sense` reconstroem o índice por segurança, enquanto o passo
normal compartilha uma reconstrução. Não foram tratados os achados F6–F12 da
revisão, exceto quando uma proteção necessária a F1–F5 também os cobre.
