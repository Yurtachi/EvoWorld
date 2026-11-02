# M1 — mente por criatura: implementação e ensaios

Data: 02/11/2026. Base `evo3/integration` em `b5c27dc`; branch local
`Yurtachi/evo3-m1-mind`. **Implementação: PASS; demonstração científica: PARTIAL.**

- [FATO] Motor mental, API, save v8 e compatibilidade implementados; 17 suítes
  passaram (16 anteriores + M1), exit 0, sem `FAIL` nem `SCRIPT ERROR`.
- [FATO] X1 diverge nos 20 pares, mas **desligar afeto não remove o efeito**.
  Desligar memória reduz a diferença conforme o limiar pré-registrado, sem
  zerá-la. Portanto não foi demonstrada a necessidade conjunta de afeto e memória.
- [FATO] X2 demonstra afeto causal, expressão e recuperação; **scores também
  mudam sem afeto**, por memória/fadiga/ruído. Não se afirma eliminação de toda
  mudança comportamental por essa ablação.
- [LACUNA] UX, revisão independente e integração pertencem ao coordenador.
  Não houve edição de UI/render/Textos, push ou merge.

## Motor e fronteiras físicas

[FATO] Implementação original em `scripts/mind/{affect,motivation,creature_mind}.gd`,
guiada pelos contratos locais. Nenhum código/asset/peso externo foi copiado,
traduzido ou incorporado; Dosidicus e Pestinha não foram acessados para implementar.
Foram lidos `EVOWORLD_3_SPEC`, `EVOWORLD_3_REUSE`, `EVOWORLD_2_SPEC`,
`EVOWORLD_2_STATUS` e `M0_integridade`.

[FATO] Os sete estados estão em [0,1], quantizados a 1e-6. Ganhos e decaimentos
dependem dos quatro traços. `cause_log` conserva as últimas 96 mudanças com
`{tick, estado, delta, causa}`; valores zero não crescem por simples decaimento.
Ausência de contato, repouso seguro e contato prolongado são condições físicas
observadas, não sorteios de emoções pelo relógio. Bloqueios físicos repetidos
(a partir do segundo impedimento) causam frustração; mero desvio preventivo
que consegue mover não conta como bloqueio. Ingestão/bebida com benefício
causam satisfação, toxicidade e disputa vividas causam receio, contato prolongado
causa saturação e ausência causa solidão ponderada por sociabilidade.

[FATO] `affect.gd` recebe números e traços; não recebe o corpo e não escreve
energia/hidratação/posição. Mudanças físicas passam pelos executores existentes
de movimento, ingestão, água e metabolismo. Companhia aproxima de um vizinho
percebido; privacidade move na direção oposta; contato exige alcance e linha
de visão. Brincar usa locomoção normal; investigar objeto permanece stub sem
objetos inventados. Familiaridade/afinidade/aversão E2/E4 continuam disponíveis
nos vínculos existentes; M1 guarda também consequências assinadas de encontros.

[FATO] Oito candidatos são pontuados por urgência, afeto, memória, temperamento
e ruído de um RNG próprio por criatura, sem sorteios extras no RNG biológico
quando M1 está desligado. Recuperação própria: recência + relevância contextual
+ importância, escolhendo até três episódios e ponderando sua consequência.
Memória M1: 32 episódios, TTL 2400 ticks; `mind_log`: 48 trocas. Episódios
expiram pelo tick persistido. Não há memória adquirida herdada.

[FATO] Compromisso mínimo de 12 ticks, máximo de 80 e margem de histerese
0,08 impedem oscilação imediata e permanência indefinida não crítica. O máximo
exclui o objetivo anterior na troca; necessidades críticas podem sobrepor esse
limite. A priorização mental começa acima de 0,55 de fome/sede; os reflexos
físicos preexistentes acima de 0,6 continuam prevalecendo sobre ordens/ensino.
As trocas gravam `{tick, objetivo, pontuacoes, motivo}`. Durante ordens/ensino,
o desejo pode ser observado enquanto o executor dessas intervenções tem prioridade
até o limiar físico de sobrevivência.

[FATO] `affect_enabled=false` remove contribuição afetiva dos scores e da
expressão e impede atualizações afetivas; `memory_enabled=false` remove
codificação e recuperação M1. Afetos históricos podem continuar persistidos
se a flag for desligada depois da experiência, para permitir reversão da ablação.
Memória/expressão legadas E2 continuam físicas e independentes dessas flags.

## Escopo, API e save

[FATO] Somente `SimWorld.new_world()` ativa por padrão o pet. O construtor
histórico `World.new()` continua sem M1. `mind_all=false` e
`mind_enabled_ids` persistem o escopo; uma lista explicitamente vazia desliga
a ativação padrão. `enable_mind(id)` e `disable_mind(id)` não mudam recursos,
genes, IDs ou RNG biológico. `mind_all=true` inclui novos nascimentos; IDs
mentais de criaturas mortas são removidos.

[FATO] `creature.mind` é null quando desativado. `creature.mind_snapshot()`
retorna cópias destacadas:

```text
afetos: {frustracao, tranquilidade, entusiasmo, receio,
         solidao, satisfacao, saturacao_social}
objetivo_atual, motivo, ultimos_logs
expressao: {valence, arousal}
cause_log, pontuacoes, affect_enabled, memory_enabled
```

[FATO] Motivos: `mind.disabled`, `mind.score`, `mind.timeout`, `mind.urgency`.
Causas: `decay`, `blocked_motion`, `need_satisfied`, `toxic_exposure`, `contact`,
`adverse_contact`, `prolonged_contact`, `absence_of_contact`, `safe_rest`,
`free_movement`. Identificadores são dados; sua apresentação pt-BR pertence a
Textos/UI. `expression_state()` inclui modulação M1 quando habilitada.

[FATO] Save v8 armazena afeto, flags, objetivo/compromisso, scores, logs,
experiências, contadores, RNG e mapa vazio de objetos reservado ao M2.
Leitura rejeita NaN/inf, tipos errados, coleções/contadores fora do limite,
estados/candidatos/causas desconhecidos, ticks futuros, IDs mentais duplicados
ou sem corpo e fontes de contato sem ancestralidade. Saves v1–v7 migram
sem inventar experiências nem ativar mente; carregar de novo o estado v8 é
idempotente. A entrada não é modificada pela migração.

[FATO] O envelope do SaveStore não mudou: tetos 8 MiB decodificados/32 MiB
em disco, razão máxima 64, backup/rollback e escrita validada continuam.
TTL persistido de ordens do M0 permanece intacto. Round trip JSON e em disco
com continuação pareada foram verificados.

## Compatibilidade e testes

[FATO] `m1_golden.json` foi capturado com o simulador intocado `b5c27dc`,
antes de M1, em dois mundos v7 com/sem E2, seed 7823. O teste migra a entrada,
executa 100 ticks e compara **todo o JSON** com a referência também migrada:
posições, necessidades, RNG, genes, eventos e memórias. Criaturas explicitamente
sem mente também continuam byte a byte iguais ao controle após enable/disable.

[FATO] Os hashes históricos de E5 foram preservados, não atualizados para
aceitar trajetórias novas. O teste histórico declara `mind_enabled_ids=[]` e
remove somente a versão/metadados novos de schema antes de calcular o mesmo
hash v7. A fixture E2 de coexistência com QBrain também explicita M1 desligado;
uma asserção E4 literal de versão 7 passou a `World.SAVE_VERSION`.
Esses são os três ajustes mínimos fora de `test_sim_m1.gd`, comunicados ao
coordenador durante a execução.

[FATO] Comando obrigatório, console Godot 4.7.2 indicado no despacho:

```text
godot --headless --path . -s tests/run_tests.gd
exit 0; 17 suites ok; 0 FAIL; 0 SCRIPT ERROR
```

[FATO] M1 testa: causas físicas, tempo neutro, ablações, compromisso/máximo,
fome/sede críticas, aproximação/afastamento, custo, memória adversa, mesma seed,
snapshot imutável, v8 JSON/disco, continuação, migração/golden e entradas hostis.
As suítes anteriores continuam cobrindo 693+ saves hostis v1–v7, 1204 mutações
aninhadas e 280 TTLs hostis do M0. Log local ignorado:
`builds/m1-tests-final.log`.

## Pré-registro e abertura única

[FATO] Ordem dos commits locais: `c8e9e91` (protocolo e golden), depois
`99dd814` (motor, testes e avaliador), depois artefatos/este relatório.
O motor/avaliador não foram ajustados após o HOLDOUT. DEV usou somente
81001–81006; HOLDOUT usou 82401–82420, mesmas seeds pareadas em todos os
braços. O avaliador cria marcador durável antes do primeiro ensaio e recusa
nova abertura quando `reports/M1_mind_eval.json` já existe. Não foi executado
novamente o HOLDOUT.

[FATO] SHA256 do protocolo canônico LF:
`4ccc451683f1e542131f1ad8aedd291e3e4b312cb51c88283cbc23556d9ccac3`.
O JSON do holdout contém o mesmo hash; SHA256 do blob LF do resultado:
`5f262cf19b85e0ff73a5158cb1ed8874af151595d53ef295516693592272f482`.
`verify_prereg.sh` foi ampliado para exigir protocolo/avaliador em commits
anteriores ao primeiro resultado e conferir o blob/checksum do protocolo.

[LACUNA] Como em M0, Git prova ordem de commits e identidade de artefatos,
não ausência universal de execuções locais ocultas. A abertura única declarada
aqui descreve esta execução; nenhum resultado E3/E4 existente foi reexecutado
ou reescrito. Integração deve preservar a ancestralidade desses commits para
que a auditoria continue válida.

## X1 — isolamento versus companhia

[FATO] 200 ensaios: 20 seeds × 5 braços × 2 perfis. A: sociabilidade 0,9,
cautela 0,2 e histórico físico positivo. B: sociabilidade 0,2, cautela 0,9 e
histórico físico de disputa. Aquisição de 30 observações em contato real;
avaliação sem alimentos/ameaças variáveis, vizinho fisicamente ao alcance,
necessidades iniciais iguais. O vizinho conserva energia/posição pelo descanso
normal durante os 240 ticks; deslocamento zero verificado nos 200 ensaios.

| Braço | Contato A | Contato B | A−B | Seeds A>B |
| --- | ---: | ---: | ---: | ---: |
| Completo | 80,71% | 0,42% | 80,29 pp | 20/20 |
| Sem afeto | 100,00% | 0,42% | 99,58 pp | 20/20 |
| Sem memória | 34,46% | 4,94% | 29,52 pp | 20/20 |
| Aleatório | 16,92% | 16,92% | 0,00 pp | 0/20 |
| Parâmetros fixos | 5,83% | 5,83% | 0,00 pp | 0/20 |

[FATO] Divergência completa passa os limiares pré-registrados: >=15 pp e
>=15/20 seeds. Sem memória reduz a diferença para 36,77% da completa,
passando o critério quantitativo de redução a <=50%, **mas não elimina
literalmente a divergência**. Sem afeto não passa: a diferença aumenta.
Logo, **X1 é PARTIAL**, e a hipótese de afeto necessário para essa divergência
foi refutada neste cenário.

[FATO] Save/load no tick 120 da avaliação preservou exatamente o estado e
a continuação em 200/200 ensaios, incluindo RNG, logs e fração de contato.
No completo, contato A foi 86,54% na primeira metade e 74,88% na segunda;
B foi 0,83% e 0%. A diferença não se deve a um reinício de memória pelo load.

[HIPOTESE] Saturação limita contato em A no braço completo; removê-la permite
permanência maior quando a memória positiva já basta. Isso é compatível com
o mecanismo, sem comprovar uma explicação única para o efeito.

[LACUNA] Temperamento e experiência variam juntos; o ensaio não separa seus
efeitos causais. Braço sem memória conserva personalidade/afetos, e sem afeto
conserva memória/temperamento. Não se afirma aprendizagem isolada do temperamento,
consciência nem generalização para ecossistemas livres.

## X2 — frustração por obstáculo

[FATO] 40 ensaios: mesmas 20 seeds, completo/sem afeto. Ensino heurístico
mantém uma tentativa física de atravessar uma barreira por 24 ticks, sem
atribuir afeto no avaliador; todas as 24 tentativas são rejeitadas pela
geometria em cada ensaio. Depois a barreira e a intervenção de ensino são
retiradas, com 96 ticks de autonomia normal.

| Métrica | Completo | Sem afeto |
| --- | ---: | ---: |
| Pico médio de frustração | 0,9724 | 0 |
| Frustração após liberação | 0 | 0 |
| Contribuição afetiva à valência no bloqueio | −0,53482 | 0 |
| Maior alteração média softmax entre objetivos medidos | 0,27215 | 0,07663 |
| Aumento >=0,10 | 20/20 | 0/20 |
| Queda >=50% após liberação | 20/20 | trivial, estado zero |

[FATO] O critério pré-registrado restrito de afeto/expressão/recuperação passa
em 20/20 seeds; a ablação deixa frustração e contribuição afetiva à expressão
em zero. Entretanto **a ablação não elimina todas as alterações dos scores**:
memória de bloqueio, fadiga e ruído também participam. O resumo JSON registra
inclusive `expression_or_probability=20` no braço sem afeto, por essa mudança
residual. Portanto X2 sustenta o mecanismo afetivo, com resultado **PARTIAL
para uma alegação ampla de eliminação da mudança de política**.

[LACUNA] Softmax é uma leitura comparável dos scores; a política real escolhe
o maior score com ruído e compromisso, não amostra desse softmax. Não confundir
esses valores com probabilidades empíricas de ação. Durante o bloqueio quem
executa é o ensino, não o desejo mental; as frequências de ação na liberação
estão no JSON, sem alegação de causalidade isolada entre afeto e frequência.

## CPU headless

[FATO] Medição final serial, sem outro processo Godot deste worker em paralelo:
seed DEV 81006, mesmo gerador de cenário, 100 ticks de aquecimento + 400
medidos por condição. Reprodução desligada; populações finais iguais às
iniciais. Uma medição exploratória anterior concorria com a suíte e foi
substituída pela medição serial, sem tocar no holdout.

| Criaturas | Desligado média/p95 ms | Só pet média/p95 ms | Todas média/p95 ms |
| --- | ---: | ---: | ---: |
| 12 | 1,484 / 2,022 | 1,616 / 2,198 | 3,114 / 4,147 |
| 30 | 3,709 / 4,712 | 3,961 / 5,050 | 7,768 / 10,870 |
| 60 | 7,444 / 8,667 | 7,747 / 9,768 | 17,579 / 23,022 |

[FATO] O pet acrescentou aproximadamente 0,13/0,25/0,30 ms/tick nesses cenários.
Todas a 60 criaturas custaram cerca de 2,36× o tempo do braço desligado. Os
custos incluem as trajetórias diferentes produzidas por cada política; não
são uma microbenchmark isolada de uma função. Artefato: `M1_mind_cpu.json`.

[LACUNA] Não se mediram FPS gráficos, 100 criaturas, distribuição entre máquinas
ou estabilidade por horas. O p95 de todas/60 excede 20 ms; isso limita a margem
para simulação a 5× nesse cenário, sem afetar a decisão de ativar só o pet.

## Reprodução e pendências

[FATO] Testes podem ser repetidos normalmente. `m1_eval.gd` sem argumentos roda
somente DEV; com `-- --holdout` recusa se o resultado já existir. Não apagar
o resultado para tentar melhorar o ensaio. `m1_cpu.gd` mede apenas seeds DEV.
`m1_capture_golden.gd` documenta a captura feita na base v7; não regenerar
o golden usando o simulador v8.

[LACUNA] Falta revisão independente do patch e validação integrada de UX pelo
coordenador. X1 não confirmou necessidade de afeto; X2 não isolou probabilidade
empírica de ação autônoma. Esses pontos exigem novo protocolo/seeds em uma
etapa futura, sem reutilizar este holdout para ajuste.
