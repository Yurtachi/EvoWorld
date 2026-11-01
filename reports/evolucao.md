# Relatório GEN — gate G3

**Status: PASS para o escopo GEN.** Reprodução e herança reais, quatro gerações
descendentes observadas e genealogia persistente, com testes e experimento verdes.

## Escopo e regras implementadas

Trabalho na branch `Yurtachi/evo-gen`, a partir de `fbe03ed`, com a identidade
Git local Yurtachi. Foram lidos `docs/ARCHITECTURE.md`, os dois documentos em
`docs/mission/`, `reports/sim.md` e `reports/learn.md`. A implementação fica em
`scripts/creature`, `scripts/world`, `scripts/evolution`, `scripts/core` e testes;
em `textos.gd` só foram acrescentadas chaves. Nenhuma alteração em UI, render,
comportamento ou no envelope de arquivos de `SaveStore`.

A reprodução assexuada acontece automaticamente ao fim da atualização de cada
organismo elegível. A API `reproduce(creature_id)` aplica as mesmas condições e
retorna o ID do filhote ou `-1`:

| Regra padrão | Valor |
|---|---:|
| Idade mínima | 300 passos = 30 segundos simulados |
| Energia mínima | 90% da capacidade do genitor |
| Energia transferida | 40% da capacidade do genitor, limitada à capacidade do filhote |
| Intervalo entre reproduções | 300 passos |
| Idade máxima | 12.000 passos = 1.200 segundos simulados |
| População máxima | 150 organismos vivos |
| Probabilidade de mutação por gene | 0,3 |
| Desvio padrão da mutação | 0,025 × amplitude permitida do gene |

A energia inicial do filhote é subtraída integralmente do genitor. Não há bônus
reprodutivo de energia nem reposição de energia ao descansar. Filhotes começam
com idade zero e IDs próprios de corpo e genoma; recebem um genitor e geração
igual à do genitor mais um. Apenas organismos vivos abaixo da idade máxima se
reproduzem; recém-nascidos só entram na atualização do passo seguinte. O limite
de população também vale para introduções pelo editor/API. Uma tentativa
inelegível não cobra energia.

Os genes são copiados do genitor. Para cada gene sorteado, o RNG do mundo gera
um desvio gaussiano, recortado a ±3 desvios padrão, aplicado dentro dos bounds
físicos e da precisão de 0,000001. O delta efetivamente aplicado fica tanto em
eventos `mutation` (`gene`, `delta`, `parent_id`, `creature_id`, `tick`) quanto no
registro permanente do nascimento. Um desvio recortado a zero não é apresentado
como mudança. Não se recria um genoma aleatório no nascimento.

Velocidade controla deslocamento e custo de movimento; visão controla alcance e
campo perceptivo; metabolismo controla gasto basal; tamanho controla capacidade
de energia, custo basal, raio de colisão e alcance para comer. Esses efeitos
físicos preexistentes foram preservados e receberam verificações comparativas.
Matiz determina aparência; não é tratada como vantagem adaptativa. O ajuste nos
limites irracionais do campo visual mantém o valor na grade decimal do save,
evitando alteração ao carregar uma mutação que atingiu um extremo.

## Genealogia, consulta e persistência

`save_version` do mundo passa a **2**. O formato do envelope de `SaveStore` e as
versões de criatura, genoma e cérebro continuam compatíveis, com campos novos
aditivos. Cada criatura persiste `reproduction_cooldown`; o mundo persiste os
parâmetros de evolução e `genealogy`, incluindo genoma de nascimento, genitores,
geração, passo de nascimento, passo/motivo de morte e mutações. Ancestrais mortos
continuam no histórico mesmo após o descarte de eventos do buffer de 256 itens.

`parents` dos nascimentos novos referencia **IDs de criaturas**, não IDs de
genomas. A validação exige genitores existentes com IDs anteriores, geração
coerente e deltas compatíveis com os genomas. Isso impede ciclos sem recursão e
sem depender da profundidade máxima da pilha. IDs de ancestrais mortos também
são reservados contra colisões com corpos, genomas e alimentos carregados.

| API pública de `SimWorld` | Retorno |
|---|---|
| `reproduce(creature_id)` | ID do filhote ou `-1` |
| `lineage(creature_id)` | Organismo e ancestrais, ordenados por ID |
| `descendants(creature_id)` | Todos os descendentes, ordenados por ID |
| `genetic_diversity()` | Variância populacional por gene entre organismos vivos |

Consultas de linhagem devolvem cópias, para não alterar o histórico ao inspecionar.
A variância divide por N, não por N−1; população vazia ou unitária retorna zero.

A migração de v1 mantém identidades, nomes, genomas, cérebro, memória, recursos,
passo, estado do RNG e sequência de IDs. Reconstrói os sobreviventes com passo
de nascimento estimado por `max(0, tick - age)`. v1 não registrava reprodução
real nem ancestrais mortos; não há como recuperá-los. Metadados de genitores ou
gerações aceitos por v1 são preservados no genoma e marcados `legacy_root=true`
no registro reconstruído: não são convertidos em vínculos não verificados.
Fundadores comuns recebem `legacy_root=false`. Não se inventam ancestrais.

As configurações novas são `reproduction_enabled`, `max_population`,
`min_reproduction_age`, `reproduction_cooldown`, `max_age`, `mutation_rate` e
`mutation_scale`. Há um limite operacional de 100.000 registros permanentes;
ao alcançá-lo, novas introduções/reproduções são recusadas, sem podar ancestrais.
O limite de arquivo de 32 MiB do `SaveStore` permanece vigente.

## Aprendizado e testes

O cérebro do genitor é preservado. Sua próxima transição Q contabiliza o custo
real da reprodução na variação de energia. Filhotes começam com a heurística
normal (`brain == null`); não há herança de memória ou aprendizado adquirido.
O protocolo G2 e seus testes controlados usam `reproduction_enabled=false` para
continuar medindo aprendizado individual. O benchmark de sensores declara o
limite correspondente a cada população, evitando que o novo teto padrão reduza
silenciosamente seus cenários de 300/1.000 organismos.

`test_evolution.gd` verifica idade/energia mínimas, transferência conservativa,
intervalo entre reproduções, ausência de reprodução de mortos, IDs próprios,
herança sem mutação, 250 heranças com mutações e extremos dos bounds, registro
dos deltas, pelo menos três gerações descendentes, genealogia sem ciclos,
persistência de ancestrais mortos, limite populacional, morte por idade,
ausência de criação de energia sem alimento, efeitos fenotípicos, variância,
consultas por cópia, migração v1, save JSON com duas precisões, continuação do
RNG/IDs e round-trip pelo `SaveStore`. Também rejeita ciclos, genitores ausentes,
gerações/deltas incompatíveis e configurações inválidas.

Executável: Godot 4.7.2 console fornecido na tarefa. Comandos executados:

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/run_tests.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/experiments/sense_bench.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/experiments/evo_run.gd -- --ticks 6000
```

Resultado final de `tests/run_tests.gd`: **exit 0**, com `test_behavior_learn`,
`test_evolution`, `test_save_store`, `test_sim_review`, `test_sim_world`,
`test_smoke` e `test_textos`, todos `ok`, sem erros de script. A suíte foi repetida
após a última alteração de teste, incluindo igualdade da próxima reprodução,
mutação e IDs depois de carregar.

`sense_bench.gd`: **exit 0**, snapshots completos idênticos entre percepção
indexada e exaustiva para 30, 100, 300 e 1.000 organismos. Foi executado em
paralelo com o experimento; seus tempos não são usados aqui como nova referência
de desempenho. `evo_run.gd -- --ticks 6000`: **exit 0**, com round-trip idêntico
nos seis mundos. `git diff --check`: **exit 0**.

A primeira rodada de desenvolvimento terminou com exit 1: a comparação de
genitores precisava normalizar os números lidos do JSON, e o teste de aprendizado
controlado precisava isolar reprodução. Ambos foram corrigidos antes das rodadas
verdes; não houve ajuste do aprendiz nem reavaliação de HOLDOUT para alterar os
critérios G2. Os resultados anteriores de aprendizado não foram regravados.

## Protocolo do experimento

`tests/experiments/evo_run.gd` aceita `--ticks N` entre 1 e 100.000, com padrão
6.000. Usa sementes fixas **7421, 104729 e 8675309** e grava as séries completas,
configuração, linhagem de exemplo e resultado da validação salvar/carregar em
`tests/experiments/results/evo_run_results.json`. Imprime população, geração
máxima já registrada, nascimentos e variância de cada gene a cada 500 passos.

Cenário com recursos renováveis: mundo 600×420, 12 fundadores, 120 alimentos
iniciais, capacidade 160, reposição de quatro alimentos a cada dez passos,
cinco obstáculos, teto de 60 vivos, idade mínima 120, intervalo reprodutivo 200
e idade máxima 3.000. Mutações usam os parâmetros padrão. Não há alimentação
manual, posicionamento de comida em função de organismos ou concessão de energia
depois da inicialização. A reposição é uma entrada explícita de recursos.

O cenário sem alimento usa as mesmas sementes e parâmetros, mas nenhum alimento
inicial ou reposição. Cada cenário inicializa seu mundo separadamente; como a
criação de alimento consome RNG, seus genomas iniciais não são um pareamento
idêntico entre condições. O cenário de escassez testa restrição energética;
não constitui uma comparação causal controlada de adaptação.

## Resultados medidos

Cada mundo avançou **6.000 passos**, equivalentes a 600 segundos simulados.
Geração zero corresponde aos fundadores; geração quatro significa quatro elos
reprodutivos sucessivos, ou cinco níveis observáveis na linhagem.

| Cenário | Semente | Geração máxima registrada | População final | Nascimentos | Mortes |
|---|---:|---:|---:|---:|---:|
| Recursos renováveis | 7421 | 4 | 60 | 120 | 72 |
| Recursos renováveis | 104729 | 4 | 60 | 120 | 72 |
| Recursos renováveis | 8675309 | 4 | 60 | 121 | 73 |
| Sem alimento | 7421 | 0 | 0 | 0 | 12 |
| Sem alimento | 104729 | 0 | 0 | 0 | 12 |
| Sem alimento | 8675309 | 0 | 0 | 0 | 12 |

Nos três mundos com recursos, a amostra do passo 500 já mostrava geração 3 e
60 vivos. O teto impediu mais nascimentos até a abertura de vagas por morte;
as novas ondas elevaram a geração máxima a 4. No cenário sem alimento, as
populações nas amostras 500/1.000/1.500 foram respectivamente **12/5/0**,
**12/2/0** e **11/2/0** nas sementes listadas. A soma de energia dos corpos nunca
aumentou em nenhum passo desses três mundos (`no_food_energy_nonincreasing=true`).
As reservas iniciais eram 80% da capacidade, abaixo do limiar reprodutivo de 90%.
Um teste separado começa com reserva suficiente para uma reprodução e comprova
que ela redistribui essa energia sem criar novos recursos.

As variâncias abaixo são populacionais, arredondadas apenas para apresentação;
o JSON contém todos os pontos a cada 500 passos e mais precisão. Identificadores
dos genes seguem os nomes técnicos originais do save.

| Semente | Passo | `size` | `speed` | `vision_range` | `vision_fov` | `metabolism` | `hue` |
|---|---:|---:|---:|---:|---:|---:|---:|
| 7421 | 0 | 3,461460 | 238,459347 | 3290,480281 | 2,347928 | 0,099653 | 0,048976 |
| 7421 | 500 | 3,495466 | 242,485995 | 3305,246116 | 2,371525 | 0,101164 | 0,047873 |
| 7421 | 3000 | 3,430125 | 247,785607 | 3406,042732 | 2,442875 | 0,101375 | 0,048636 |
| 7421 | 6000 | 3,594371 | 263,558950 | 3536,474136 | 2,470880 | 0,102981 | 0,047471 |
| 104729 | 0 | 8,561121 | 169,108215 | 2557,932227 | 2,056164 | 0,079336 | 0,132854 |
| 104729 | 500 | 9,015888 | 173,880155 | 2610,877852 | 2,067730 | 0,083069 | 0,133894 |
| 104729 | 3000 | 8,876101 | 166,959766 | 2623,791643 | 2,057458 | 0,087689 | 0,137644 |
| 104729 | 6000 | 9,428450 | 189,445782 | 2747,638350 | 1,896736 | 0,083607 | 0,142473 |
| 8675309 | 0 | 5,711490 | 255,264049 | 1548,526545 | 1,738730 | 0,086466 | 0,068378 |
| 8675309 | 500 | 5,664885 | 252,345336 | 1352,853573 | 1,698951 | 0,085657 | 0,066192 |
| 8675309 | 3000 | 5,781079 | 259,261040 | 1324,762486 | 1,632090 | 0,083723 | 0,066683 |
| 8675309 | 6000 | 5,014626 | 236,042989 | 840,049474 | 1,654554 | 0,084628 | 0,059779 |

Nas três populações extintas, todas as variâncias são zero a partir da amostra
1.500. Isso é a convenção para população vazia, não evidência de homogeneização
genética adaptativa.

Exemplo auditável na semente 7421:

| ID da criatura | Genitor | Geração | Nascimento | Morte |
|---:|---:|---:|---:|---:|
| 124 | — | 0 | 0 | 3000 |
| 192 | 124 | 1 | 120 | 3120 |
| 264 | 192 | 2 | 240 | 3240 |
| 360 | 264 | 3 | 360 | 3360 |
| 1508 | 360 | 4 | 3240 | Viva no passo 6000 |

Na passagem 360 → 1508, `speed` mudou de **63,800438 para 63,063029**:
delta registrado **−0,737409**, dentro do máximo **3,525** para esse gene.
`size` mudou de **11,888464 para 11,627410** (delta **−0,261054**),
`vision_range` de **92,711719 para 103,793748** (delta **+11,082029**) e
`metabolism` de **0,849103 para 0,903295** (delta **+0,054192**). Os outros genes
foram copiados sem mudança. Os quatro ancestrais mortos continuam disponíveis
na mesma linhagem após salvar/carregar.

Artefato: `tests/experiments/results/evo_run_results.json`, SHA-256
`22019fbcf2826dbc36fafce842434dd1d113776157bbdd735123b972dc7e1c76`.

## Limites da interpretação

As medições comprovam reprodução, hereditariedade com variação e persistência
de linhagens. **Não foi medida adaptação.** Não há critério de melhora de aptidão,
comparação entre genótipos em ambiente comum, controle sem mutação ou teste de
seleção que permita essa alegação. Mudanças de variância, sobrevivência ou
gerações isoladamente não demonstram adaptação; o teto de população interfere
fortemente nos nascimentos no cenário abundante.

A seleção ecológica ocorre pelas regras de energia, alimento, competição e
mortalidade existentes. Introduções de fundadores pelo jogador continuam sendo
entradas explícitas de organismos/energia. Não há pareamento sexual, herança de
cérebro, mutação de topologia neural, espécies automáticas ou painel novo nesta
entrega. UI e renderização serão integradas pelo responsável desses caminhos.
O determinismo é verificado nesta versão/plataforma do Godot, sem promessa de
replay idêntico entre versões ou plataformas.
