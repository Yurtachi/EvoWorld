# M1 — Convivência na interface real

Data: 02/11/2026. Base: `evo3/integration` em `f4efe0d`; branch local
`Yurtachi/evo3-m1-ui`. Implementação, testes da interface e captura gráfica: PASS.

## Comportamento entregue

- [FATO] Convivência é o modo padrão ao criar um jardim. O pet inicia ampliado
  e acompanhado pela câmera. Estado afetivo aparente e desejo atual aparecem
  primeiro; o balão lateral usa a causa real mais recente do afeto dominante,
  excluindo o mero decaimento, ou o motivo da escolha quando não há afeto.
  Todos esses dados vêm de `creature.mind_snapshot()`.
- [FATO] Cor, postura, tamanho/opacidade do ícone e extensão do arco variam
  proporcionalmente ao afeto dominante. Há um indicador mental apenas na
  seleção; o balanço acompanha o tick e para quando pausado. A ablação retira
  a modulação M1, preservando a expressão legada independente. O nome é
  renderizado com fonte constante em pixels para permanecer legível no zoom.
- [FATO] O seletor fica acima dos modos e pode acompanhar qualquer criatura.
  A seleção pela lista amplia e segue o corpo sem ativar sua mente. Sem mente,
  a UI informa isso explicitamente, sem inferir desejos; o aviso de CPU aparece
  antes do botão que chama `world.enable_mind`. Mundos novos mantêm só o pet
  ativo por padrão; saves legados continuam sem ativação implícita.
- [FATO] Laboratório separado apresenta os sete afetos, pontuações da última
  decisão, seis mudanças recentes do `cause_log` e seis trocas do `mind_log`,
  com causas e motivos traduzidos. Afeto e memória M1 podem ser ligados ou
  desligados na seleção, inclusive no pet. As flags persistem no save v8;
  valores retidos aparecem como históricos quando afeto está desligado.
- [FATO] Apresentar companhia usa `spawn_creature` em ponto livre próximo,
  validado antes para evitar a realocação automática para longe. Preserva
  seleção e posições existentes. Colocar obstáculo usa a ferramenta física
  existente; Retirar rochas próximas remove obstáculos a até 120 unidades
  além de seus raios e reconstrói o índice espacial. Não altera afetos ou desejos.
- [FATO] O tutorial navegável tem cinco etapas, com roteiro de 20 minutos:
  adotar, alimentar, apresentar companhia, ler desejo e observar eventual
  privacidade. Fica na Convivência e na Ajuda; não mostra logs ou ablações.
  Corpo, traços e experiências ficam recolhidos por padrão ao final do painel.
- [FATO] Textos novos de jogador e traduções mentais estão em
  `scripts/core/textos.gd`, seção M1 e formatadores. A linguagem usa
  “parece/aparenta” e identifica estados computacionais simulados.

## Verificação executada

[FATO] Executável: Godot console 4.7.2 do caminho indicado no despacho,
renderer GL Compatibility, Windows, NVIDIA GeForce RTX 2050 / driver 610.62.

```text
godot --headless --path . -s tests/run_tests.gd
17 suítes: ok; exit 0; sem FAIL ou SCRIPT ERROR

godot --headless --path . -s scripts/ui/verify_ui.gd
Integração da UI: ok; exit 0

godot --path . -s scripts/ui/verify_ui.gd
Integração da UI: ok; janela gráfica; exit 0
```

[FATO] `verify_ui.gd` foi ampliado para verificar modo padrão, destaque do pet,
escopo mental, leitura imutável, seleção sem ativação, ativação sem alterar o
corpo, ablação da seleção e do pet, save/load das flags, companhia física sem
trocar seleção, retirada de rochas, frustração por colisões reais, causas,
pontuações, logs, tradução de oito motivos, cinco etapas do tutorial, limpeza
de seleção ausente e largura mínima de 1100 pixels. Mantém verificações E1–E4.

[FATO] As capturas usam a mesma cena de jogo, em build debug, sem reescrever
valores afetivos. Os cenários de inspeção usam seed 81002, um pet sem recursos,
70 passos de isolamento ou 35 passos em um anel físico de rochas; companhia
é colocada pela ferramenta real e observada por 20 passos. São fixtures
de apresentação identificadas no rodapé, sem pretensão experimental.

## Capturas novas e inspeção visual

[FATO] PNGs produzidos nesta execução; os cenários de inspeção estão em
1100×680 e o benchmark está em 1280×720:

| Captura | Conteúdo inspecionado |
|---|---|
| [M1-convivencia.png](M1-convivencia.png) | Pet, afeto, desejo e motivo legíveis |
| [M1-companhia.png](M1-companhia.png) | Companhia física e seleção preservada |
| [M1-frustracao.png](M1-frustracao.png) | Bloqueio real, frustração e postura |
| [M1-sem-mente.png](M1-sem-mente.png) | Ausência honesta, aviso de custo e ativação |
| [M1-ferramentas.png](M1-ferramentas.png) | Ferramentas para observar companhia/bloqueio |
| [M1-laboratorio.png](M1-laboratorio.png) | Rotulagem simulada, ablações e afetos |
| [M1-pontuacoes.png](M1-pontuacoes.png) | Oito pontuações traduzidas |
| [M1-causas-log.png](M1-causas-log.png) | Passos, deltas e causas |
| [M1-trocas.png](M1-trocas.png) | Desejos e motivos das trocas |
| [M1-tutorial.png](M1-tutorial.png) | Etapa inicial e navegação sem debug |
| [M1-fps-12.png](M1-fps-12.png) | Jardim real, mini gráfico e resultado do benchmark |

[FATO] Todos os PNGs foram abertos e inspecionados. Os textos principais e
botões cabem na largura mínima; conteúdos longos têm quebra e rolagem vertical
intencional. Não foi observado inglês nos textos de jogador capturados; os
nomes e textos claros contrastam com os fundos escuros. A primeira inspeção
levou à correção da nitidez dos nomes, remoção de aviso duplicado e ocultação
do marcador de alvo quando não há alvo solicitado/restaurado, evitando
encobrir o pet. Não houve medição instrumental de contraste.

## FPS gráfico — 12 criaturas, mente só no pet

[FATO] Comando executado em janela gráfica debug, com caminho absoluto:

```text
godot --path . -- --capture=C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m1-ui/reports/M1-fps-12.png --fps-benchmark=12
```

[FATO] Resultado em [M1-fps-12.json](M1-fps-12.json): 12 criaturas iniciais e
finais, **1 mente ativa**, `pet_mind_active=true`, velocidade 1×, 1280×720,
778 quadros em 8,002838 s após 2 s de aquecimento. Média **97,22 FPS**;
p95 do intervalo entre quadros **14,359 ms**. Os intervalos são medidos
em `RenderingServer.frame_post_draw`, com simulação, UI e renderização ativas.

## Limites e pendências

- [FATO] As ferramentas oferecem condições físicas; não escolhem a reação.
  Desviar não equivale a bloqueio repetido, e contato não garante companhia
  desejada ou privacidade. Desejo e ação podem diferir sob necessidades,
  comandos ou ensino. A UI não afirma que um indivíduo tenha consciência.
- [FATO] O Laboratório explicita a limitação de X1 registrada em
  [M1_mind.md](M1_mind.md): desligar afeto não demonstrou eliminar a diferença
  social. Não foram executados `ensino_eval`, `learn_eval`, `social_eval` ou
  `m1_eval`, nem alterados os JSONs experimentais preexistentes.
- [HIPOTESE] O destaque do pet e os detalhes recolhidos podem facilitar a
  primeira experiência; isso ainda precisa de observação com jogadores.
- [LACUNA] Um benchmark gráfico local não estima custo em outros dispositivos,
  30/60/100 criaturas ou várias mentes ativas. Esta medição corresponde ao
  escopo solicitado de 12 criaturas com mente apenas no pet.
- [LACUNA] O roteiro de 20 minutos é orientação manual, sem validação de
  usabilidade ou promessa de que privacidade surgirá nesse intervalo.
  Causas/logs na UI são recortes dos buffers limitados do simulador.
- [FATO] Foram respeitados os diretórios de ownership: nenhuma edição em
  mind, world, creature, behavior ou persistence. Implementação própria;
  nenhum código GPL copiado. Sem push, merge ou operação Git destrutiva.
- [LACUNA] Revisão independente e integração ficam com o coordenador;
  este worker entrega um commit local seletivo e estes artefatos.
