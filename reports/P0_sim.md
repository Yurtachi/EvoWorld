# P0-SIM — pet único, alimentação física e save v15

Base: `evo4/pet`, commit `efb7810`; branch de trabalho `Yurtachi/evo4-p0-sim`.
Implementação e medições locais em 02/11/2026, Godot 4.7.2 console, Windows.

## [FATO] Mundo padrão e compatibilidade

- `World.new_pet_world(seed, nome)` cria exatamente um organismo, adotado como `pet_id`, com nome aparado/limitado a 64 caracteres e mente avançada ativa somente nele. O nome também aparece no evento inicial e na genealogia.
- Reprodução desligada por padrão. `set_reproduction(true)` é uma decisão explícita; `spawn_creature(pos, nome)` continua disponível para introduções posteriores. Nenhuma reposição de organismos ou ressurreição foi adicionada.
- `World.new_world(seed)` também usa o padrão de um pet. Seus parâmetros finais são: 24 alimentos iniciais, capacidade global 48, reposição de um alimento a cada 40 ticks, nove regiões físicas de água, oito obstáculos e dimensão histórica 1200 × 760. Comida e água continuam sujeitas à geometria, à percepção e à ingestão físicas.
- `World.new_ecosystem_world(seed, config)` é o preset avançado explícito: 12 organismos, reprodução ligada, três regiões de água e alimentação/regeneração históricas. Aceita configurações explícitas.
- Por autorização do coordenador, `World.new(seed, config)` e `new_world` com `creature_count` explícito mantêm as regras históricas dos experimentos. A UI de adoção deve chamar **`new_pet_world`**, sem passar a população antiga.
- Carregar saves v1–v14 preserva população, reprodução, genealogia, recursos, RNG, IDs, mente e demais regras existentes. A migração não adota novos defaults nem apaga criaturas.

## [FATO] Contrato para a UI

```gdscript
var world = World.new_pet_world(7421, "Pipoca")
world.set_feeding_mode("feeder")
var feeder_id = world.place_feeder(Vector2(200, 200), {
    "tipo_alimento": "fruta", "estoque": 20, "intervalo_ticks": 100,
    "capacidade_local": 5, "raio": 40.0, "enabled": true
})
world.feeder_refill(feeder_id, 10)
world.feeder_set_enabled(feeder_id, false)
world.set_reproduction(false)
var pet = world.pet_snapshot()
```

- `feeding_mode`: `manual`, `feeder` ou `ecosystem`; `set_feeding_mode` retorna `false` para um valor desconhecido. Modos são exclusivos para reposição automática: manual desliga ambas, feeder executa somente os alimentadores, ecosystem usa somente `food_regrow`. Colocação manual de comida permanece disponível em todos.
- O padrão do pet é `ecosystem`, sem alimentador implícito. `manual` desliga `food_regrow`; passar `food_regrow=false` à entrada configurável também é respeitado.
- `world.feeders` contém registros físicos: `id`, `pos` (Vector2 em runtime), `tipo_alimento`, `estoque`, `intervalo_ticks`, `capacidade_local`, `raio`, `enabled`, `last_tick`.
- Defaults de colocação: fruta, estoque zero, intervalo 100, capacidade local 5, raio 40, ligado. Colocar um alimentador não troca automaticamente o modo alimentar.
- Um alimentador tenta colocar **um item** na própria posição por intervalo, começando após um intervalo completo. Conta todos os tipos de comida no raio, inclusive itens de outros alimentadores, e respeita também a capacidade global. Não consome estoque se a colocação falhar ou a capacidade estiver cheia.
- Tentativa bloqueada reinicia o intervalo. Desativar preserva estoque/relógio; reativar permite a próxima tentativa quando o intervalo já tiver decorrido. Não há reposição retroativa em rajada.
- `place_feeder` retorna ID ou `-1`; `feeder_refill` e `feeder_set_enabled` retornam sucesso booleano. Reabastecimento não trunca silenciosamente estoque excedente: rejeita a operação inteira.
- `pet_snapshot()` retorna `{id, name, pos, energy, max_energy, hydration, age, alive, mind, feeding_mode, reproduction_enabled}`; `pos` é array numérico, `mind` é o snapshot cognitivo existente. Retorna `{}` se o pet morreu. Mutar o snapshot não muda o organismo.
- Nenhum texto de jogador foi introduzido fora do catálogo `scripts/core/textos.gd`; não houve alteração em `scripts/ui` ou `scripts/render`.

## [FATO] Alimentação e limites do save

O alimentador tem acesso somente à colocação física de comida; não escreve energia, hidratação, posição nem estado mental. Não aparece nos sensores ou na memória da criatura. A comida produzida passa pela mesma visão, alcance, campo visual e oclusão dos demais alimentos; para ganhar energia, a criatura precisa chegar ao alcance e executar a ingestão existente. Obstáculos impedem percepção/ingestão através deles.

Save do mundo v15; o envelope de disco e seus limites anteriores permanecem. `feeders` e `config.feeding_mode` são opcionais; sua ausência preserva a representação/regras históricas. A migração v14→v15 é idempotente e não modifica o dicionário de entrada; versões anteriores percorrem a cadeia existente.

Limites novos: 64 alimentadores, estoque de 0 a 1.000.000, intervalo de 1 a 10.000.000 ticks, capacidade local de 1 a 10.000 itens e raio de 5 a 512 unidades. Posição deve ser finita, dentro do mundo com margem de cinco unidades e livre de obstáculos. `last_tick` deve estar entre zero e o tick atual. Configurações/records têm campos tipados e delimitados; NaN, infinito, booleanos em números, tipos/posições inválidos, chaves extras e IDs futuros são rejeitados.

O registro dos alimentadores ocorre depois do registro de criaturas vivas, genomas, ancestrais mortos, alimentos, águas, objetos, livros, quadros, desenhos/galeria e terminais. Todos usam o mesmo `used_ids`, incluindo as réplicas canônicas de artefatos existentes; colisões entre categorias são rejeitadas. Dados de alimentadores/modo alimentar rotulados v1–v14 são rejeitados como schema futuro, sem descarte silencioso.

## [FATO] Verificação e CPU

`tests/unit/test_sim_p0.gd` cobre:

1. Quatro seeds por 5.000 ticks com exatamente um organismo vivo em todo o intervalo, genealogia de um fundador e nenhum nascimento; adoção/nome/mente, snapshot, introdução posterior e API de reprodução.
2. Outros 5.000 ticks na seed 7421 em modo manual, com comida ofertada fisicamente fora do alcance inicial e fontes físicas de água, sem reescrever energia/hidratação do corpo.
3. Estoque finito, intervalos, capacidades local/global, reabastecimento, ativação/desativação, tipos de alimentos e modos de reposição.
4. Ausência de ganho direto de energia, ausência de percepção remota, ingestão por aproximação/alcance e bloqueio por obstáculo. Comparação corporal pareada com/sem alimentador remoto e com/sem reposição ecológica.
5. Save/load em disco com alimentador, roundtrip JSON e continuação determinista, inclusive após reabastecer; criação com mesma seed.
6. Migrações v1–v14, idempotência, entrada preservada, tipos/limites hostis e 12 identidades de diferentes categorias em uma fixture com criatura morta e artefato real.
7. Dois hashes capturados executando o motor original de `efb7810` em um `git archive` separado: seis fundadores, personalidade, água, reprodução e 600 ticks, com e sem mente em todos. Só `save_version` é normalizado para 14; nenhum campo biológico é removido.

| Cenário antigo | SHA-256 original e atual |
|---|---|
| Sem mente | `bbd1465f14a4555a8751df83b1568188faeb1f9633c1b87de461df06a415228f` |
| Com mente em todos | `75c8cc5c0109cc5668401e8e8b4255dc53751c56d4d9f86068cdedc60d271073` |

Os goldens existentes de `test_perf_determinism.gd` permanecem intactos. Com autorização explícita do coordenador, somente os cenários históricos que exigiam população/reprodução antigas foram trocados para `new_ecosystem_world`: `test_sim_e1._new_world_and_round_trip`, `test_sim_e2._profiles`, `test_save_robustez._new_world_generations`. O assert da versão corrente no teste M5 passa a consultar `World.SAVE_VERSION`; a migração v13 continua terminando em v14 antes da etapa nova.

Medição isolada do preset final, 5.000 ticks por seed, mente ativa: 160001 = 0,3678 ms/tick; 160002 = 0,4879; 160003 = 0,3793; 7421 = 0,3975. Resultado: 4/4 sobreviventes, zero nascimentos, nenhum organismo extra. São custos de simulação headless, sem renderização.

Validação final: `godot --headless --path . -s tests/run_tests.gd` terminou com exit 0, **26/26 suítes aprovadas**, sem diagnósticos `SCRIPT ERROR:`/`ERROR:`. Log em `reports/P0_sim_tests.txt`; a base tinha 25 suítes e P0 acrescenta uma. No passe completo, os custos do pet ficaram em 0,4313 / 0,5353 / 0,4471 / 0,4443 ms/tick nas seeds 160001 / 160002 / 160003 / 7421, respectivamente.

## [FATO] Ajuste explícito do preset novo

As sondagens abaixo usaram as mesmas quatro seeds (160001, 160002, 160003, 7421), 5.000 ticks, sem cuidado. Não são holdouts científicos; nenhum avaliador fechado `*_eval` foi executado ou JSON histórico reescrito.

| Alimentos iniciais / teto / intervalo | Águas | Sobreviventes |
|---|---:|---:|
| 12 / 24 / 100 | 3 | 1/4 |
| 24 / 48 / 40 | 3 | 0/4 |
| 40 / 64 / 20 | 3 | 2/4 |
| 48 / 72 / 20 | 3 | 2/4 |
| 56 / 80 / 20 | 3 | 0/4 |
| 32, 64, 72 ou 80 / 80 / 20 | 3 | 2/4 em cada cenário |
| 24 / 48 / 40 | 6 | 3/4 |
| **24 / 48 / 40 (final)** | **9** | **4/4** |

O trace do cenário 48/72/20 identificou hidratação zero e objetivo `beber` antes das mortes nas seeds 160001 e 160003, apesar de 72 alimentos presentes. O coordenador autorizou aumentar a sustentabilidade sem energia direta/ressurreição; a solução final manteve a comida esparsa e aumentou somente o número de fontes físicas de água no preset pet.

## [HIPOTESE] / [LACUNA]

- [HIPOTESE] Mais fontes físicas tornam a exploração hidratante mais acessível; as sondagens apoiam a decisão de produto nestas quatro seeds. Alterar geração inicial também altera o consumo de RNG e os genomas sorteados, portanto esses resultados não isolam causalmente o número de fontes nem demonstram sobrevivência geral.
- [LACUNA] Quatro seeds e 5.000 ticks não garantem vida permanente. Fome, desidratação e idade continuam podendo causar morte; mundos manuais exigem cuidado. Não foi introduzida imortalidade.
- [LACUNA] CPU é medição local, sem FPS/UI e sem garantia para o pior caso de 64 alimentadores com 10.000 alimentos. Integração visual dos controles/objetos pertence ao worker de UI/render.
