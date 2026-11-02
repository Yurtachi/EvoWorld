# M1b — causalidade do afeto, recuperação e persistência

Data: 02/11/2026. Base `evo3/integration` @ `f4efe0d`, branch local
`Yurtachi/evo3-m1-fix`. **Implementação/compatibilidade: PASS; critérios
pré-registrados: PASS; demonstração ampla de estratégia física em X2: PARTIAL.**

- [FATO] Afeto e memória apresentam efeitos causais separados sobre contato
  físico em X1b: +48,61 pontos percentuais cada, nos contrastes fatoriais.
  Ablação específica remove aproximadamente 100% do respectivo contraste.
- [FATO] Frustração antecipa a troca de objetivo nos 20/20 pares X2b; porém a
  contagem de ações físicas muda em apenas 4/20, não nos outros 16/20.
  Não se afirma que uma troca de nome do objetivo seja uma nova estratégia física.
- [FATO] 18 suítes passaram, exit 0: as 17 existentes e `test_sim_m1b.gd`.
  Golden legado, determinismo e saves v1–v8 continuam cobertos.
- [LACUNA] Revisão independente e integração pertencem ao coordenador.
  Não houve push/merge nem edição de UI/render/persistência/Textos.

## Diagnóstico e mudança real

[FATO] A leitura de `M1_mind.md` e do código confirmou que o M1 já somava
afetos aos scores, mas mantinha compromisso fixo de 12/80 ticks e histerese
0,08. Memória de contato positiva/negativa podia dominar as escolhas; os dois
perfis originais variavam simultaneamente em temperamento e experiência.
Desligar afeto removia também a saturação que limitava contato positivo. O
resultado negativo do holdout M1 permanece válido e não foi reescrito.

[FATO] A alteração de produção está exclusivamente em
`scripts/mind/motivation.gd`. `utilities()` mantém necessidades, temperamento,
recuperação episódica e os mesmos oito sorteios do RNG mental por decisão.
`modulation()` calcula limiares afetivos e controles de persistência sem ler
episódios. `scores()` subtrai os limiares; `choose()` aplica compromisso,
histerese, exclusão da estratégia bloqueada e urgências. O objetivo resultante
continua passando pelo executor físico existente `_mind_action()`.

[FATO] Frustração reduz compromisso mínimo de 12 até 2 ticks e máximo de 80
até 12, proporcionalmente ao estado, quando há bloqueios recentes e o objetivo
é locomotor. Com frustração >=0,25 e pelo menos dois bloqueios, a estratégia
atual é excluída na próxima decisão não crítica, mesmo antes do mínimo. O
contador sozinho não ativa essa liberação: sem afeto os limites são 12/80.
Movimento efetivo já limpa o contador e reduz frustração pelo observador M1.

[FATO] Solidão reduz o limiar de companhia; saturação o eleva e reduz o de
privacidade. Receio aumenta limiares de exploração/companhia, favorece
privacidade com vizinho e repouso sem vizinho, e eleva histerese. Satisfação
eleva limiares de exploração/brincadeira e favorece repouso; foi removido seu
antigo bônus de companhia. Fome/sede críticas continuam prevalecendo.

[FATO] Os limiares sociais equivalem algebricamente a contribuições aditivas
aos scores. A mudança estrutural além desses pesos é a persistência afetiva;
não se atribui causalidade à simples renomeação de parcelas. Recuperação
continua sendo o mecanismo M1 de três episódios por recência, relevância e
importância, sem mudanças no algoritmo nem acesso a afeto.

[LACUNA] O sensor não identifica uma fonte espacial de toxicidade com
proveniência suficiente para associá-la a um alvo evitável. Receio favorece
cautela/afastamento social geral; não foi implementada evitação seletiva de
uma fonte tóxica específica. Não se inventou esse dado nem se alterou o mundo
fora do ownership. Código próprio, sem consulta/cópia de fontes GPL.

## Protocolo, congelamento e auditoria

[FATO] Protocolo novo e imutável:
`tests/experiments/m2_affect_preregistro.md`, commit **52f7657**.
Motor, avaliador e testes congelados em **4d8a82a**, antes da abertura.
TRAIN: 93601–93604; DEV: 93701–93706; HOLDOUT único: 94831–94850,
distintos dos 81001–81006/82401–82420 de M1. TRAIN e DEV finais passaram.
Nenhum motor, parâmetro, avaliador, critério ou seed mudou após o holdout.

[FATO] SHA256 do protocolo como texto UTF-8 sem BOM, LF:
`375b6cdc194ec5eea5d65e422dd6799ba9b224ab62079852bc65a565917fbad7`.
O resultado registra esse hash e hashes do motor/avaliador. O avaliador grava
e sincroniza marcador `status=opened` antes do primeiro ensaio; recusa nova
abertura se `reports/M1b_afeto_eval.json` existe. Não foi invocado novamente.

[FATO] SHA256 do resultado integral em LF:
`d639e7f3399489c8e1af213b986fcb7fa0d9cf32dfcc5917f4565d7b43a38ede`.

[FATO] A auditoria `python tests/experiments/m2_affect_verify.py` verifica o
protocolo ancestral, sua identidade, hashes congelados anteriores ao primeiro
commit do resultado, seeds e presença da guarda. A ordem local é protocolo,
motor/avaliador, resultado; o histórico deve ser preservado na integração.

[FATO] Durante TRAIN, corrigiram-se dois defeitos da fixture antes do
congelamento: ID de vizinho assumido incorretamente e edição de genoma após
registrar ancestralidade. Esses ensaios iniciais não passaram persistência e
não foram usados como evidência. A versão final usa ID efetivo e cria o genoma
do vizinho antes do spawn; 100% dos round trips passaram em TRAIN/DEV/HOLDOUT.
Não houve ajuste dos limiares de produção depois do primeiro TRAIN.

[LACUNA] Git demonstra a identidade e ordem de artefatos, não ausência
universal de execuções ocultas. A abertura única descreve esta execução.

## X1b — fatorial afeto × memória, ação física

[FATO] 480 ensaios = 20 seeds × 6 braços × 2 estados × 2 memórias. Doadores
adquirem estado por 100 observações de contato prolongado ou ausência. Outros
doadores adquirem três episódios positivos/adversos por 61 observações de
encontro real, com/sem disputa de alimento. Não há atribuição direta de afeto
ou recompensa inventada; as observações de aquisição avançam tick sem
metabolismo, intervenção controlada declarada no protocolo.

[FATO] Afeto e episódios são transplantados separadamente para cópias de
mesmo corpo, RNG, traços 0,5, geometria, fisiologia e vizinho ao alcance.
A ablação é aplicada só na avaliação, conservando históricos adquiridos;
`affect_enabled=false` elimina modulação/expressão/atualização, não apaga
estados anteriores. `memory_enabled=false` elimina codificação/recuperação M1.
A memória e a expressão corporal legadas E2 permanecem independentes.
São 36 ticks de autonomia sem ordens/ensino; contato exige alcance e linha de
visão. O vizinho permaneceu imóvel em 480/480 ensaios.

| Braço | Efeito afetivo A | Efeito de memória M | Seeds A>0 / M>0 |
| --- | ---: | ---: | ---: |
| Completo | +48,61 pp | +48,61 pp | 20/20 / 20/20 |
| Sem afeto | ~0 pp | +97,22 pp | 0/20 / 20/20 |
| Sem memória | +70,00 pp | 0 pp | 20/20 / 0/20 |
| Sem ambos | 0 pp | 0 pp | 0/20 / 0/20 |
| Aleatório | 0 pp | 0 pp | 0/20 / 0/20 |
| Parâmetros fixos | 0 pp | 0 pp | 0/20 / 0/20 |

[FATO] A = média do contraste solidão−saturação sobre as duas memórias;
M = média do contraste memória positiva−negativa sobre os dois afetos.
Sem afeto remove ~100% de A (resíduo numérico −4,86e−17 em fração);
sem memória remove 100% de M. A sem memória conserva 144% do completo;
M sem afeto conserva 200%. Todos os critérios de magnitude, especificidade,
ablação e controles pré-registrados passaram, sem interpretar os efeitos
fatoriais como partes aditivas independentes de um único total.

[FATO] No completo, a célula solidão+memória positiva permanece em contato
100% dos ticks; as outras três ficam em 2,78% cada (um tick em 36).
Há interação forte entre os canais: a memória negativa ou a saturação bastam
para limitar contato nesse cenário. Save/load no tick 18 preservou exatamente
o JSON final e a continuação em 480/480 ensaios, incluindo RNG/logs/afetos.

[LACUNA] O contraste afetivo cruza vetores adquiridos completos, incluindo
entusiasmo/tranquilidade, não apenas um escalar de solidão ou saturação.
Testes unitários isolam cada estado. As seeds variam RNG em geometria fixa;
não representam 20 ambientes ecológicos distintos. O ensaio demonstra
causalidade do estado atual sob intervenção, não aprendizagem social livre,
necessidade de afeto em toda divergência, nem superioridade sobre o antigo
motor M1 em um novo confronto direto. O fracasso original de X1 não foi apagado.

## X2b — persistência e limite da mudança de estratégia

[FATO] 160 ensaios = 20 seeds × 4 braços × 2 condições. A aquisição frustrada
rejeita dez tentativas físicas contra obstáculo; o neutro não passa pelas
tentativas. Memória episódica de bloqueio é limpa para isolar o estado;
contadores corporais são preservados, controlados pelos braços sem afeto.
A avaliação parte de explorar recém-comprometido, por 12 ticks autônomos.

| Braço | Encurtamento da permanência inicial | Pares com >=4 ticks | Repouso frustrado / neutro |
| --- | ---: | ---: | ---: |
| Completo | 12 ticks na janela | 20/20 | 48/240 / 0/240 |
| Sem afeto | 0 ticks | 0/20 | 0/240 / 0/240 |
| Sem memória | 12 ticks na janela | 20/20 | 48/240 / 0/240 |
| Sem ambos | 0 ticks | 0/20 | 0/240 / 0/240 |

[FATO] No completo, o primeiro objetivo muda na primeira decisão, índice 0;
o neutro conserva explorar nos 12 ticks. O valor 12 usado para ausência de
troca é censura à direita, não latência exata observada. A ablação de afeto
remove 100% desse contraste; sem memória o conserva integralmente. Pico de
frustração 0,56925, após liberação/96 ticks 0 em 20/20 pares completos;
passam os critérios de persistência e recuperação.

[FATO] A inspeção descritiva pós-holdout das ações, já registradas no JSON,
encontra contagens diferentes em **4/20 pares**, por repouso em todos os 12
ticks dessas quatro seeds. Nos demais 16/20, completo frustrado e neutro
executam 1 `avoid_obstacle` + 11 `explore`. Sem afeto são 20/20 com essas
mesmas contagens; sem memória reproduz as quatro seeds com repouso.
Esse endpoint físico não tinha limiar de aprovação pré-registrado.

[HIPOTESE] Quando o novo objetivo é companhia sem vizinho percebido, o
executor existente usa exploração como fallback. Assim, excluir explorar
pode mudar o objetivo sem mudar a classe da ação. Isso explica a limitação
do acoplamento entre candidato e executor; o avaliador X2 não registrou a
identidade de todos os objetivos novos nem trajetórias completas, então não
se afirma essa explicação por seed como fato observado.

[LACUNA] **X2b é PASS para a persistência do objetivo pré-registrada e PARTIAL
para troca física consistente de estratégia.** Um próximo protocolo deverá
medir alvo/rota/primeira ação alternativa executável, impedir alternativas
indisponíveis e definir limiar físico antes de novas seeds inéditas. Nenhuma
correção foi feita após olhar o holdout, e ele não deve ser reutilizado para ajuste.

## Compatibilidade, testes e CPU

[FATO] Comando obrigatório, Godot console 4.7.2 indicado no despacho:
`godot --headless --path . -s tests/run_tests.gd`: exit 0, 18 suítes ok,
sem FAIL/SCRIPT ERROR. Inclui golden integral M1 de origem v7, determinismo,
continuação JSON/disco v8, migrações/hostis v1–v7 e cenários E2/E3/E4/E5.
Log local ignorado: `builds/m2_affect_tests.log`.

[FATO] A nova suíte testa solidão, saturação, receio, satisfação,
persistência frustrada, ablações, urgências, separação memória/limiares e
round trip do estado. Não há campo novo persistido: controles são derivados
dos estados/counters existentes, portanto save v8 e validadores não mudaram.
Mundos sem mente continuam na trajetória/golden legados. Nenhum experimento
antigo `ensino_eval/learn_eval/social_eval/m1_eval` foi executado nem seu JSON alterado.

[FATO] CPU serial deste worker, seed TRAIN 93604, 100 ticks de aquecimento +
400 medidos por condição, reprodução desligada. Populações finais iguais
às iniciais. Não houve outro processo Godot deste worker concorrendo com CPU.

| Criaturas | Desligado média/p95 ms | Só pet média/p95 ms | Todas média/p95 ms |
| --- | ---: | ---: | ---: |
| 12 | 1,687 / 2,671 | 2,047 / 3,034 | 3,634 / 6,203 |
| 30 | 4,971 / 7,730 | 5,153 / 8,287 | 12,504 / 17,595 |
| 60 | 10,424 / 15,358 | 10,384 / 14,960 | 23,255 / 37,388 |
| 100 | 22,468 / 30,756 | 20,885 / 29,393 | 51,407 / 70,825 |

[FATO] Critério operacional pet acrescenta <=2 ms/tick médio: PASS nos quatro
tamanhos. Acréscimos observados +0,360/+0,182/−0,040/−1,583 ms. Diferenças
negativas são compatíveis com ruído de medição/trajetórias distintas, não
prova de aceleração pela mente. Todas/100 custa 2,29× o desligado, p95 70,825 ms.

[LACUNA] Não se demonstrou ausência de regressão frente a M1 por benchmark
pareado de dois motores na mesma máquina/carga; o controle é mente desligada.
Os tempos incluem física/consultas/trajetórias, não função mental isolada.
Não se inferem FPS gráfico, escalabilidade sustentada nem margem para 5×.
Ativar somente o pet continua sendo a configuração padrão apropriada a estes dados.

## Artefatos e reprodução

[FATO] `M1b_afeto_eval.json` conserva os 640 ensaios do holdout e metadados;
`M1b_afeto_train.json` e `M1b_afeto_dev.json` conservam os ensaios finais de
desenvolvimento; `M1b_afeto_cpu.json` contém amostras resumidas e orçamento.
O campo `scientific_status=PASS` do avaliador refere-se estritamente aos
critérios pré-registrados, não à generalização física adicional discutida aqui.

[FATO] Podem-se repetir testes, TRAIN (`m2_affect_eval.gd -- --train`), DEV
(`m2_affect_eval.gd`, sem argumentos) e CPU (`m2_affect_cpu.gd`). HOLDOUT está
fechado: conservar o resultado e não apagar o marcador. A auditoria de commits
é somente leitura. Identidade local dos commits: Yurtachi, sem trailers de IA.

[LACUNA] Revisão independente, UX e eventual trabalho futuro sobre a
disponibilidade de alternativas ficam para coordenação; não se declara mente
subjetiva nem experiência consciente. No produto, a formulação deve continuar
como “parece buscar companhia” ou “aparenta cautela”, com textos via Textos.
