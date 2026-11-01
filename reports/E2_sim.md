# E2-SIM — motivação, temperamento e experiência individual

Status: **PASS no escopo da simulação**. A integração de apresentação pertence ao
worker UI; este trabalho não altera `scripts/ui` nem `scripts/render`.

## Base e autoria

[FATO] Branch `Yurtachi/evo2-e2-sim`, base `12b869d` da continuação E1,
identidade Git local Yurtachi, sem push. Foram lidos
`docs/EVOWORLD_2_SPEC.md`, `docs/PESTINHA_LICENCAS.md`, `reports/E1_sim.md` e
`reports/learn.md`. Implementação própria em GDScript, a partir dos requisitos e
do modelo matemático de erro de predição; nenhum código, texto, peso, asset ou
dependência do Pestinha foi incorporado.

`SimWorld` continua `RefCounted`, com passo fixo de 0,1 segundo e um único RNG
semeado. As atualizações de preferências, memória e vínculos não adicionam
energia, hidratação ou posição.

## Contrato e mecanismos

[FATO] `SimWorld.new_world(seed, config)` ativa `personality_enabled=true` por
padrão e mantém os 12 fundadores do E1. Configurações explícitas continuam
podendo escolher outra população ou desativar E2 ao criar o mundo.
`SimWorld.new(...)` e saves v1–v4 mantêm a personalidade desativada por padrão.
Não há criação de perfis nem consumo adicional de RNG no legado.

| Dimensão | Implementação e efeito observável |
|---|---|
| Fadiga/descanso | `fatigue` em [0,1]; movimento aumenta 0,007/passo, outras ações ativas 0,002. Descansar reduz 0,025, não move e multiplica o custo metabólico por 0,6, sem criar energia. |
| Estímulo/curiosidade | `boredom` aumenta com o tempo e a curiosidade. Movimento efetivo reduz o déficit conforme a novidade da região; movimento bloqueado não o alivia. |
| Sociabilidade/contato | `loneliness` aumenta conforme tempo e sociabilidade. A motivação pode aproximar fisicamente de um vizinho percebido; encontros ao alcance reduzem o déficit e deixam evidência. Procurar sem encontrar não concede contato. |
| Temperamento | `genome.temperament`: `curiosity`, `caution`, `sociability`, `impulsivity`, todos em [0,1]. Quatro sorteios independentes por fundador; perfil separado dos drives e do aprendizado. |
| Hereditariedade | Cópia assexual do temperamento, com a taxa e a escala de mutação já configuradas no mundo. Delta limitado a três desvios e aos extremos [0,1]; mutações entram na genealogia e nos eventos. |
| Memória episódica | `creature.personality.episodes`, no máximo 32 registros com `{tick, context, action, consequence, reward_source}`. Contexto: três faixas de energia, três de hidratação e tipo de alimento. Consequência: deltas medidos de energia, hidratação e fadiga, mais evento. |
| Esquecimento | Rotina expira depois de 300 passos; episódios com variação energética relevante, bebida ou contato podem durar 2400. Ao exceder 32, amostras rotineiras são descartadas antes dos episódios consequenciais. |
| Habituação | Até 24 estímulos recentes: comida percebida, símbolo percebido, região explorada ou contato com jogador. Repetição reduz novidade; ausência recupera sensibilidade. Não altera reflexos de sobrevivência nem cria recompensa alimentar. |
| Condicionamento | Preferência por tipo e previsão contextual atualizadas somente depois da ingestão física; perceber ou oferecer comida não atualiza essas tabelas. Até 5 preferências e 45 contextos. |
| Familiaridade | Até 32 vínculos por organismo, com contagem, valência, familiaridade e último encontro; contagem limitada a 10000. Mesmo parceiro só conta novamente após 30 passos; familiaridade e valência decaem. |
| Expressão | `creature.expression_state()` devolve `{valence, arousal}`: valência em [-1,1], ativação em [0,1], derivadas de carências, descanso e eventos medidos. Legado devolve valores neutros. |

O condicionamento usa `V += alpha * (lambda - V)`, com
`alpha = 0,12 + 0,18 * caution` e
`lambda = clamp((delta_energia + 0,25 * delta_hidratacao) / 32 - toxicidade / 8, -1, 1)`.
A toxicidade é a componente de dano aplicada pela ingestão do E1; assim uma
exposição tóxica pode causar aversão mesmo quando a nutrição líquida é positiva.
A aprendizagem não modifica a tabela física dos alimentos. Curiosidade,
cautela e impulsividade também modulam a avaliação alimentar; o mesmo escore é
usado pela heurística e pela observação fornecida ao cérebro.

Fome ou sede acima dos limites críticos existentes (0,6) têm prioridade sobre
descanso, exploração, contato, ordens e cérebro em mundos E2. Entre fome/sede,
a seleção considera o déficit e os recursos percebidos; todos os efeitos
continuam sujeitos a movimento, alcance e oclusão. Quando outro controlador
assume uma ação, a transição Q pendente é suspensa, sem atribuir ao cérebro
uma consequência que ele não escolheu. A tabela, os índices das ações e o
protocolo de recompensas Q do legado não foram renumerados ou substituídos.

API disponível para integração:

```gdscript
creature.temperament # cópia do perfil genético
creature.personality # null no legado; estado individual em mundos E2
creature.expression_state() # {valence, arousal}
world.interagir_jogador(creature_id, position, valencia = 0.2) # bool
```

`interagir_jogador` exige criatura viva, contato ao alcance e linha de visão.
Contato distante ou repetido antes do intervalo retorna `false`, sem inflar o
vínculo. O contato registra episódio; não alimenta, hidrata ou teleporta.
As novas chaves pt-BR ficam exclusivamente em `E2_CATALOGO` e `E2_RAZOES`,
acrescentados ao fim de `textos.gd` para o worker de apresentação integrar.
A memória antiga `creature.memory` conserva seu contrato de eventos e limite
16; os episódios E2 ficam em campo separado para preservar os consumidores.

## Save e determinismo

[FATO] O schema do mundo sobe de v4 para **v5**, pois passa a salvar a flag,
o temperamento opcional do genoma e o estado individual opcional da criatura.
A migração v4→v5 faz cópia profunda, desativa E2 e preserva fisiologia, população,
posições, IDs, RNG, cérebro e genealogia. A cadeia v1→v2→v3→v4→v5 continua
disponível; repetir a migração em v5 não muda o snapshot. Os campos opcionais
dos subobjetos conservam suas versões locais e são governados pelo schema v5.

Validação rejeita NaN/inf, números fora do intervalo, booleanos/textos no lugar
de números, contêineres errados, episódios acima do limite, ações/fontes/eventos
desconhecidos, contextos inválidos e datas futuras. Vínculos com criaturas exigem
um ID diferente do próprio organismo e existente na genealogia, inclusive quando
o parceiro já morreu. O limite de checkpoint de 32 MiB e o backup validado do
`SaveStore` permanecem em vigor. Descendentes recebem estado individual vazio:
não herdam episódios, preferências, contexto condicionado, habituação, vínculos
ou déficits dos pais.

Foi encontrada e corrigida uma divergência na primeira verificação de retomada:
iterar as chaves de temperamento na mutação dependia da ordem do JSON. A mutação
agora percorre uma lista fixa de quatro nomes; empates na evicção de vínculos e
hábitos também usam chaves ordenadas.

## Resultados automatizados

Comando: `godot --headless --path . -s tests/run_tests.gd`, com o executável
console Godot **4.7.2.stable.official.ed1daf0bf** informado na tarefa.
Resultado final: **exit 0**, os **12 arquivos** de teste passaram, sem erros
de script. Saída registrada em [`E2_sim_tests.txt`](E2_sim_tests.txt).

| Verificação | Resultado observado |
|---|---|
| Drives e física | Descanso: custo 0,041760 e fadiga 0,95→0,925; exploração: custo 0,081600 e tédio 0,95→0,939500, com deslocamento real. Contato exige aproximação e deixa vínculo/episódio. |
| Sobrevivência | Fome e sede críticas prevaleceram sobre fadiga, contato, ordem `parar` e QBrain. A transição Q suspensa não recebeu a recompensa da ação de sobrevivência. |
| Mesmo genótipo, experiências distintas | Oito ingestões de cogumelo em fome ou saciedade produziram preferências -0,530180 e -0,848288. Com estado atual e geometria relativa iguais, o primeiro escolheu o cogumelo próximo; o segundo, a folha mais distante. |
| Condicionamento com evidência | Contextos de ingestão distintos ficaram registrados; dano tóxico medido foi -8. Apenas perceber fruta repetidamente não modificou preferências ou condicionamento. Fruta ingerida produziu preferência benéfica. |
| Habituação e recuperação | Vinte repetições reduziram a novidade para menos de 30% da resposta inicial; ausência recuperou sensibilidade. |
| Vínculos e expressão | Contato próximo criou vínculo/episódio; clique distante ou repetido no mesmo passo foi recusado. Familiaridade/valência decaíram e carências/evento negativo reduziram valência e elevaram ativação. |
| Limites e esquecimento | 200 registros/estímulos/parceiros respeitaram 32 episódios, 24 hábitos e 32 vínculos. Rotina expirou antes do episódio de dano, que também expirou por idade. |
| Descendência | Sem mutação, temperamento foi copiado; estado, episódios e aprendizado nasceram vazios. Três sementes com mutação verificaram [0,1] e máximo de 0,075001 de variação para escala 0,025. |
| Identidade após morte | Morte apagou `pet_id`; descendente e nova introdução não assumiram a identidade. Carregamento preservou a ausência do pet e sua morte na genealogia. |
| Persistência E2 | Snapshot completo, incluindo drives, memória, vínculos, preferências e QBrain, coincidiu antes/depois de JSON e checkpoint. Mais 200 passos após carregar permaneceram idênticos passo a passo. |
| Legado v1–v4 | Testes E1/evolução mantiveram a cadeia v1/v2/v3; fixture v4 foi aceita. Migração não consumiu RNG/IDs nem ativou E2. |
| Baseline anterior | Snapshots reais v4, antes e depois de 100 passos, foram capturados com código intacto do commit `12b869d`. A continuação atual coincidiu integralmente com a referência, incluindo RNG, eventos e genes. |
| Regressões | Testes de aprendizado G2, evolução G3, sinais G4, comandos, diálogo, persistência, ecologia E1 e textos passaram na mesma execução. |

### Resposta dos 12 fundadores sob o mesmo estímulo

Cada perfil foi colocado em cena independente com corpo/genética física iguais,
fadiga/tédio/isolamento de 0,65, energia/hidratação iguais, sem alimento/obstáculo
e um vizinho visível à mesma distância. Só o temperamento varia. A execução
repetida reproduziu as mesmas ações; a ablação com temperamento 0,5 em todas
as dimensões produziu uma única ação em cada grupo de 12.

| Semente | Perfis únicos | Explorar | Descansar | Aproximar-se do vizinho | Ações na ablação neutra |
|---|---:|---:|---:|---:|---:|
| 17 | 12/12 | 10/12 | 2/12 | 0/12 | 1 |
| 89 | 12/12 | 5/12 | 2/12 | 5/12 | 1 |
| 9181 | 12/12 | 4/12 | 5/12 | 3/12 | 1 |
| 20261101 | 12/12 | 5/12 | 5/12 | 2/12 | 1 |

## Limites e integração restante

[FATO] Este gate demonstra mecanismos e diferenciação em cenários controlados.
Não demonstra consciência, compreensão, afeto humano, adaptação evolutiva da
personalidade, melhora geral de sobrevivência ou superioridade sobre o QBrain.
Os perfis geram distribuições de ações distintas; não se exige que cada um dos
12 organismos escolha uma ação exclusiva, nem que toda semente exiba as três
ações no primeiro passo.

[LACUNA] Não foram repetidos os experimentos estatísticos completos G2/G3/G4;
a evidência de compatibilidade aqui é a suíte de regressão e a comparação
integral com o replay v4 de 100 passos. O determinismo verificado é no mesmo
Godot/plataforma. Não há benchmark de grandes populações ou garantia de FPS;
os limites por organismo não garantem que toda população máxima caiba em 32 MiB.

[FATO] O condicionamento é tabular por tipo de alimento e contexto fisiológico,
com atualização online e sem consolidação offline. Não há agente de linguagem,
rede pulsada, ensino social ou inferência de intenções. A expressão é um escore
observável para apresentação, não uma classificação clínica ou emocional.
A diversidade genética agregada existente continua medindo os seis genes físicos;
o perfil adicional pode ser inspecionado diretamente no genoma/genealogia.

[LACUNA] A UI ainda precisa integrar as novas chaves/expressão e chamar a API
de contato do jogador. O ponto de criação de jardins deve usar
`World.new_world`, como já comunicado ao coordenador; a chamada histórica
`World.new` não ativa E2. Não foi editado código de UI/render neste branch.
