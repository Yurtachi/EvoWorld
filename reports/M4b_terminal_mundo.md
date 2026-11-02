# M4b — terminal físico, autonomia e X7

[FATO] Integração final implementada e corrigida. **X7: FAIL global do
congelamento original**, pelo critério pré-registrado de integridade do save.
O avaliador produziu **PARTIAL** nas seis medidas comportamentais; três falhas
de carregamento foram descobertas na auditoria posterior e corrigidas em
commit separado, sem reabrir o holdout. Não há demonstração de vantagem de
aprendizado de solução de problemas sobre a heurística/programa fixo.

[FATO] Base `evo3/integration` @ `74eae56`; branch local
`Yurtachi/evo3-m4b-sim`. Código próprio, sem cópia GPL, push ou merge.
Identidade Git local Yurtachi. Não foram editados `scripts/ui` ou `scripts/render`.

## Fronteira física e orçamento

[FATO] `world.place_terminal(Vector2)` cria objeto persistente com ID global,
posição real e três manuais anexos, limitado a 16 terminais. O objeto é
percebido por alcance, campo visual e oclusão. Durante programa ativo a criatura
conserva a referência ao dispositivo já visto, dentro do alcance visual e sem
atravessar oclusão; virar de costas não apaga uma sessão física em andamento.

[FATO] O adaptador confiável `scripts/terminal/terminal_mundo_real.gd`
implementa a interface M4a e delega ações pequenas ao executor do mundo:

| Comando | Consequência real |
| --- | --- |
| OLHAR | Sensores atuais, posição relativa, limites públicos do mundo, corpo e manuais disponíveis. |
| MARCAR | Marcador no mundo em coordenadas inteiras relativas ao terminal, entre -64 e 64; uma marca por dono/dispositivo. |
| MOVER | Uma translação cardinal, distância `min(unidades, velocidade × 0,1 s)`, com a mesma colisão varrida e limites corporais da locomoção. |
| DESENHAR | Um passo do ateliê em quadro próximo, sem oclusão e com referência compatível; produz primitivas/artefatos reais. |
| LER | Consulta um dos livros-manuais físicos anexos ao dispositivo próximo. |

[FATO] O programa inteiro é analisado e verificado contra os comandos conhecidos
antes da primeira ação. Até oito passos sintáticos são aceitos por sessão;
REPETIR é expandido em lista limitada antes de iniciar. Cada criatura executa
**no máximo uma instrução atômica por tick**, inclusive em chamadas repetidas
da API. O cursor persiste no save; não há loop aguardando movimento, desenho
ou leitura dentro de `step()`. A sessão expira após 40 ticks e tem cooldown de
dois ticks. Uma ação que falha encerra a sessão sem desfazer ações físicas anteriores.

[FATO] Cada instrução e página oferecida de manual custa 0,004 de energia no
mundo. Movimento e desenho acrescentam seus custos físicos, uma única vez;
metabolismo e hidratação continuam no caminho habitual. Nenhum módulo em
`scripts/mind/terminal_learning.gd` escreve energia, hidratação ou posição.

[LACUNA] O orçamento é cooperativo e por criatura, não uma interrupção de
código arbitrário nem um limite global de microssegundos. A ponte é código
confiável fixo; as funções delegadas fazem trabalho limitado pelas coleções
do mundo. O prazo M4a entre instruções continua disponível. Os terminais e
manuais são objetos/componentes da simulação, não processos ou arquivos reais.

## Motivação e descoberta

[FATO] `usar_terminal` concorre com os demais objetivos por curiosidade,
lacuna de comandos e ociosidade. Compromisso mínimo de 12 e máximo de 80 ticks,
com liberação quando o dispositivo deixa de estar disponível. Fome ou sede
acima de 0,55 interrompem a atividade. Não há ativação de objetivos por
`terminal_set_task`: essa API apenas define o alvo operacional possível.

[FATO] Curiosidade baixa com pouca ociosidade permite ignorar; `enabled=false`
permite desativar e `terminal_refuse(c, duração)` permite adiar por até 10000
ticks. Oferecer manual respeita recusa, alcance e necessidades críticas.
A criatura pode continuar explorando, descansando, comendo ou bebendo.

[FATO] Cada criatura começa com OLHAR/AJUDA. O manual `mapa` revela uma página
por interação, na ordem MARCAR, MOVER e LER, com proveniência `manual`.
AJUDA mantém proveniência `ajuda`; `livro_desenho` revela DESENHAR e
`livro_repeticao` revela REPETIR. Prática mantém a descoberta M4a de REPETIR
após três execuções válidas. Esses livros anexos não foram inseridos no
catálogo global M3c nem exigem prosa livre: são conteúdo offline enumerado.

[FATO] A política gera programas curtos dos comandos conhecidos e de modelos
parametrizados pelo alvo. A tabela individual associa objetivo e sequência de
operações a contagens limitadas de sucesso/falha, com média suavizada e bônus
exploratório. O feedback de objetivo exige marcador produzido na sessão e
deslocamento corporal real até tolerância de 1,5 unidade. Um OLHAR válido não
recebe sucesso de objetivo por haver uma marca antiga no local.

[LACUNA] Os modelos já fornecem a relação geométrica entre alvo, direção e
argumentos; não há inferência de gramática ou semântica geral. A associação
transferida usa a estrutura de comandos, não argumentos literais completos.
O gerador atual é adequado ao ensaio cardinal próximo, não a navegação
arbitrária com desvios, alvos diagonais ou síntese geral de programas.

## API para apresentação

```gdscript
var id = world.place_terminal(pos)
world.terminal_set_task(creature, "marcar_mover", Vector2i(6, 0))
world.terminal_offer_manual(creature, id, "mapa")
world.terminal_refuse(creature, 180)
var snapshot = world.terminal_snapshot(creature) # aceita também ID da criatura
var same_state = creature.terminal_snapshot()
```

[FATO] `world.terminals`: `{id, pos: Vector2, books}`.
`world.terminal_markers`: `{owner_id, terminal_id, pos: [x,y], tick}`.
Snapshot: `state {conhecidos, tentativas, tabela, sucessos, versao}`;
`task {kind, target}`; `active {program, instructions, index, terminal_id,
started, origin}` ou vazio; `table`, `outcomes`, `enabled`, `refusal_until`,
`cooldown`, `last_tick`. Tentativas M4a registram instruções/erros; outcomes
registram o programa completo, objetivo e desfecho físico. As cópias são profundas.

[FATO] Ações: `seek_terminal`, `use_terminal`, `read_terminal_manual`;
objetivo `usar_terminal`, motivo `mind.iniciativa.terminal`. O contrato foi
enviado ao coordenador para textos em `scripts/core/textos.gd` e UI.
Foi necessário ampliar somente o enum fechado de episódios em
`scripts/behavior/personality.gd`, para que essas ações recarreguem.

## Save v13, validação e correções posteriores

[FATO] Estado individual é lazy em `mind.terminal`. Migrações v1–v12 não
criam terminais, comandos ou memórias e não consomem RNG/IDs; round trips
idempotentes são testados em todas essas versões. Campos M4b em schemas
antigos são rejeitados antes da migração. Mantiveram-se envelopes, backup e
rollback do SaveStore; alterou-se apenas seu comentário de versão.

[FATO] Limites: 16 dispositivos, 48 marcas, 48 tentativas M4a, 48 desfechos,
32 associações por objetivo, 32 programas M4a, sete comandos, contagens até
10000 e sessão de até oito instruções. Validação rejeita tipos errados,
booleanos como inteiros, NaN/INF, IDs duplicados ou ausentes, timestamps
futuros, históricos enormes, proveniência falsa e cursor/programa divergentes.
As instruções persistidas precisam coincidir com nova análise do programa.

[FATO] Depois do holdout, uma sondagem independente de save produziu:

```text
TERMINAL_ARTIFACT_ID_COLLISION_ACCEPTED=true
FRACTIONAL_VALID_MARKER_ACCEPTED=false
LONG_REFUSED_PROGRAM_SAVE_ACCEPTED=false
```

[FATO] O registro de IDs dos artefatos precedia a nova coleção de terminais,
mas não era incorporado ao conjunto consultado por ela. A correção registra
esses IDs antes de restaurar terminais. A segunda falha vinha de subtração
float32 em posições como `255.99998 + 64`: a diferença não é exatamente
inteira. A correção reconstrói a operação física a partir do deslocamento
arredondado e exige igualdade com a posição resultante, sem aceitar pontos
fora da grade. Regressões cobrem três fronteiras de expoente, três offsets e
rejeição de deslocamentos adulterados de 0,25 unidade.

[FATO] Uma terceira regressão cobre programa sintaticamente válido, mas ainda
desconhecido, com espaços até exceder 128 caracteres. O módulo M4a aceitava
sua chave de tabela de até 256 caracteres; o formato global limita chaves a
128 e recusava salvar o mundo inteiro. A ponte passa a descartar somente
essas chaves de programas recusados, preservando o histórico opaco do erro.

```text
M4b unit: PASS
TERMINAL_ARTIFACT_ID_COLLISION_ACCEPTED=false
FRACTIONAL_VALID_MARKER_ACCEPTED=true
LONG_REFUSED_PROGRAM_SAVE_ACCEPTED=true
```

[FATO] Essas correções são posteriores ao resultado histórico `5de92a7`,
limitadas à validação/persistibilidade de entrada recusada e às regressões. Não mudaram seleção de programas,
física ou dados X7. O manifesto congelado não foi reescrito. Isso constitui
exceção explícita à imutabilidade do motor prevista no protocolo: o código
final corrigido **não recebeu outro holdout**. Pelo critério conservador do
pré-registro, a falha de integridade descoberta rebaixa o X7 original de
PARTIAL calculado para **FAIL global**, mesmo após a correção de engenharia.

## Segurança e testes

[FATO] O scanner recursivo M4a inclui automaticamente o adaptador novo e é
chamado também pela suíte M4b. Proíbe FileAccess/DirAccess, OS, APIs de rede,
Expression/eval, processos, chamadas dinâmicas e outras capacidades externas
em `scripts/terminal`. A ponte e seus executores do mundo não usam essas APIs.
Somente persistência/testes acessam arquivos; o terminal fictício não os acessa.

[FATO] Entradas hostis incluem prefixo válido com sufixo PowerShell,
CMD, separadores de shell, caminhos, REPETIR enorme e chamadas a OS.
Nenhuma produz ação física antes da validação integral. O corpus M4a de
1078 entradas também passa. Os testes M4b verificam contato/colisão/custo,
reentrada no tick, iniciativa física, prioridade de fome/sede, recusa,
desenho real, save em disco, migrações, continuação e corrupções aninhadas.

[FATO] Suíte integral executada antes de cada commit: **24 suítes, exit 0**,
sem FAIL ou SCRIPT ERROR. Inclui os corpora legados 693+, 1204 e 280 casos,
golden M1 e determinismo. Nenhum avaliador fechado anterior foi executado.
Nenhum JSON experimental anterior foi modificado ou precisou ser restaurado.

## Pré-registro, congelamento e abertura

[FATO] Protocolo: `d9b57a1`, SHA256 Git/LF
`d06c550522795c098c5f51efd4d2731c83d2087f7f1be5b998e79e95940afd88`.
Motor/primeiro avaliador: `f8ec992`. Congelamento final de 80 arquivos:
`810cc856bc1d5b59b15c4786e03348e47b4bd21d`. Resultado histórico: `5de92a7`.
O protocolo não foi alterado depois de criado.

[FATO] A primeira invocação com `--holdout` foi recusada na guarda de hashes,
antes de criar marcador ou acessar cenários: o decoder Godot removia BOM UTF-8
de dois arquivos, mas os hashes Git o incluíam. A correção da canonicalização
foi commitada em `810cc85`, antes dos dados. Pré-verificação independente
conferiu os 80 hashes. Houve depois **uma abertura efetiva**, árvore limpa,
marcador `opened` gravado/flush antes dos ensaios, término `complete`, exit 0.
Não se testou a recusa por reabertura, pois o holdout não foi reexecutado.

[FATO] TRAIN `154101–154104`, DEV `154201–154206`, HOLDOUT novo
`154401–154424`, 24 seeds pareadas, cinco braços, 2880 tentativas. Dois DEV
independentes produziram SHA256 idêntico
`79163e3d70cb81148d0ee5d03eb6eddf4310bba46e63c49a8f99dc1b2ec190cf`.
Resultado holdout, bytes LF: SHA256
`2be0adb55a0a772135db9b8c5b56cbf1ae861e4f956a257022db1d567907c4af`.

[FATO] `m4b_terminal_verify.py` audita ancestralidade, protocolo imutável,
hashes no congelamento e no commit de resultado e recalcula contagens das
linhas; não executa o experimento. Foi acrescentado a `verify_prereg.sh`.
O PASS desse gate é integridade histórica, não PASS científico.

## X7: resultados e limites

[FATO] Cada tentativa restaura um corpo/cenário saciado, conserva o estado
terminal individual e avança o relógio. Há 12 tentativas de aquisição e seis
por fase de avaliação, com limite de 40 ticks por tentativa. A motivação é
consultada e eventual recusa conta como falha; não se força `usar_terminal`.
O alvo novo muda o terminal de posição e troca deslocamento horizontal por
vertical, mantendo a família de regras. O braço sem memória apaga a tabela
de objetivo antes de cada escolha, preservando comandos e diagnóstico.

| Braço | Aquisição (288) | Mesmo alvo (144) | Novo alvo (144) | Total (576) |
| --- | ---: | ---: | ---: | ---: |
| Completo/manual | 216 | 144 | 144 | 504 (87,50%) |
| Sem ensino, com AJUDA disponível | 168 | 144 | 144 | 456 (79,17%) |
| Programa aleatório | 97 | 49 | 48 | 194 (33,68%) |
| Programa fixo parametrizado/heurística | 288 | 144 | 144 | 576 (100%) |
| Sem tabela de memória | 0 | 0 | 0 | 0 (0%) |

[FATO] H-a falhou: ganho global 8,33 pontos percentuais, abaixo dos 20
pré-registrados; mesmo só na aquisição, 16,67 pontos não atingem o limiar.
O sem ensino descobre comandos por AJUDA e alcança o completo depois da
aquisição. As 1150 entradas `error=objetivo` são falhas de objetivo físico,
não 1150 erros de sintaxe ou capacidades externas.

[FATO] H-b passou no cenário restrito: 24/24 seeds completas resolveram o
novo alvo. H-c falhou: embora supere aleatório e sem memória, o fixo já
resolve tudo sem treinamento. O motor fornece os modelos geométricos;
o resultado não estabelece aprendizado de solução de problemas.

[FATO] H-d passou na prova local: após um sucesso físico real, o mesmo
programa é apresentado em cenário com nova colisão. Em 24/24, `recusado`
fica no histórico e o score cai de 0,808088 para 0,615470. A próxima escolha
muda de `MARCAR 3 0; MOVER LESTE 3` para OLHAR, sem repetição imediata.
[LACUNA] Não demonstra planejamento de desvio ou supressão universal de erros.

[FATO] H-e passou: perfil com curiosidade zero e recusa explícita por 1000
ticks permaneceu 200 ticks sem usar o terminal, com sobrevivência, energia,
hidratação e posição exatamente iguais ao controle em 24/24 pares.
[LACUNA] Não mede sobrevivência vitalícia, todos os perfis ou frequência
espontânea de recusa numa população aberta.

[FATO] H-f passou: comandos, erros, tabela, escolha e sessão ativa foram
conservados por round trip JSON do schema v13 e 20 ticks de continuação
exata em 24/24 pares. O caminho SaveStore em disco também passa na suíte.
[LACUNA] Os 24 pares não são 24 gravações físicas de envelope em disco.

[HIPOTESE] A tabela pode reduzir exploração repetitiva em outras tarefas.
[LACUNA] Este ensaio não sustenta essa generalização, interpretação de prosa,
novas famílias de programas, escrita autônoma geral ou consciência. A falha
global de integridade do motor original permanece no registro científico.

## CPU headless

[FATO] Seed `154301`, todas as mentes, populações pareadas, 40 ticks de
aquecimento e 200 amostras por célula, reprodução desativada. Dados brutos em
`M4b_terminal_cpu.json`, obtidos com a política congelada antes das correções
exclusivas do carregamento. Valores em ms/tick:

| Criaturas | Sem terminal média / p95 | Com terminal média / p95 | Máximo de ações terminal/tick |
| --- | ---: | ---: | ---: |
| 12 | 2,599 / 3,261 | 2,906 / 4,066 | 2 |
| 30 | 7,301 / 10,371 | 7,846 / 9,798 | 3 |
| 60 | 14,787 / 19,023 | 17,966 / 21,817 | 6 |
| 100 | 27,412 / 33,219 | 33,805 / 42,355 | 8 |

[FATO] Populações finais 12/30/60/100, sem mortes. Até 16 terminais próximos
às posições iniciais; nem todas as criaturas os usaram simultaneamente.
[LACUNA] É medição headless no computador da execução, sem renderização e
sem equivalência a FPS gráfico ou garantia de pior caso para 100 usuários
simultâneos do terminal.

## Verificação e entrega

```text
godot --headless --path . -s tests/run_tests.gd
godot --headless --path . -s tests/experiments/m4b_unit_runner.gd
python tests/experiments/m4b_terminal_verify.py HEAD
bash tests/experiments/verify_prereg.sh
git diff --exit-code 74eae56 -- reports/E3_ensino_eval.json reports/E4_social_eval.json reports/M1_mind_eval.json reports/M2_curiosidade_eval.json reports/M3_atelie_eval.json reports/M3b_copia_eval.json reports/M3c_biblioteca_eval.json
```

[FATO] Executável console Godot 4.7.2 indicado no despacho. Resultados X7 e
CPU são novos arquivos; os arquivos experimentais anteriores foram mantidos.
[LACUNA] Integração visual/textos de jogador e revisão independente do patch
cabem ao coordenador e ao worker de UI; esta entrega fornece a API física,
estado, testes, registros históricos e correções de validação documentadas.
