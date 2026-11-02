# M3c — biblioteca, conhecimento e perguntas por lacuna (X6)

[FATO] Base `evo3/integration` em `73a9cc6`; branch `Yurtachi/evo3-m3c-sim`. Implementação e X6 restrito: **PASS**, segundo os critérios registrados antes do holdout. Não se afirma compreensão de linguagem, escrita, consciência ou generalização a categorias novas.

## Pré-registro e congelamento

[FATO] Protocolo imutável em `4eb4050`, arquivo `tests/experiments/m3c_biblioteca_preregistro.md`, SHA256 dos bytes Git normalizados para LF `0030c4468e6f04aa4f45ef8898b0bd9c7cc2d539e04eb8c10fb3a189229f81c0`; o BOM UTF-8 integra o hash. Motor, avaliador, auditor e 36 arquivos congelados em **`6e0584f1c6e57755f6239e9ecad454d4465df06e`**, posterior ao protocolo e anterior ao resultado.

[FATO] TRAIN: `140101–140104`; DEV: `140201–140206`; holdout inédito: **`140401–140424`**, 24 seeds pareadas e quatro braços, totalizando 96 trajetórias. Perguntas: 24 seeds × três condições × 48 ticks adicionais. Variaram curiosidade, cautela, sociabilidade e distância do livro, com parâmetros pareados entre braços.

[FATO] Houve uma única invocação `--holdout`, exit 0, com worktree limpa. O marcador `status=opened` foi gravado e descarregado em disco antes de qualquer ensaio, passando depois a `complete`. A guarda recusa arquivo existente ou árvore suja; não foi testada por reabertura. Nenhum motor foi ajustado depois da abertura e nenhum avaliador fechado anterior foi executado.

[FATO] Dois processos DEV produziram arquivos idênticos, SHA256 `3d7848447fe122c46f4a3f430ac7816a9fe28ecdb610ccba82803b910c13a5eb`, em `builds/`. Antes do congelamento foram corrigidos serialização/contagem de campos de perguntas e construção da genealogia do cenário, sem alterar o protocolo.

[LACUNA] Git e marcador documentam esta execução, sem provar ausência universal de execuções ocultas. Seeds novas no mesmo cenário não são novas famílias de regras nem generalização ecológica ampla.

## Conhecimento e fronteira física

[FATO] Cada criatura tem até 48 fatos `{id, conteudo, fonte, confianca, tick, validade, evidencia}`; conteúdo mapeia categoria observável para valor operacional em [-1,1]. Fontes permitidas: `observado`, `interagido`, `livro:ID:pagina`, `cuidador`, `inferido`. Livro/cuidador nunca viram evidência por repetição. A memória de objetos mantém hipótese e deltas físicos separados por instância.

[FATO] Mesmo conteúdo e fonte são consolidados preservando proveniência. Fatos expiram 3600 ticks após codificação/consolidação, sem renovação por simples visibilidade; no limite sai o mais antigo. Há sete fontes possíveis, três associações de glifos, uma pergunta pendente, 48 contextos perguntados e uma sessão de leitura por criatura. Confiança histórica da fonte permanece limitada após esquecimento dos fatos.

[FATO] A expectativa pondera confiança do fato e da fonte; evidência real recebe peso maior. Somente o mundo, após alcance e oclusão, aplica a consequência física. Depois, o conhecimento recebe deltas medidos. Contradição reduz fato e fonte em 0,45, piso 0,05; confirmação aumenta em 0,05, teto 0,95. Cada fonte é julgada no máximo uma vez por desfecho, mesmo com várias páginas. Os módulos cognitivos não escrevem energia, hidratação ou posição.

[HIPOTESE] O mecanismo pode ajudar em ambientes mistos, sujeitos a novos ensaios. [LACUNA] Não há lógica proposicional ou quantificadores: uma advertência conservadora sobre cápsulas pode perder confiança após uma cápsula neutra, pois não se representa a distinção entre “algumas podem causar dano” e previsão individual.

## Biblioteca, leitura e perguntas

[FATO] Catálogo original offline v1: `guia_capsulas`, duas páginas, cautela com cápsulas e pedras neutras; `guia_pedras`, uma página neutra; `guia_enganoso`, uma página recomendando cápsulas como seguras. A advertência condiz com a possibilidade real de dano; o enganoso é contradito pela cápsula aversiva da prova. Variantes de cápsula continuam com a mesma aparência, sem revelar o tipo oculto.

[FATO] O objetivo `ler` exige livro percebido e curiosidade ou ociosidade suficientes. A criatura aproxima-se pela locomoção comum; ler exige alcance `size+5`, linha de visão livre e oito ticks distintos por página. Repetir a chamada no mesmo tick não avança duas vezes. Tempo e metabolismo correm; fome/sede críticas prevalecem. Não há recompensa nutricional pela leitura.

[FATO] Pergunta exige categoria percebida ainda sem fato, alvo específico e objetivo ativo `investigar_objeto` não resolvido. O evento contém criatura, objeto, categoria, objetivo e tick; `library.question.unknown` permite a apresentação centralizada em `Textos` de “O que é isso?”. Cooldown de 180 ticks, uma pendente e contexto lembrado por até 3600 ticks; sociabilidade muito baixa permite silêncio. O motor não sorteia perguntas por tempo.

[FATO] Opções reconhecidas: `evitar`, `seguro`, `neutro`, `silencio`. Texto sem opção reconhecida é ignorado. A resposta grava fonte `cuidador`, com confiança dependente de sociabilidade, cautela e histórico; `silencio` encerra sem fato, e cautela extrema com confiança histórica baixa permite recusa. Experiência contraditória corrige essa fonte. O holdout usa temperamentos favoráveis e não mede taxa populacional de recusa ou conversa livre.

[LACUNA] Não há interpretação de prosa arbitrária. O conselho muda utilidade de investigação, sem controlador geométrico de desvio. “Evitar” no X6 significa não executar interação aversiva, sem provar maior distância corporal. UI/renderização e textos visíveis pertencem ao worker UI, informado do contrato; este patch não altera essas pastas nem `textos.gd`.

## Resultado do holdout

| Hipótese | Observado em 24 seeds | Resultado |
| --- | --- | --- |
| H-a | Verdadeiro: 24/24 evitaram; sem livro: 0/24; vantagem pareada 1,00 | PASS |
| H-b | Enganoso: 24/24 sofreram contato real; fato e fonte 0,80 → 0,35; segunda cápsula evitada em 24/24 | PASS |
| H-c | Lacuna: 24 perguntas/1152 ticks; conhecido e sem lacuna: zero; máximo uma por contexto | PASS |
| H-d | Resposta aceita e preservada como `cuidador` em 24/24; confiança 0,5135–0,6335 | PASS |
| H-e | Livro sem memória: 0/24 evitaram; diferença para sem livro = 0,00 | PASS |

[FATO] Taxa de perguntas por tick: lacuna `24/1152 = 0,020833`; conhecido e sem lacuna `0`. Controle aleatório independente sem lacuna: quatro perguntas/1152 ticks, taxa `0,003472`, em 3/24 seeds; sorteia com probabilidade 1/180 por tick e não representa outra política cognitiva completa.

[FATO] Sem livro e enganoso fizeram 24 interações na primeira prova e evitaram a segunda cápsula. Sem memória continuou interagindo na segunda: 0/24 evitaram. Verdadeiro leu 16 ticks e enganoso oito, após 7–10 ticks de aproximação; sem memória leu 16 ticks sem codificar fatos. Não se repôs energia/hidratação nas provas. O JSON registra ações por tick, contatos, corpo antes/depois, páginas, fatos e confiança por seed; o auditor recalcula as hipóteses sem executar Godot.

## Glifos: associação limitada

[FATO] Três glifos discretos, `anel`, `barra`, `onda`, associáveis a `capsula`, `pedra`, `quadro`. Demonstração de objeto visível com feedback correto aumenta confiança; feedback incorreto a reduz. A medida secundária ensina dois por criatura, rotacionados por seed, deixando o terceiro sem demonstração. No holdout, consultas dos ensinados em novos contextos/instâncias acertaram 48/48; o terceiro retornou desconhecido em 24/24.

[LACUNA] É recuperação de associação categórica; a consulta recebe o ID do glifo já discretizado, sem classificar imagem ou geometria. O significado do terceiro não foi inferido: rejeitá-lo não demonstra generalização sem treino. Não se afirma escrita ou linguagem geral.

## Persistência e verificação

[FATO] Save do mundo v12 com migração encadeada v1–v11. A migração v11 é idempotente e não inventa conhecimento ou biblioteca; estado vazio é omitido, preservando snapshots e RNG de cenários legados sem biblioteca. O envelope `SaveStore` mantém o formato; mudou o schema do mundo.

[FATO] Rejeitam-se NaN/INF, tipos incorretos, fonte inválida, confiança fora do intervalo, IDs de fatos duplicados, livros duplicados ou colidindo com IDs físicos, conteúdo de livro adulterado, página/progresso inválido, tick futuro, listas excessivas e leitura de livro inexistente. Perguntas precisam corresponder à criatura, objeto e categoria. Schemas antigos com conhecimento futuro são rejeitados; verificam-se relações e limites antes de indexar páginas, conforme RM3-01–03.

[FATO] `test_sim_m3c.gd` cobre aproximação/leitura, leitura remota/duplicada recusada, integridade corporal, SaveStore após leitura, continuação determinista, perguntas pendentes/respondidas via JSON, antispam, fonte do cuidador, dano real, glifo desconhecido, feedback negativo, ablação, esquecimento, migração e entradas hostis. A suíte integral passou **22 suítes, exit 0, zero FAIL e zero SCRIPT ERROR**, incluindo corpus legados. A asserção v11 em `test_sim_m3b.gd` usa agora `World.SAVE_VERSION`; `personality.gd` ganhou somente `seek_book`/`read_book` no whitelist de episódios, necessário ao save após leitura.

[LACUNA] O corpus hostil não é prova exaustiva. Exportação/revisão visual não integram esta tarefa; integração e revisão independente continuam sob o coordenador.

## CPU headless

[FATO] Godot 4.7.2 console, seed 140050, todas as criaturas com mente, livros/objetos, alimento/água, sem reprodução. Trinta ticks de aquecimento e 240 amostras por população, após encerrar a suíte; tempos de `SimWorld.step`, sem renderização.

| Criaturas | Mediana ms/tick | p95 ms/tick | Máximo ms/tick |
| --- | --- | --- | --- |
| 12 | 3,287 | 4,380 | 8,108 |
| 30 | 12,263 | 15,539 | 25,000 |
| 60 | 26,674 | 31,363 | 38,710 |
| 100 | 57,402 | 70,678 | 81,459 |

[LACUNA] Em 100 criaturas, 57,4 ms/tick limita aceleração e excede o orçamento de 16,7 ms de um quadro a 60 quadros/s. O ciclo fixo é 0,1 s; estes dados não são FPS gráfico. Sem baseline CPU sem biblioteca, não se atribui todo custo ao novo módulo; o protocolo não estabeleceu limiar numérico de CPU.

## API para integração

```gdscript
world.library # {version: 1, books: [{id, pos: Vector2, book_id}]}
world.place_book(pos, "guia_capsulas") # ID ou -1
creature.knowledge_snapshot() # cópia: facts, sources, questions, reading, symbols...
world.pending_questions # cópia dos eventos de todas as criaturas
world.responder_pergunta(question_id, "evitar") # bool de resposta aceita
world.demonstrar_simbolo(creature_id, "anel", object_id, true) # exige visibilidade
```

[FATO] Fatos usam campos pt-BR; perguntas contêm `id`, `creature_id`, `object_id`, `category`, `goal`, `tick`, `text_key`. `reading.page` conta páginas concluídas, `progress` vai de 0 a 7. `Books.BOOKS` expõe fatos; títulos e prosa visível devem vir de `scripts/core/textos.gd`.

[FATO] Auditoria sem reabertura: `python tests/experiments/m3c_biblioteca_verify.py HEAD` e `bash tests/experiments/verify_prereg.sh`. O gate X5 usa a revisão histórica de seu resultado para verificar seus hashes congelados, permitindo evolução do motor. JSON antigos intactos; novos: `M3c_biblioteca_eval.json` e `M3c_biblioteca_cpu.json`. Sem push, merge, GPL, internet, trailers de IA ou comandos destrutivos.
