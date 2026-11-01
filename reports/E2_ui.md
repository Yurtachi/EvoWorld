# E2-UI — personalidade observável no jardim

Status: **PASS no escopo UI/render**. Data: 01/11/2026.

## Implementação e limites de autoria

[FATO] Trabalho no branch `Yurtachi/evo2-e2-ui`, com identidade Git local
Yurtachi, commits seletivos e sem push. Foram lidos `docs/EVOWORLD_2_SPEC.md`,
`reports/E1_sim.md`, `reports/E2_sim.md` e `reports/E1_ui.md`. Nenhum arquivo
de simulação foi editado. Implementação própria em GDScript; nenhum código,
texto, peso ou recurso do Pestinha foi copiado.

[FATO] `Textos.texto`, `acao` e `razao` consomem `E2_CATALOGO` e `E2_RAZOES`.
Os textos novos estão no mesmo catálogo, em pt-BR. Nomes personalizados,
identificadores e chaves JSON permanecem estáveis.

[FATO] O Cuidador apresenta cinco abas, simultaneamente acessíveis na janela
mínima de 1100×680:

| Aba | Origem e apresentação |
|---|---|
| Corpo | Barras para fome, sede, fadiga, necessidade de estímulo e contato; percentual e aviso de que barras maiores significam mais necessidade atual. |
| Traços | Curiosidade, cautela, sociabilidade e impulsividade do genoma; explica traço herdado, estado atual e aprendido. |
| Memória | Até oito episódios mais recentes existentes, em ordem inversa, com passo, ação traduzida, consequência e deltas físicos medidos. Não cria episódios de apresentação. |
| Comida | As cinco categorias do catálogo, valor aprendido de −1 a +1 ou “sem experiência”; explica que percepção/oferta não ensinam preferência. |
| Vínculos | Cuidador e criaturas conhecidas, nome/ID quando disponível, familiaridade, encontros e último contato; inclui ausência de vínculos e parceiros fora do jardim. |

[FATO] O componente `scripts/ui/personality_inspector.gd` é somente leitura.
Saves legados mostram personalidade desativada; não recebem temperamento ou
memória inventados. Sem seleção, os dados da criatura anterior são apagados.
A lista selecionável do Cuidador atualiza a necessidade mais urgente; quando
todas são menores que 10%, informa “necessidades baixas”.

[FATO] O render chama `creature.expression_state()`. Valência altera brilho,
proporção da postura e arco discreto sobre o corpo; ativação controla amplitude
e frequência do balanço. O tempo do balanço é o passo do mundo, portanto a
pausa congela a expressão. Legado mantém geometria/cor neutras, sem ícone E2.
A aba Corpo exibe os escores e a legenda em português, usando “Aparenta”.

[FATO] Carinho é uma ferramenta do Cuidador: selecionar uma criatura, ativar
Carinho e clicar no corpo. `_give_attention` chama `world.interagir_jogador`
para validar alcance, oclusão e intervalo. Os recibos distinguem sucesso,
distância, espera restante, seleção ausente, mundo legado e recusa física.
O intervalo é de 30 passos, equivalentes a 3 segundos de simulação; pausado,
não avança. Sucesso registra vínculo/episódio, sem alterar energia, água ou
posição diretamente.

[FATO] O catálogo de nomes brasileiros só é aplicado em `create_world`, depois
de `World.new_world`, antes da primeira apresentação/gravação. A configuração
também recebe `initial_names`; como a base SIM atual não lê essa opção, a UI
aplica a lista na fronteira de criação e sincroniza nomes dos registros
genealógicos e eventos iniciais existentes. Os 12 nomes são Mel, Bento, Tica,
Juca, Lola, Zeca, Nina, Dora, Caju, Bia, Chico e Lia. O nome escolhido pelo
jogador para o companheiro prevalece. Populações maiores repetem o catálogo
com sufixo numérico; carregar nunca passa por esse caminho.

## Validação

[FATO] Executável: Godot 4.7.2 console oficial fornecido na tarefa. Comandos
executados na raiz:

| Comando | Saída | Evidência |
|---|---|---|
| `godot --headless --path . -s tests/run_tests.gd` | exit 0; 12 arquivos de teste passaram | [E2_ui_regression.txt](E2_ui_regression.txt) |
| `godot --headless --path . -s scripts/ui/verify_ui.gd` | exit 0, “Integração da UI: ok”, sem erros de script | [E2_ui_tests.txt](E2_ui_tests.txt) |
| `godot --path . -- --fps-benchmark=12` | exit 0; janela gráfica real, população final 12 | [E2-fps-12.json](E2-fps-12.json), [captura](E2-fps-12.png) |
| `git diff --check` | exit 0 | sem erros de whitespace |

[FATO] O verificador percorre os controles reais da cena: cinco abas, leitura
das barras, necessidade urgente na lista, nome escolhido, fundadores naturais,
contato distante sem efeito, contato aceito sem recursos físicos, repetição
recusada com recibo de espera, episódio/vínculo reais, preferência após ingestão,
save v5 completo, limpeza da seleção e largura das abas em 1100×680. Mantém os
fluxos anteriores de diálogo, genealogia, expansão, alimentação, água,
configurações e persistência. O carregamento UI da fixture v3 conserva o
snapshot e os nomes completos, apresenta E2 desativado e recusa carinho com
explicação. A suíte completa cobre a cadeia v1/v2/v3/v4 e persistência v5.

[FATO] Benchmark E2: seed 7421, Windows, OpenGL Compatibility, RTX 2050,
1280×720, velocidade 1×, 2 segundos de aquecimento e 8,009 segundos de coleta.
Foram 863 quadros, **107,75 quadros/s** de média e **11,926 ms** no p95 da
duração de quadro. População inicial/final: 12/12; passo final: 102.

[HIPÓTESE] Esse resultado sugere margem para o jardim padrão nesta máquina.
Uma execução não estabelece desempenho em outros dispositivos ou populações,
nem benefício de aprendizado ou adaptação.

## Capturas novas e inspeção visual

[FATO] Todas foram geradas pela cena real deste build e abertas para inspeção.
Jardim/benchmark usam 1280×720; as demais usam a janela mínima 1100×680.

| Arquivo | O que foi inspecionado |
|---|---|
| [E2-jardim.png](E2-jardim.png) | 12 criaturas, nomes naturais, água, estado inicial e lista fechada. |
| [E2-lista.png](E2-lista.png) | 12 entradas selecionáveis, nome + necessidade mais urgente, lista cabe no limite inferior. |
| [E2-necessidades.png](E2-necessidades.png) | Cinco barras reais, percentuais, ativação/valência e ícone sobre a seleção. |
| [E2-tracos.png](E2-tracos.png) | Quatro traços e explicações de herança/estado/aprendizado. |
| [E2-memoria.png](E2-memoria.png) | Contato e ingestão reais, ação/consequência em português e deltas medidos. |
| [E2-preferencias.png](E2-preferencias.png) | Fruta aprendida e demais categorias explicitamente sem experiência. |
| [E2-vinculos.png](E2-vinculos.png) | Cuidador conhecido, familiaridade de 4%, um encontro e passo do contato. |
| [E2-expressao.png](E2-expressao.png) | Legenda completa acessível por rolagem; “Aparenta tensão corporal”. |
| [E2-carinho.png](E2-carinho.png) | Recibos de sucesso e tentativa repetida recusada, sem promessa de recurso físico. |
| [E2-ajuda.png](E2-ajuda.png) | Instruções E2 em pt-BR, com rolagem do texto longo. |
| [E2-novo-mundo.png](E2-novo-mundo.png) | Nome editável Mel, população 12 e botões dentro da janela. |
| [E2-fps-12.png](E2-fps-12.png) | Cena renderizada após medição, gráfico e resultado em português. |

[FATO] As abas foram compactadas após inspeção para exibir os cinco títulos
sem setas ou corte horizontal. Rótulos quebram linhas dentro do painel; não
foram encontrados termos de estado em inglês nas capturas. Texto claro sobre
verde escuro e seleção destacada preservam a leitura observada. Conteúdo
longo usa rolagem visível: a legenda completa aparece na captura de expressão;
a ajuda tem mais texto abaixo da primeira área visível.

[FATO] Detalhes E2 são fixtures explícitas, sem saves pessoais: reduzem energia
e hidratação, ajustam fadiga/estímulo/contato e colocam fruta no corpo. A
ingestão passa pelo executor físico `_eat`, e contato por `interagir_jogador`;
nenhuma preferência, memória ou familiaridade é fabricada pela UI. As criaturas
não são deslocadas. Jardim/lista mostram o estado inicial sem esses ajustes;
benchmark avança naturalmente a simulação.

Para reproduzir, substitua `godot` pelo executável indicado na tarefa:

```powershell
godot --path . -- --capture=reports/E2-jardim.png --capture-state=e2-garden
godot --path . -- --capture=reports/E2-lista.png --capture-state=e2-roster --capture-minimum
godot --path . -- --capture=reports/E2-necessidades.png --capture-state=e2-needs --capture-minimum
godot --path . -- --capture=reports/E2-tracos.png --capture-state=e2-traits --capture-minimum
godot --path . -- --capture=reports/E2-memoria.png --capture-state=e2-memory --capture-minimum
godot --path . -- --capture=reports/E2-preferencias.png --capture-state=e2-preferences --capture-minimum
godot --path . -- --capture=reports/E2-vinculos.png --capture-state=e2-bonds --capture-minimum
godot --path . -- --capture=reports/E2-expressao.png --capture-state=e2-expression --capture-minimum
godot --path . -- --capture=reports/E2-carinho.png --capture-state=e2-attention --capture-minimum
godot --path . -- --capture=reports/E2-ajuda.png --capture-state=help --capture-minimum
godot --path . -- --capture=reports/E2-novo-mundo.png --show-new-world --capture-minimum
godot --path . -- --fps-benchmark=12
```

[LACUNA] A revisão visual é local, sem estudo de usabilidade ou teste de
acessibilidade com participantes. O painel mantém a rolagem externa do
Cuidador e a rolagem interna das abas longas. O arco/brilho é discreto no
enquadramento geral; aproximar torna a expressão mais visível. Uma captura
estática não demonstra o balanço temporal; ele está ligado ao passo no código.
Não foi feita revisão independente nem integração no branch do coordenador.
