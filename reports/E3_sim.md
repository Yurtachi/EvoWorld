# E3-SIM — ensino operacional verificado na simulação

[FATO] **PASS no escopo SIM e no critério de eficácia pré-registrado**, em cenário
aberto controlado. Branch `Yurtachi/evo2-e3-sim`, base recebida `da71881` (E2 já
integrado na continuação `evo2/e1-base`), identidade local Yurtachi, sem push.
Lidos `docs/EVOWORLD_2_SPEC.md`, `reports/E1_sim.md`, `reports/E2_sim.md` e
`reports/E1_ui.md`. Implementação própria, sem copiar código, textos, pesos ou
assets do Pestinha e sem dependências novas. Nenhum arquivo de UI/render foi editado;
`textos.gd` recebeu somente a seção E3 ao final.

## Mecanismo e evidência física

[FATO] `ir_ate_local` exige alcançar um alvo marcado a até `tamanho + 5` unidades,
sem oclusão. `buscar_agua` exige evento `drink` no passo da ação da habilidade,
com ganho hídrico positivo pelo executor físico normal. Aproximação, botão,
hidratação prévia e mera presença de água não comprovam a tarefa.

`ensino_mostrar` pode apenas marcar o alvo ou ativar uma rota assistida. A rota
escolhe ações discretas reais de andar/virar/beber/descansar; paga os mesmos
custos, respeita limites e colisões, e contabiliza cada passo assistido. Não há
teleporte. Alterar o alvo encerra a tentativa anterior como cancelada e inicia
outra; assim um alvo movido para junto do corpo não reescreve a evidência anterior.
Uma ordem explícita de chamar/seguir/parar/brincar cancela a tentativa, evitando
contar condução pelo jogador como autonomia.

[FATO] Fome/sede críticas suspendem o ensino e assumem a sobrevivência física,
mesmo com personalidade desativada. A tentativa ainda pode expirar pelo tempo de
mundo; ações de sobrevivência não recebem crédito de ensino. Sem sessão ativa,
as decisões legadas mantêm o comportamento anterior e seu consumo de RNG.

[FATO] `QBrain` ganhou tabela `goal_q`, separada das células de sobrevivência:
2 habilidades × 13 direções relativas × 3 distâncias × 2 estados de obstáculo,
com os mesmos IDs de ações físicas. São **156 estados**, sem coordenadas absolutas,
IDs de alvo ou seeds. Local marcado é informação explícita do jogador; água é
obtida dos sensores normais, com visão e oclusão, sem consulta onisciente a recursos.
Sem água visível, a criatura explora fisicamente, sem inserir amostras fictícias.

A atualização de ensino é retorno Monte Carlo terminal dentro do QBrain:
`Q(s,a) += 0,25 × (retorno - Q(s,a))`, retorno inicial 1, desconto 0,97 ao
percorrer a trajetória para trás. O aprendiz explora com probabilidade fixa 0,15;
congelado escolhe somente o maior valor aprendido. O ensino não usa o update TD
da tabela fisiológica. Demonstrações e tentativas autônomas usam o mesmo registro;
uma conclusão pode receber crédito uma única vez e apenas após pedido de recompensa.

[FATO] **Não existe shaping de distância neste gate.** Uma tentativa bloqueada,
oscilação, timeout ou aproximação sem conclusão produz zero atualização de ensino.
Recompensa prematura/repetida/congelada é recusada com código e zero updates.
O botão não escreve energia, hidratação, posição ou tabela Q de sobrevivência.
Fracasso de ensino não aplica punição arbitrária. Custos metabólicos e danos
físicos já existentes continuam reais.

## Registro, estado de aprendizado e save

[FATO] Cada criatura tem estado opcional `ensino`, com até 32 sessões, 32
tentativas, 64 eventos e trajetória ativa de até 256 ações. A duração pedida deve
estar entre 1 e 256 passos. Os eventos ligam início/mostrar à observação,
ação/resultado físico (`moved`, `drink`, `no_movement`), desfecho e atualização.
Cada tentativa guarda habilidade, alvo, datas, status, passos, assistência,
recompensa/updates e energia/distância antes/depois. Observar devolve cópias
destacadas e não cria recompensa nem modifica a simulação.

A API calcula sucesso recente por habilidade usando somente tentativas **sem
assistência**, até 20 entre as 32 retidas. Requer pelo menos 5 tentativas e taxa
≥0,70 para `learned=true`; antes disso ou abaixo do limiar devolve
**“Ainda não aprendeu”**. Demonstrações bem-sucedidas não satisfazem esse critério.
`ensino_reset(id)` limpa tabela, contador e histórico de ensino somente daquela
criatura, preservando corpo, genoma, personalidade e Q de sobrevivência.

[FATO] O schema mudou: mundo **v6**, QBrain **v4**, registro de ensino v1.
A cadeia v1→v2→v3→v4→v5→v6 preserva os dados antigos; v5→v6 é cópia sem criar
ensino, sem sortear RNG e sem inventar experiência. QBrain v1/v2/v3 preserva as
células antigas e inicializa a tabela de objetivos em zero. Migrações são
idempotentes e não alteram a entrada. Validação rejeita NaN/inf, tabelas e
históricos acima do limite, estados/ações fora de faixa, datas futuras,
duplicação/ordem inválida de sessões/tentativas e divergência entre tentativa
concluída ativa e histórico. QBrain v4 sem seus novos campos é recusado.

O `SaveStore` existente continua com checksum, arquivo temporário validado,
backup e limite de 32 MiB. Foi verificado round-trip em JSON e checkpoint real,
inclusive uma trajetória parcialmente executada que continua identicamente.

## API para integração de UI

[FATO] Métodos públicos de `SimWorld`, por ID de criatura:

| Método | Contrato |
|---|---|
| `ensino_habilidades()` | Lista `{id,text,requires_target}` das duas habilidades. |
| `ensino_iniciar(id, skill, target=Vector2.INF, assisted=false, horizon=200, policy="q")` | Inicia sessão/tentativa; local exige alvo válido, água exige fisiologia hídrica ativa. Anexa QBrain se não houver brain. |
| `ensino_mostrar(id, target=Vector2.INF, assisted=false)` | Mostra alvo e/ou alterna rota assistida em tentativa ativa. Alvo diferente inicia outra tentativa. |
| `ensino_observar(id)` | Snapshot sem efeito: `ok`, `creature_id`, `skills`, `sessions`, `attempts`, `events`, `active`, `before_after`, `limits`. |
| `ensino_recompensar(id)` | `{ok,code,updates}`; só `success` físico ainda não recompensado e brain treinável atualiza. |
| `ensino_cancelar(id)` | Encerra tentativa ativa como cancelada, sem prêmio/punição. |
| `ensino_reset(id)` | Reinicia treinamento dessa criatura; retorna booleano. |

`skills` contém `skill`, `attempts`, `successes`, `success_rate`, `learned`,
`status`, `text`, `threshold`, `minimum_attempts`. `active` contém `skill`,
`target` como `[x,y]`, `status` (`active/success/timeout/cancelled/death`),
`steps`, `assistance`, `rewarded`, `updates` e medidas anteriores/posteriores;
o snapshot omite a trajetória interna. `before_after` compara a taxa autônoma
antes da sessão com a taxa atual, não prevê competência futura.

`policy="heuristica"` serve como controle explícito do experimento; a integração
de ensino do produto deve manter `"q"`. Texto ao jogador está em
`Text.E3_CATALOGO` e mapeamento de razões em `Text.E3_RAZOES`. A UI deve apresentar
códigos traduzidos e separar assistência de sucesso autônomo. `ok=true` ao iniciar
significa somente pedido aceito, nunca tarefa aprendida ou concluída.

## Experimento pré-registrado

[FATO] Pré-registro e protocolo executável foram commitados em **`a66ea9c`**, antes
de qualquer execução HOLDOUT. Implementação avaliada: **`1be655d`**. Não houve
mudança de hiperparâmetros, seeds, horizonte ou critério após o pré-registro ou
após olhar o holdout. A execução `--dev` usou somente TRAIN.

Protocolo: [`ensino_preregistro.md`](../tests/experiments/ensino_preregistro.md),
script [`ensino_eval.gd`](../tests/experiments/ensino_eval.gd).
TRAIN: seeds 41001–41016, seis repetições por habilidade (192 episódios totais;
RNG de geometria `seed + repetição × 100000`, como fixado no script pré-registrado).
Todas são demonstrações assistidas, concluídas e recompensadas fisicamente;
192/192 sucessos e 6620 atualizações de células. HOLDOUT: 20 seeds inéditas
93001–93020, duas habilidades, cinco braços, horizonte comum 140 passos.
Corpos novos, posições e orientações novas, sem assistência em todos os braços.

[HIPOTESE] A política condicionada treinada generalizaria melhor que a mesma
política zerada, sem se esperar superar a heurística geométrica. Critério
confirmatório fixado: congelado ≥70% **em cada habilidade**, ganho agregado
≥30 pontos percentuais sobre naive, p<0,05 e assistência HOLDOUT zero.

| Braço | Local | Água | Sucesso total | Passos médios, censura 140 | Energia final média | Δ energia médio | Sobrevivência | Ações assistidas |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| aleatorio | 0/20 | 1/20 | 2,5% | 139,875 | 66,2475 | -10,5525 | 100% | 0 |
| heuristica | 20/20 | 20/20 | 100% | 33,2 | 74,0969 | -2,7031 | 100% | 0 |
| naive, zerado congelado | 0/20 | 0/20 | 0% | 140 | 65,8173 | -10,9827 | 100% | 0 |
| trained_frozen | 20/20 | 20/20 | 100% | 33,2 | 74,0969 | -2,7031 | 100% | 0 |
| trained_online | 11/20 | 20/20 | 77,5% | 71,55 | 71,1838 | -5,6162 | 100% | 0 |

[FATO] Tempo médio apenas entre conclusões: aleatório 135 passos (um sucesso),
heurística e congelado 33,2, online 51,6774; naive não concluiu. Cada passo vale
0,1 segundo de simulação. A tabela mantém os fracassos censurados para não
favorecer artificialmente braços que concluem poucas tarefas.

[FATO] Comparação primária congelado versus naive: **40 vitórias, zero derrotas,
zero empates**, ganho de 100 pontos percentuais, teste de sinais binomial exato
bilateral **p=1,8189894×10⁻¹²**. Todos os critérios pré-registrados passaram.
Heurística versus naive: 40/0/0, mesmo p; aleatório: 1/0/39, p=1;
online: 31/0/9, p=9,3132257×10⁻¹⁰. Comparações secundárias são descritivas, sem
correção de múltiplas comparações e sem redefinir o gate pela mais favorável.

[LACUNA] O teste primário pré-registrado considera 40 pares seed/habilidade;
as duas tarefas da mesma seed compartilham geometria e podem ser correlacionadas.
Uma checagem conservadora adicional, agrupando as duas tarefas por seed, dá
20 vitórias, zero derrotas e **p=2×0,5²⁰=1,9073486×10⁻⁶**. Esta sensibilidade
é posterior ao pré-registro e não substitui o critério original.

[FATO] Online foi pior que congelado na habilidade de local (55% versus 100%),
e precisou mais passos; não se afirma melhora por continuar treinando. Frozen
teve zero updates em HOLDOUT; online teve 1602 (média 40,05 por episódio),
somente nas conclusões reais. Não houve retuning para corrigir esse resultado.
Congelado e heurística produziram as mesmas métricas neste cenário.

Dados completos, por episódio, com taxas, tempos, energia, assistência,
atualizações e tabela treinada: [`E3_ensino_eval.json`](E3_ensino_eval.json).
Saída da primeira execução completa: [`E3_ensino_eval.txt`](E3_ensino_eval.txt).
SHA-256 do pré-registro lido na execução:
`2273c32de9c8f6243573eb400f16b665f1b795507491170a20732f666aef1ebc`.
SHA-256 do JSON bruto:
`3b812492eece0f4e3eb4d454bf55268ea3663ad6231cfad07eeb818448f7da37`.

## Validação

[FATO] Godot **4.7.2.stable.official.ed1daf0bf**, Windows, executável console
fornecido na tarefa. Comandos executados na raiz:

| Comando (prefixado pelo executável Godot informado) | Resultado |
|---|---|
| `--headless --path . -s tests/run_tests.gd` | **exit 0**, 13 arquivos de teste verdes, sem erro de script. |
| `--headless --path . -s tests/experiments/ensino_eval.gd -- --dev` | **exit 0**, somente TRAIN, 192/192 demonstrações concluídas. |
| `--headless --path . -s tests/experiments/ensino_eval.gd` | **exit 0**, cinco braços completos, `efficacy_pass=true`. |
| `git diff --check` | **exit 0**. |

Saída da suíte: [`E3_sim_tests.txt`](E3_sim_tests.txt).
`test_sim_e3.gd` cobre recompensa antes/sem conclusão; repetição de recompensa;
ausência de efeito fisiológico nas APIs; chegada física; bebida real; assistência
contabilizada; sede prioritária; comando que cancela ensino; reset individual;
round-trip/continuação determinista/checkpoint; limites; NaN; QBrain incompleto;
migração idempotente v5 e QBrain v3; taxa de sucesso autônomo que sobe após cinco
sucessos e volta a “Ainda não aprendeu” após fracassos recentes. Teste de
comportamento medido: naive termina a 490 unidades e falha; treinado congelado
termina a 11,36 unidades e conclui, com zero assistência, após 405 updates TRAIN.

As regressões existentes verificam carregamento v1/v2, fixture real v3, fixture
real v4 e replay do baseline anterior, mais ecologia, personalidade, comandos,
sinais, evolução e persistência. E3 acrescenta carregamento explícito v5; todos
carregam em v6 sem inventar sessões ou recompensas.

## Limites

[LACUNA] A evidência é de transferência em terreno aberto, com dois objetivos,
um tipo corporal e sem competição ou obstáculos no holdout. Não demonstra
navegação em labirintos, generalização entre corpos, melhora ecológica de longo
prazo, entendimento de linguagem ou superioridade sobre a heurística. Ausência
de água visível pode levar a fracasso. `buscar_alimento_tipo` ficou fora deste
gate; não é anunciado como habilidade disponível.

[LACUNA] A retenção é limitada: só as 32 últimas tentativas e 64 últimos eventos
ficam por criatura viva; trajetórias anteriores não são um arquivo ilimitado.
O histórico não passa a descendentes nem sobrevive à remoção definitiva do corpo
do mundo. Limites individuais não garantem que a população máxima com todos os
brains caiba nos 32 MiB do SaveStore. Determinismo foi verificado no mesmo
Godot/plataforma; não há garantia entre versões.

[LACUNA] Integração visual do alvo, painel, botões e formatadores E3 pertence à
UI; este worker não a validou nem editou `scripts/ui` ou `scripts/render`.
Revisão independente e integração dos commits pertencem ao coordenador.
