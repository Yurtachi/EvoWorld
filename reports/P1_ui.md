# P1 — lugares lembrados e polimento da convivência

[FATO] Base `evo4/pet` em `5d78967`, branch local `Yurtachi/evo4-p1-ui`, Windows, Godot 4.7.2 console / GL Compatibility. Escopo: `scripts/ui`, `scripts/render`, `scripts/core/textos.gd`, README e evidências deste relatório. Nenhum arquivo de world, creature, mind, spatial ou persistence foi editado; nenhum avaliador fechado foi executado. Commit seletivo local, identidade Yurtachi, sem push, merge ou trailers de IA.

## Camada de memória e fronteira dos dados

[FATO] **Lugares que lembra** começa desligado na Convivência. `spatial_presenter.gd` recebe somente `creature.spatial_snapshot()`, os sensores atuais e o estado de ativação/ação. Não recebe referência ao mundo. Anéis dourados para comida e azuis para água vêm exclusivamente dos lugares desse snapshot; a opacidade é `0,24 + 0,70 × expectativa × confiança`. Não há localização de comida oculta adicionada pelo apresentador. A linha tracejada usa exclusivamente a posição do objetivo lembrado e aparece durante `seek_place`/`inspect_place`, com a memória ativa.

[FATO] Losangos claros vêm de `world.sense(creature, false)`, nunca de uma lista direta de recursos. A cena física continua desenhando seus próprios alimentos e lagos. A legenda distingue **lembrado**, **percebido agora** e **o mundo físico**, inclusive quando há lembrança de água em chão agora vazio ou comida física sem anel de memória. Rótulos mantêm tamanho de tela e evitam colisão entre si; marcadores fora da região útil são omitidos. Atualização da consulta visual em até 100 ms; ferramentas e interruptor atualizam imediatamente. A leitura não ensina, move ou alimenta o pet.

[FATO] O painel simples mostra **Procura comida onde costuma achar** ou a variante de água, com a justificativa registrada. Essa linha continua disponível com o mapa desligado. A câmera em acompanhamento inclui o pet e o alvo lembrado quando a camada está ligada; arrastar/rolar conserva os controles anteriores. Nenhuma expressão procedural do corpo foi substituída.

[FATO] O início do Laboratório científico mostra expectativa, confiança, encontros, achados, falhas e idade da última evidência. Explica que encontros incluem observações e que confiança decai sem evidência; o prazo de esquecimento é 36.000 passos. **Memória espacial ativa** altera somente `mind.spatial.enabled`, preservando lugares e corpo; o estado persiste no save v16. O controle Memória M1 também precisa estar ativo. Pets de saves antigos têm ativação explícita por `creature.enable_spatial_memory()`.

## Primeira experiência e apresentação

[FATO] O tutorial passa por colocar comida repetidamente no mesmo ponto, observar retorno por iniciativa e retirar comida para observar revisão. **Modificar ambiente → Retirar comida neste ponto** remove alimentos físicos num raio de 18 unidades, sem editar expectativa. O motor continua responsável por perceber, inspecionar e registrar falhas; alimentadores precisam estar desligados/retirados para não repor o local.

[FATO] O cartão ocupa uma faixa larga a partir de y=150, abaixo da dica de controle; na janela mínima ele cresce para acomodar a quebra de linhas. A câmera centraliza o pet no espaço restante. Necessidades, ações, modos, motivo de busca e interruptor cabem na Convivência mínima sem rolagem. O zoom próximo foi reduzido de até 6× para até 4,4× para mostrar mais entorno. Terreno recebeu cor mais clara; vegetação usa folhas com caule, nervura e sombra opacos; fruta ganhou contorno, brilho e folha; água usa tons claros e margem definida.

[FATO] Vegetação, comida, rochas e água só são desenhadas quando seu contorno cabe na região livre do habitat. Isso impede meias frutas e lagos cortados pelas bordas/cartão; não muda os recursos físicos ou os sensores. [LACUNA] Ao arrastar a câmera, um recurso na borda pode aparecer/desaparecer inteiro; recursos muito grandes podem exigir afastar a câmera. Objetos opcionais mantêm seu desenho anterior.

[HIPOTESE] Fruta com brilho e contorno, plantas mais sólidas e margem clara da água tornam os recursos mais distinguíveis do chão e das marcas de memória. A inspeção visual própria confirmou legibilidade nas capturas abaixo; não houve teste com jogadores.

## Capturas novas e inspeção própria

[FATO] Todas as imagens foram abertas e inspecionadas após a captura. Godot gráfico real, 1280×720, exceto os dois mapas comparados e a captura mínima, em 1100×680. O par ligado/desligado conserva estado e câmera. São cenas controladas de apresentação, não resultados de uma nova avaliação científica.

| Captura | Evidência conferida |
|---|---|
| [P1-inicial.png](P1-inicial.png) | Preset real de abertura, tutorial separado da dica, pet e fruta inteiros |
| [P1-polimento.png](P1-polimento.png) | Fruta brilhante, semente distinta, água clara, plantas nítidas e rosto preservado |
| [P1-minimo.png](P1-minimo.png) | Tutorial com quebra de linhas, rosto e controles inteiros em 1100×680 |
| [P1-memoria-ligada.png](P1-memoria-ligada.png) | Anéis de água/comida em lugares vazios, losango em fruta recém-percebida, outra fruta física sem marca; cuidados sem rolagem |
| [P1-memoria-desligada.png](P1-memoria-desligada.png) | Mesmo estado/câmera sem anéis, losango ou legenda; motivo de busca preservado no painel |
| [P1-procurando.png](P1-procurando.png) | Ação real `seek_place`, linha tracejada até o lugar lembrado, painel com motivo |
| [P1-expectativa-menor.png](P1-expectativa-menor.png) | Anel mais fraco, três buscas sem achado, ação real de explorar, sem linha de busca ativa |
| [P1-laboratorio.png](P1-laboratorio.png) | Controle de ablação e detalhe de evidências/esquecimento no início do Laboratório |
| [P1-fps.png](P1-fps.png) | Gráfico de quadros e resumo da medição, camada de memória ligada |

[FATO] A preparação visual usa o pet do preset 7421, oito ingestões físicas de fruta em um local e três bebidas reais em outro. Depois posiciona o corpo para uma partida de demonstração e chama `world.step()` para produzir a ação; não escreve `last_action` nem fabrica lugares. A cena de revisão realiza três inspeções vazias de 18 passos, separadas por 600 passos de preparação para atravessar os intervalos. A expectativa de comida passa de **0,990989 para 0,148594**, com três falhas reais. Recursos físicos são colocados após o passo para mostrar percepção recente separada de lembrança; o próximo passo pode mudar a escolha do pet.

[LACUNA] Essa cena preparada não mede rapidez espontânea de abandono. O resultado científico P1 permanece **PARTIAL**: o critério H-B não passou no horizonte original, conforme [P1_memoria_espacial.md](P1_memoria_espacial.md) e [review_p1.md](review_p1.md). Não foram alterados cooldowns, política ou estimadores, nem reaberto o holdout.

## Verificação e desempenho

[FATO] Antes do commit, `godot --headless --path . -s tests/run_tests.gd`: **27/27 suítes, exit 0**; `godot --headless --path . -s scripts/ui/verify_ui.gd`: **Integração da UI: ok, exit 0**. Nenhum diagnóstico `SCRIPT ERROR:` ou `ERROR:` nos logs finais. O teste de robustez imprime a frase de sucesso “87 casos sem SCRIPT ERROR”; isso não é um diagnóstico. Nenhum JSON histórico de `reports/` foi modificado pela suíte.

[FATO] `verify_ui.gd` preserva suas verificações anteriores e acrescenta: camada desligada na abertura; limites do tutorial e da dica; busca real com memória; leitura sem mutação; marcas somente dos lugares lembrados; percepção separada; invariância a comida/alimentador ocultos; retirada sem revisão instantânea; ablação sem perda do histórico/corpo; persistência da ablação; controles visíveis em largura mínima; intensidade menor após inspeções vazias; detalhe de esquecimento e ativação de memória para saves antigos. Logs finais: [P1_ui_tests.txt](P1_ui_tests.txt) e [P1_ui_verify.txt](P1_ui_verify.txt).

[FATO] Medição gráfica isolada, sem outra suíte ou captura simultânea: Windows, NVIDIA GeForce RTX 2050, GL Compatibility, 1280×720, velocidade 1×, 1 pet com mente, 3 objetos, 1 quadro, 1 livro, 1 terminal, camada ligada e 5 lugares lembrados ao terminar. Aquecimento de 2 s; **1.322 quadros em 8,000718 s; média 165,24 FPS; p95 de quadro 8,243 ms**. Dados novos em [P1-fps.json](P1-fps.json). O gráfico usa deltas de renderização reais; seu valor instantâneo na imagem não é a média da janela.

[LACUNA] A medição cobre essa carga e esse hardware, não 64 lugares visíveis nem populações grandes; não demonstra ganho causal sobre P0, pois a cena/câmera são diferentes. Os JSON históricos de `reports/` permanecem intactos; somente o novo `P1-fps.json` foi criado para esta evidência.
