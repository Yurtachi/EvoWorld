# E1-UI — cuidado, água, alimentos e expansão

Status: **PASS no escopo de integração UI/render E1**. Relatório de 01/11/2026, pt-BR.

## Base e limites de ownership

[FATO] Branch `Yurtachi/evo2-e1-ui`, baseada em `evo2/e1-base` @ `38723ae`, já contendo E1-SIM. Identidade Git local: Yurtachi. Alterações restritas a `scripts/ui/`, `scripts/render/`, `scripts/core/textos.gd`, `README.md` e evidências/relatório `reports/E1-*`/`reports/E1_ui.md`. Sem push, operação destrutiva de Git ou trailers de IA.

[FATO] Lidos `docs/EVOWORLD_2_SPEC.md`, `reports/E1_sim.md` e `reports/ui2.md`. A UI consome os contratos existentes; não houve edição de world, creature, behavior, environment, evolution ou communication. Nenhum código, texto, peso ou asset do Pestinha foi copiado. Água, ícones e formas de alimentos são desenhos próprios; `water.png` não é carregado. Terreno/rocha Kenney CC0 existentes permanecem.

## Comportamento integrado

- **Novo mundo:** `create_world` chama `SimWorld.new_world` com o valor explícito do seletor. Padrão novo de 12 criaturas, três águas, quatro tipos alimentares e companheiro nomeado. Preferência de população já configurada continua prevalecendo. Carregar usa o caminho existente do SaveStore e não repovoa o mundo.
- **Água:** regiões de `world.waters` são desenhadas em azul com margem e pequenas linhas de superfície. Não são textura de terra. Um evento `drink` com hidratação positiva produz gota, anel e “Bebeu +…” por dois segundos de simulação. A indicação deriva do evento real, inclusive com mundo pausado após o passo observado.
- **Alimentos:** quatro botões com ícones, formas e cores diferentes: fruta coral circular, semente amarela alongada, folha verde e cogumelo lilás com haste. Selecionar o tipo atualiza plantio, oferta e o perfil do catálogo canônico. Cogumelo exibe aviso de toxicidade.
- **Oferta:** botão do Cuidador chama `world.oferecer_alimento(selected_id, food_type)`. O recibo inicial informa ID/destinatário/tipo e espera. Aproximação exige redução medida de distância; refeição exige evento `eat` com mesmo ID de alimento/destinatário e ganho positivo. Desaparecimento sem esse evento é explicitamente inconclusivo. Bebida entra apenas com ganho positivo. Colocar alimento não escreve energia, hidratação ou posição e não impõe aceitação.
- **Recibos:** histórico temporário de até 32 entradas, com quatro entradas recentes visíveis e rolagem normal do Cuidador. Reinicia ao criar/carregar. Bebidas históricas já presentes no save não são apresentadas como novas intervenções da sessão.
- **Expansão:** confirmação com direita/inferior, quantidade, tamanho atual/resultante, área, custo **zero** e limite de **100.000 por eixo**. O contrato E1 não tem moeda; não se inventou débito. Confirmar chama `world.expand`, preserva entidades/IDs/RNG e reenquadra a câmera. Expansões inválidas são bloqueadas. O zoom comporta o limite; detalhes de terreno menores que pixels são omitidos para evitar milhões de ladrilhos em vistas gerais.
- **Inspector:** energia, hidratação/sede quando ativas, idade, último evento próprio, perfil/palatabilidade do alimento escolhido, alertas de sede e toxicidade. O perfil informa que não existe preferência individual registrada nesta etapa. Saves antigos mostram fisiologia de sede desativada, preservando a semântica antiga.
- **Cuidador:** nomes legíveis e clicáveis, seleção por corpo e lista de nomes, oferta e informações de cuidado. Genes detalhados ficam no Laboratório. Rótulos que colidiriam são omitidos priorizando a seleção. Acima de 30 criaturas, a vista geral mostra nomes só do companheiro/seleção; zoom aproxima os demais e a lista permanece completa.
- **Laboratório:** toggle, genealogia, mutações, curvas, sinais e custos reais continuam funcionando. O tutorial em pt-BR foi atualizado em seis passos e explica sede, quatro alimentos, oferta, expansão, saves e proteção.
- **FPS:** mini gráfico das últimas 120 durações de quadro na barra inferior. O comando de medição abre a cena real a 1× e registra quadros apresentados, população final, média e p95, sem headless e sem acessar preferências ou saves pessoais.

## Verificação automatizada

Executável: `C:/Users/Yurtachi/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe`.

| Comando, no root | Saída | Evidência |
|---|---:|---|
| `godot --headless --path . -s tests/run_tests.gd` | 0 | 11 suítes verdes, incluindo E1-SIM e textos; sem SCRIPT ERROR |
| `godot --headless --path . -s scripts/ui/verify_ui.gd` | 0 | Cena real, controles, persistência, idioma e novos percursos E1 |
| `git diff --check` | 0 | Sem erros de whitespace |

[FATO] O verificador da UI mantém os percursos anteriores de conversa, laboratório, sinais, proteção, configuração e autosave. Acrescenta padrão de 12/três águas/quatro tipos; plantio tipado pelos quatro botões; água pela ferramenta; seleção por lista/nome; confirmação/custo/limite de expansão; snapshot completo conservado exceto tamanho; enquadramento próximo ao limite; oferta sem ganho imediato seguida de aproximação e ingestão reais; bebida física; avisos e formatadores E1; ingestão ao alcance com ganho zero sem recibo de refeição; migração da fixture v3 real e carregamento com três criaturas e sede desativada; gráfico com amostras; botões e diálogos na janela mínima de 1100×680. A fixture de ganho zero move o alimento ao alcance e chama o executor físico; não fabrica evento de refeição.

## Capturas novas e revisão visual

Todas foram produzidas pelo Godot gráfico, com a cena e os controles reais. Comandos exatos de reprodução no README.

| Arquivo | O que comprova |
|---|---|
| `E1-12-criaturas-agua.png` | Jardim inicial pausado: 12 corpos/nomes, três águas, população e companheiro reais |
| `E1-4-alimentos.png` | Quatro ícones/tipos e toxicidade do cogumelo em 1100×680 |
| `E1-expandir-antes.png` | Confirmação de direita +300, área, custo e limite antes da alteração |
| `E1-expandir-depois.png` | Resultado 1500×960 após direita +300 e inferior +200; câmera ajustada |
| `E1-oferecer-alimento.png` | Oferta #109, bebida +35, distância 16,7→13,4 e ingestão +24, com passos reais |
| `E1-agua-bebendo.png` | Criatura visível na água com “Bebeu +35”, hidratação e último evento confirmados |
| `E1-inspector.png` | Energia, hidratação/sede, aviso de sede, último evento, palatabilidade e toxicidade |
| `E1-novo-mundo.png` | Formulário mínimo com nomes, semente e população 12 editável |
| `E1-ajuda.png` | Tutorial atualizado completo no tamanho mínimo |
| `E1-laboratorio.png` | Laboratório mantido após evolução natural até passo 1200 |
| `E1-fps-12.png` / `E1-fps-30.png` | Gráfico e medição em execução com as duas populações |

[FATO] Inspecionadas as imagens novas para quebra/corte de texto, inglês e contraste. Os quatro alimentos e as confirmações cabem na largura mínima; o tutorial e formulário cabem na altura mínima; o perfil e os alertas quebram linhas. Corrigidos a altura da barra inferior, o texto do gráfico atravessado pela curva e a sobreposição dos nomes. Painéis laterais têm rolagem deliberada para acessar conteúdo excedente; não há corte horizontal dos controles. Os nomes junto às bordas da câmera podem sair da vista ao aproximar, como o próprio terreno. Texto do jogador em pt-BR; nomes próprios e marca preservados.

[FATO] `e1-offer`, `e1-water` e `e1-inspector` são **fixtures explícitas**, não uma alegação de comportamento espontâneo do mundo inicial: reduzem reservas para mostrar a física sem esperar muitos minutos e colocam água junto da criatura; oferta/inspector removem alimentos concorrentes. Não deslocam criaturas. Aproximação, bebida e ingestão acontecem por `world.step`, eventos e ganhos reais. O cenário inspector rebaixa hidratação depois do passo físico para exibir o alerta. O jardim padrão e os benchmarks não recebem essas manipulações. A captura de laboratório avança naturalmente; nascimentos/genomas não são forçados.

## Medição gráfica

```powershell
godot --path . -- --fps-benchmark=12
godot --path . -- --fps-benchmark=30
```

[FATO] Windows, Godot 4.7.2, OpenGL Compatibility, NVIDIA GeForce RTX 2050, janela 1280×720, seed 7421, velocidade 1×. Aquecimento de 2 s e coleta de aproximadamente 8 s; automático/preferências desativados só no cenário de evidência. Última execução registrada:

| População inicial/final | Quadros | Média (quadros/s) | p95 de quadro (ms) | Coleta (s) |
|---|---:|---:|---:|---:|
| 12/12 | 888 | 110,94 | 12,097 | 8,005 |
| 30/30 | 620 | 77,38 | 19,485 | 8,012 |

Dados brutos: `E1-fps-12.json` e `E1-fps-30.json`. O comando termina após a captura e retorna 0. O gráfico mede cadência de quadros; não mede eficácia de política, aprendizado ou estabilidade ecológica. Carga do computador e sincronização da janela afetam resultados; não há promessa de FPS para outros equipamentos nem gate de desempenho previamente definido.

## Limites e continuidade

[LACUNA] Não existe preferência alimentar individual nesta etapa; a UI apresenta apenas a palatabilidade canônica disponível. Não existe moeda para cobrar expansão. Água colocada em saves legados não ativa retroativamente a sede. Recibos e amostras de FPS são de sessão; eventos físicos e fisiologia continuam persistidos pelo simulador v4. A oferta não força a criatura a comer, e o estado de um QBrain pode recusar o alimento.

[FATO] Não foi declarada eficácia aprendida para água/alimentos nem equilíbrio ecológico. Não restam bloqueios no escopo UI E1; revisão independente e integração do commit pertencem ao coordenador.
