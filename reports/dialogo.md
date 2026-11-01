# Relatório DIALOGO — parte do gate G4

Status: módulo concluído e testado; integração jogável de movimento e proteção pendente do coordenador/SIM. Este relatório não declara o gate G4 completo.

## Escopo e entrega

- Worktree: `C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo-dialogo`.
- Branch: `Yurtachi/evo-dialogo`; base: `fbe03ed136b7d18a427f2d8120a0fda71c3c4750`.
- Somente arquivos novos em `scripts/communication/`, `tests/unit/test_dialogo.gd` e este relatório; nenhum arquivo do simulador, catálogo central, UI ou persistência alterado.
- Foram lidos `docs/ARCHITECTURE.md`, ambos os documentos de `docs/mission/`, `reports/sim.md` e `reports/learn.md`.
- Identidade Git local preservada: Yurtachi. Sem push, operações destrutivas ou trailers de IA.

## API implementada

`Dialogo.interpretar(texto: String) -> Dictionary` é pura: recebe apenas texto e retorna `intent` e `comando`. Reconhece `chamar`, `oferecer_comida`, `perguntar_estado`, `seguir`, `parar`, `brincar`, `proteger`; entradas desconhecidas retornam `intent = "desconhecido"` e comando vazio. Aceita maiúsculas, espaços repetidos, pontuação, acentos compostos/decompostos e formas sem acentos. A gramática é delimitada: não busca palavras soltas em frases arbitrárias nem executa texto livre. `não me siga` e `pare de me seguir` significam parar; outras negações ou comandos combinados não previstos são desconhecidos.

`Dialogo.responder(intent, criatura: SimCreature, mundo: SimWorld) -> Dictionary` aceita o dicionário do interpretador ou o identificador da intenção. Retorna `texto`, `evidencias: Array` e `comando`, sem aplicar efeitos. Para uma criatura viva pertencente ao mundo, usa exclusivamente energia/máximo, fome derivada, idade em passos/segundos, última ação/razão registradas, alimento realmente percebido por `sense` e o último evento próprio de alimentação dentro dos 100 passos anteriores (dez segundos simulados). Razões históricas são rotuladas como registradas, sem confundi-las com o estado atual.

A frase “Estou com pouca energia” exige energia estritamente abaixo de 35% do máximo; 35% e 90% não a produzem. A percepção respeita alcance, campo de visão e oclusão. Eventos de outras criaturas, futuros ou antigos não são narrados; evidências de eventos são cópias independentes. A narração não inventa lembranças nem afirma consciência, emoção literal, consumo ainda não ocorrido ou proteção ativa. Intenções desconhecidas e criaturas ausentes/mortas recebem respostas seguras sem evidências inventadas.

Os novos textos para jogadores estão centralizados em `scripts/communication/dialogo_textos.gd`, conforme a exceção de ownership explícita deste despacho. Traduções existentes de ações/razões e números são reutilizadas de `scripts/core/textos.gd`; o rótulo local “Avançar” corrige apenas a apresentação do diálogo, pois o catálogo herdado contém `Avan?ar`. Nenhum identificador ou chave JSON foi traduzido. Este catálogo pode ser incorporado ao central pelo dono desse arquivo na integração.

`Comandos` é um adaptador transitório, uma instância por mundo:

```gdscript
const DialogoAPI = preload("res://scripts/communication/dialogo.gd")
const ComandosAPI = preload("res://scripts/communication/comandos.gd")
var comandos = ComandosAPI.new()

var pedido = DialogoAPI.interpretar("Siga-me!")
var resposta = DialogoAPI.responder(pedido, mundo.creatures[mundo.pet_id], mundo)
var recibo = comandos.aplicar(pedido, mundo, Vector2(300, 200))
# Exibir resposta.texto e recibo.texto; ambos distinguem pedido e aplicação.
```

- `aplicar(pedido, mundo, alvo = Vector2.INF)`: somente o companheiro vivo recebe comandos. Retorna `{aceito, aplicado, codigo, texto}` e `food_id` quando colocou alimento. Alvos ausentes, não finitos ou externos são rejeitados sem alterar o mundo.
- `oferecer_comida` chama `mundo.place_food` perto do companheiro, em até oito posições determinísticas, respeitando geometria/capacidade. É um efeito real, com `aplicado=true`; não aumenta energia diretamente. O teste confirma a ingestão subsequente pelo simulador real.
- `chamar` define um alvo até chegar; `seguir` mantém um alvo atualizável por `atualizar_alvo(mundo, alvo)`; `parar` substitui deslocamentos por descanso; `brincar` propõe um deslocamento curto de 40 unidades, sem alegar prazer ou afinidade. Esses comandos retornam `aceito=true, aplicado=false`: foram registrados para o hook, não executados pela física nesta branch.
- `acao_pendente(criatura, mundo)` retorna `{ativo, acao, razao}`; as ações usam os índices já existentes em `scripts/behavior/actions.gd`. Perto do alvo propõe descanso; longe, avanço/curva conforme direção. Chamar/brincar terminam ao chegar; seguir aguarda novas posições.
- `proteger` registra uma solicitação consultável por `protecao_solicitada(mundo)`, com `aplicado=false`. Não há proteção biológica aplicada nesta branch. `limpar()` cancela ordens/solicitações ao carregar ou criar outro mundo. A referência fraca evita ciclo se o mundo futuramente possuir o adaptador; comandos de um mundo não vazam para outro com IDs iguais.

## Patch mínimo de integração, reservado ao dono de SIM/UI

1. Criar uma instância de `Comandos` para cada mundo ativo. A UI interpreta a entrada, aplica o comando fornecendo uma posição explícita do jogador/cursor e mostra o recibo; ao seguir um alvo móvel, atualiza essa posição. Ao carregar/criar mundo, instanciar outro adaptador ou chamar `limpar()`. O texto livre nunca fornece código nem coordenadas sem validação da UI.
2. Em `SimWorld._update_creature`, antes de escolher cérebro/heurística, consultar `comandos.acao_pendente(creature, self)`. Se `ativo`, encaminhar `acao` à mesma física das ações discretas; se não, preservar a decisão existente. O menor refactor é extrair a parte de efeitos de `_act_with_brain` para um helper que recebe o índice da ação e os sensores; reaproveitá-lo nos dois caminhos. Preservar colisões, sensores, alimentação, metabolismo, arredondamento, ordem dos IDs e custo por passo. `parar` suspende deslocamento, não metabolismo.
3. Razões novas retornadas pelo adaptador: `dialogo.stop`, `dialogo.arrived`, `dialogo.chamar`, `dialogo.seguir`, `dialogo.brincar`. Acrescentar as traduções ao catálogo central no patch de integração; até lá, a apresentação usa o fallback em português. Registrar intervenções externas separadamente do aprendizado: não atribuir recompensas de ações do jogador à última ação autônoma pendente de Q-learning. O integrador deve encerrar/suspender essa transição ao assumir controle e verificar retomada do cérebro.
4. Para proteção real, o dono do simulador precisa definir e aplicar uma política explícita de cuidado antes de anunciar “proteção ativa”. `protecao_solicitada` é apenas a entrada dessa política. Intervenções contra morte/inanição devem ser registradas com contexto e consideradas na análise ecológica; não basta adicionar uma etiqueta. A política e sua persistência pertencem ao patch de integração, não foram simuladas neste módulo.
5. Nenhum formato de save foi alterado, por isso não há bump artificial de versão. As ordens deste adaptador são transitórias e não são restauradas no save atual. Se a integração persistir ordens/proteção, adicionar campos opcionais validados com coordenadas codificadas como arrays numéricos, elevar `save_version` a partir da versão corrente de SIM e migrar a anterior para ordens vazias/proteção desligada; incluir testes de migração, round-trip e retomada. Não gravar `Vector2`, referência de objeto ou script em JSON.

## Validação

Executável: Godot 4.7.2 console informado no despacho.

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/run_tests.gd
```

Primeira execução: **exit 0**, sete arquivos de teste `ok`: `test_behavior_learn`, `test_dialogo`, `test_save_store`, `test_sim_review`, `test_sim_world`, `test_smoke`, `test_textos`; sem erros de script. Execução final após acrescentar a comprovação de consumo do alimento: **exit 0**, os mesmos sete arquivos `ok`, sem erros de script. `git diff --cached --check`: **exit 0** antes do commit.

A suíte nova cobre todas as intenções, variações/acentos/NFD, limites da gramática, desconhecido, energia baixa versus alta e limiar, fome/idade/ação, ausência de mutação do snapshot, alimento fora do campo visual/oculto, eventos próprios/alheios/antigos, evidências independentes, ausência/morte/criatura de outro mundo, alimento real/capacidade/ingestão, validação de alvos, seguir/atualizar/parar, chegada, brincar, proteção pendente e isolamento de comandos por mundo.

Limites: não foi feita integração visual nesta branch; deslocamentos e proteção requerem os ganchos acima. Não se afirma aprendizado de linguagem, emoção, memória longa, eficácia de proteção, persistência de ordens ou conclusão do gate G4.
