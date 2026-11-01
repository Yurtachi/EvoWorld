# Sinais — gate G4

## Pré-registro, antes dos resultados

Data: 01/11/2026. Este protocolo será commitado antes da primeira execução do
experimento completo. Não será ajustado após observar as sementes de avaliação.

Hipótese: disponibilizar um canal de símbolos neutros ao Q-learning pode melhorar
forrageamento e sobrevivência e alterar sincronização. Não há significado associado
a nenhum símbolo, recompensa por emissão ou resposta reflexiva programada.

- Treino: sementes 2101–2106, duas passagens, até 1500 passos por episódio.
- Avaliação: treino nas mesmas seis sementes; holdout 8101–8110, nunca usado
  para treinar, depurar ou ajustar parâmetros. Políticas congeladas na avaliação.
- Mundo 600×420, oito organismos, 40 alimentos iniciais, capacidade 60, reposição
  de um alimento a cada dez passos, quatro obstáculos, sem reprodução.
- Canal: quatro símbolos, alcance 180, custo 0,3 de energia por emissão,
  perda independente de pacote de 5% por receptor, validade de dez passos.
- Treinamento reúne tabelas de oito corpos; cada corpo mantém transição própria.
  Q-learning usa os parâmetros herdados, sem recompensa adicional ou significado
  fixado. A tabela inicia em zero. Não usa o checkpoint do experimento G2.
- Avaliação pareada por semente com o mesmo checkpoint: `enabled` (canal ligado),
  `disabled` (canal desligado, emissões indisponíveis, nenhum custo de sinal),
  `muted` (canal ligado com perda de 100%, mesmas ações/custos que `enabled`).
  `muted` é controle secundário para distinguir custo/ações de disponibilidade de
  informação. O desligamento operacional também muda o conjunto de ações;
  portanto não isola sozinho a informação recebida.
- Métricas por episódio: alimento consumido por organismo inicial; média da idade
  na morte/fim; sincronização = fração de pares vivos com a mesma última ação por
  passo, somada e dividida pelo número total de pares observados; emissões,
  recepções e fração de primeiras ações após recepção diferentes da ação anterior.
  Pares incluem descanso; sincronização não implica cooperação ou benefício.
- Unidade de análise: semente, comparação pareada. Empates não são vitórias.
- Critério global de evidência de benefício (apenas holdout): `enabled` supera
  `disabled` em alimento em pelo menos 9/10 sementes; sobrevivência média pelo
  menos 1,05×; sincronização média aumenta pelo menos 0,02; há recepções e
  mudanças de ação registradas. Todos os critérios devem passar. A comparação
  `muted` e as métricas em treino são descritivas, sem resgatar falha global.
- Falha será declarada sem mudar critérios ou atribuir semântica aos símbolos.
  Mudança após recepção é temporal; não comprova causalidade individual.

Comando: `godot --headless --path . -s tests/experiments/signal_ablation.gd`.
Saída durável: `tests/experiments/results/signal_ablation_results.json`.
O comando termina com 0 se a execução/gravação foi válida, mesmo quando a hipótese
falha; o campo `success` registra o resultado científico.

## Implementação entregue

O pré-registro acima foi fixado no commit **74fbbdd**, antes da execução completa.
O canal é lógica pura em `scripts/communication/signal_channel.gd`, sem rede ou
gerador aleatório paralelo. A API pública é `world.emitir_sinal(id, symbol)`;
`emit_signal` já é um método reservado do Godot e não foi sobrescrito.

As configurações são `signal_enabled`, `signal_count` (4–8), `signal_range`,
`signal_noise` (probabilidade de perda independente por receptor), `signal_cost`
e `signal_ttl` (1–1000 passos). Padrões: desligado, quatro símbolos, alcance 180,
ruído 0,05, custo 0,3 e validade dez passos. Desligado preserva o experimento G2
e os mundos anteriores; o produto pode ligar explicitamente o canal na interface.
O experimento G4 liga/desliga explicitamente. A heurística antiga não emite sinais
automaticamente; um cérebro Q ou a API realiza a emissão.

Uma emissão válida cobra energia inclusive quando todos os pacotes se perdem.
Símbolo/ID inválido, corpo morto, energia insuficiente ou canal desligado recusam
a emissão sem cobrança. Alcance é radial e independe de campo visual/oclusão;
rochas não bloqueiam este canal. A consulta usa a grade espacial, ordenada por ID.
Todas as perdas usam o RNG do mundo. A ordem de atualização permanece estável:
IDs posteriores podem reagir no mesmo passo; anteriores reagem no próximo.

`sense(...).signal` inclui o último símbolo, emissor, passo e categorias de direção
e distância na recepção. Direção: esquerda (<−0,25 rad), frente (±0,25 rad),
direita (demais); regiões traseiras pertencem à esquerda/direita conforme o ângulo
relativo normalizado. Distância: até metade do alcance ou além. Após a validade,
a observação fica vazia; o último registro histórico continua salvo na criatura.
A leitura fornece cópia, sem permitir alteração do estado original.

`signal_log` guarda até 256 emissões com `{tick, emitter, symbol, context,
receivers, action_changes}`. Contexto registra se havia alimento visível e energia
abaixo de 35% antes do custo; não é uma definição semântica do símbolo. Cada
primeira decisão observada após uma recepção registra receptor, passo, ação
anterior e posterior, inclusive quando iguais. Nova recepção pode sobrescrever
uma ainda não reagida. O buffer limitado pode descartar emissões antigas.
Mudanças durante controle do jogador também são observações temporais e não
demonstram efeito causal do sinal.

O Q-brain agora tem versão 2: 2352 estados × 13 ações (cinco ações anteriores e
oito símbolos possíveis). Sem sinal, os 48 estados originais mantêm seus índices.
Somente os símbolos configurados são ações disponíveis; com canal desligado,
apenas as cinco ações antigas participam de exploração, decisão e bootstrap.
A recompensa continua sendo variação fisiológica real de energia e penalidade
de morte. Não há bônus de sinal, tradução de símbolo ou reflexo de reação.
O cérebro aleatório respeita a mesma máscara de ações.

O save do mundo passa de **2 para 3**, migrando 2 e mantendo o caminho 1→2→3.
Mundos antigos começam com canal desligado, log vazio e nenhuma ordem. Cérebro
Q v1 preserva os valores das 48×5 entradas, parâmetros e transição pendente,
expandindo os demais valores com zero. O envelope `SaveStore` permanece na
versão anterior. Sinais recebidos, configurações, log, ordens e solicitação de
proteção são dados JSON validados; vetores usam arrays de números. IDs históricos
de emissores/receptores devem pertencer à genealogia. Malformações retornam `null`.

O mundo possui **`world.comandos`**, instância persistida. `seguir`, `parar`,
`chamar` e `brincar` passam pela mesma física discreta, metabolismo e colisões.
Seguir permite atualizar o alvo; chamar e brincar encerram a ordem ao chegar.
Não há planejamento de caminho: um obstáculo pode impedir a chegada. Parar
continua gastando energia. Durante controle externo, apenas a transição Q pendente
é descartada, preservando tabela e histórico de recompensas; o cérebro retoma
quando a ordem termina ou é limpa. `proteger` permanece uma solicitação, sem
proteção biológica implementada ou promessa de imortalidade.

A integração visual deve reutilizar `world.comandos`, pois um adaptador externo
não compõe o save do mundo. Novas ações internas são `emit_signal_0` a
`emit_signal_7`; razões são `signal.emitted`, `signal.rejected` e `dialogo.*`.
São identificadores, não textos de apresentação. O coordenador foi avisado para
traduzir esses códigos no catálogo central e expor o canal na UI; não foram
alterados os paths de UI/render/catálogo neste trabalho. A remoção do preload de
SimWorld no diálogo/adaptador evita uma dependência circular com o novo dono.

## Resultados completos

Motor: Godot 4.7.2, mesmo executável de console informado no despacho. Uma execução
completa, sem ajuste posterior por holdout. Evidências em
`tests/experiments/results/signal_ablation_results.json` e
`tests/experiments/results/signal_ablation_output.txt`.

| Conjunto | Condição | Alimentos/organismo | Sobrevivência em passos | Sincronização | Emissões/episódio |
|---|---|---:|---:|---:|---:|
| Treino, avaliação congelada | Ligado | 21,8750 | 1475,875 | 0,437103 | 0 |
| Treino, avaliação congelada | Desligado | 21,8750 | 1475,875 | 0,437103 | 0 |
| Treino, avaliação congelada | Perda de 100% | 21,8750 | 1475,875 | 0,437103 | 0 |
| Holdout | Ligado | 22,1625 | 1476,400 | 0,464043 | 0 |
| Holdout | Desligado | 22,1625 | 1476,400 | 0,464043 | 0 |
| Holdout | Perda de 100% | 22,1625 | 1476,400 | 0,464043 | 0 |

**Critério global reprovado:** zero vitórias estritas em alimento nas dez sementes,
razão de sobrevivência 1,0000, diferença de sincronização 0,0000, nenhuma recepção
na política congelada. As três condições também coincidem em cada semente.
Não há evidência de comunicação útil ou significado emergente nesse protocolo.

Durante treinamento exploratório houve **10.656 emissões, 19.538 recepções,
17.979 primeiras reações registradas e 14.889 ações diferentes da anterior**.
Isso comprova tráfego e rastreamento, não interpretação causal ou semântica.
A média de alimento passou de 20,1875 na primeira passagem para 22,3333 na segunda;
essa mudança não é uma demonstração de benefício do canal. Na avaliação gulosa,
a política aprendeu uma solução que não emite. A fração de mudança de ação é zero
por convenção quando não há recepções e não deve ser lida como ausência de reação
a um estímulo efetivamente apresentado.

Hash SHA-256 do checkpoint treinado, registrado no JSON:
`19e1d5b5b173d42acf6d8724b20828fcbeab5fc5eeaeb294ae08c74776c1ce79`.
O checkpoint não é aplicado automaticamente aos organismos do produto.

## Validação e limites

`tests/unit/test_signal_channel.gd` cobre custo, alcance, oito símbolos,
direção/distância, perda total/parcial e reproduzível, canal desligado, símbolo/ID
inválido, energia insuficiente, validade, cópia da observação, limite do log,
reação condicionada pelo estado Q, contabilização energética, migração Q v1,
migração de mundo v2, rejeição de dados inválidos, round-trip JSON e `SaveStore`,
continuação determinística e execução/retomada das quatro ordens do jogador.
Inclui isolamento da transição de aprendizado e respeito a obstáculos.

O coordenador autorizou explicitamente somente a atualização da comparação
`save_version == 2` em `test_evolution.gd:281` para `World.SAVE_VERSION`, necessária
ao bump; o restante desse arquivo foi preservado. A referência geométrica em
`test_sim_review.gd` agora inclui os novos campos de observação vazios.
O experimento G2 declara `signal_enabled=false`, preservando seu protocolo.

Rodadas de desenvolvimento detectaram o conflito com `Object.emit_signal`, a
comparação de versão antiga e a expectativa incorreta do teste para o ângulo
traseiro normalizado. Foram corrigidos antes da validação final. A primeira
rodada com erro de parser terminou com exit 0 por uma limitação do runner herdado;
esse exit isolado não foi tratado como sucesso. Rodadas intermediárias com
asserções falhando terminaram com exit 1. A validação final exige também ausência
de `SCRIPT ERROR`/`Parse Error`, além do código de saída.

Resultados finais:

- `godot --headless --path . -s tests/run_tests.gd`: **exit 0**, nove arquivos
  `ok`, sem `SCRIPT ERROR` ou erro de parser; saída em
  `tests/experiments/results/signal_unit_output.txt`.
- `godot --headless --path . -s tests/experiments/signal_ablation.gd`:
  **exit 0**, execução e gravação válidas; resultado científico `success=false`.
- `git diff --check` e `git diff --cached --check`: **exit 0**.

As mudanças finais de consulta pela grade mantêm os mesmos candidatos em ordem
de ID e a mesma filtragem/aleatoriedade da consulta completa usada pelo processo
do experimento já carregado. O registro de reações passa a buscar a última emissão
compatível para cobrir chamadas manuais repetidas no mesmo passo; o experimento
emite no máximo uma vez por corpo/passo. Essas correções não alteram o protocolo
ou a dinâmica experimental observada. A suíte final verifica o código entregue.

Este escopo entrega o mecanismo e uma ablação negativa honesta. A observação
visual e os fluxos do jogador pertencem à integração do coordenador; o experimento
não aprovou uma alegação de comunicação útil nem de linguagem emergente.
