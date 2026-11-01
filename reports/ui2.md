# UI2 — integração de diálogo, laboratório e acabamento

**Status: concluído no escopo UI2 (parte visual de G4 e controles/documentação de G5).** Relatório de 01/11/2026, em português brasileiro. O benefício científico do canal de sinais não é declarado aprovado; o resultado negativo continua registrado em `reports/sinais.md`.

## Base e escopo

- Worktree: `C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo-ui3`.
- Branch: `Yurtachi/evo-ui3`; base inicial `56c4822`, atualizada por avanço direto de `main` até `43d9cca`, conforme instrução do coordenador, para integrar SINAIS/save v3.
- Identidade Git local preservada: Yurtachi. Sem push, reset destrutivo, remoção de arquivos de trabalho ou trailers de IA.
- Alterações próprias restritas a `scripts/ui/`, `scripts/render/`, `scripts/core/textos.gd`, `README.md`, `docs/` e novas evidências `reports/ui2-*`/este relatório. Nenhum arquivo de world, creature, behavior, communication ou evolution foi editado pelo worker UI2; as mudanças desses módulos vieram do avanço de `main`.
- Lidos arquitetura, missão e relatórios de simulação, aprendizado, evolução, diálogo, UI e idioma; o relatório SINAIS foi lido após sua integração.

## Implementação entregue

**Conversa:** painel com campo de texto/Enter/Enviar, exemplos de intenções e alvo marcado com o botão direito no jardim. Usa `Dialogo.interpretar/responder` e a instância persistente `world.comandos`. Mostra resposta, recibo e evidências do instante consultado: passo/ID, energia, fome, idade, ação/razão, IDs de alimento percebido e evento próprio recente, quando disponível. Entradas desconhecidas não inventam evidências. O alvo de seguir é restaurado do comando salvo antes do primeiro quadro; não é sobrescrito pela posição do companheiro após carregar.

**Laboratório:** toggle independente do Cuidador; genoma e seis genes, geração, nascimento, mutações reais, ancestrais e descendentes pelas APIs do módulo de evolução. Mortos continuam consultáveis pelo registro genealógico. Listas familiares mostram até 12 registros, com indicação de excedente. Resumo inclui população viva, geração máxima e totais permanentes de nascimentos/mortes. Eventos ecológicos recentes priorizam introduções/nascimentos/mortes, seguidos de até quatro alimentações recentes, sem deixar um fluxo de comida ocultar todos os eventos de ciclo de vida ainda presentes no buffer.

**Curvas:** até 180 amostras observadas, com intervalo de pelo menos 50 passos. População e diversidade têm escalas próprias e legenda com máximos. A diversidade da curva é a média das variâncias divididas pela amplitude de cada gene ao quadrado; os valores brutos por gene também aparecem. O histórico começa ao criar/carregar e não altera ou inventa dados científicos.

**Sinais:** leitura do contrato real de `signal_log`, incluindo símbolo, emissor, contexto, receptores e primeiras ações após recepção, todas traduzidas. Há ativação do canal, escolha de símbolo e emissão manual pela seleção, identificada como intervenção com custo real de energia. O log mostra até 20 emissões; IDs/reação por emissão são resumidos a 12, informando excedentes. Na ausência de API/eventos há gancho claro e eventos do simulador. A UI não atribui semântica humana ou causalidade a uma sequência temporal; decisões iguais antes/depois também são mostradas.

**Configurações e ajuda:** velocidade, população inicial de 1–100, proteção por pausa preventiva e autosave. Preferências são gravadas separadamente em `user://ui-settings.cfg`; menus de edição dos novos campos e SpinBox usam o catálogo pt-BR. O modo sobrevivência tem aviso explícito de morte por energia/idade, inclusive na UI de cuidado. A ajuda traz seis passos curtos e atalhos. O formulário inicial também passou a ter rolagem protegida e dimensões verificadas.

**Proteção:** a UI pausa antes de um passo com energia do companheiro ≤15% ou idade a um passo do limite. Não escreve energia/idade, não oferece imortalidade nem altera a biologia para mascarar risco. A mensagem explica a pausa, seu efeito sobre a observação ecológica e a necessidade de desligar a proteção para avançar sob essas condições; alimento colocado não é consumo instantâneo.

**Autosave:** ponto `autosave` separado do manual `world`, a cada 60 segundos quando houve avanço ou intervenção com o mundo pausado. Usa a validação, soma, temporários e cópia do `SaveStore` existente. Recuperação disponível nos Ajustes; carregar pausa e preserva o mundo aberto se falhar. Capturas desativam autosave e leitura/gravação de preferências pessoais; testes usam diretório exclusivo. A UI não adicionou campos ao schema do mundo: usa o save v3 com migração 2→3/1→2→3 do simulador integrado.

**Visual e textos:** cenário usa Kenney CC0, sem modificar arquivos/licenças: terreno discreto e recortes de vegetação (28,10) e pedra (54,21) do atlas original. A inspeção revelou nomes antigos incompatíveis com os sprites `apple.png`/`rock.png`; esses recortes não são usados. `docs/ASSET_PROVENANCE.md` registra as coordenadas corretas. Organismos permanecem procedurais e ligados aos genes. Corrigido `Avan?ar` para **Avançar**; acrescentadas traduções das ações `emit_signal_0..7`, razões `signal.*` e `dialogo.*`, sem traduzir identificadores ou chaves salvas.

## Validação

Motor: **Godot 4.7.2.stable.official.ed1daf0bf**, executável console fornecido no despacho. Execução gráfica em OpenGL 3.3 / NVIDIA GeForce RTX 2050.

| Comando/verificação | Resultado final |
|---|---|
| `godot --headless --path . -s tests/run_tests.gd` após integrar `main`/SINAIS | **exit 0**, nove arquivos `ok`, sem erros de script |
| `godot --headless --path . -s scripts/ui/verify_ui.gd` | **exit 0**, `Integração da UI: ok`, sem erros de script |
| Nove capturas gráficas novas, abertas e inspecionadas | **exit 0** em todas |
| `git diff --check` | **exit 0** |

Arquivos da suíte: `test_behavior_learn`, `test_dialogo`, `test_evolution`, `test_save_store`, `test_signal_channel`, `test_sim_review`, `test_sim_world`, `test_smoke`, `test_textos`.

O teste de UI exercita formulário/nomes/semente, ferramentas reais, seleção, câmera, pausa/5×, idioma, menus nativos e erro real de JSON inválido; consulta fundamentada sem alteração fisiológica; oferta de alimento; bloqueio de atalhos durante digitação; genealogia/mutações/descendentes; séries temporais; sinal emitido pela API com cobrança de energia e apresentação do log; instância compartilhada de comandos e execução física de seguir; proteção por energia e idade; aplicação de configurações; população inicial; autosave com mundo pausado, cópia anterior, preservação do manual e restauração exata; alvo persistente e primeiro quadro após carregar; todos os diálogos na janela mínima.

Durante o desenvolvimento houve falhas de compilação (`PackedStringArray.any`, inferência numérica e preload de PNG antes da importação), corrigidas antes das execuções finais. O teste ampliado e as capturas detectaram janelas largas/altas demais ao anexar rótulos antes de configurar quebra de linha; a criação dos rótulos e a rolagem foram corrigidas, incluindo o formulário inicial. Não houve erro de script nas execuções finais.

## Capturas novas do build integrado

| Estado | Arquivo | Resolução |
|---|---|---|
| Cuidador, aviso de proteção e cenário Kenney | [ui2-cuidador.png](ui2-cuidador.png) | 1280×720 |
| Resposta, recibo e evidências | [ui2-dialogo.png](ui2-dialogo.png) | 1280×720 |
| Diálogo com evidências na janela mínima | [ui2-dialogo-minimo.png](ui2-dialogo-minimo.png) | 1100×680 |
| Laboratório e séries reais | [ui2-laboratorio.png](ui2-laboratorio.png) | 1280×720 |
| Mutações, ancestrais e diversidade | [ui2-linhagem.png](ui2-linhagem.png) | 1100×680 |
| Emissão, receptores e decisões após recepção | [ui2-sinais.png](ui2-sinais.png) | 1100×680 |
| Ajustes e aviso explícito de sobrevivência | [ui2-ajustes.png](ui2-ajustes.png) | 1100×680 |
| Tutorial curto completo | [ui2-ajuda.png](ui2-ajuda.png) | 1100×680 |
| Novo mundo, população e botões completos | [ui2-novo-mundo.png](ui2-novo-mundo.png) | 1100×680 |

Todas foram obtidas pelo modo de captura da cena real, sem montagem/edição de texto. As telas do laboratório avançam naturalmente a semente 7421 até o passo 1200: 84 vivos, geração máxima 3, 74 nascimentos e seis mortes; a seleção #388 tem ancestrais #282, #177 e #90. Há 23 amostras efetivamente observadas na captura, com tempos reais no eixo; nenhuma população ou curva foi desenhada de forma roteirizada.

A captura de sinais faz uma emissão manual do símbolo 0 pela seleção #388 no passo 1200 e avança um passo: os receptores #189, #290, #418, #448 e #468 têm suas decisões registradas no passo 1201. As ações desse exemplo permaneceram iguais, fato mostrado na tela; não se afirma mudança ou benefício inexistente. O exemplo é uma intervenção, não prova de emergência.

Inspeção visual final: acentos e vírgulas corretos; resposta/evidências, ajuda, configurações e formulário com botões completos na resolução mínima; nenhum texto de jogador em inglês encontrado nos estados capturados. Painéis laterais mantêm rolagem para conteúdos extensos; o cabeçalho usa reticências para nomes muito longos. Os valores de quadros/s capturados com a simulação pausada não constituem benchmark.

## Limites e integração restante

Não há pendência de implementação dentro do despacho UI2. Cabe ao coordenador revisar e integrar o commit do branch, sem anunciar benefício científico do canal reprovado no experimento. A proteção é deliberadamente pausa preventiva da interface; executores externos/headless não ficam protegidos por essa preferência. As curvas são locais à sessão, eventos/logs e listas são limitados explicitamente, e o jardim padrão não passa a usar um cérebro treinado por abrir o Laboratório.
