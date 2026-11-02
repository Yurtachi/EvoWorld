# M4b — UI de terminal fictício, console virtual e laboratório

[FATO] Trabalho na branch local `Yurtachi/evo3-m4b-ui`, base `evo3/integration` em `5f13150`, Godot 4.7.2 console. Foram lidos `docs/EVOWORLD_3_SPEC.md`, `reports/M4a_terminal.md`, `reports/M4b_terminal_mundo.md` e `reports/M3c_ui.md`. A entrega altera somente a UI (`scripts/ui/`), a renderização (`scripts/render/`), o catálogo centralizado de textos (`scripts/core/textos.gd`), `README.md` e estes artefatos de documentação e teste; não altera `scripts/terminal/`, `scripts/mind/`, `scripts/world/`, `scripts/creature/` ou `scripts/persistence/`.

## Comportamento entregue

[FATO] **Ferramenta Terminal**: adicionada à segunda linha do rodapé. Clicar ativa a ferramenta física que desenha prévia ciano no raio de interação e posiciona no jardim via `world.place_terminal(pos)`. O render desenha os dispositivos em `world.terminals` com representação intencionalmente artesanal e fictícia: pedestal de pedra entalhada com runas, tela de pergaminho/cristal luminescente esmeralda e três abas de manuais afixados coloridos (*mapa*, *livro de desenho*, *livro de repetição*). O dispositivo tem etiqueta discreta e pinos de coordenadas fictícias (`MARCADOR`), sem nenhuma semelhança visual com prompts ou shells de sistemas operacionais reais.

[FATO] **Console virtual do jogador**: botão dedicado **Console virtual** no rodapé (opcional e intencional, nunca compulsório). Abre diálogo interativo exibindo tarja de aviso obrigatória: *"terminal fictício: não executa comandos do computador"*. Suporta botões de inserção rápida para os 7 comandos da DSL fictícia (`OLHAR`, `MARCAR`, `MOVER`, `DESENHAR`, `REPETIR`, `AJUDA`, `LER`), entrada de texto livre e respostas do mundo virtual em português brasileiro (`OK`, `POS=<x,y>`, `DESENHO=<id>`, etc.). Comandos hostis ou típicos de sistemas operacionais reais (como `dir`, `ls`, `cat`, `rm`, `powershell`, `cmd`, `sh`, etc.) são ativamente interceptados e rejeitados sem execução no host.

[FATO] **Painel Terminal da criatura**: integrado ao inspetor da Convivência via `TerminalPresenter`. Apresenta:
- Linha de atividade em tempo real (`terminal_snapshot(creature)`), indicando aproximação física, execução de comando, leitura de manual ou recusa ativa com passos restantes.
- Diálogo **Terminal · comandos e tentativas**: exibe comandos conhecidos com procedência rigorosa (`inicial`, `ajuda`, `manual`, `livro`, `pratica`), histórico das 8 tentativas mais recentes com indicação visual de sucesso/erro e carimbo temporal, sequência funcional por objetivo e estado de recusa/adiamento.
- **Divulgação honesta do experimento X7**: texto científico explícito detalhando que um programa fixo roteirizado atinge o mesmo ou mais que o aprendizado (100% vs 87,5%), não há prova científica de aprendizado autônomo de soluções gerais no M4, e a auditoria de save no holdout congelado registrou FAIL global inicial, corrigido na integração pós-holdout.

[FATO] **Oferecer manual e recusa**: botões dedicados na Convivência:
- **Oferecer manual**: diálogo que lista os 3 manuais afixados ao terminal (`mapa`, `livro_desenho`, `livro_repeticao`) com descrições em pt-BR e chama `world.terminal_offer_manual(creature, manual_id)`.
- **Adiar / recusar terminal**: diálogo com confirmação e chamada a `world.terminal_refuse(creature, ticks)` (padrão de 120 passos / 12 segundos simulados), permitindo à criatura priorizar necessidades vitais ou exploração livre sem penalidades.

[FATO] **Laboratório M4b**: seção dedicada posicionada no topo do Laboratório, contendo:
- Resumo científico honesto das conclusões do X7 e limites auditados.
- Catálogo taxonômico de erros observáveis (`CMD_UNKNOWN`, `SYNTAX_INVALID`, `PHYS_TARGET_UNREACHABLE`, `DRAW_CANVAS_BLOCKED`, `PHYS_COOLDOWN_ACTIVE`).
- Status e aviso de ablação de memória procedural (sem tabela de comandos a taxa de sucesso cai para 0%).
- Tabela de limites de CPU headless (24,7 µs/passo isolado de terminal; ~40.500 passos/s em 1 núcleo) com explicação do impacto em rotas físicas completas.
- Histórico expansível de execuções da criatura selecionada.

[FATO] **Tutorial 8/8**: `Roteiro · terminal fictício` (30–35 min), orientando a posicionar o dispositivo, demonstrar comandos básicos e respeitar recusas. Botão de acesso direto na Convivência e navegação em 8 etapas atualizada.

[FATO] **Persistência**: dispositivos de terminal, estados procedurais das criaturas e configurações de ablação sobrevivem e são verificados no save/load v13 da UI.

## Verificação

[FATO] `godot --headless --path . -s tests/run_tests.gd`: **24 suítes, exit 0**, sem FAIL ou SCRIPT ERROR. Executado integralmente durante a implementação e na validação final. Cobre simulação, mente, ateliê, biblioteca, terminal fictício, segurança hostil e save v13. Nenhum teste fechado `*_eval` foi executado.

[FATO] `godot --headless --path . -s scripts/ui/verify_ui.gd`: **exit 0**, `Integração da UI: ok`, sem SCRIPT ERROR. O verificador cobre a colocação da ferramenta Terminal no mundo, console virtual com execução segura e rejeição de comando hostil, painel de comandos com proveniência e texto honesto do X7, oferta de manual, recusa voluntária ativa com contagem regressiva, persistência de terminais e estados no save/load v13, elementos do Laboratório M4b, etapa 8 do tutorial e limpeza da seleção.

[FATO] `git diff --check` e `git diff --exit-code HEAD -- 'reports/*_eval.json'` passaram sem erros. Nenhum arquivo experimental pré-existente foi modificado. Todos os textos voltados ao jogador estão centralizados em `scripts/core/textos.gd`, mantendo vocabulário estritamente observacional ("parece/aparenta", nunca "sente/entende").

## Capturas novas e inspeção visual

[FATO] Todos os 8 arquivos PNG abaixo foram gerados pelo build atual com janela de **1100×680**, abertos e minuciosamente inspecionados quanto a cortes, quebra de linha, contraste e integridade linguística em português brasileiro.

| Captura | Conteúdo inspecionado |
| --- | --- |
| [M4b-tool.png](M4b-tool.png) | Ferramenta Terminal ativa no rodapé; pedestal de pedra com tela de cristal esmeralda e abas de manuais no terreno. |
| [M4b-console.png](M4b-console.png) | Console virtual com tarja de aviso obrigatória, botões DSL rápidos, comando digitado e resposta em pt-BR. |
| [M4b-creature.png](M4b-creature.png) | Painel Terminal da criatura com comandos conhecidos, origens, histórico recente e texto honesto do X7 legível. |
| [M4b-manual.png](M4b-manual.png) | Diálogo de oferecer manual com 3 opções afixadas (`mapa`, `livro_desenho`, `livro_repeticao`) e confirmação legível. |
| [M4b-refusal.png](M4b-refusal.png) | Diálogo de recusa/adiamento e status ativo "Recusa / adiamento ativo (restam 120 passos)" no inspetor. |
| [M4b-lab.png](M4b-lab.png) | Seção M4b no Laboratório com revisão do X7, taxonomia de erros, ablação e tabela de limites de CPU headless. |
| [M4b-tutorial.png](M4b-tutorial.png) | Etapa 8/8 do tutorial (`Terminal fictício, comandos e autonomia`), rolagem legível e instruções completas. |
| [M4b-fps-12.png](M4b-fps-12.png) | Cena gráfica com 12 criaturas, terminal físico no terreno, 3 objetos e quadro; fluidez estável acima de 100 FPS. |

[FATO] Não foram observados cortes de texto, sobreposição ilegível de rótulos, termos residuais em inglês ou contraste insuficiente nos diálogos e ferramentas novas. Textos extensos possuem rolagem explícita com barra vertical legível.

[LACUNA] A inspeção visual atesta os cenários de fixtures registrados na resolução padrão de 1100×680. Não esgota variações de escala em monitores com High-DPI não padronizados ou configurações de sistema operacional fora do ambiente validado.

## FPS gráfico com terminal

[FATO] Comando executado: `godot --path . -- --fps-benchmark=12 --capture=<caminho-absoluto>/reports/M4b-fps-12.png --capture-minimum`. Medição gráfica em tempo real a 1×, com 2 segundos de aquecimento e 8 segundos de amostragem. Dados registrados em [M4b-fps-12.json](M4b-fps-12.json):

| Métrica | Valor medido |
| --- | --- |
| População inicial / final | 12 / 12 criaturas |
| Terminais / livros / objetos / quadros | 1 / 1 / 3 / 1 |
| Mentes ativas | 1 (no pet) |
| Janela / adaptador | 1100×680 / NVIDIA GeForce RTX 2050 |
| Quadros renderizados / tempo de coleta | 826 quadros / 8,004034 s |
| Média de taxa de quadros | **103,20 quadros/s** |
| Percentil 95 (p95) de tempo de quadro | **13,078 ms** |
| Passo final da simulação | 102 |

[LACUNA] O benchmark reflete a carga padrão do produto (12 criaturas com uma mente ativa e um terminal no jardim), não medindo 12 mentes ativas simultaneamente em tarefas do terminal. [HIPOTESE] Múltiplos terminais com várias criaturas interagindo simultaneamente demandarão maior consumo de CPU nas rotas de aproximação física, justificando a tabela de limites de CPU headless disponibilizada no Laboratório.
