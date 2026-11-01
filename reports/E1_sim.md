# E1-SIM — alimentos, água, expansão e persistência

Status: **PASS no escopo de simulação**. Integração de apresentação fica com o
responsável por UI/render; este patch não altera esses diretórios.

## Base e implementação

[FATO] Trabalho na branch `Yurtachi/evo2-e1-sim`, a partir de `evo2/e1-base`
(`14f915b`), identidade Git local Yurtachi. Lidos a especificação E1,
`docs/ARCHITECTURE.md`, `docs/mission/*`, `reports/G5_produto.md` e
`reports/evolucao.md`. Implementação própria em GDScript; nenhum código, texto,
peso ou asset do Pestinha foi utilizado, nem foram adicionadas dependências.

`SimWorld` continua `RefCounted`, com passo fixo de 0,1 segundo e um único RNG
semeado. Recompensa só altera a tabela Q; energia, hidratação e posição continuam
derivando das ações físicas e dos custos explícitos.

## Alimentos

A única tabela de parâmetros fica em
`scripts/environment/food_catalog.gd`. Valores fictícios, em unidades da
simulação, sem equivalência nutricional com alimentos reais:

| `food_type` | Nutrição | Hidratação | Palatabilidade | Toxicidade |
|---|---:|---:|---:|---:|
| `legacy` | 32 | 0 | 1,0 | 0 |
| `fruta` | 24 | 18 | 0,9 | 0 |
| `semente` | 40 | 2 | 0,7 | 0 |
| `folha` | 12 | 10 | 0,5 | 0 |
| `cogumelo` | 20 | 6 | 0,3 | 8 |

`place_food(pos, tipo="legacy")` mantém o uso anterior. Cada item possui
`food_type`; `energy` permanece no save para conservar exatamente o valor dos
itens legados, inclusive saves antigos com energia diferente de 32. Para itens
tipados, a validação exige a nutrição da tabela canônica.

A escolha básica minimiza `(distância + 1) / palatabilidade`, tanto na heurística
quanto na seleção observada pelo QBrain. A energia da ingestão é
`clamp(min(capacidade, energia + nutrição) - toxicidade, 0, capacidade)`;
a hidratação soma o parâmetro do alimento quando a fisiologia hídrica está ativa.
A ingestão exige alcance `tamanho + 5` e ausência de obstáculo entre corpo e item.
O item é consumido mesmo sem benefício; só ganho **líquido positivo de energia**
produz evento/memória `eat` e conta como refeição. Isso corrige a contagem de
refeições de ganho zero, inclusive no protocolo G2 que conta esses eventos.

`oferecer_alimento(creature_id, tipo="fruta")` retorna o ID colocado ou `-1`.
Procura deterministicamente até 16 posições livres próximas, além do alcance
imediato de ingestão, sem gastar RNG. Não muda fisiologia nem desloca a criatura;
ela precisa perceber, aproximar e ingerir. Não impõe aceitação a um cérebro
treinável ou a uma criatura saciada.

## Água e decisões

`waters` contém regiões circulares `{id, pos, radius}`. A API
`place_water(pos, radius=30.0)` retorna ID ou `-1`; valida raio de 1 a 500,
limites do mundo e teto de 256 regiões. São recursos renováveis sem colisão
sólida: é possível beber na margem e transitar pelo terreno de água.

As regras estão em `scripts/environment/water_rules.gd`:

- Hidratação inicial/capacidade: 100; `thirst = 1 - hydration / 100`, limitado a
  `[0,1]`.
- Perda por passo: `0,8 × metabolismo × 0,1`, mesmo em repouso.
- Bebida: até 35 unidades, sem alterar energia, limitada à capacidade.
- Alcance da bebida: distância à margem mais próxima de até `tamanho + 5`, com
  linha física desobstruída. O executor confere novamente a geometria.
- Hidratação zero cobra mais `2 × 0,1` unidades de energia por passo; não há
  hidratação espontânea, nem morte instantânea. A morte por energia esgotada
  continua registrada como `starvation`.
- Sede estritamente maior que 0,6 suspende ordens do jogador. A heurística busca
  água percebida, bebe ao alcance ou explora se não percebe água. Os custos de
  metabolismo e deslocamento permanecem ativos.

Os sensores consultam uma grade espacial de regiões, incluindo o raio na área
de busca. Retornam posição da margem, centro, raio e ID apenas quando passam
pelos mesmos filtros de visão e oclusão. Resultados não compartilham dicionários
mutáveis com o mundo. `drink` persiste ganho hídrico positivo e ID da região;
tentativa distante ou com reserva cheia não produz evento de bebida.

As ações históricas 0–12 conservam seus números. `DRINK=13` é aditiva;
`allowed_actions` impede selecionar sinais desligados quando a bebida está
disponível. A observação Q preserva os 2.352 estados anteriores e acrescenta
784 estados de sede alta, codificando água por alcance/direção/distância,
obstáculo e sinal. A tabela tem 3.136 × 14 células. A recompensa em cenários
hídricos é a variação real de energia mais `0,25 × variação real de hidratação`;
a penalidade terminal existente permanece. Nenhum reforço injeta recursos.

## Mundo novo e compatibilidade

`SimWorld.new_world(seed, config={})` é a entrada de produto: padrão de
12 organismos, água ativa e três regiões. Configuração explícita de população
continua prevalecendo. A distribuição e reposição iniciais alternam os quatro
tipos de alimento, sem sorteio adicional para escolher tipos.

`SimWorld.new(seed, config)` conserva os padrões históricos dos experimentos,
inclusive 16 organismos quando não especificados e `water_enabled=false`.
Experimentos existentes com população explícita e sem água mantêm o conjunto de
ações e observações anterior. É possível ativar água explicitamente no construtor.
Ao carregar, população, IDs e recursos vêm do save; nenhum fundador é acrescentado.

`expand(side, amount)` aceita `right`/`direita` e `bottom`/`inferior`, retorna
booleano e altera somente `size`. Rejeita montantes não numéricos, não finitos,
nulos, negativos, sem aumento representável ou que excedam 100.000 por eixo.
Não gera terreno/recursos, não consome RNG/IDs, não altera coordenadas,
genealogia, comandos ou eventos. Esquerda/superior são recusadas, pois exigiriam
deslocamento migrado explícito. Não existe encolhimento.

## Save v4

O schema mudou de fato: hidratação, tipo alimentar, regiões de água,
`config.water_enabled` e evento `drink`. Portanto `SAVE_VERSION=4`. O envelope
`SaveStore` permanece versão 1, com gravação temporária validada, checksum,
backup e limite de 32 MiB já existentes.

Migração sequencial v1 → v2 → v3 → v4: mantém todos os IDs, posições, RNG,
genealogia disponível, comida e fisiologia anterior. Comidas antigas recebem
`legacy`; criaturas recebem hidratação 100; mundos anteriores permanecem sem
fisiologia hídrica e sem regiões inventadas. A migração não altera o dicionário
de entrada e carregar novamente o resultado v4 é idempotente.

QBrain passa de versão 2 para 3 porque a tabela ganhou ações/estados e a
transição ganhou hidratação. A migração de cérebros v1/v2 conserva cada célula
aprendida e os índices históricos de ação/estado; as células novas começam em
zero. O teste v3 real verifica todas as células antigas.

A validação recusa NaN/inf, tipos errados, hidratação fora de `[0,100]`, regiões
malformadas/fora do mundo, IDs duplicados ou fora da sequência, tipos alimentares
desconhecidos e itens tipados com energia incompatível. Limites anteriores de
criaturas, alimentos, obstáculos, memória, eventos e genealogia continuam ativos.

## Evidências

Executável fornecido: Godot 4.7.2 console oficial. Comandos executados no root:

| Comando (prefixo: executável Godot informado) | Exit code | Resultado |
|---|---:|---|
| `--headless --path . -s tests/run_tests.gd` | 0 | 11 suítes verdes, incluindo `test_sim_e1.gd` |
| `--headless --path . -s tests/experiments/learn_eval.gd -- --dev` | 0 | Protocolo G2 executável; somente seeds TRAIN 1001–1003 |
| `--headless --path . -s tests/experiments/sense_bench.gd` | 0 | Snapshots indexado/exaustivo iguais em 30/100/300/1.000 organismos |
| `git diff --check` | 0 | Sem erros de whitespace |

O modo G2 de desenvolvimento terminou em aproximadamente 22,7 segundos. Médias
de sobrevivência: aleatório 1.577 passos, heurística 2.834, aprendiz treinado
2.715 e congelado 2.198. Não houve reavaliação do holdout, modificação de critérios
ou sobrescrita dos artefatos publicados; esta execução não estabelece um novo
gate de eficácia de aprendizado. A remoção de refeições de ganho zero afeta a
contagem, como exige E1.

`tests/fixtures/world_v3.json` foi gerado **antes das alterações** pelo build
da base `14f915b`, com seed 10811, três criaturas, dois obstáculos, 12 alimentos,
QBrain v2 no pet e 31 passos. SHA-256:
`02c4f9442439870d7431035c8fe409744e3599c3b7799e7c7a6a0ccf19d6f4a3`.

`test_sim_e1.gd` cobre: migração desse save real; duas expansões conservando
snapshot completo exceto tamanho; rejeição de expansão inválida; migrações v1/v2;
quatro efeitos alimentares distintos; legado; toxicidade na saciedade; refeição
zero; oferta sem efeito imediato seguida de aproximação/ingestão; palatabilidade;
sensor de margem com centro distante; visão/oclusão e cópia de sensores; bebida
fora/dentro de alcance; limite hídrico; suspensão de ordem pela sede; regra de
seca; QBrain hídrico, coexistência com oito sinais e transição persistida;
determinismo de dois mundos E1 por 900 passos; continuação de save; arquivo v4
e recuperação de backup corrompido; matriz de tipos e valores inválidos.

## Integração e limites

- UI deve chamar `new_world` apenas para criar um mundo novo; carregar continua
  via `from_dict`/`SaveStore`.
- Render deve desenhar `waters` de forma distinta da terra; não há mudanças de
  assets/render neste patch, conforme ownership.
- Ferramenta de oferta tipada deve chamar `oferecer_alimento`. O intent antigo
  em `communication/comandos.gd` ainda chama `place_food` legado; esse caminho
  está fora do ownership atribuído e foi informado ao coordenador.
- `textos.gd` recebe apenas a seção final `E1_CATALOGO`/`E1_RAZOES`; o dono de UI
  deve ligá-la aos formatadores `texto`, `acao`, `razao` e `evento` existentes.
- [LACUNA] Não há alegação de aprendizado eficaz de busca de água, adaptação
  ecológica ou equilíbrio de longo prazo. Há observações/ações/recompensa reais
  e testes físicos; eficácia exige experimento próprio posterior.
- [LACUNA] Não foi feita revisão independente nem validação visual neste worker.
  Determinismo é comprovado nesta versão/plataforma do Godot.
