# E4-SIM — encontros, diálogo e informação assimétrica

[FATO] **PASS restrito no NOVO protocolo M0-B contrabalanceado.** Em 20 seeds
inéditas, cada uma com ambos os lados: ativo 38/40, desligado 20/40, embaralhado
20/40, uniforme 20/40 e decoder sem sinal com prior TRAIN 20/40. Ativo teve
18/20 à esquerda e 20/20 à direita; ganho agregado +45 pp e 18 vitórias,
zero derrotas, dois empates POR SEED contra cada controle. Pré-registro separado
`33bc81e`, implementação/checkpoint congelados `f7f90f4`, TRAIN/DEV antes do
HOLDOUT, aberto uma única vez. Dados, custos por lado e limites:
[`M0_social.md`](M0_social.md). Utilidade demonstrada somente neste cenário
com codificador fixo e decoder aprendido, sem linguagem emergente.

[FATO] O E4 ORIGINAL abaixo é registro histórico distinto: 18/20 ativo,
8/20 desligado, 10/20 embaralhado, com distribuição 8E/12D e controle
desligado sempre esquerda. Seu pré-registro e JSON não foram alterados nem
reexecutados neste ciclo; a contrabalança e os baselines adicionais pertencem
ao novo protocolo M0-B. Os limiares originais passaram, mas a comparação antiga
isolada não elimina a ressalva sobre prior e frequência dos lados.

## Base e autoria

[FATO] Branch `Yurtachi/evo2-e4-sim`, worktree Orca com
`baseRef=evo2/e1-base`, HEAD inicial `962412c`. Pré-registro separado em
`ad63789`; implementação congelada em `e1f43db` antes do primeiro HOLDOUT.
Commits locais com identidade Yurtachi, sem push ou trailers de IA. Lidos
`docs/EVOWORLD_2_SPEC.md`, relatórios E1/E2, `reports/E3_sim.md` e
`reports/sinais.md`. Implementação própria a partir dos requisitos; nenhum
código, peso, texto ou asset do Pestinha foi incorporado.

## Dinâmica social e persistência

[FATO] `scripts/social/social_dynamics.gd` reutiliza os `bonds` e episódios E2.
Encontros exigem vizinho percebido, proximidade física e ausência de oclusão;
o mesmo parceiro conta novamente somente após 30 passos. Familiaridade sobe
0,04 por encontro e conserva o decaimento existente. Afinidade é a parte positiva
da valência; aversão, a magnitude da parte negativa. Encontro próximo sem disputa
tem valência 0,25; presença de alimento percebido a até 48 unidades dos dois,
com ambos com fome >0,2, produz valência −0,5 e episódio `resource_contention`.
O vínculo aprende pela regra E2 `V += 0,2 × (resultado − V)`.

[FATO] Solidão/sociabilidade motivam aproximação e, após familiaridade >=0,12,
seguir o vizinho percebido. Aversão/cautela motivam afastamento. Afinidade,
fome do parceiro e saciedade própria podem motivar ceder acesso ao alimento;
fome/impulsividade podem motivar disputá-lo. Os escores competem acima de 0,32,
em ordem determinista, sem sortear um vencedor ou conceder recurso por intenção.
Sobrevivência, ordens aplicáveis e ensino ativo têm prioridade; fadiga >=0,85
impede essas ações sociais. Aproximação conserva o código E2 `seek_contact`;
as demais ações usam `social_follow`, `social_avoid`, `social_share` e
`social_compete`, com razões `social.*`.

[FATO] Ceder acesso significa deslocar-se para longe do recurso; o parceiro
precisa alcançá-lo e ingerir por conta própria. Competir usa movimento e ingestão
normais. Cada corpo paga metabolismo/movimento, respeita colisões e pode falhar.
Consultas, seleção e diálogo não criam vínculos. A interação explícita E2 com
o jogador continua exigindo alcance/visibilidade e só altera o vínculo `player`.

[FATO] `world.social_observar(id)` retorna cópia com `ok`, `relations`, `limit`;
cada relação contém `id`, `encounters`, `familiarity`, `affinity`, `aversion` e
`last_tick`. Até 32 vínculos, contagem até 10000 e até 32 episódios por corpo;
valências/familiaridade finitas e limitadas continuam validadas pelo E2.
Empates de descarte usam chaves ordenadas. Vínculos não são herdados.

[FATO] Save **v7**: os campos de vínculo permanecem iguais, mas o domínio
validado de ações e eventos episódicos foi ampliado. Isso justifica o bump;
um leitor v6 anterior não conhece esse vocabulário. Migração v6→v7 é cópia sem
inventar experiências, sem RNG ou alterações fisiológicas, e é idempotente.
V1→v2→v3→v4→v5→v6→v7 permanece sequencial; o envelope e os backups do
SaveStore permanecem existentes. Regressões verificam v1/v2, fixtures reais
v3/v4, v5 e o novo teste v6, além de round trip v7 e continuação determinista.

[LACUNA] Valência social é um modelo explícito de contato/disputa, não leitura
de emoções ou aprendizado irrestrito de reciprocidade. “Repartir” aqui significa
ceder acesso; não divide um alimento em porções nem garante benefício ao vizinho.
O contato E2 ainda busca o vizinho por heurística. Os testes não demonstram
cooperação sustentada em populações grandes, nem determinismo entre motores.

## Diálogo com evidências

[FATO] Reutilizados `dialogo.gd` e `dialogo_textos.gd`; `Dialogo.CONSULTAS`
adiciona `perguntar_gostos`, `perguntar_aprendizado` e `perguntar_agua`.
`interpretar` aceita “do que você gosta?”, “o que aprendeu?” e “onde está a água?”.
`responder` devolve texto, `evidencias` copiadas e `comando={}`. O adaptador
`Comandos` reconhece as consultas como leitura sem criar ordens.

[FATO] Gostos vêm somente de preferências alimentares aprendidas positivas
>0,05. Aprendizado de habilidades exige os critérios reais E3 de pelo menos
cinco tentativas autônomas recentes e taxa >=70%; tentativa assistida não serve
como prova. Água é localizada somente por `sense.waters` atual. Sem suporte,
a resposta é “Não sei; não tenho evidência suficiente nos meus registros.”
As fontes consultadas são listadas mesmo quando vazias: `personality.preferences`,
`ensino.statistics`, `personality.episodes`, `sense.waters` e `creature.memory`.

[LACUNA] A memória de bebida contém ID e evento, sem coordenada: não sustenta
localizar água oculta. O diálogo conserva essa limitação e não consulta o mapa
global para completar a resposta. Não traduz sinais neutros em palavras. A
apresentação visual das fontes deve ser feita pela UI.

[FATO] `textos.gd` recebeu somente seção E4 ao fim, com `E4_CATALOGO`,
`E4_RAZOES`, `e4_acao` e `e4_razao`; o diálogo usa esses helpers. Nenhum arquivo
de `scripts/ui` ou `scripts/render` foi alterado.

## Experimento pré-registrado

[HIPOTESE] Informação exclusiva do emissor, transmitida pelo canal, permite ao
receptor aprender uma escolha de destino que melhora chegada/bebida. Protocolo:
[`social_preregistro.md`](../tests/experiments/social_preregistro.md), commit
`ad63789`, anterior à implementação e avaliação. SHA-256 lido na execução:
`1802639dcc4c96c384f2471848812a78294e32d7e553e4522fc177853cd98d20`.

[FATO] Treino separado: 96 episódios, 12 passagens pelas seeds 51001–51008,
epsilon 0,2, alpha 0,3, tabela 3×2 inicialmente zerada; 88/96 bebidas durante
treino exploratório. O emissor usa um codificador fixo de dois símbolos neutros
condicionado somente à própria observação; o receptor aprende qual dos dois
marcos públicos escolher a partir do símbolo ou da ausência. Recompensa 1
somente após evento físico `drink` do receptor; 0 no fracasso. Nenhum reforço
altera fisiologia. QBrain e checkpoint de outros gates não foram reutilizados.

[FATO] Mundo 640×400, receptor (320,200), emissor (320,100), água com raio 18
em (140,200) ou (500,200). O emissor vê uma região; receptor inicialmente vê zero.
O fixture intervém explicitamente na visão (500/30 unidades, FOV TAU), fora dos
limites genéticos do produto, conforme pré-registro. Um navegador heurístico
comum aos braços orienta o corpo ao marco escolhido; não recebe o local oculto
da água. Movimentos, metabolismo e bebida são executados por `world.step()` e
pelas ações reais, sem teleporte. Não há risco neste cenário.

[FATO] Canal real: uma tentativa antes da decisão, alcance 200, custo 0,3,
perda 10%, validade 100 passos. O braço embaralhado substitui o símbolo recebido
por sorteio independente do local, com RNG exclusivo do harness; preserva as
mesmas tentativas, custos e perdas do ativo. É uma intervenção experimental
na recepção; o histórico do canal continua registrando o símbolo emitido, e os
dados brutos distinguem `symbol` e `received`. Desligado recusa emissão e não
cobra o custo. A dinâmica do produto mantém o RNG único do mundo.

[FATO] HOLDOUT 91501–91520: mesmo checkpoint congelado, mesmas seeds pareadas,
sem atualização ou retuning. Ativo e embaralhado receberam 18/20 pacotes;
desligado recebeu zero. Cada braço teve os mesmos oito locais à esquerda e
doze à direita. A escolha sem sinal aprendeu a opção esquerda no treino;
nenhum controle consultou o local escondido.

| Braço | Chegou ao alcance da água | Bebeu | Passos até sucesso, censura 100 | Energia receptor | Energia emissor | Custo emissão |
|---|---:|---:|---:|---:|---:|---:|
| Ativo | 18/20 | 18/20 (90%) | 44,2 | 4,0268 | 3,5708 | 0,3 |
| Desligado | 8/20 | 8/20 (40%) | 75,2 | 6,4008 | 5,5648 | 0 |
| Embaralhado | 10/20 | 10/20 (50%) | 69,0 | 5,9260 | 5,4060 | 0,3 |

[FATO] Tempos e custos são médias por episódio; todos os sucessos ocorreram em
38 passos (3,8 s). Fracassos permanecem em 100 passos, sem removê-los da média.
Energia do emissor inclui metabolismo e emissão: a média menor no ativo também
reflete terminar mais cedo. “Chegar” é alcançar a distância que permite beber
na margem, não necessariamente entrar no círculo.

[FATO] Ativo versus desligado: +50 pontos percentuais, dez vitórias estritas,
zero derrotas e dez empates pareados. Ativo versus embaralhado: +40 pontos,
oito vitórias, zero derrotas e doze empates. Gate pré-registrado: ativo >=75%,
ganho >=25 pontos contra cada controle e >=7 vitórias contra cada controle;
todos passaram. Não se acrescentou critério estatístico após ver HOLDOUT.

[LACUNA] Ganho causal restrito ao decoder aprendido, encoder fixo, duas opções,
navegação aberta e intervenção sensorial. Não se afirma que um símbolo significa
“água aqui”, que os dois corpos inventaram um código, ou que uma política
autônoma do ecossistema emite sinais úteis. O checkpoint experimental não é
instalado nos pets do produto. O resultado negativo anterior de `reports/sinais.md`
continua válido para seu protocolo; este cenário não o reclassifica.

## Evidências e validação

[FATO] Godot 4.7.2.stable.official.ed1daf0bf, Windows, console fornecido no
despacho. Comandos na raiz, usando esse executável:

| Comando | Resultado |
|---|---|
| `--headless --path . -s tests/run_tests.gd` | exit 0, 14 arquivos verdes, sem SCRIPT ERROR/Parse Error |
| `--headless --path . -s tests/experiments/social_eval.gd -- --dev` | exit 0, somente 96 episódios TRAIN |
| `--headless --path . -s tests/experiments/social_eval.gd` | exit 0, uma execução HOLDOUT, gate PASS |
| `git diff --check` e `git diff --cached --check` | exit 0 |

[FATO] `test_sim_e4.gd` cobre familiaridade por encontro e ausência de efeito
de consulta/clique distante; afinidade/aversão por encontros; decisões de seguir,
ceder, disputar e evitar; save round trip, continuação determinista, limites,
migração v6 idempotente; diálogo sem evidência, preferência após ingestão e
habilidade após cinco conclusões reais; canal desligado; determinismo do fixture.
No controle determinista completo local×símbolo independente, embaralhado e
desligado acertam 50%, ativo 100%; não se apresenta esse decoder de fixture como
resultado de treino. As regressões anteriores permanecem verdes.

[FATO] Rodadas de desenvolvimento detectaram o nome de ação E2 esperado e
problemas no fixture (codificação de texto e tipos numéricos após intervenções
diretas). Foram corrigidos antes da suíte final e antes de abrir HOLDOUT.
Não foram executados `ensino_eval.gd` nem `learn_eval.gd` neste trabalho.

[FATO] Artefatos: [`E4_sim_tests.txt`](E4_sim_tests.txt),
[`E4_social_eval.txt`](E4_social_eval.txt) e
[`E4_social_eval.json`](E4_social_eval.json), com todos os episódios TRAIN/HOLDOUT,
checkpoint, observações iniciais, escolhas, chegadas, bebidas, tempos, custos e
comparações pareadas. SHA-256 do JSON bruto:
`9c1fefccb083858d8ee4fe840279a7c965d0ee6cc6d33317aa566b3a55cc4a4c`.

[LACUNA] Revisão independente, integração dos commits e validação visual ficam
com o coordenador. Não houve mudanças em UI/render ou publicação externa.
