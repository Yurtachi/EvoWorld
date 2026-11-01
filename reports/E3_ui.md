# E3-UI — ensino na interface real

Status: **PASS no escopo UI/render**. Data: 01/11/2026.

[FATO] Branch local `Yurtachi/evo2-e3-ui`, recebido já criado sobre
`evo2/e1-base` em `962412c54393fee1403076cb5ff1971ede37e77c`, sem commits
intermediários na base. Identidade Git local Yurtachi, commits seletivos, sem
push. Foram lidos `docs/EVOWORLD_2_SPEC.md`, os relatórios E1/E2 SIM/UI,
`reports/E3_sim.md` e `reports/sinais.md`. Não foram editados caminhos de
simulação; não houve cópia de código, textos, pesos ou assets do Pestinha.

## Comportamento entregue

[FATO] O painel lateral tem três modos: Cuidador, Ensinar e Laboratório.
Ensinar opera sobre a seleção atual, feita no mapa ou na lista do Cuidador.
Mostra o nome da criatura, duas habilidades obtidas de `ensino_habilidades`,
selo, alvo, controles, progresso físico, métricas e eventos. Sem seleção,
apaga os dados anteriores e bloqueia as ações. Escolher outra habilidade
não encerra implicitamente uma tentativa: seu progresso continua identificado
pelo nome da habilidade que está realmente ativa.

| Controle | Contrato real |
|---|---|
| Marcar alvo no mapa | Ferramenta de clique para local; marcador amarelo separado do alvo azul do diálogo. Validação física é do simulador. |
| Mostrar | `ensino_iniciar`/`ensino_mostrar`, assistência habilitada, política `q`, horizonte de 200 passos. Linha tracejada e legenda ASSISTÊNCIA. |
| Observar sem guiar | Inicia tentativa autônoma ou desliga a assistência atual; conserva o número de ações assistidas anteriores. |
| Recompensar | Habilita somente após `success` físico, sem recompensa anterior e com cérebro treinável; chama `ensino_recompensar`. |
| Cancelar tentativa | `ensino_cancelar`, sem prêmio ou punição. |
| Reiniciar treinamento | Confirmação com nome da criatura; só depois chama `ensino_reset`. A confirmação fica vinculada à criatura e ao mundo que a abriram. |

[FATO] Alterar um alvo local em andamento usa a regra de cancelamento e nova
tentativa do simulador. Um alvo recusado preserva o marcador anterior.
Água usa a percepção da criatura, sem alvo onisciente; o botão de marcação
fica desativado nessa habilidade. A assistência hídrica recebe legenda junto
ao corpo. O tutorial explica que só beber com ganho hídrico conclui e que
Iniciar/Espaço faz o mundo pausado avançar. Ordens de diálogo atualizam o
cancelamento no painel mesmo sem avanço de passo.

[FATO] A linha assistida é uma direção indicativa até o alvo, identificada
como assistência; não é um planejador de caminho nem promete atravessar
obstáculos. A UI não move criaturas nem escreve aprendizado. O custo e a
execução física pertencem à API SIM. Fome/sede críticas mantêm sua prioridade.

[FATO] Os textos repetem: recompensa é sinal de aprendizado, não repõe
energia/hidratação; conclusões assistidas não comprovam aprendizado autônomo.
O selo vem de `ensino_observar.skills`: pelo menos cinco tentativas autônomas,
sucesso de 70% ou mais nas últimas vinte retidas. Não se infere aprendizado
de um pedido aceito ou de uma demonstração concluída.

[FATO] Métricas mostram sucesso autônomo, sucessos/amostra, tentativas totais
e sessões retidas. A curva recalcula a taxa por tentativa autônoma no histórico
retido, com referências 0/70/100%; antes/depois usa `before_after` do simulador.
Não há amostras inventadas nem promessa de competência futura. São até 32
sessões, 32 tentativas e 64 eventos no SIM; a UI mostra os dez eventos mais
recentes em ordem inversa, com passo, ação, resultado físico e updates traduzidos.

[FATO] `textos.gd` integra `E3_CATALOGO`/`E3_RAZOES`, os códigos de recusa e os
eventos. Ajuda e README descrevem o fluxo completo. Identificadores persistidos
continuam estáveis. A leitura do painel usa snapshot destacado, atualizado por
passo/seleção e após intervenções; não consome RNG da simulação.

## Validação executada

[FATO] Godot **4.7.2.stable.official.ed1daf0bf**, executável console informado
na tarefa, Windows. Nenhum dos experimentos `ensino_eval.gd` ou `learn_eval.gd`
foi executado por este worker, e seus artefatos não foram alterados.

| Comando, prefixado pelo executável Godot informado | Resultado | Evidência |
|---|---|---|
| `--headless --path . -s tests/run_tests.gd` | exit 0; 13 arquivos de teste passaram | [E3_ui_regression.txt](E3_ui_regression.txt) |
| `--headless --path . -s scripts/ui/verify_ui.gd` | exit 0; Integração da UI: ok | [E3_ui_tests.txt](E3_ui_tests.txt) |
| `--path . -- --fps-benchmark=12` | janela gráfica real; população final 12 | [JSON](E3-fps-12.json), [captura](E3-fps-12.png) |
| `git diff --check` | exit 0 | sem erro de whitespace |

[FATO] Benchmark final: seed 7421, Windows, OpenGL Compatibility, NVIDIA
GeForce RTX 2050, janela 1280×720, velocidade 1×, dois segundos de aquecimento
e 8,004655 segundos de coleta. Foram 860 quadros, **107,4375 quadros/s** de
média, **12,179 ms** no p95 de duração do quadro, população inicial/final
12/12 e passo final 101. A medição final foi feita sem outro teste deste
worker executando em paralelo; não demonstra melhora ou eficácia de ensino.

[FATO] O verificador percorre controles reais da cena, as duas habilidades,
marcação de alvo, alvo inválido, assistência ligada/desligada sem apagar
evidência, cancelamento por novo alvo, chegada física, bloqueio de prêmio
prematuro/repetido, atualização Q sem recurso físico, selo e gráfico,
reinício confirmado/cancelado, bebida física, limpeza da seleção, larguras
na janela mínima, save v6 completo, cancelamento por diálogo e recusa hídrica
no save legado. Mantém as verificações E1/E2 e demais fluxos da UI.

[FATO] A suíte completa cobre os saves v1–v6, incluindo migrações idempotentes,
fixtures antigas e continuidade determinista E3. O verificador de selo usa
cinco tentativas reais com alvo próximo para testar apresentação do contrato;
isso não é evidência de generalização. A evidência de eficácia e seus limites
permanecem no relatório [E3-SIM](E3_sim.md).

## Capturas novas e inspeção

[FATO] Capturas geradas pela cena real e abertas para inspeção, em 1100×680
(janela mínima); benchmark em 1280×720. Textos em pt-BR, rótulos quebram linhas
dentro do painel e as três abas principais cabem sem corte horizontal. Texto
claro sobre verde escuro e alvos amarelos mantiveram contraste legível na
inspeção local. Conteúdo longo usa uma rolagem vertical visível; as capturas
de evolução/eventos mostram a parte inferior, acessível sem console.

| Captura | Inspeção |
|---|---|
| [E3-rota.png](E3-rota.png) | Alvo e direção tracejada, ASSISTÊNCIA, selo Ainda não aprendeu, prêmio bloqueado. |
| [E3-conclusao.png](E3-conclusao.png) | Conclusão física, 36 passos assistidos e prêmio habilitado; selo continua sem aprendizado. |
| [E3-recompensa.png](E3-recompensa.png) | Recibo de 36 updates, prêmio bloqueado depois de usado e aviso sobre recursos. |
| [E3-observar.png](E3-observar.png) | Nova tentativa sem guia, alvo marcado e zero ações assistidas. |
| [E3-aprendizado.png](E3-aprendizado.png) | Selo observado vindo da API após cinco tentativas autônomas reais. |
| [E3-evolucao.png](E3-evolucao.png) | 80% (4/5), seis sessões/tentativas totais, curva e antes 75% → agora 80%. |
| [E3-agua.png](E3-agua.png) | Região física, bebida +35, habilidade concluída e recompensa registrada. |
| [E3-eventos.png](E3-eventos.png) | Eventos com ação e resultado traduzidos, mais recentes primeiro. |
| [E3-reiniciar.png](E3-reiniciar.png) | Confirmação nomeia Mel, explica o escopo e oferece manter treinamento. |
| [E3-ajuda.png](E3-ajuda.png) | Tutorial de ensino completo, com rolagem e botão Fechar dentro da janela. |
| [E3-fps-12.png](E3-fps-12.png) | Jardim gráfico com 12 criaturas e amostra de quadros reais. |

[FATO] As capturas de ensino usam fixture explícita: novo mundo com uma
criatura, terreno aberto, sem comida, rochas ou reprodução. Não deslocam o
corpo. O alvo é marcado a 120 unidades na direção do centro; Mostrar executa
a física real até o desfecho. Água é colocada a 70 unidades e hidratação
inicial ajustada para 65 antes da tarefa. A captura de evolução recompensa a
demonstração e executa cinco tentativas autônomas com alvos 40 unidades à
frente da orientação atual; houve quatro sucessos e um timeout, todos reais.
Esses alvos próximos/terreno aberto são fixture visual, não teste de eficácia.

Reprodução das capturas, substituindo `godot` pelo executável informado:

```powershell
godot --path . -- --capture=reports/E3-rota.png --capture-state=e3-route --capture-minimum
godot --path . -- --capture=reports/E3-conclusao.png --capture-state=e3-success --capture-minimum
godot --path . -- --capture=reports/E3-recompensa.png --capture-state=e3-reward --capture-minimum
godot --path . -- --capture=reports/E3-observar.png --capture-state=e3-observe --capture-minimum
godot --path . -- --capture=reports/E3-aprendizado.png --capture-state=e3-learned --capture-minimum
godot --path . -- --capture=reports/E3-evolucao.png --capture-state=e3-history --capture-minimum
godot --path . -- --capture=reports/E3-agua.png --capture-state=e3-water --capture-minimum
godot --path . -- --capture=reports/E3-eventos.png --capture-state=e3-events --capture-minimum
godot --path . -- --capture=reports/E3-reiniciar.png --capture-state=e3-reset --capture-minimum
godot --path . -- --capture=reports/E3-ajuda.png --capture-state=help --capture-minimum
godot --path . -- --fps-benchmark=12
```

## Limites

[LACUNA] Inspeção visual local, sem estudo de usabilidade, medição formal de
contraste ou revisão independente. O selo expressa o critério do simulador
sobre histórico limitado; tarefas fáceis ou repetidas não comprovam transferência
para outros corpos, obstáculos ou recursos ocultos. Alternar Observar após
Mostrar não elimina assistência anterior; inicie outra tentativa para obter
amostra totalmente autônoma. Aprendizado permanece individual e não é herdado.

[LACUNA] O painel usa rolagem para gráfico, comparação e eventos. A linha de
assistência não desenha uma rota navegável completa por obstáculos; indica a
direção declarada e o modo assistido real. Não há localização de água além da
percepção. Saves sem sede recusam Buscar água, preservando o legado.

[HIPOTESE] O fluxo e o benchmark local sugerem viabilidade do jardim padrão
nesta máquina; uma amostra não garante FPS em outras máquinas ou populações.
Integração no branch do coordenador e revisão independente cabem ao coordenador.
