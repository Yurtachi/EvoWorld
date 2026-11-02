# M3c — UI de biblioteca, conhecimento e perguntas

[FATO] Trabalho na branch local `Yurtachi/evo3-m3c-ui`, base `evo3/integration` em `74eae56`, Godot 4.7.2 console. Foram lidos `docs/EVOWORLD_3_SPEC.md`, `reports/M3c_biblioteca.md`, `reports/M4a_terminal.md` e `reports/review_m3.md`. A entrega altera somente UI, render, catálogo de textos, README e estes artefatos de UI; não altera biblioteca, mente, mundo, criaturas, persistência, terminal ou ateliê.

## Comportamento entregue

[FATO] **Livro**, na segunda linha do rodapé, abre catálogo fixo com três títulos e descrições em pt-BR. Confirmar escolhe a ferramenta; clicar no jardim chama `world.place_book(pos, book_id)`. O render desenha livros de `world.library.books` com ícone original de livro aberto e identificador. Não lê arquivos externos nem importa prosa livre.

[FATO] A Convivência consulta `creature.knowledge_snapshot()`, sem criar fatos pela apresentação. Mostra aproximação quando a ação real é `seek_book`, página e progresso durante `read_book`, páginas concluídas e quantidade de fatos daquele título ainda retidos. Usa “Parece interessada em ler” durante a ação e “Última leitura registrada” depois; uma página observada sem fato retido não é descrita como conhecimento adquirido. A seleção sem mente e a seleção vazia não reutilizam os registros da anterior.

[FATO] **Conhecimento · fatos e fontes** mostra conteúdo operacional, FONTE, CONFIANÇA do fato, passo de registro, validade e EVIDÊNCIA física versus HIPÓTESE/afirmação atribuída. Formata as fontes observado, interagido, livro com título/página, cuidador e inferido. A credibilidade histórica das fontes é mostrada separadamente; não é a mesma medida que a confiança do fato. Fonte de livro abaixo da confiança inicial, com tolerância numérica, recebe aviso de perda de credibilidade por experiência contraditória. A evidência posterior permanece separada da afirmação original do livro.

[FATO] Perguntas de `world.pending_questions` aparecem sem popup automático na Convivência, identificando criatura, objeto, categoria percebida e passo. A pergunta da seleção tem prioridade; quando é de outra criatura, seu nome é explícito. As quatro opções fechadas chamam `world.responder_pergunta`: evitar, seguro, neutro e silêncio. A resposta aceita abre seu registro como “O cuidador disse”, fonte cuidador, confiança limitada e hipótese; recusa/expiração recebem recibo próprio. Ignorar encerra sem fato. A simulação continua na reprodução escolhida; os atalhos de câmera/reprodução ficam suspensos nos diálogos de catálogo/conhecimento.

[FATO] Conhecimento também apresenta os três glifos, sua confiança e associação conhecida ou insuficiente/expirada. A nota informa que são IDs discretos associados a categorias, sem escrita, leitura de imagens ou linguagem geral. A captura de associação conhecida usa duas demonstrações pela API real de `world.demonstrar_simbolo`; o painel do produto é uma consulta dessas associações, sem novo editor de demonstração de glifos.

[FATO] O Laboratório apresenta o X6 já registrado, com resultados restritos e limites, sem executar o avaliador. Oferece o mesmo conteúdo de fatos/fontes em seção expansível e explica o controle existente de memória. Desligar **Memória M1 ativa** marca os registros como históricos e desativa aquisição/uso pela API existente, sem apagá-los; ablação e livro sobrevivem ao save/load da UI. O tutorial agora tem sete etapas e um acesso direto **Roteiro · livro e dúvida**: Guia de pedras, leitura por iniciativa e depois objeto ainda desconhecido, pergunta possível e atribuição ao cuidador.

## Verificação

[FATO] `godot --headless --path . -s tests/run_tests.gd`: **23 suítes, exit 0**, sem FAIL ou SCRIPT ERROR. Executado integralmente durante a implementação e novamente antes do commit. Inclui os testes de biblioteca/save v12 e o terminal hostil da base; nenhum `*_eval` fechado foi invocado.

[FATO] `godot --headless --path . -s scripts/ui/verify_ui.gd` e `godot --path . -s scripts/ui/verify_ui.gd`: **exit 0**, `Integração da UI: ok`, sem SCRIPT ERROR na validação final. O verificador percorre botão Livro e catálogo, seleção de título, colocação real, aproximação e leitura por `world.step`, fato do livro com proveniência, contato aversivo com queda de confiança para 0,35, evidência física posterior, ablação/save/load, pergunta contextual, resposta atribuída, ignorar sem fato, glifo conhecido/desconhecido, limpeza por seleção e roteiro. Verifica tamanho do diálogo, quebra de texto, botão Livro e todas as quatro opções visíveis na janela mínima. Há regressão para não inventar perda de credibilidade por arredondamento de 0,80.

[FATO] `git diff --check` e `git diff --exit-code HEAD -- 'reports/*.json'` passaram antes do commit; JSON experimentais versionados permaneceram intactos, sem necessidade de restauração. O único JSON novo desta entrega é o benchmark gráfico de UI. Identidade local Yurtachi; commit seletivo, sem push, merge, trailers de IA ou código externo/GPL.

## Capturas novas e inspeção visual

[FATO] Todos os PNG abaixo foram gerados novamente pelo build atual, abertos e inspecionados. Os cenários usam a cena real, janela de **1100×680**, seed de inspeção **81303**, uma criatura curiosa/sociável, visão de 360°, reservas iniciais altas e mundo sem reprodução ou recursos concorrentes. O livro fica a 42 unidades; aproximação e páginas são produzidas por passos reais. Perguntas são preparadas por decisão com percepção real; resposta, contato e glifo passam pelas APIs reais. São preparos explícitos de inspeção, sem alegar vida livre ou nova medição de eficácia.

| Captura | Conteúdo inspecionado |
| --- | --- |
| [M3c-catalog.png](M3c-catalog.png) | Catálogo, descrição, confirmação e fechamento legíveis. |
| [M3c-approaching.png](M3c-approaching.png) | Livro separado do corpo; iniciativa e motivo em português. |
| [M3c-reading.png](M3c-reading.png) | Página 1/1, progresso 3/8, zero fatos antes da conclusão. |
| [M3c-question.png](M3c-question.png) | Lacuna contextual e quatro respostas visíveis, em duas colunas. |
| [M3c-answer.png](M3c-answer.png) | “O cuidador disse”, fonte cuidador, confiança 0,66 e hipótese. |
| [M3c-knowledge.png](M3c-knowledge.png) | Fato do livro, confiança 0,80, validade e fonte separada. |
| [M3c-contradiction.png](M3c-contradiction.png) | Afirmação do livro a 0,35 e evidência interagida a 0,95. |
| [M3c-sources.png](M3c-sources.png) | Rolagem até credibilidade 0,35 e aviso de contradição. |
| [M3c-symbols.png](M3c-symbols.png) | Anel associado com 0,60, outros glifos desconhecidos e limite explícito. |
| [M3c-lab.png](M3c-lab.png) | X6 com números do relatório original e limites científicos. |
| [M3c-ablation.png](M3c-ablation.png) | Controle de memória desligado e explicação da intervenção. |
| [M3c-tutorial.png](M3c-tutorial.png) | Etapa 7/7, apresentação de livro e rolagem do roteiro. |
| [M3c-fps-12.png](M3c-fps-12.png) | Cena gráfica com 12 criaturas e livro; leitura concluída registrada. |

[FATO] Não observei cortes horizontais, texto interno em inglês ou falta de contraste que impedisse a leitura dos controles novos. Textos longos de Conhecimento, Laboratório e tutorial têm rolagem explícita; o trecho que sai da área inferior reaparece ao rolar. A inspeção inicial encontrou a quarta opção abaixo da área inicial e um aviso falso de credibilidade por precisão: ambos foram corrigidos, verificados e recapturados. O corpo pode cobrir parte do livro durante a leitura, conservando sua identificação.

[LACUNA] A inspeção cobre os estados e o tamanho registrados, sem provar todo layout, nome personalizado, escala de sistema ou adaptador. Perguntas ficam no painel Convivência, portanto não são um alerta sobreposto ao Laboratório. O roteiro e a pergunta não garantem que todo temperamento vá ler ou perguntar; o motor permite silêncio/recusa. O painel exibe todos os fatos atualmente retidos, com rolagem, sem inventar histórico de fatos já esquecidos.

## FPS gráfico com livro

[FATO] Comando: `godot --path . -- --fps-benchmark=12 --capture=<caminho-absoluto>/reports/M3c-fps-12.png --capture-minimum`. Medição gráfica a 1×, dois segundos de aquecimento e oito segundos de coleta, processo de capturas já encerrado. Fonte: [M3c-fps-12.json](M3c-fps-12.json).

| Medida | Resultado |
| --- | --- |
| População inicial/final | 12 / 12 |
| Livros / objetos / quadros | 1 / 3 / 1 |
| Mentes ativas | 1, no pet |
| Janela / adaptador | 1100×680 / NVIDIA GeForce RTX 2050 |
| Quadros / coleta | 805 / 8,000589 s |
| Média | 100,62 quadros/s |
| p95 da duração de quadro | 13,556 ms |
| Passo final | 102 |

[LACUNA] Esta amostra mede 12 corpos com uma mente, não 12 mentes ativas nem todas as janelas de conhecimento abertas. Não há comparação pareada antes/depois, repetição de desempenho ou gate numérico; hardware, carga e sincronização influenciam o valor. O custo headless de 12 mentes no relatório de biblioteca é outra medida. [HIPOTESE] Populações com todas as mentes e muitos livros podem custar mais; precisam de benchmark gráfico próprio antes de extrapolação.
