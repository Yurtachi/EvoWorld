# M2 — iniciativa, objetos físicos e memória de consequências

[FATO] Data: 02/11/2026. Base `evo3/integration` @ `a9c8e01`, branch local
`Yurtachi/evo3-m2-sim`. Implementação e compatibilidade: **PASS**;
X3 nos critérios pré-registrados: **PASS**. Não se afirma consciência nem
generalização ecológica a partir destes ensaios controlados.

[FATO] 19 suítes passaram, exit 0: as 18 anteriores e `test_sim_m2.gd`.
O holdout foi aberto uma única vez, com 24 seeds pareadas e 1008 ensaios.
Não houve push, merge, mudança de UI/render, código GPL ou execução dos
avaliadores antigos de ensino/aprendizado/social/M1. Os testes unitários
existentes executam seus próprios cenários de ensino/social, conforme o runner.

## Objetos e fronteira de conhecimento

[FATO] `world.place_object(pos, tipo)` retorna ID ou −1. O catálogo versionado
v1 oferece `capsula_neutra`, `capsula_agradavel`, `capsula_aversiva` e `pedra`;
há limite de 128 objetos por mundo. As três cápsulas têm a mesma aparência
`lisa` e categoria `capsula`. O agente não recebe o tipo interno nem as
consequências do catálogo: o sensor entrega exclusivamente ID, posição,
categoria e aparência, filtrados por alcance, campo visual e oclusão.

[FATO] `interact_object` exige criatura viva com mente, alcance corporal
`size + 5` e linha de visão livre. Só o mundo consulta os efeitos ocultos:
cápsula neutra não fornece recurso; agradável fornece até +4 energia e +2
hidratação; aversiva reduz energia em 4,6 e hidratação em 2, incluindo custo
de toxicidade 0,15. O valor aprendido usa deltas efetivamente aplicados ao
corpo, toxicidade e contato real; a política jamais aplica valor aprendido
como recompensa corporal. Surpresa é uma consequência de contato do catálogo,
registrada na evidência e usada para alterar entusiasmo/receio computacionais.

[FATO] As memórias são individuais: até 48 instâncias, duas categorias
consolidadas e 48 cooldowns por criatura. Cada instância guarda `observado`
ou `interagido`, confiança, tick da observação, `evidence_tick`, validade,
familiaridade, próxima tentativa, hipótese e evidência separadas. Observar
nunca cria deltas corporais nem ensina valor. A categoria observada começa
com valor/confiança zero; contatos atualizam uma média exponencial (ganho 0,6)
e confiança (+0,25, teto 1), consolidando no máximo 10000 amostras contadas.

[FATO] A validade de instância é renovada por observação, mas evidência e
valor aprendido expiram após 3600 ticks sem contato, inclusive se o objeto
continuar visível. Instâncias/categorias ausentes expiram; ao atingir o limite,
a entrada mais antiga na ordem de inserção é removida. Não se guardam
históricos ilimitados. O snapshot mental expõe uma cópia dos objetos para
inspeção; esse canal contém somente conhecimento adquirido pela criatura.

[LACUNA] A aprendizagem generaliza por **categoria visual**, não pelo tipo
oculto: uma cápsula adversa pode induzir cautela diante de outras cápsulas.
Isso evita onisciência, mas não implementa discriminação visual mais fina,
inferência causal sofisticada ou descoberta de propriedades sem contato.
Os objetos ainda não têm dinâmica própria, inventário ou genealogia histórica.

## Escolha autônoma e habituação

[FATO] O interesse básico é `novidade * curiosidade - risco * cautela`.
Novidade = inverso de familiaridade de instância + 0,4 × familiaridade da
categoria, com recuperação parcial de até 0,35 após ausência. Ver acrescenta
0,008 à familiaridade da instância e 0,004 à da categoria; interagir acrescenta
1 e 0,8, respectivamente, todos limitados a 12. Risco percebido é a parte
negativa do valor aprendido, ponderada pela confiança, sem ler efeitos ocultos.

[FATO] Entusiasmo e tédio corporal existente modulam o interesse; receio
reduz a ativação da investigação. O tédio vem de `personality.boredom`,
sem acrescentar um afeto persistido novo. A ablação `curiosity_enabled=false`
remove o termo de curiosidade do interesse, conservando outros traços/física;
`affect_enabled=false` remove a modulação afetiva; `memory_enabled=false`
remove familiaridade/risco/hipóteses aprendidos, conservando cooldown físico.

[FATO] O candidato compete com os objetivos existentes, sob ruído mental
semeado. Compromisso mínimo de 12 e máximo de 80 ticks limitam oscilação/loop;
alvo indisponível ou já interagido permite liberação antecipada. Contato e
timeout impõem 180 ticks de intervalo para nova tentativa. Fome/sede acima de
0,55 suspendem investigação e prevalecem em `choose()`. O executor usa
`seek_object`, movimento/custo/colisão existentes e `investigate_object` no
contato. A criatura pode ignorar, aproximar-se, interagir ou retornar depois.

[FATO] O `mind_log` limitado a 48 entradas registra objetivos, scores, tick e
razões `mind.iniciativa.novidade` ou `mind.iniciativa.lacuna`; a evidência do
evento físico fica na memória e no cause_log `object_contact`. Não há comando
de jogador ou ensino nos braços endógenos do X3. A mente permanece habilitada
somente no pet por padrão; mundos antigos não ganham mente nem objetos.

[LACUNA] Timeout limita permanência, sem fornecer planejamento de rotas novo.
O executor usa movimento existente; obstáculos podem impedir a investigação.
`mind.iniciativa.evento` fica reservado no vocabulário, sem afirmar que foi
exercitado neste ensaio. Integração visual e textos pt-BR via Textos pertencem
ao worker de UX/coordenador; não se adicionaram strings de jogador aqui.

## Pré-registro, congelamento e abertura

[FATO] Protocolo: `tests/experiments/m2_curiosity_preregistro.md`, commit
`f1a6349`. Motor/avaliador/testes: `ab5bc9f`. Resultado único: `49350ea`.
TRAIN 106101–106104; DEV 106201–106206; HOLDOUT 107301–107324. As seeds são
distintas das séries M1/M1b e foram pareadas entre todos os braços/condições.
TRAIN/DEV finais passaram; nenhum motor, parâmetro, avaliador, critério ou
seed foi alterado após abrir o holdout.

[FATO] SHA256 do protocolo em UTF-8/LF:
`f560da4498f9d35510f5d562e03b0c212546e42f9553559d42880089849ec19d`.
SHA256 do resultado integral em LF:
`84c8c5b2ef61e9ae26f2cfc461565cd0117200125c56f2f29e83a3e1abde91c5`.
O JSON inclui hashes dos arquivos congelados, seeds, estado inicial,
objetivos, ações e latências por ensaio. O avaliador escreve/flush/fecha
`status=opened` antes do primeiro ensaio e recusa abertura se o arquivo existir.
Não se invocou a abertura novamente para testar a guarda.

[FATO] `verify_prereg.sh` passou E3/E4/M1/M2 sem executar experimentos;
`m2_curiosity_verify.py` verifica ancestralidade, identidade do protocolo,
hashes do motor antes do primeiro resultado, sementes, 1008 linhas, pares de
estado atual idêntico e round trips. Preservar a sequência de commits na
integração; squash/recriação de protocolo eliminaria essa prova histórica.

[LACUNA] Git prova ordem/identidade dos artefatos, não ausência universal de
execuções ocultas. A abertura única descreve a execução deste worker.

## X3 — resultados físicos, 24 seeds por célula

[FATO] Todos os ensaios usam o mesmo perfil de alta curiosidade: curiosidade
0,9, cautela 0,8, sociabilidade 0,2 e impulsividade 0,3, visão de 360° e objeto
neutro a 24 px, sem obstáculos/recursos/ordens. Janela de 36 ticks, uma
interação máxima observada por ensaio. Ausências recebem latência censurada
36; esse valor não é uma latência exata observada.

[FATO] Doadores adquirem memória por oito contatos reais espaçados por 181
ticks. A aquisição avança o relógio sem metabolismo/decay entre contatos e
restaura fisiologia antes de cada contato: intervenção controlada explícita,
não vida livre. Habituado testa imediatamente uma instância nova da mesma
categoria; histórico neutro/aversivo testa após 600 ticks de ausência, para
permitir recuperação parcial. Transplanta-se somente memória para clones de
corpo/afeto atual/RNG iguais; o contraste afetivo transplanta separadamente
estado adquirido por cápsulas agradáveis ou aversivas, sem memória doadora.

| Braço | Novo: interação / latência censurada | Habituado | Histórico neutro / aversivo | Entusiasmo / receio |
| --- | ---: | ---: | ---: | ---: |
| Completo | 24/24 / 5,000 | 0/24 | 24/24 / 0/24 | 24/24 / 0/24 |
| Sem memória | 24/24 / 5,000 | 24/24 | 24/24 / 24/24 | 24/24 / 24/24 |
| Sem afeto | 24/24 / 5,000 | 0/24 | 24/24 / 0/24 | 24/24 / 24/24 |
| Sem curiosidade | 0/24 / 36,000 | 0/24 | 0/24 / 0/24 | 0/24 / 0/24 |
| Aleatório | 7/24 / 28,750 | 7/24 | 7/24 / 7/24 | 7/24 / 7/24 |
| Sempre investiga | 24/24 / 5,000 | 24/24 | 24/24 / 24/24 | 24/24 / 24/24 |
| Nunca investiga | 0/24 / 36,000 | 0/24 | 0/24 / 0/24 | 0/24 / 0/24 |

[FATO] H1 (>=70% iniciativa): 100%, PASS. H2 (queda >=25 pp por habituação):
100 pp, PASS. H3 (histórico aversivo reduz >=25 pp): 100 pp, PASS.
H4 (sem memória remove >=80% de H3): remove 100%, PASS. H5 (sem curiosidade
reduz >=25 pp): 100 pp, PASS. H6 (sem afeto reduz contraste afetivo >=10 pp):
100 pp, PASS. Todos os 24 pares apresentaram a direção prevista nos contrastes
completos; não houve hipótese pré-registrada falha neste holdout.

[FATO] Retirar afeto não elimina o contraste de memória. Retirar memória
elimina habituação e cautela aprendida, mas conserva receio computacional:
na célula sem memória + receio, a interação ocorre em 24/24 com latência
média 32,625, contra 5 no entusiasmo. O contraste binário desaparece nessa
janela, mas resta um atraso afetivo; não se afirma que toda consequência
da experiência desapareça ao desligar apenas memória.

[FATO] Sempre/nunca impõem objetivo por tick como controles declarados,
usando o mesmo executor físico; não contam como iniciativa endógena.
Aleatório usa o RNG mental para escolher objetivos e conserva compromisso.
Todos os braços realizam save/load no tick 18; os 1008 round trips foram
idênticos e a execução prosseguiu pelo estado carregado.

[LACUNA] O pré-registro define recuperação parcial de 600 ticks, mas não
fixa explicitamente a espera no contraste de históricos: o avaliador a
concretizou antes do congelamento/holdout e grava `recovery_ticks_history=600`.
O efeito demonstrado é de **retorno após ausência**, não investigação imediata
após oito contatos. As 24 seeds variam RNG, não geometria, temperamento ou
ecologias independentes. Não se estimou intervalo populacional inferencial.

[LACUNA] Não se demonstra superioridade sobre o controle sempre investiga no
objeto seguro: ambos chegam em cinco ticks. O ganho demonstrado é seletividade
causada por memória/afeto, com contato físico medido. O fatorial de afeto usa
vetores adquiridos completos; não isola cada afeto individual nem separa
entusiasmo de receio em magnitudes equivalentes. Não se afirma que afeto seja
necessário para iniciativa ou para o contraste de histórico.

## Persistência e compatibilidade

[FATO] Save v9 inclui objetos e versão do catálogo. A migração v8 adiciona
coleções vazias, preservando mente/RNG/histórico; v1–v7 passam pelas migrações
existentes até v8/v9. A carga repetida é idempotente e não modifica a entrada.
Campos desconhecidos hostis, NaN, tipos incorretos, tamanhos, IDs duplicados,
ticks futuros, fontes e evidências incompatíveis são validados antes de uso.
O SaveStore existente continua responsável por envelope/checksum/backup e
rollback, sem mudança no protocolo de disco.

[FATO] O teste M2 cobre contato remoto rejeitado, aparência indistinguível
antes do contato, fonte/hipótese/evidência, prioridade fisiológica, cooldown,
timeout, habituação/recuperação, esquecimento/limites, histórico/ablação,
NaN/tipos hostis, v8→v9, round trip e continuação idêntica por 60 ticks.
A suíte integral preserva golden v7/M1 e hashes históricos de comportamento.
Os valores golden não foram regenerados. Duas adaptações de schema nos testes
existentes: expectativa usa `World.SAVE_VERSION`, e digest v7 remove somente
`objects`/`object_catalog_version` além dos metadados M1 já excluídos.

[FATO] Comando obrigatório executado com Godot console 4.7.2 indicado no
despacho: `godot --headless --path . -s tests/run_tests.gd`, **exit 0, 19
suítes ok**, sem FAIL/SCRIPT ERROR na execução final. Logs locais ignorados:
`builds/m2_tests_frozen.log` e `builds/m2_cpu.log`.

## CPU com 32 objetos

[FATO] Medição serial após terminar a suíte, sem outro processo Godot deste
worker: seed TRAIN 106104, 100 ticks de aquecimento + 400 medidos, reprodução
desligada, 32 objetos em todas as condições. Populações finais iguais às
iniciais; mente desligada ou somente um pet. Artefato `M2_curiosidade_cpu.json`.

| Criaturas | Desligada média/p95 ms por tick | Só pet média/p95 | Diferença média |
| --- | ---: | ---: | ---: |
| 12 | 1,560 / 2,246 | 1,706 / 2,317 | +0,146 |
| 30 | 4,670 / 6,714 | 5,189 / 7,805 | +0,519 |
| 60 | 9,429 / 12,785 | 10,118 / 14,776 | +0,690 |
| 100 | 23,824 / 31,772 | 22,240 / 29,658 | −1,583 |

[LACUNA] A diferença negativa em 100 é compatível com ruído e trajetórias
distintas, sem evidência de aceleração pelo motor mental. Os tempos incluem
percepção/física/ecologia, não isolam a função cognitiva e não comparam dois
motores distintos. Não se mediram render/FPS, mente em todas as criaturas,
centenas de objetos ou execução sustentada. Não se infere margem garantida
para velocidade 5×; o padrão de só pet permanece.

## Reprodução e pendências

[FATO] Pode-se repetir a suíte, TRAIN (`m2_curiosity_eval.gd -- --train`), DEV
(`m2_curiosity_eval.gd`, sem argumentos), CPU (`m2_curiosity_cpu.gd`) e auditoria
somente leitura. HOLDOUT permanece fechado: conservar `M2_curiosidade_eval.json`
e nunca apagá-lo para tentar melhorar resultados. Artefatos de TRAIN/DEV usam
arquivos próprios; relatórios JSON antigos permanecem intactos.

[LACUNA] Revisão independente, integração sequencial e validação UX ficam
com o coordenador. Este relatório documenta limites observados e não converte
PASS do cenário controlado em alegação de indivíduo consciente ou curiosidade
universal. Nenhum código congelado foi ajustado após observar o holdout.
