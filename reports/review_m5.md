# Revisão dinâmica independente do M5 (X8, save v14)

Revisor: execução própria sobre `4a0a42f` (branch `evo3/integration`). Commits avaliados: `ffe9e14` (pré-registro), `b7e4a23` (motor + avaliador), `bc8c41a` (holdout), `68d7bf9` (relatório), `4a0a42f` (reclassificação).

**Veredito de gravidade: NÃO há achados críticos nem altos.** Há 3 médios e 6 baixos. Nenhum SCRIPT ERROR foi provocado por saves hostis, e o release exportado roda limpo.

## Resumo dos itens pedidos

| # | Item | Resultado |
|---|---|---|
| 1 | Suíte e pré-registro | 25/25 `ok`, `EXIT 0`, 0 SCRIPT ERROR. `verify_prereg.sh` termina com `M5 PASS ... scientific_verdict=PASS`. |
| 2 | Ordem e seeds | Ordem correta e seeds disjuntas (detalhes abaixo). |
| 3 | Fuzz de saves | 7085 + 176 casos, 0 SCRIPT ERROR, 0 aceitações indevidas relevantes (um achado baixo). |
| 4 | Não-herança | Provada. Nenhum caminho de cópia ou referência compartilhada. |
| 5 | Reprodução voluntária | Condições mentais exigidas só quando há mente. Mundos sem mente são idênticos aos anteriores; mundos com mente NÃO são (achado M1). |
| 6 | Braços do X8 | Os 5 braços rodaram. Só 3 foram avaliados. Controles 0,000 são por construção (achado M2). |
| 7 | Energia/hidratação/posição | Nenhuma alteração direta fora das regras físicas. |
| 8 | Release | Exportado em pasta temporária. `--quit-after 300`: exit 0, 0 ERROR. |
| 9 | Texto ao jogador | Em pt-BR (regra do projeto), sem inglês. As strings M5 não são usadas por nenhuma tela (achado L2). |

## 1. Suíte e pré-registro

```
$ godot --headless --path . -s tests/run_tests.gd   -> 25 linhas ": ok", EXIT 0, grep SCRIPT ERROR = 0
$ bash tests/experiments/verify_prereg.sh
M5 PASS prereg_commit=ffe9e14 prereg_blob=68302d26... blob_sha256=d355c19c... evaluator_commit=b7e4a23f... result_commit=bc8c41a2...
M5 PASS historical prereg=ffe9e14 freeze=b7e4a23 result=bc8c41a seeds=24 rows_f7=120 rows_repro=24 scientific_verdict=PASS
```

## 2. Ordem pré-registro -> motor -> holdout

- `git log --format='%h %ad'`: `ffe9e14` 08:19:30, `b7e4a23` 09:04:55, `bc8c41a` 09:06:18. A ordem está correta.
- O blob do pré-registro é idêntico em `ffe9e14`, no avaliador, no resultado e em HEAD. Os hashes batem com o `preregister_sha256` do JSON. Não houve edição posterior.
- O pré-registro prometia "avaliador e motor em etapa separada". Eles foram no mesmo commit `b7e4a23`, junto com 353 linhas de teste unitário. Isso é compatível com o texto, mas impede provar que não houve iteração sobre o holdout. A `builds/m5_dev.json` e a `builds/m5_train.json` são ignoradas pelo git, então não há registro auditável do treino e do desenvolvimento.
- Seeds do holdout: 151401–151424. As demais séries são 91501–91520 (E4), 106xxx/107301–107324 (M1/M2), 118401–118424 (M3), 129401–129424 (M3b), 140401–140424 (M3c), 154xxx (M4b) e 93xxx. Não há interseção. O `grep -rn 1514[0-2][0-9]` só acha o próprio X8 (e um `error: 0.151414` coincidente no JSON do M3b, que não é seed).
- Há um único commit de resultado, e o avaliador recusa arquivo de saída existente e árvore suja.

## 3. Fuzz de saves hostis

Scripts em `C:\Users\Yurtachi\AppData\Local\Temp\rev\` (fora do repo). Os saves reais não foram tocados.

Comando: `godot --headless --path . -s .../fuzz.gd` (mundo voluntário com nascimento biparental, 622 folhas).

```
CASES 7085 ACCEPTED 181    (sem SCRIPT ERROR / Parse Error)
bomb7MiB:    "Compressed checkpoint exceeds the 64:1 expansion limit."
bomb_lie:    "Invalid compressed checkpoint header."   (uncompressed_bytes=999999999)
bomb_under:  "Invalid compressed checkpoint size or header."   (uncompressed_bytes=1000)
store save: true load: true
```

Das 181 aceitações, 177 são no-ops legítimos. Exemplos: sobrescrever `death_tick` por -1 num vivo, `legacy_root=true` num fundador, `name="x"`, `tick=5` igual ao original, listas vazias e `save_version` 14.0. Ficou 1 caso de nível baixo (L5). Cobertura testada:

- Genealogia biparental: pais iguais, inexistente, o próprio filho, ciclo, 3 pais, string/NaN/inf/float/dict/null/negativo/zero, ordem trocada, lista vazia e parceiro morto antes do nascimento. Todos rejeitados. Gerações erradas (0, 2, 3, -1, 1e9, NaN) também.
- `fuzz2.gd`: mundo com objeto, terminal e quadro. 176 colisões de ID entre todos os registros (criaturas, genomas, comida, água, objetos, terminais, quadros) deram 0 aceitações.
- `reproduction_rules`: 10 variantes hostis rejeitadas (tipo, NaN, inf, string, fora de [0,1], chave extra).
- `next_id` baixo, `save_version` 0..16 e tipos errados: rejeitados.
- Limitação: as versões v1..v12 foram testadas por rotular o dict v14 com outra versão, não com saves reais antigos. Os testes de migração existentes da suíte cobrem os reais e passaram.

## 4. Não-herança (prova)

`probe.gd` povoa o genitor com vínculos, preferências, conhecimento, terminal e desenhos. Faz `reproduce` nas 4 combinações (voluntário e legado, com e sem `mind_offspring`). Depois percorre o grafo de objetos (`get_property_list`, `get_instance_id`, `is_same`) de genitor e filhote:

```
cfg vol=true  mind_off=true  child=6  ep=0 bonds=0 pref=0 cond=0 exp=0 know=0 term=true log=0 objs=0
  alias(creature): shared refs=0 ; child unchanged after parent mutation: true
(idem nas outras 3 configurações: shared refs=0)
```

Os filhotes nascem de `Mind.new`, `Personality.new` e `Atelier` novos em `_spawn` (`scripts/world/sim_world.gd:220-243`). O genoma passa por `from_dict(to_dict())`, que copia. Os `.clear()` das linhas 455-472 são redundantes, mas inofensivos: o teste mostrou 0 referências compartilhadas, então não limpam dados do genitor. A não-herança vale **por construção**, e o H-f do holdout (24/24) é verdadeiro mas não discriminante. Os 3 vínculos de um filhote após 3 ticks são encontros novos legítimos (IDs "2" e "4").

## 5. Reprodução voluntária

Teste com `probe2.gd`, `can_reproduce` em casal vinculado:

```
mind=true  affect=true  frus=0.9 -> false self_affect_frustrated
mind=true  affect=false frus=0.9 -> true  consent_granted
mind=false affect=false          -> true  consent_granted
voluntária sem personalidade     -> reproduce = -1  (familiaridade exigida)
corrida natural 3000 ticks (12 criaturas, mind_all, voluntária): 14 nascimentos, 14 registros biparentais
```

Ou seja, vínculo, familiaridade, valência, fisiologia e compatibilidade são sempre exigidos. As condições afetivas (frustração, receio, saturação) só valem quando a criatura tem mente com afeto ligado (`sim_world.gd:377`, `:388`) -> achado M3.

Determinismo de mundos antigos, hash SHA-256 do `to_dict` (sem `save_version`) após 1500 ticks, em `f741a83` (pré-M5, extraído com `git archive` para pasta temporária) contra HEAD. `golden.gd`, 3 configurações x 2 seeds:

```
sem mente (14 criat., 60 comidas)            11 e 22: IDÊNTICO
personalidade + água, sem mente              11 e 22: IDÊNTICO
mind_all + personalidade + água (10 criat.)  11: aa43e3f5... -> a2d1ba26...   22: 9ce745e9... -> f5c0d5bb...  DIFERENTE
```

## 6. Braços do X8

- O avaliador (`m5_convivencia_eval.gd:13`) roda os 5 braços e `reports/M5_convivencia_eval.json` tem 120 linhas F7 (24 x 5). A ressalva do coordenador em `EVOWORLD_3_EXPERIMENTS.md` ("faltam aleatório e sem afeto") está imprecisa: eles rodaram, mas o avaliador **não avalia nem reporta** esses dois (`:333-343`) e o relatório não os cita.
- Resultados por braço (contraste médio B-C, 24 seeds), lidos do JSON:

| Braço | média | mín–máx | valores distintos |
|---|---|---|---|
| completo | 76,99 | 72,0–119,7 | 4 |
| sem_afeto | 76,99 | 72,0–119,7 | 4 (idêntico ao completo) |
| aleatorio | 108,25 | 63,3–119,9 | 23 |
| sem_memoria | 0,000 | 0–0 | 1 |
| parametros_fixos | 0,000 | 0–0 | 1 |

- Controles 0,000 por construção: `sem_memoria` e `parametros_fixos` fazem `bonds.clear()` (`m5_convivencia_eval.gd:96,108`). B e C só diferem no histórico, e o desenho contrabalançado norte/sul cancela qualquer viés de posição (+72/-72 -> 0).
- A decisão é regra direta sobre o vínculo: `Social.decide` mais o score `(1+val*0.5+fam*0.5)/dist` em `sim_world.gd:2161+`. O objetivo `buscar_companhia` é imposto pelo avaliador (`set_goal`), não escolhido pela mente.
- `policy_mode="random"` não é uma política aleatória. O `CreatureMind` só distingue `"full"` e `"fixed"`, e `!= "full"` desliga o viés de memória. O braço "aleatório" aproxima-se de B **mais** que o completo.

## Achados

### M1 (média) Mundos com mente deixam de ser reproduzíveis em relação ao pré-M5
- Local: `scripts/world/sim_world.gd:2161-2200` (`buscar_companhia`/`buscar_privacidade` agora usam `Social.decide` e pontuam por vínculo; antes escolhiam o vizinho mais próximo).
- Prova: hashes `golden.gd` da seção 5 (mind_all). O relatório M5 §2.1 item 7 afirma "estrita equivalência numérica" e isso é falso para mundos com mente. A suíte passa porque não tem golden de mundo com mente. Mundos sem mente são idênticos.
- Impacto: saves e experimentos M1–M4 com mente reexecutados em HEAD divergem. Os JSONs históricos continuam auditáveis, mas não reproduzíveis com o motor atual.
- Sugestão: guardar o comportamento novo atrás de flag (ex.: `reproduction_voluntary`/`social_bond_goals`), ou documentar a quebra e adicionar um golden com mente.

### M2 (média) O PASS do X8 é mais fraco do que o relatório afirma
- Local: `tests/experiments/m5_convivencia_eval.gd:333-343`; `reports/M5_convivencia.md` §3 e §5 [FATO] 2–3.
- Prova: tabela da seção 6. `sem_afeto` é idêntico ao completo (afeto sem efeito causal sobre esta tarefa). `aleatorio` supera o completo. Só ~4 valores distintos entre 24 seeds (o resultado é determinístico, então as seeds quase não amostram). Os braços 0,000 resultam de `bonds.clear()`.
- O texto "descartando predisposição basal" (§5 item 3) não se sustenta: `parametros_fixos` também zera os vínculos, então testa apenas "sem vínculo = sem preferência".
- O H-d desfavorável foi testado só com valência negativa (`:219`), não com "parceiro estranho" nem "afeto desfavorável", como o pré-registro dizia.
- O veredicto "PASS restrito" de `4a0a42f` é razoável, mas o `M5_convivencia.md` ainda diz "PASS" sem ressalvas (L1).

### M3 (média) Condições mentais da reprodução são opcionais na prática
- Local: `sim_world.gd:377` e `:388` (`mind != null and affect_enabled`).
- Prova: `mind=true affect=false frus=0.9 -> true consent_granted` e `mind=false -> true`. Os descendentes têm `mind == null` por padrão (`mind_offspring=false`), então só os fundadores com mente respeitam frustração, receio e saturação. O pré-registro e o relatório descrevem isso como condição geral. A ablação "sem afeto" da reprodução também não foi testada.
- Sugestão: documentar, ou tratar ausência de mente como estado neutro explícito no relatório.

### Baixos
- **L1** `reports/M5_convivencia.md:34` diz `mutation_scale = 0.05` mas o motor usa 0.025 (`sim_world.gd:92`). Todo o relatório continua com "PASS" e "100% de conformidade" depois da reclassificação.
- **L2** Strings `M5_UI` (`scripts/core/textos.gd:5-21`) estão em pt-BR (de acordo com a regra do projeto). Nenhuma é usada fora do catálogo (`grep m5_ scripts` só acha `textos.gd`), então o jogador não vê nada de M5. As chaves citadas no relatório (`ui.m5.reproduction.voluntary`, `...refused_hunger`) não existem. Há marcação de gênero ("disposta", "indisposta"). Não encontrei texto em inglês novo visível ao jogador. O pedido de revisar "texto em inglês" conflita com a regra pt-BR da memória do projeto; seguiu-se a regra do projeto.
- **L3** H-e do avaliador (`:204`) usa `|delta| <= 0.35`, contra o limite real de 3σ = 0.075 e o texto do pré-registro (r > 0.85 ou desvio gaussiano). O temperamento vem só do genitor 1, não há recombinação, apesar da "genealogia biparental" e do "genoma recombinado" do relatório.
- **L4** Os `.uid` de `m5_convivencia_cpu.gd`, `m5_convivencia_eval.gd` e `test_sim_m5.gd` não foram versionados (o commit `f741a83` passou a rastreá-los). Eles reaparecem como untracked a cada execução. Removi os gerados pelas minhas execuções.
- **L5** Um save rotulado v8..v13 sem `reproduction_rules`, mas com genealogia de 2 pais, é aceito (`ACC version=13 norules`). Um v13 verdadeiro nunca teria 2 pais. Inofensivo, mas é uma validação ausente.
- **L6** `Social.decide` e a escolha de parceiro para reproduzir só se aproximam por proximidade física. Uma criatura voluntária sem `buscar_companhia` raramente forma o par (14 nascimentos em 3000 ticks e 12 criaturas). Não é falha, só um custo de interpretação.

## 7. Energia, hidratação e posição

`grep` por `.energy|.hydration|.pos` em `scripts/` não encontra atribuição nos módulos de afeto, conhecimento ou social. As atribuições estão em comida, água, movimento, custo de sinal, terminal e atelier, que já existiam. O único novo é `parent.energy -= transferred` na reprodução (`sim_world.gd:429,451`, a energia vai para o filhote: transferência física conservada) e o cooldown do parceiro. Os `.clear()` do filhote não tocam em fisiologia.

## 8. Release

```
$ godot --headless --path . --export-release "Windows Desktop" <TEMP>/rev/exp/EvoWorld.exe   -> 109,9 MB, DONE
$ <TEMP>/rev/exp/EvoWorld.exe --headless --quit-after 300   -> EXIT 0, "SCRIPT ERROR|ERROR" = 0
```

## Estado do repositório

Só `reports/review_m5.md` foi commitado. O avaliador de holdout, os `m5_*eval` e os experimentos não foram executados. Nenhum `reports/*.json` foi regravado (`git status` limpo exceto pelos `.uid` gerados pelo Godot, removidos).
