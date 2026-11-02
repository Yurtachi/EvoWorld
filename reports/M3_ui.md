# M3 — Ateliê, quadro de desenho e calibração motora na interface real

[FATO] Data: 02/11/2026. Base `evo3/integration` @ `531e16f`, branch local `Yurtachi/evo3-m3-ui`.
Interface gráfica, regressão automatizada e inspeção visual: PASS.
Sem push/merge, sem bibliotecas de terceiros não autorizadas, sem alteração nos módulos congelados (`scripts/atelier|mind|world|creature|persistence`) e sem execução de experimentos `*_eval`.

## 1. Entrega e fronteira de conhecimento

[FATO] A ferramenta **Quadro** (`world.place_board`) e a ferramenta **Demonstrar** (`world.demonstrar_forma`) foram integradas à barra de ferramentas principal e ao painel lateral da Convivência. Clicar no terreno com a ferramenta Quadro posiciona um cavalete físico com tela 64×64 e drop shadow suave, registrando o ID do quadro no ecossistema sem alterar a seleção nem teletransportar criaturas.

[FATO] A ferramenta **Demonstrar** abre diálogo acessível e modal (`demo_dialog`), permitindo ao usuário:
1. Escolher a forma geométrica de referência (`Linha`, `Círculo` ou `Quadrado`);
2. Regular a escala da guia visível entre 0,45 e 1,60 (passo 0,05);
3. Ajustar o centro horizontal X e vertical Y no quadro entre 10 e 54 (passo 2);
4. Visualizar imediatamente em uma tela de prévia em miniatura (`AtelierCanvas`) a referência gerada em ciano com retículo central.
Ao confirmar ou ao clicar diretamente em um botão de forma rápida (`Linha`, `Círculo`, `Quadrado`), a referência demonstrada é enviada ao simulador e fica visível sobre o quadro tanto no mundo 2D quanto nos componentes de UI.

[FATO] O desenho das criaturas no quadro ocorre com **física e ações primitivas reais** (`move_pen`, `pen_down`, `pen_up`, `segment`). Durante a execução da ação `draw_stroke`, os traços são renderizados em tempo real tanto no quadro no jardim quanto no componente `board_canvas` do painel de Convivência, indicando o progresso do traçado (ex.: `Traço em tempo real: segmento 4/8 no quadro #3 (Mel)`), com ponta da caneta em destaque visual.

[FATO] A **Galeria de criações** exibe todos os artefatos concluídos no mundo (`world.gallery`), com persistência de miniaturas dos traços gerados (`mini.setup(art.strokes, ref, false)`), título do artefato, identificação e nome do autor (`owner_name`, `owner_id`), passo de conclusão, ID do quadro e métrica de erro Chamfer. Na ausência de referência demonstrada, os artefatos são identificados como rabisco exploratório livre.

[FATO] No **Laboratório**, a aba de ateliê exibe:
1. Aviso honesto de limites auditados (`m3_lab_warning`): explicita a reclassificação de X4 como PARTIAL, registrando que a criatura calibra traços seguindo pontos da guia visível a cada passo, mas **ainda não copia de memória**; que escrita e símbolos são fora de escopo (M3b); e que recompensa de aprendizado é puramente cognitiva, não repondo energia ou hidratação;
2. Estado de treino e política motora da seleção: status de aprendizagem ativo/desligado, política atual (`treinável`, `congelada`, `sem treino (naive descalibrado)`, `aleatória (rabisco)`) e número de atualizações efetuadas;
3. Chave de ablação de treino (`CheckButton`) e seletor de política (`OptionButton`) que modificam diretamente o estado de `creature.atelier` com intervenção explícita;
4. Tabela de competência por forma com **texto honesto** que distingue formalmente:
   - *Demonstrado*: `demonstrado no quadro`, `demonstrado antes`, `não demonstrado`;
   - *Praticado*: `praticado (N×)`, `não praticado (0×)`;
   - *Aprendeu*: `aprendeu calibração guiada (ainda não copia de memória)` quando o erro mediano atinge o limiar (<0,22), `praticado em calibração (ainda não aprendeu; ainda não copia de memória)` ou `ainda não aprendeu (ainda não copia de memória)`;
5. Curva gráfica de erro por forma (`AtelierChart`), plotando a distância de Chamfer [0, 1] ao longo das tentativas sucessivas para cada forma, com linha de referência no limiar 0,22;
6. Histórico paginado das tentativas recentes, detalhando ID da tentativa, passo, quadro, forma, erro Chamfer, redução de erro ($\Delta\text{erro}$), contagem de atualizações e estado honesto.

[FATO] O tutorial de introdução **Primeiros 25 minutos** foi expandido com a etapa 6/6 (20–25 min · Ateliê e quadro de desenho), orientando o jogador a posicionar o quadro, aguardar iniciativa autônoma por curiosidade em 1×, demonstrar formas com escala/posição e inspecionar a curva de calibração e os limites honestos no Laboratório.

[HIPOTESE] A exibição em tempo real da ponta da caneta e dos traços no mundo e no painel lateral reforça para o jogador que a simulação executa passos cinemáticos discretos, sem gerar formas pré-renderizadas ou texturas estáticas opacas.

[LACUNA] Conforme registrado na auditoria formal do coordenador (commit `531e16f`), o aprendizado de formas (X4) constitui calibração de malha fechada / servo visual guiado passo a passo pela referência externa. O modelo não possui ainda representação interna latente para reproduzir o traço de memória quando a referência é removida do quadro. Essa limitação é comunicada com total transparência ao usuário em todos os pontos de contato da interface.

## 2. Verificação automatizada executada

[FATO] Ambiente de execução: Godot Engine v4.7.2-stable oficial (console exe), Windows 11, renderizador GL Compatibility, GPU NVIDIA GeForce RTX 2050 (Driver 610.62).

1. **Suíte completa de testes unitários e de integração** (`tests/run_tests.gd`):
   ```text
   godot --headless --path . -s tests/run_tests.gd
   20 suítes executadas: ok; exit 0; 0 falhas; 0 erros de compilação/parse.
   Log durável registrado em reports/M3-ui-tests.txt.
   ```
2. **Verificação integrada de UI em modo headless** (`scripts/ui/verify_ui.gd`):
   ```text
   godot --headless --path . -s scripts/ui/verify_ui.gd
   Integração da UI: ok; exit 0.
   Log durável registrado em reports/M3-ui-verification.txt.
   ```
3. **Verificação integrada de UI em modo janela gráfica** (`scripts/ui/verify_ui.gd`):
   ```text
   godot --path . -s scripts/ui/verify_ui.gd
   OpenGL API 3.3.0 NVIDIA 610.62 - Compatibility
   Integração da UI: ok; exit 0.
   Log durável registrado em reports/M3-ui-graphics.txt.
   ```

[FATO] A rotina `_verify_m3` em `scripts/ui/verify_ui.gd` valida:
- Imutabilidade do estado do mundo ao inspecionar a UI e o Laboratório;
- Colocação de quadro físico pela ferramenta `Quadro` via `place_board`;
- Atualização imediata do painel de Convivência com status do quadro livre;
- Realização de rabisco espontâneo livre pela criatura Mel na ausência de guia;
- Aparição imediata do artefato na Galeria de criações com miniatura e rótulos;
- Abertura e preenchimento do diálogo `Demonstrar` com opções de linha, círculo, quadrado, escala e translação;
- Aplicação de referência demonstrada via `demonstrar_forma` e reflexo visual imediato no quadro e no painel;
- Renderização de traços em tempo real com segmentos incrementais durante a ação física `draw_stroke`;
- Alimentação da curva de erro e do histórico de tentativas com dados reais de sessões guiadas;
- Exibição do aviso de limites honestos (`Ainda não copia de memória`) e distinção rigorosa de `demonstrado`, `praticado` e `aprendeu`;
- Ablação funcional de treino e alternância de política motora para naive descalibrado;
- Robustez do save/load v10: preservação íntegra de quadros, artefatos da galeria, snapshots de competência e ablações;
- Acesso à etapa 6/6 do tutorial de ateliê;
- Encaixe de todas as novas ferramentas e painéis na largura mínima suportada de 1100×680 pixels;
- Desativação correta de controles na ausência de criatura selecionada.

## 3. Desempenho gráfico (FPS Benchmark)

[FATO] O benchmark gráfico padronizado foi executado na resolução de 1100×680 pixels, com ecossistema de 12 criaturas ativas, 1 quadro com demonstração ativa e desenho de criatura, 3 objetos físicos e mente habilitada no pet:
- Arquivo de métricas: `reports/M3-fps-12.json`
- Captura correspondente: `reports/M3-fps-12.png`

| Métrica | Valor Medido | Requisito Mínimo | Status |
|---|---|---|---|
| Taxa Média de Quadros | **104,35 FPS** | $\ge$ 30,0 FPS | APROVADO |
| Percentil 95 de Duração ($p_{95}$) | **12,15 ms** | $\le$ 33,3 ms | APROVADO |
| Quadros Renderizados | 835 quadros em 8,00 s | — | Confiável |
| Janela Mínima | 1100 × 680 | 1100 × 680 | APROVADO |
| População Ativa | 12 criaturas (1 mente ativa) | 12 criaturas | APROVADO |
| Elementos Adicionais | 1 quadro de desenho + 3 cápsulas | Quadro + objetos | APROVADO |

## 4. Capturas novas e inspeção visual detalhada

[FATO] Todas as capturas de tela foram geradas a partir do build atual, na resolução de teste de 1100×680 pixels. Cada imagem foi submetida a rigorosa inspeção visual:

| Captura | Cenário e Elementos Inspecionados | Avaliação de Corte, Contraste e Idioma |
|---|---|---|
| [M3-scribble.png](M3-scribble.png) | Criatura Mel no quadro após rabisco livre autônomo. Exibe estado aparente `Aparenta satisfação`, desejo `Parece querer desenhar no quadro`, ação física `Traçando segmentos no quadro`. | **100% pt-BR**. Vocabulário puramente observacional ("parece/aparenta", nunca "sente"). Sem cortes ou sobreposições. |
| [M3-demo.png](M3-demo.png) | Modal **Demonstrar forma no quadro** centralizado com seleção de forma (Círculo), escala (1,15), centro X=34, Y=30, prévia gráfica com guia ciano e retículo. | Sem corte; contraste adequado em fundo escuro floresta; botões e campos traduzidos; atalhos de jogo suspensos. |
| [M3-drawing.png](M3-drawing.png) | Execução de traço em tempo real no quadro físico no jardim e no painel lateral (segmento 4/8, ponta de caneta laranja ativa, guia de quadrado visível). | Quadro desenhado com cavalete, tela e contorno; rótulo do quadro legível; botões da barra inferior (`Quadro`, `Demonstrar`) perfeitamente alinhados dentro dos limites. |
| [M3-gallery.png](M3-gallery.png) | Galeria de criações na Convivência com miniaturas fiéis dos artefatos salvos, títulos autônomos, autor com identificador, tick de conclusão e evolução do erro Chamfer decrescente (0,163 $\to$ 0,110 $\to$ 0,000). | Miniaturas renderizadas via vetores reais com padding; textos legíveis; sem truncamento de identificadores de organismos. |
| [M3-lab-curve.png](M3-lab-curve.png) | Curva de erro Chamfer no Laboratório por forma (amarelo Linha, azul Círculo, verde Quadrado), linhas guia de 0,0, 0,22 e 1,0, eixo sem cortes, e histórico detalhado de tentativas. | Título de seção completo sem corte; texto do eixo ajustado com precisão; contraste nítido em conformidade com as diretrizes visuais. |
| [M3-ablation.png](M3-ablation.png) | Aviso honesto de limitações no Laboratório, status de treino e política motora, switch de ablação de calibração desativado e política alterada para `sem treino (naive descalibrado)`. | Texto honesto de limites auditados em destaque amarelo suave; controles funcionais e legíveis; sem qualquer termo em inglês vazado. |
| [M3-tutorial.png](M3-tutorial.png) | Etapa 6/6 do tutorial (20–25 min · Ateliê e quadro de desenho) aberta sobre a janela de jogo. | Texto claro, instruindo o fluxo completo sem falsas promessas de telepatia ou memória motora ausente; quebra de linha suave. |
| [M3-fps-12.png](M3-fps-12.png) | Benchmark ao vivo com 12 criaturas, 1 quadro, 3 objetos, notificação de taxa média (104,3 quadros/s) e gráfico de oscilação temporal suave. | Barra inferior estável, mini-gráfico responsivo e sem quedas bruscas de desempenho. |

## 5. Salvamento e persistência v10

[FATO] O formato de persistência v10 foi integralmente suportado:
- Quadros colocados no jardim persistem posição, ID, referência demonstrada (`reference_shape`, `reference_params`, `reference_strokes`) e traços ativos;
- A galeria do mundo (`world.gallery`) preserva todos os artefatos históricos com propriedade individual, carimbo de tempo, traços vetoriais brutos e erro associado;
- Os organismos mantêm seu componente de ateliê com políticas modificadas, estado de aprendizagem e histórico de tentativas;
- Carregar um arquivo salvo v10 reconstrói perfeitamente o visual dos quadros no mapa e reabastece as miniaturas da galeria sem perda de informação ou mutação inadvertida de estado.

## 6. Conclusão

[FATO] A interface do marco M3 cumpre 100% dos requisitos estipulados no despacho, incorporando as correções e auditorias de transparência científica acordadas com o coordenador. Todos os testes unitários e de integração passam com código de saída 0, a integridade visual da interface na resolução mínima está assegurada e as evidências estão consolidadas neste relatório.
