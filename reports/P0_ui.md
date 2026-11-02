# P0 — convivência com um pet

[FATO] Trabalho iniciado em `efb7810`, na branch `Yurtachi/evo4-p0-ui`, derivada de `evo4/pet`. Escopo: `scripts/ui`, `scripts/render`, `scripts/core/textos.gd`, README e estas evidências. Nenhum arquivo do motor, criatura, mente ou persistência foi editado pela UI; nenhum avaliador fechado foi executado.

[FATO] A abertura entra diretamente na convivência, com um pet, reprodução desligada, acompanhamento suave e zoom automático calculado a partir do tamanho do genoma. Arrastar libera a câmera; rolar ajusta o zoom; Observar de perto retoma o acompanhamento. Redimensionar preserva o acompanhamento quando ativo.

[FATO] O painel reúne quatro necessidades físicas, humor aparente e ação atual em pt-BR. Alimentar coloca comida pela API, Oferecer água coloca uma região física próxima e Brincar oferece atenção pela interação existente; essas ações não repõem reservas ou movem o corpo diretamente. Fome e energia compartilham a mesma reserva; Descanso é `1 - fatigue`, explicitado nas ferramentas.

[FATO] Modificar ambiente e Ferramentas abrem Ambiente, Atividades, Ensino e Laboratório científico. Os controles legados foram realocados, preservando ateliê, galeria, biblioteca, diálogo, terminal, ensino, expansão, sensores, ablações e inspeção científica. Ateliê, livros e terminal são objetos opcionais, ausentes do mundo inicial; clicar nesses objetos abre sua atividade, e clicar em um alimentador abre os controles desse alimentador, preservando a seleção do pet. Novo mundo oferece convivência com um pet e ecossistema avançado com população configurável.

[FATO] O corpo procedural tem silhueta arredondada, orelhas, patinhas, cauda curta curvada, focinho, olhos com piscar e direção do olhar. As patas e o balanço acompanham ações de deslocamento; fome afeta a boca, sede acrescenta uma gota, fadiga abaixa as orelhas/pálpebras, afeto dominante altera expressão, comer/beber têm gestos próprios e repouso com fadiga fecha os olhos. Tamanho e matiz vêm do genoma; não há sorteio de forma ou humor. Piscar e balanço usam o passo da simulação e congelam na pausa.

[HIPOTESE] A silhueta frontal com orelhas, patas e focinho comunica companhia com mais clareza que o corpo anterior com cauda triangular. A inspeção visual própria confirmou essa leitura e expressões distinguíveis; não foi realizado teste com jogadores.

[FATO] O tutorial inicial tem três passos sobre observar, oferecer comida/água e brincar/descobrir. O botão Primeiros cuidados recolhe e reabre o cartão. Na largura mínima, o cartão não cobre o pet e as ações e modos de alimentação cabem sem rolagem; essas condições também são verificadas automaticamente.

## Verificação e imagens

[FATO] Antes da integração, `godot --headless --path . -s tests/run_tests.gd`: **25 suítes ok, exit 0, nenhum diagnóstico `SCRIPT ERROR:`**. Depois da integração: **26/26 suítes ok, exit 0**, incluindo `test_sim_p0.gd`, sem diagnósticos `SCRIPT ERROR:` ou `ERROR:`. A frase de sucesso de um teste contém literalmente “sem SCRIPT ERROR”; ela não é um diagnóstico. `godot --headless --path . -s scripts/ui/verify_ui.gd`: **exit 0, Integração da UI: ok**, preservando verificações antigas e acrescentando abertura direta, pet único, laboratório oculto, quatro necessidades, modos, estoque físico, controles de alimentador, criação explícita de ecossistema avançado e limites visuais em 1100×680.

[FATO] Log durável do último ciclo anterior ao commit: [P0_ui_tests.txt](P0_ui_tests.txt). Nenhum JSON histórico de `reports` foi alterado; `P0-fps.json` é uma medição nova. Commit local seletivo, identidade Yurtachi, sem push ou trailers de IA.

[FATO] Capturas gráficas novas com Godot 4.7.2, GL Compatibility e janela 1280×720; a captura mínima usa 1100×680. São cenas controladas de debug, não avaliações científicas: as condições iniciais de fome, hidratação e fadiga são preparadas e a ação é obtida pelas regras do simulador. A investigação usa contato físico aceito por `interact_object`, sem escrever `last_action` na UI. O genoma do pet inicial é preservado nas cenas controladas.

| Captura | Evidência |
|---|---|
| [P0-inicial.png](P0-inicial.png) | Convivência, pet grande, tutorial e ações |
| [P0-alimentando.png](P0-alimentando.png) | Ação real `eat`, boca e patas |
| [P0-bebendo.png](P0-bebendo.png) | Ação real `drink`, água e gesto de beber |
| [P0-dormindo.png](P0-dormindo.png) | `rest` com fadiga alta, olhos fechados |
| [P0-investigando.png](P0-investigando.png) | Contato real, ação `investigate_object` e entusiasmo registrado |
| [P0-expressoes.png](P0-expressoes.png) | Déficits físicos, orelhas e pálpebras abaixadas |
| [P0-ferramentas.png](P0-ferramentas.png) | Menu contextual com funcionalidades preservadas |
| [P0-alimentador.png](P0-alimentador.png) | Alimentador físico funcionando, modo feeder, estoque 40 → 39 e comida colocada |
| [P0-minimo.png](P0-minimo.png) | Janela mínima e enquadramento |
| [P0-fps.png](P0-fps.png) | Gráfico de quadros durante execução gráfica |

[FATO] Inspeção visual própria das capturas: títulos e botões em pt-BR, necessidades com contraste, rosto legível, quatro ações principais visíveis, ferramenta científica fora da convivência. Foram corrigidos acentos, cobertura parcial do pet pelo tutorial na largura mínima, modos cortados e excesso de vegetação. O corpo deixou de usar a cauda triangular e o rosto lateral do desenho anterior.

[FATO] Medição gráfica do preset integrado, sem outra captura ou suíte simultânea: 1 pet com mente, 3 objetos, 1 quadro, 1 livro, 1 terminal, 1×, NVIDIA GeForce RTX 2050, 1280×720, Windows, aquecimento de 2 s e janela de 8,003533 s. **1041 quadros, média 130,07 FPS, p95 de quadro 10,206 ms**. Dados em [P0-fps.json](P0-fps.json). Esses objetos adicionais pertencem apenas à carga do benchmark; não ao mundo inicial. O gráfico usa deltas reais de renderização; o número de uma captura recém-aberta não substitui essa medição.

## Integração e limites

[FATO] O coordenador autorizou integrar `evo4/pet` em `6f12c7a`; a atualização foi por fast-forward, sem duplicar commits e sem conflito com os arquivos da UI. `pet_world_adapter.gd` agora chama diretamente a API P0-SIM: `new_pet_world`, `new_ecosystem_world`, `set_feeding_mode`, alimentadores e leitura do modo persistido. A abertura usa o preset de pet, sem população explícita antiga; o ecossistema usa a entrada avançada própria. Saves antigos continuam carregando suas populações e estados pelo motor.

[FATO] Alimentador integrado e verificado pela UI real: colocação física, reposição de 20 porções, liga/desliga e mudança exclusiva entre Manual/Alimentador/Ecossistema. O painel mostra tipo de comida, intervalo em segundos, capacidade local e estoque do registro do mundo. A captura usa intervalo controlado de 10 passos; depois de dez passos o estoque passou de 40 para 39, foi colocado um alimento e o modo permaneceu `feeder`. Não há estoque ou distribuição simulados no apresentador.

[LACUNA] “Parece dormir” é uma interpretação visual do repouso com fadiga, não um novo modelo fisiológico de sono. A interação Brincar reutiliza atenção do cuidador; não acrescenta brinquedo ou habilidade. A inspeção visual e as suítes verificam comportamento e apresentação, não consciência, sentimento, linguagem emergente ou competência científica nova.
