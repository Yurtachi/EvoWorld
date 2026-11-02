# EvoWorld 3.0 (M0-C) — Estudo de Referências, Auditoria de Licenças e Matriz de Reuso

**Data da Auditoria:** 02 de novembro de 2026
**Responsável:** Worker M0-C (`REUSE`)
**Escopo:** Estudo técnico e jurídico **somente leitura** (com rede) de 8 referências externas para evolução do EvoWorld 3.0, sem download de repositórios inteiros ou datasets e sem edição de código-fonte.
**Documentos Correlatos:** [`ARCHITECTURE.md`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/docs/ARCHITECTURE.md), [`EVOWORLD_2_SPEC.md`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/docs/EVOWORLD_2_SPEC.md), [`PESTINHA_LICENCAS.md`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/docs/PESTINHA_LICENCAS.md), [`REUSE_MATRIX.md`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/docs/REUSE_MATRIX.md), [`ASSET_PROVENANCE.md`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/docs/ASSET_PROVENANCE.md).

---

## 1. Sumário Executivo (`[FATO]` / `[HIPÓTESE]` / `[LACUNA]`)

- **[FATO]** Foram inspecionados via API oficial do GitHub e leitura direta de cabeçalhos/arquivos remotos (sem clonagem local e sem download de datasets) os 8 projetos de referência estipulados para a fase M0-C: **Dosidicus**, **Pestinha**, **Pet Mochi**, **AI Town**, **HermitClaw**, **Sketch-RNN (`magenta/magenta`)**, **Quick Draw Dataset** e **OpenC2E**.
- **[FATO]** Três das referências possuem licenças da família GNU com efeitos de copyleft: **Dosidicus** (`GPL-2.0`), **Pestinha** (`GPL-3.0-or-later`, além de assets com direitos não confirmados) e **OpenC2E** (`LGPL-2.1-or-later`). Para todas as referências sob GPL/LGPL, estabelece-se a diretriz estrita: **proibido copiar, traduzir ou portar código, pesos ou assets; apenas conceitos científicos e padrões de arquitetura de alto nível podem ser reimplementados do zero em GDScript guiados pelos requisitos do EvoWorld (Clean-Room)**.
- **[FATO]** O repositório **HermitClaw** declara a licença `MIT` ao final de seu `README.md`, porém **não possui arquivo `LICENSE` dedicado** na raiz nem metadado SPDX detectável pela API do GitHub (`NO_SPDX_DETECTED`), além de conter um alerta crítico de segurança sobre execução de comandos shell e *monkey-patching* em Python que não constituem barreira real de isolamento.
- **[FATO]** Os repositórios **magenta/magenta** (`Apache-2.0`, commit `c15687ebd1` de 06/01/2026) e **googlecreativelab/quickdraw-dataset** (`CC BY 4.0`, commit `5fe6c0a910` de 11/03/2025) encontram-se oficialmente **arquivados** (*read-only*) no GitHub.
- **[FATO]** Nenhum arquivo externo, biblioteca ou dataset foi baixado ou incorporado à árvore do projeto nesta etapa. Todos os candidatos avaliados foram devidamente registrados em [`ASSET_PROVENANCE.md`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/docs/ASSET_PROVENANCE.md).
- **[HIPÓTESE]** A combinação de (a) rastreabilidade causal ação→consequência com margem sobre deriva basal, (b) recuperação de memória multicritério (`recência + relevância + importância + confiança`), (c) consolidação hierárquica em repouso e (d) portão de saliência com *cooldowns* em camadas permitirá ao EvoWorld 3.0 explicar cada mudança de comportamento ao jogador em linguagem natural fundamentada sem depender de LLM obrigatório nem quebrar o determinismo de [`SimWorld`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/scripts/world/sim_world.gd).
- **[LACUNA]** Caso o EvoWorld 3.0 decida futuramente incorporar um subconjunto estático de traços vetoriais do **Quick, Draw! Dataset** (`CC BY 4.0`) como vocabulário visual de rabiscos/glifos, será necessário curar manualmente as categorias desejadas (filtrando ruído ou desenhos inadequados moderados de forma imperfeita na origem) e exibir atribuição formal ao Google, Inc. na tela de créditos e em [`ASSET_PROVENANCE.md`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/docs/ASSET_PROVENANCE.md).

---

## 2. Análise Individual das Referências Inspecionadas

### 2.1 Dosidicus (`github.com/ViciousSquid/Dosidicus`)

- **[FATO] Licença Real Confirmada:** **GNU General Public License v2.0 (`GPL-2.0`)**, verificada no arquivo `LICENSE` na raiz do repositório e no metadado SPDX da API do GitHub.
- **[FATO] Data / Commit / Versão Inspecionada:**
  - Data da inspeção: `2026-11-02`
  - Branch padrão: `3.2.0_LatestVersion`
  - Commit HEAD inspecionado: `0b9357421e8c72e70864823519adffcec4b8eec1` (`2026-10-22T20:15:45Z` — *"Merge pull request #58 from ViciousSquid/codex/macos-dmg-installers"*)
  - Tags publicadas: `v3.1.0` (`d904db7`), `v3.0.0.0` (`73922ca`), `v2.18` (`5875c4d`).
- **[FATO] README e Proposta:** Apresenta o *Dosidicus electronicus* como um sandbox cognitivo transparente em formato de pet virtual (uma lula digital) cujo objetivo é tornar cada neurônio, sinapse e aprendizado visíveis ao cuidador (*"What if a Tamagotchi had a neural network and could learn stuff?"*). Destaca o motor de simulação próprio em NumPy (sem PyTorch/TensorFlow), neurogênese orientada por déficit de capacidade e registro completo de proveniência sináptica.
- **[FATO] Estrutura do Repositório:** 522 entradas na árvore Git (480 arquivos blob). Divide-se em:
  - `src/` (~100 módulos Python/PyQt para desktop e núcleo compartilhado): destaque para `plasticity.py`, `stdp.py`, `causal_learning.py`, `neural_provenance.py`, `capability.py`, `neurogenesis.py`, `consolidation.py`, `sleep_consolidation.py`, `decision_engine.py`, `portable_brain.py`, `brain_io.py`, além das abas de inspeção (`brain_decisions_tab.py`, `brain_learning_tab.py`, `brain_knowledge_tab.py`, `brain_network_tab.py`).
  - `android/` (adaptação mobile em Kivy que importa o motor cognitivo desktop via `prepare_apk.py`, com UI móvel em `android/dosidicus_mobile/ui/` como `learning_cards.py` e `decisions_panel.py`).
  - `custom_brains/` (redes pré-configuradas em JSON) e `plugins/achievements/`.
- **[FATO] Testes:** 50 arquivos relacionados a testes (`tests/test_*.py` com 45 suítes cobrindo pipeline neural, plasticidade hebbiana, aprendizado causal, herança, intercâmbio de cérebros JSON/ZIP, modo headless e estágios sociais; mais 4 suítes em `android/tests/`). Executados via `pytest` com `QT_QPA_PLATFORM=offscreen`.
- **[FATO] Manutenção e Saúde:** Ativamente mantido (330 estrelas, commits recentes em outubro de 2026, 5 workflows de CI/CD no GitHub Actions para builds Nuitka, Windows ARM64, macOS DMG e Android APK).
- **[FATO] Issues Abertas Relevantes (3 abertas):**
  - `#35` (`2026-04-02`): *BUG: Hebbian timer and Neurogenesis timer do not reflect "Speed" setting* — alerta clássico sobre desacoplamento entre relógio de simulação (ticks/velocidade) e temporizadores de aprendizado (no EvoWorld isso já é prevenido usando exclusivamente o contador discreto `world.tick`).
  - `#31` (`2026-03-10`): *ToDo: Squid should change size based on age*.
  - `#30` (`2026-03-10`): *(enhancement) Squid Evolutionary timeline*.
- **Mecanismo Útil (em palavras próprias — Causalidade Experiência → Mudança de Política e Visualização):**
  1. **Separação entre Correlação e Contingência Causal:** Em vez de apenas reforçar neurônios que disparam juntos (correlação hebbiana simples), o sistema abre uma "janela de episódio de ação" toda vez que o agente inicia um comportamento deliberado (ex.: comer, explorar, fugir), anotando quais pistas sensoriais estavam ativas no instante da escolha. Quando a janela fecha alguns segundos depois, mede-se a variação líquida de cada necessidade homeostática no período. Para determinar se a ação realmente *causou* a melhora ou piora, a variação observada é descontada da **deriva basal** daquela mesma necessidade quando a ação não está em execução ($\text{efeito} = \Delta_{\text{médio da ação}} - \text{deriva}_{\text{basal}}$).
  2. **Confiança Epistêmica Estatística:** Uma única experiência dramática nunca recebe confiança máxima. A confiança na relação causal cresce com a raiz do número de repetições ($1 - 1/\sqrt{n}$, exigindo $n \ge 2$) multiplicada pela razão sinal-ruído entre a magnitude do efeito e o desvio-padrão histórico daquela consequência.
  3. **Atribuição de Crédito Temporal e Livro-Razão de Proveniência (*Provenance Ledger*):** A valência líquida da consequência retroalimenta os traços de elegibilidade temporal das sinapses que participaram da decisão. Crucialmente, toda alteração de peso sináptico ou criação de neurônio grava no próprio cérebro (e não na UI) um registro limitado contendo o mecanismo causador (coativação, sequência temporal, recompensa causal, consolidação em sono), o episódio de origem e o delta aplicado. Mesmo quando eventos antigos saem da fila circular, acumuladores por conexão preservam a contabilidade exata.
  4. **Visualização Transparente de Decisões e Aprendizado:** A interface divide a explicabilidade em três visões complementares:
     - *Painel de Decisão com Pontuação Base vs. Ajustada:* Exibe barras horizontais para todas as ações candidatas, mostrando simultaneamente um marcador vertical para o peso bruto antes dos modificadores (personalidade/memória) e a barra preenchida com o peso final ajustado, além de um rótulo qualitativo de certeza da escolha (*Dividido*, *Inclinado*, *Razoavelmente seguro*, *Confiante*, *Decisivo*) derivado da margem da ação vencedora.
     - *Cartões de Aprendizado (LTP/LTD):* Lista as mudanças sinápticas recentes como cartões coloridos indicando potenciação (verde) ou depressão (vermelho/rosa), a regra que disparou a mudança, o delta numérico e a força resultante em linguagem humana (*fraca*, *moderada*, *forte*).
     - *Topologia em Linhas Funcionais:* Desenha a rede em três faixas legíveis (impulsos internos no topo, banco motor no meio e sentidos na base), evitando emaranhados ilegíveis.
- **Diretriz Legal GPL-2.0:** **Proibido copiar, traduzir ou portar código, estruturas de dados literais ou assets do Dosidicus.** Adotar exclusivamente as ideias de medição de contingência contra deriva basal, cálculo de confiança por repetição/variância e visualização comparativa (score base vs. score modificado + rótulo de confiança) reescritas do zero por requisitos em GDScript.

---

### 2.2 Pestinha (`github.com/mille-okws/pestinha`)

- **[FATO] Licença Real Confirmada:** **GNU General Public License v3.0 or later (`GPL-3.0-or-later`)** para o código-fonte (`LICENSE` e seção Licença do `README.md`), com ressalva explícita de que **as imagens e textos de `assets/` não estão cobertos pela licença** por ausência de confirmação de direitos autorais.
- **[FATO] Data / Commit / Versão Inspecionada:**
  - Data da inspeção: `2026-11-02`
  - Branch padrão: `main` (sem tags de release publicadas)
  - Commit HEAD inspecionado: `5063be916e68ebeaaf3723d49b387cfe2c362549` (`2026-11-01T23:47:58Z` — *"Update licensing details in README.md"*, que sucedeu os commits `64c32f004c` e `b875b30242` de correção de atalho global no macOS).
- **[FATO] Estrutura, Testes, Manutenção e Issues:**
  - **Estrutura:** 266 arquivos blob organizados em `pestinha/core/` (`homeostasis.py`, `conditioning.py`, `episodic.py`, `emotion.py`, `motor.py`, `nervous_system.py`, `physics.py`, `protesto.py`), `pestinha/mind/`, `pestinha/body/`, `pestinha/controle/`, `pestinha/plataforma/`, `docs/`, `ferramentas/` e `tests/`.
  - **Testes:** 30 suítes `tests/test_*.py` executadas com `pytest` via `.github/workflows/testes.yml`, cobrindo homeostase, condicionamento, castigo, carinho, migração e robustez.
  - **Manutenção e Issues/PRs Abertas:** Ativo (57 estrelas, commits em 01/11/2026); 1 PR aberto (`#4`, `2026-11-02`: *"fix(ci): corrige dependências, testes e geração de executáveis multiplataforma"*).
- **Mecanismo Útil (Homeostase, Habituação, Condicionamento e Memória Episódica):**
  - Conforme instrução da missão, a auditoria jurídica completa e a descrição conceitual detalhada de homeostase, habituação sensorial, condicionamento clássico (Rescorla-Wagner), memória episódica (bandit contextual) e plasticidade de três fatores já estão documentadas integralmente em [`docs/PESTINHA_LICENCAS.md`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/docs/PESTINHA_LICENCAS.md) (e já embasaram a implementação limpa de [`personality.gd`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/scripts/behavior/personality.gd) no EvoWorld 2.0). Não se duplica o conteúdo aqui; consulte diretamente [`docs/PESTINHA_LICENCAS.md`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/docs/PESTINHA_LICENCAS.md).
- **Diretriz Legal GPL-3.0-or-later:** **Proibido copiar, traduzir ou portar código, pesos, textos ou assets do Pestinha.** Reimplementação limpa orientada exclusivamente por requisitos e modelos matemáticos de domínio público.

---

### 2.3 Pet Mochi (`github.com/cskwork/pet-mochi`)

- **[FATO] Licença Real Confirmada:** **MIT License (`MIT`)**, confirmada no arquivo `LICENSE` (`Copyright (c) 2026 cskwork`) e no metadado SPDX do GitHub.
- **[FATO] Data / Commit / Versão Inspecionada:**
  - Data da inspeção: `2026-11-02`
  - Branch padrão: `main`
  - Commit HEAD inspecionado: `29e67cfeebeaeb05d07c9b568bb0008c3482fc4e` (`2026-10-28T04:44:29Z` — *"Merge pull request #16 from cskwork/feat/e2e-tests"*)
  - Tags publicadas: `v0.3.0` (`95ddb92`), `v0.2.0` (`5d89c1b`).
- **[FATO] README e Proposta:** Pet de desktop *local-first* construído com **Tauri 2 (Rust)** e **Svelte 5 (TypeScript)** sob a diretriz norteadora *"The pet must feel alive even when the LLM is off"*. Funciona 100% offline sem conta ou nuvem, usando simulação determinística contínua a cada 3 segundos e acionando LLM local opcional (Ollama) apenas em momentos de alta saliência.
- **[FATO] Estrutura do Repositório:** 349 arquivos blob divididos em 4 camadas bem demarcadas (documentadas em `docs/ARCHITECTURE.md` e `PRD.md`):
  1. *Simulação pura (`src/lib/sim/`):* funções puras TypeScript sem DOM, sem Tauri e sem I/O assíncrono (`tick.ts`, `decay.ts`, `mood.ts`, `movement.ts`, `salience.ts`, `choreography.ts`, `nudges.ts`, `personality.ts`, `quirks.ts`, `rituals.ts`, `snacks.ts`, `statusReportGate.ts`).
  2. *Interface (`src/lib/components/`):* componentes Svelte 5 (`Pet.svelte`, `MochiSprite.svelte`, `PetStatus.svelte`, `autonomousGate.ts`), glifos visuais de humor e animações de estados.
  3. *Ponte/Eventos (`src/lib/bridge/` e `src/lib/events/`):* barramento de eventos em processo e wrapper tipado para o Tauri.
  4. *Backend Rust (`src-tauri/src/`):* persistência SQLite + busca textual FTS5 (`db.rs`), adaptador LLM com controle de cooldown (`llm/cooldown.rs`, `llm/ollama.rs`), e caixa de areia estrita de arquivos (`sandbox.rs`, `watcher.rs`).
- **[FATO] Testes:** 44 arquivos de teste (27 suítes unitárias Vitest em `src/lib/**/*.test.ts` executando ~99 testes de simulação em menos de 1s + suíte E2E Playwright em `tests/e2e/*.spec.ts` sobre backend Tauri mockado + testes Rust `cargo test`, totalizando 459 testes passando declarados na CI `.github/workflows/ci.yml`).
- **[FATO] Manutenção e Issues Abertas:** Ativo e bem higienizado (commits em 28/10/2026, CI com Node 24 e job Windows Rust, **0 issues abertas**; decisões técnicas e itens de backlog documentados em `DECISIONS.md` e `BACKLOG.md`).
- **Mecanismo Útil (em palavras próprias — Simulação Local Contínua + LLM Só em Momentos Relevantes):**
  1. **Núcleo de Simulação Puro e Acumulação em Ponto Flutuante com Arredondamento nas Fronteiras:** O loop principal roda a cada 3 segundos executando funções puras e determinísticas que atualizam necessidades lentas (fome, energia, tédio, curiosidade, estresse, afeto) em variáveis `float` internas para evitar perda de precisão por truncamento em deltas pequenos. A conversão para inteiros ocorre **exclusivamente nas duas fronteiras externas**: no momento de persistir o snapshot e no momento de exibir os números na interface.
  2. **Portão de Saliência (*Salience Gate*) e Triplo Cooldown:** O LLM jamais é chamado dentro do tick de simulação nem em interações cotidianas (clicar, acariciar ou alimentar têm custo zero de rede/LLM e usam reações determinísticas locais). Uma chamada autônoma ao modelo só é cogitada quando um evento discreto supera um limiar numérico composto pela soma de três parcelas: **importância intrínseca do evento + urgência do humor atual + peso do vínculo com o cuidador** ($\text{saliência} \ge 70$). Mesmo que passe pelo limiar, a chamada precisa atravessar três camadas de *cooldown* independentes: um bloqueio temporal no portão de saliência (90s), um bloqueio por categoria na camada de apresentação (5 minutos) e uma trava de segurança no backend.
  3. **Coreografia de Vocabulário Fechado e Fallback Determinístico:** Quando o LLM opcional responde ou reage a um momento saliente, ele não pode inventar estados arbitrários; ele escolhe uma sequência de animação a partir de um catálogo fechado de poses nomeadas. Se o LLM estiver desligado, indisponível ou retornar JSON inválido, um seletor determinístico local assume silenciosamente sem interromper a experiência.
  4. **Ranking de Memória com Fator de Confiança e Glifos Desambiguadores de Estado:** As memórias persistidas são recuperadas por uma combinação linear ponderada ($0{,}4 \times \text{importância} + 0{,}3 \times \text{recência} + 0{,}3 \times \text{confiança}$), permitindo que um fato antigo porém de alta certeza supere uma inferência recente incerta. Na expressão visual, estados internos que compartilham paleta desaturada semelhante (fome, tédio, solidão, curiosidade) recebem glifos dedicados suprimidos automaticamente durante o sono ou durante animações de ação conflitantes.

---

### 2.4 AI Town (`github.com/a16z-infra/ai-town`)

- **[FATO] Licença Real Confirmada:** **MIT License (`MIT`)**, confirmada no arquivo `LICENSE` (`Copyright (c) 2023 a16z-infra`) e no metadado SPDX do GitHub. Note-se que o `README.md` credita separadamente os tilesheets e assets visuais de terceiros (OpenGameArt / itch.io), os quais não serão utilizados no EvoWorld.
- **[FATO] Data / Commit / Versão Inspecionada:**
  - Data da inspeção: `2026-11-02`
  - Branch padrão: `main` (sem tags de release)
  - Commit HEAD inspecionado: `8e05997f2409275669c8344b84a51692e83f3f33` (`2026-08-26T00:34:11Z` — *"Merge pull request #305 from hamedrabah/fix/isolate-retrieved-memories"*).
- **[FATO] README e Estrutura:** Implementação de referência em TypeScript/Convex/PixiJS inspirada no artigo *Generative Agents: Interactive Simulacra of Human Behavior* (Park et al., 2023). Possui 209 arquivos blob divididos em:
  - `convex/engine/` (`abstractGame.ts`, `historicalObject.ts`): motor de simulação em passos discretos (*steps* de 1s que agregam 60 *ticks* lógicos de movimentação/pathfinding, com número de geração monotônico para impedir execução concorrente).
  - `convex/aiTown/` (`world.ts`, `player.ts`, `agent.ts`, `agentOperations.ts`, `conversation.ts`, `conversationMembership.ts`): regras de mundo, máquina de estados de conversação e despacho de operações assíncronas.
  - `convex/agent/` (`memory.ts`, `conversation.ts`, `embeddingsCache.ts`): fluxo de memória episódica, pontuação de recuperação e reflexão.
  - `src/` (interface React + PixiJS).
- **[FATO] Testes:** 7 arquivos `.test.ts` (Jest) em `convex/` (`conversation.test.ts`, `historicalObject.test.ts`, `asyncMap.test.ts`, `compression.test.ts`, `geometry.test.ts`, `minheap.test.ts`, `types.test.ts`).
- **[FATO] Manutenção e Issues Abertas Relevantes:** 10.737 estrelas e 76 issues/PRs abertas; manutenção comunitária esporádica (último merge em agosto de 2026). Issues abertas de grande relevância arquitetural para o EvoWorld:
  - `#284` (`2025-06-17`): *Multiple Critical Failures in AI Town - Timeouts, Generation Mismatches, and Conversation Loops* — evidencia como acoplar chamadas assíncronas demoradas ao loop de simulação causa perda de sincronia de geração e timeouts em cascata.
  - `#283` (`2025-06-17`): *Agents stuck in goodbye loop - never leave* — mostra o risco de agentes presos em ciclos sociais infinitos sem teto rígido de duração/turnos.
  - `#296` (`2026-04-11`): *Security: No server-side validation that sender belongs to target conversation/world*.
  - Commit `8e05997f24` / PR `#305` (`2026-08-26`): *Isolate retrieved memories from system prompts* — corrige vulnerabilidade onde memórias recuperadas de conversas anteriores eram concatenadas diretamente no prompt de sistema, permitindo contaminação de instruções.
- **Mecanismo Útil (em palavras próprias — Memória e Socialização de Agentes):**
  1. **Recuperação em Duas Etapas com Sobreamostragem (*Overfetch*) e Normalização Min-Max:** Quando um agente precisa recordar experiências sobre outro indivíduo ou situação, o sistema primeiro busca $10 \times N$ candidatos por similaridade semântica e, em seguida, pontua cada candidato somando três componentes normalizados na faixa $[0, 1]$ dentro do conjunto candidato:
     - **Relevância:** grau de pertinência ao contexto ou parceiro atual;
     - **Importância:** pontuação escalar (0 a 9) atribuída no momento em que a memória foi gravada (diferenciando eventos banais de eventos marcantes);
     - **Recência:** decaimento exponencial por horas desde o último acesso ($0{,}99^{\lfloor \Delta t_{\text{horas}} \rfloor}$). Ao recuperar uma memória, seu carimbo de `lastAccess` é atualizado, mas com uma trava de amortecimento (*throttle* de 5 minutos) para evitar escritas redundantes em acessos seguidos.
  2. **Reflexão Acionada por Acúmulo de Importância:** Após encerrar e resumir uma interação social, o agente soma a importância das memórias recentes criadas desde a última reflexão (até 100 itens). Somente quando essa soma acumulada ultrapassa um limiar alto (500 pontos) o agente dispara um ciclo de **reflexão**, sintetizando 3 conclusões de alto nível que são salvas de volta como novas memórias do tipo `reflection`, mantendo ponteiros explícitos (`relatedMemoryIds`) para os episódios primários que serviram de evidência.
  3. **Máquina de Estados de Socialização e Cooldowns Anti-Spam:** Os encontros sociais seguem estados físicos explícitos (`convidado` $\to$ `caminhando até o parceiro` $\to$ `participando`), exigindo proximidade espacial antes da troca de mensagens. Para evitar que agentes fiquem eternamente conversando com o mesmo vizinho ou tentando convidar quem acabou de recusar, o agente respeita tempos de resfriamento explícitos (`CONVERSATION_COOLDOWN` após sair de uma conversa ou tentar um convite, e `ACTIVITY_COOLDOWN` durante atividades individuais), alternando para caminhada ou tarefas solitárias nesse intervalo.

---

### 2.5 HermitClaw (`github.com/brendanhogan/hermitclaw`)

- **[FATO] Licença Real Confirmada e Ressalva de Auditoria:** O final do arquivo `README.md` (linhas 422–424) declara textualmente `## License\n\nMIT`. Contudo, **[LACUNA]** o repositório **não contém arquivo `LICENSE` dedicado** na árvore Git nem campo `license` em `pyproject.toml` ou `frontend/package.json` (a API do GitHub reporta `NO_SPDX_DETECTED`). Por prudência jurídica e de segurança, nenhum código ou asset do HermitClaw deve ser copiado; aproveitam-se apenas ideias conceituais descritas publicamente.
- **[FATO] Data / Commit / Versão Inspecionada:**
  - Data da inspeção: `2026-11-02`
  - Branch padrão: `main` (versão `0.1.0` em `pyproject.toml`, sem tags Git)
  - Commit HEAD inspecionado: `2b69414969e66702f4aad50e0b09594cc26ccd11` (`2026-02-17T18:26:08Z` — *"updated further security clarification"*).
- **[FATO] README, Estrutura, Testes, Manutenção e Issues:**
  - **Proposta:** Um "caranguejo-eremita" de IA que vive dentro de uma pasta (`{name}_box/`) e de um quarto pixel-art $12 \times 12$, operando em loop contínuo de pensamento, pesquisa e escrita.
  - **Estrutura:** Repositório enxuto com 39 arquivos blob: `hermitclaw/` (`main.py`, `brain.py`, `memory.py`, `identity.py`, `prompts.py`, `providers.py`, `pysandbox.py`, `server.py`, `tools.py`, `config.py`), `frontend/src/` (`App.tsx`, `GameWorld.tsx`, `sprites.ts`) e `tests/` (`test_config.py`, `test_providers.py`).
  - **Testes:** Apenas 2 arquivos de teste unitário simples (`test_config.py` e `test_providers.py`, sem testes do loop cognitivo nem do sandbox).
  - **Manutenção e Issues Abertas:** 329 estrelas, sem novos commits desde 17/02/2026. Possui 8 issues/PRs abertas, com destaque para:
    - `#15` (`2026-10-12`): *Security: please enable Private Vulnerability Reporting* — reforça a preocupação da comunidade com a superfície de execução de comandos do projeto.
    - `#11` (`2026-02-22`): *Frontend Request - add a dropbox to the hermit's room*.
    - `#10` (`2026-02-21`) e PR `#12` (`2026-03-08`): incompatibilidades do campo `name` em chamadas de ferramenta da API de LLM.
- **Mecanismo Útil (em palavras próprias — Motivação, Curiosidade, Interesses, Objetos do Quarto e Reflexões):**
  1. **Genoma de Personalidade e Interesses Derivado de Semente Determinística:** Na criação do indivíduo, uma semente de entropia é convertida via hash criptográfico determinístico (SHA-512) em três dimensões inatas: **3 domínios de curiosidade** (sorteados de um catálogo de 50 temas), **2 estilos de pensamento** (de 16 opções, como buscar causa-e-efeito ou encontrar padrões em ruído) e **1 temperamento basal** (de 8 perfis, como paciente/metódico ou inquieto/explorador). A mesma semente gera sempre o mesmo perfil inicial, mas as experiências vividas deslocam o foco ao longo do tempo.
  2. **Modos Motivacionais, Modo Foco e Equilíbrio Exploração → Produção:** Quando não está atendendo ao usuário, o agente alterna entre humores autônomos (*Pesquisador*, *Aprofundador*, *Construtor*, *Escritor*, *Explorador*, *Organizador*) ou trava no *Modo Foco* quando o usuário solicita atenção exclusiva a um item. Para impedir que o agente fique preso apenas consumindo estímulos sem produzir efeitos concretos no mundo, o cérebro rastreia uma razão de exploração contínua (`_consecutive_research_cycles`, introduzida no commit `9edba82449`) e injeta um impulso corretivo quando muitos ciclos se passam sem ação construtiva.
  3. **Objetos Semânticos do Quarto (Ancoragem Espacial da Cognição):** O quarto $12 \times 12$ possui estações físicas com coordenadas fixas associadas ao estado mental corrente: **Escrivaninha** (trabalho/criação), **Estante** (pesquisa/consulta), **Janela** (ponderação/reflexão), **Planta**, **Cama** (repouso) e **Tapete Central** (estado neutro), acompanhadas de ícones sobre a cabeça (balão de pensamento, partículas de reflexão, prancheta de planejamento, exclamação ao detectar item novo). Deslocar a criatura até o objeto correspondente torna o estado interno legível mesmo sem ler logs de texto.
  4. **Hierarquia de Reflexão em Profundidade (`depth 0 → depth 1 → depth 2`):** O fluxo de memória soma a importância (1 a 10) de cada pensamento; quando o acumulador atinge o limiar (50), o ciclo de sonho/reflexão extrai de 2 a 3 sínteses das últimas 15 memórias e as grava com `depth = 1` (e referências aos IDs de origem). Reflexões futuras podem sintetizar reflexões anteriores (`depth = 2`), formando crenças progressivamente mais abstratas, separadas do ciclo periódico de planejamento (que roda a cada 10 ciclos atualizando metas de curto prazo).
- ⚠️ **ADVERTÊNCIA CRÍTICA DE SEGURANÇA (Shell e Monkey-Patching NÃO São Barreira):**
  - **[FATO]** O HermitClaw executa um LLM em loop autônomo com ferramenta de `shell` e busca web, tentando restringir o agente à pasta `{name}_box/` por meio de uma lista de bloqueio de comandos (`sudo`, `curl`, `rm -rf /`, `..`) em `tools.py` e de *monkey-patching* em Python dentro de `pysandbox.py` (sobrescrevendo `builtins.open`, funções de `os` e injetando módulos falsos em `sys.modules` para `subprocess`, `socket`, `ctypes`, etc.).
  - **[FATO]** Como o próprio autor adverte nos commits `9745c060e6` e `2b69414969` (*"they are not a security boundary — they are bypassable"*), **listas de bloqueio de shell e monkey-patches dentro do mesmo interpretador Python são trivialmente contornáveis** (por exemplo, via introspecção de frames/classes base `__subclasses__()`, recarga de módulos nativos, links simbólicos ou injeção de prompt vinda de arquivos/páginas externas).
  - **Regra Inegociável para o EvoWorld:** O EvoWorld **jamais** adotará execução de shell, `OS.execute()`, avaliação dinâmica de scripts (`GDScript.reload()` / `Expression` de entrada externa) ou *monkey-patching* como suposto sandbox. Toda simulação e persistência do EvoWorld permanece estritamente declarativa em dados JSON validados por schema fechado ([`save_store.gd`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/scripts/persistence/save_store.gd) e [`sim_data.gd`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/scripts/core/sim_data.gd)), sem acesso a rede ou processos do sistema operacional.

---

### 2.6 Sketch-RNN (`github.com/magenta/magenta` — `magenta/models/sketch_rnn`) e Quick, Draw! Dataset (`github.com/googlecreativelab/quickdraw-dataset`)

#### A. Sketch-RNN (`magenta/models/sketch_rnn`)
- **[FATO] Licença Real Confirmada:** **Apache License 2.0 (`Apache-2.0`)**, verificada no arquivo `LICENSE` na raiz de `magenta/magenta` e nos cabeçalhos de `magenta/models/sketch_rnn/utils.py` e `model.py`.
- **[FATO] Data / Commit / Versão Inspecionada:**
  - Data da inspeção: `2026-11-02`
  - Branch padrão: `main` (repositório **arquivado / somente leitura** em `2026-01-06`)
  - Commit HEAD inspecionado: `c15687ebd1c1cc12658cd468c737d3c24c02b918` (`2026-01-06T01:17:53Z` — *"Update status to indicate repository is archived"*)
  - Última tag publicada: `v2.1.4` (`82ef836`).
- **[FATO] Estrutura, Testes, Manutenção e Issues:**
  - **Estrutura:** O subdiretório `magenta/models/sketch_rnn/` contém 10 arquivos (`README.md`, `__init__.py`, `model.py`, `rnn.py`, `sketch_rnn_train.py`, `utils.py` e 4 diagramas SVG em `assets/`).
  - **Testes:** Nenhum teste unitário específico dentro de `magenta/models/sketch_rnn/`; código originalmente escrito para TensorFlow 1.x / Python 2.7/3.x legado.
  - **Manutenção e Issues:** Repositório arquivado com 428 issues históricas abertas (muitas relatando quebra de instalação com versões modernas de NumPy 2.0, numba e Apple Silicon, ex.: issues `#2116`, `#2115`, `#2113`, `#2110`).

#### B. Quick, Draw! Dataset (`googlecreativelab/quickdraw-dataset`)
- **[FATO] Licença Real Confirmada:** **Creative Commons Attribution 4.0 International (`CC BY 4.0`)** para os dados dos desenhos, declarada expressamente no arquivo `LICENSE` (*"This data made available by Google, Inc. under the Creative Commons Attribution 4.0 International license. https://creativecommons.org/licenses/by/4.0/"*). Os scripts de exemplo de parsing no repositório (`examples/binary_file_parser.py`, `examples/nodejs/*.js`) trazem cabeçalho **Apache-2.0**.
- **[FATO] Data / Commit / Versão Inspecionada:**
  - Data da inspeção: `2026-11-02`
  - Branch padrão: `master` (repositório **arquivado / somente leitura**)
  - Commit HEAD inspecionado: `5fe6c0a910b3732bc3db7639d3c9e7c287617f2f` (`2025-03-11T00:12:28Z` — *"Update README.md"*).
- **[FATO] Estrutura, Testes, Manutenção e Issues:**
  - **Estrutura:** 10 arquivos no repositório Git (`LICENSE`, `README.md`, `categories.txt` com as 345 categorias, `preview.jpg`, e parsers de exemplo em `examples/`). Os dados em si residem no Google Cloud Storage (`gs://quickdraw_dataset/`).
  - **Testes e Issues:** 0 arquivos de teste; 32 issues abertas no arquivo histórico (ex.: `#86` sobre coleta de dados, `#65` sobre ambiguidade de tradução de categorias como *crown/clown*). O próprio `README.md` alerta que, embora moderada, a coleção de 50 milhões de desenhos pode conter rabiscos inadequados.

#### C. Mecanismo Útil (Desenho como Sequência de Traços, Viabilidade em Godot, Tamanho e Atribuição)
1. **Representação de Desenho como Sequência de Traços Vetoriais:**
   - **Formato Simplificado por Polilinhas (QuickDraw Simplified / Binary):** Cada desenho é uma lista de traços (*strokes*), onde cada traço é uma sequência de coordenadas $(x_0, x_1, \dots), (y_0, y_1, \dots)$ alinhada ao canto superior esquerdo, escalada uniformemente para caber em uma caixa $256 \times 256$ (valores inteiros de 1 byte `0..255`), reamostrada com espaçamento de 1 pixel e simplificada pelo algoritmo de **Ramer-Douglas-Peucker (RDP)** com $\varepsilon = 2{,}0$ (tipicamente restando menos de 30 a 80 pontos por desenho).
   - **Formato de Deslocamento Relativo `stroke-3` e `stroke-5` (Sketch-RNN):** Em vez de coordenadas absolutas, cada passo da sequência é uma tupla $(\Delta x, \Delta y, p_{\text{lift}})$, onde $\Delta x, \Delta y$ são deslocamentos relativos ao ponto anterior (`int8` ou `int16`) e $p_{\text{lift}} \in \{0, 1\}$ indica se a caneta permanece no papel ($0$) ou é levantada ao final daquele segmento ($1$). No formato `stroke-5`, o estado da caneta é expandido para um vetor *one-hot* $(p_1, p_2, p_3)$ indicando caneta abaixada, caneta levantada ou fim do desenho.
   - ** Perturbação e Interpolação Vetorial:** O Sketch-RNN demonstra que desenhos em formato de traços suportam duas operações geométricas muito baratas sem borrar pixels: (a) *drop/jitter* de pontos intermediários de um segmento longo (mantendo os pontos extremos do traço) e (b) escala/morfagem contínua entre sequências.
2. **Viabilidade Técnica em Godot 4.7.2 (GDScript):**
   - **[FATO] Inviabilidade do Modelo Neural Sketch-RNN em Runtime:** Executar a rede Seq2Seq VAE (encoder Bi-RNN + decoder LSTM com Mixture Density Network de 20 misturas gaussianas bivariadas em TensorFlow) dentro do Godot é **inviável e indesejável**: viola a regra *No Python at runtime*, exigiria dezenas de megabytes de pesos por categoria e custo de CPU desproporcional.
   - **[FATO] Altíssima Viabilidade da Representação `stroke-3` / Polilinhas Simplificadas em GDScript:** Representar ícones expressivos, "rabiscos" da criatura (ex.: em um cavalete/quadro de atividades ou balão de expressão) ou símbolos de sinais como pequenas listas de traços `stroke-3` ou polilinhas `PackedVector2Array` (geradas proceduralmente ou lidas de um catálogo compacto de poucas dezenas de bytes por símbolo) é **100% nativo e imediato em Godot**. Basta usar `CanvasItem.draw_polyline()` ou `draw_line()` avançando um contador de progresso por tick para animar o traço sendo desenhado ao vivo, modulando o tremor (*jitter*) e a velocidade pelo estado real da criatura (`fatigue`, `arousal`, `curiosity`).
3. **Tamanho dos Dados (Motivo para NÃO Baixar o Dataset Bruto):**
   - O dataset completo abrange **50 milhões de desenhos em 345 categorias**:
     - *Raw NDJSON:* > 22 GB;
     - *Simplified NDJSON:* ~7 GB;
     - *Binary (`.bin`):* ~1,5 a 4 GB no total (~2 MB a 15 MB por arquivo de categoria contendo ~110.000 desenhos cada, a ~15 bytes de cabeçalho + $2N$ bytes por traço);
     - *Sketch-RNN (`.npz`):* 75.000 amostras por classe (~20 MB a 50 MB por arquivo `.npz`).
   - Conformidade estrita com a missão: **nenhum arquivo `.npz`, `.ndjson`, `.bin` ou `.npy` foi baixado**. Caso o EvoWorld utilize desenhos baseados em traços, um catálogo interno de 20 a 50 rabiscos curados em formato `stroke-3` compacto ocupará **menos de 4 KB no total** em GDScript/JSON.
4. **Exigências de Atribuição (`CC BY 4.0`):**
   - Se traços extraídos do Quick, Draw! Dataset forem futuramente incorporados ao jogo, a licença **CC BY 4.0** exige obrigatoriamente: (1) crédito expresso a **Google, Inc.** como criadora do *Quick, Draw! Dataset*, (2) link para a licença `https://creativecommons.org/licenses/by/4.0/`, (3) indicação de que os dados foram filtrados/simplificados/convertidos para o formato do EvoWorld, e (4) registro completo com SHA256 em [`docs/ASSET_PROVENANCE.md`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/docs/ASSET_PROVENANCE.md). Se os vetores de traços forem 100% autorais/procedurais do EvoWorld (`CC0`), nenhuma obrigação CC BY 4.0 se aplica.

---

### 2.7 OpenC2E (`github.com/openc2e/openc2e`)

- **[FATO] Licença Real Confirmada:** **GNU Lesser General Public License v2.1 or later (`LGPL-2.1-or-later`)**, confirmada no arquivo `COPYING` na raiz do repositório, no metadado SPDX do GitHub (`LGPL-2.1`) e nos cabeçalhos dos arquivos-fonte C++ (`src/openc2e/creatures/Biochemistry.cpp`, `Creature.h`, `CreatureAI.cpp`: *"either version 2 of the License, or (at your option) any later version"*). O subdiretório `externals/SDL3` possui licença `Zlib`.
- **[FATO] Data / Commit / Versão Inspecionada:**
  - Data da inspeção: `2026-11-02`
  - Branch padrão: `main`
  - Commit HEAD inspecionado: `dfcd46f2d6748f6fedc8ba61c3269bdf02956786` (`2026-10-07T19:45:26Z` — *"c++17: replace ghc_filesystem with std::filesystem"*)
  - Tags publicadas: `v0.2` (`d3f0d6d`), `mngplayer2-v1.0.1` (`528843d`).
- **[FATO] README, Estrutura, Testes, Manutenção e Issues:**
  - **Proposta:** Motor livre em C++17 reimplementando a série clássica de vida artificial *Creatures* (*Creatures 1, 2, 3* e *Docking Station*), incluindo máquina virtual de scripts CAOS, genética, cérebro em lobos/tratos e bioquímica completa.
  - **Estrutura:** 2.493 arquivos no repositório total, sendo **514 arquivos próprios** (fora `externals/SDL3`), divididos em `src/common/`, `src/fileformats/` (parsers de genoma `.gen`, `.pray`, `.sfc`, `.cob`), `src/openc2e/` (motor unificado, `caos/`, `creatures/Biochemistry.cpp`, `Creature.cpp`, `CreatureAI.cpp`, `c2eBrain.cpp`, `oldBrain.cpp`, e inspetores ImGui como `BrainViewer.cpp` e `CreatureGrapher.cpp`) e `src/opencreatures1/`.
  - **Testes:** 15 suítes de teste C++ próprias (`src/opencreatures1/tests/BiochemistryTest.cpp`, `MacroTest.cpp`, `ScriptoriumTest.cpp`, `src/openc2e/tests/CaosTest.cpp`, `src/fileformats/tests/*Test.cpp`, `src/common/**/*Test.cpp`) executadas via CTest no workflow `.github/workflows/build.yml`.
  - **Manutenção e Issues Abertas:** Mantido ativamente (173 estrelas, commits em outubro de 2026); 22 issues abertas focadas em fidelidade de comandos CAOS legados (`#181`, `#180`, `#176`, `#173`), temporização de ticks (`#183`) e serialização (`#205`).
- **Mecanismo Útil (em palavras próprias — Biologia, Bioquímica e Necessidades):**
  1. **Fisiologia como Rede Bioquímica Uniforme:** Em vez de tratar fome, cansaço, dor, estresse e recompensas como variáveis desconexas com regras *ad hoc*, o organismo mantém um vetor de substâncias químicas internas (concentrações normalizadas em $[0, 1]$), cada qual dotada de uma **taxa de meia-vida (*half-life*)** genética que dita a velocidade com que a substância decai exponencialmente de volta a zero a cada ciclo bioquímico (a cada 4 ticks lógicos).
  2. **Tríade Emissores → Reações → Receptores (*Loci*):** O acoplamento entre corpo, ambiente e mente ocorre por três componentes parametrizados pelo genoma:
     - **Quimioemissores (*Emitters*):** Leem um estado corporal ou sensorial (*locus* somático, circulatório, reprodutivo ou sensório-motor — por exemplo, gasto muscular ou estímulo visual) e injetam uma substância correspondente na corrente sanguínea.
     - **Reações Químicas ($r_1 A + r_2 B \xrightarrow{k} p_1 C + p_2 D$):** Transformam nutrientes ingeridos (ex.: amido/glicose) em reservas energéticas (`ATP`) ou convertem toxinas em subprodutos de dano/anticorpos a uma taxa proporcional às concentrações disponíveis.
     - **Quimiorreceptores (*Receptors*):** Monitoram a concentração de uma substância acima de um limiar e modulam um *locus* alvo: podem alterar a marcha motora (*gait*), disparar ações involuntárias (como reflexo de sono ou recuo), ajustar a taxa de reparo tecidual ou alimentar diretamente os **20 níveis de impulso (*drives*)** enviados ao lobo de impulsos (`driv`) do cérebro.
  3. **Custos Metabólicos de Órgãos (`ATP`/`ADP`) e Dano por Inanição:** Cada órgão interno (incluindo o cérebro) possui um relógio biológico próprio (`biotick += clockrate`) e um custo energético proporcional à sua complexidade genética. A cada batimento do órgão, ele consome `ATP` e produz `ADP`; se o nível de `ATP` for insuficiente, o órgão deixa de processar suas reações e sofre uma perda real de vitalidade (*short-term / long-term lifeforce*) proporcional a um coeficiente de dano (`atpdamagecoefficient`), elevando o químico de lesão (*Injury*).
  4. **Redução de Impulso (*Drive Reduction*) como Sinal de Reforço:** As necessidades internas (*drives* como fome, sede, dor, solidão, tédio, cansaço) não decidem a ação por decreto rígido, mas entram como sinais no cérebro; quando uma ação resulta na queda da concentração de um químico de impulso (ex.: comer gera glicose que consome o químico de fome), essa derivada negativa funciona como reforço biológico intrínseco.
- **Diretriz Legal LGPL-2.1-or-later:** Como o EvoWorld é distribuído como aplicação unificada em GDScript sem vinculação dinâmica de bibliotecas C++, **é proibido copiar, traduzir ou portar código C++ do OpenC2E**. Adotam-se exclusivamente os conceitos biológicos de domínio público (emissores/receptores, meia-vida exponencial, custo energético de manutenção proporcional à complexidade genética e reforço por redução de déficit) reimplementados do zero por requisitos em GDScript.

---

## 3. Matriz de Decisão de Reuso (`reutilizar biblioteca | estudar padrão | descartar`)

Conforme diretriz da arquitetura do EvoWorld (*Simulação determinística em GDScript `RefCounted`, zero Python em tempo de execução, zero rede em runtime e licenciamento limpo*), consolida-se abaixo a decisão recomendada para cada referência:

| Referência | Licença Confirmada | Versão / Commit Inspecionado | Esforço de Adoção | Risco Técnico / Legal | Decisão Recomendada | Racional e Diretriz Obrigatória |
|---|---|---|---|---|---|---|
| **Dosidicus**<br>`ViciousSquid/Dosidicus` | **GPL-2.0** | Branch `3.2.0_LatestVersion`<br>`0b9357421e` (`2026-10-22`) | Médio (em GDScript próprio) | **Alto (se copiado)** / **Baixo (Clean-Room)** | **estudar padrão** | **DECLARAÇÃO GPL EXPLÍCITA:** Proibido copiar, traduzir ou portar código, pesos ou assets (GPL-2.0 contaminaria o repositório). Estudar e reimplementar por requisitos os padrões de contingência causal ($\Delta - \text{deriva basal}$), confiança estatística por repetição/variância, registro de proveniência de mudanças de política e visualização comparativa (score base vs. ajustado + rótulo de confiança). |
| **Pestinha**<br>`mille-okws/pestinha` | **GPL-3.0-or-later** *(assets sem direitos confirmados)* | Branch `main`<br>`5063be916e` (`2026-11-01`) | Baixo (base já aplicada em E2) | **Crítico (se copiado)** / **Baixo (Clean-Room)** | **estudar padrão** | **DECLARAÇÃO GPL EXPLÍCITA:** Proibido copiar, traduzir ou portar código, pesos, textos ou assets (ver [`docs/PESTINHA_LICENCAS.md`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/docs/PESTINHA_LICENCAS.md)). Padrões matemáticos de homeostase, habituação, Rescorla-Wagner e memória episódica já reimplementados do zero em [`personality.gd`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/scripts/behavior/personality.gd). |
| **Pet Mochi**<br>`cskwork/pet-mochi` | **MIT** | Branch `main` (`v0.3.0`)<br>`29e67cfeeb` (`2026-10-28`) | Baixo a Médio | Baixo | **estudar padrão** | Stack distinta (Tauri 2 / Rust / Svelte 5), portanto não se reutiliza como biblioteca. Excelente referência de arquitetura para: (1) acumulação `float` interna com arredondamento apenas nas fronteiras, (2) portão de saliência + múltiplos *cooldowns*, (3) coreografia de catálogo fechado com fallback determinístico offline e (4) ponderação de confiança na memória. |
| **AI Town**<br>`a16z-infra/ai-town` | **MIT** *(assets de terceiros separados)* | Branch `main`<br>`8e05997f24` (`2026-08-26`) | Médio | Baixo | **estudar padrão** | Stack web/cloud (Convex + PixiJS + LLM obrigatório), incompatível como biblioteca local. Excelente padrão para: (1) score de recuperação de memória (`relevância + importância + recência` normalizados), (2) reflexão disparada por soma acumulada de importância com links para memórias-fonte e (3) máquina de estados de encontro social com *cooldowns* anti-loop. |
| **HermitClaw**<br>`brendanhogan/hermitclaw` | **MIT (no README)** *(sem arquivo `LICENSE` dedicado)* | Branch `main` (`v0.1.0`)<br>`2b69414969` (`2026-02-17`) | Baixo a Médio | **Médio (ausência de `LICENSE` SPDX)** / **Extremo (se imitar shell)** | **estudar padrão** *(motivação/quarto)* / **descartar** *(execução shell/sandbox)* | Estudar os padrões de: (1) interesses/curiosidade derivados deterministicamente da semente/genoma, (2) estações/objetos do ambiente ancorados ao estado cognitivo, (3) razão exploração→produção e (4) hierarquia de reflexão (`depth 0 -> 1`). **Descartar integralmente** o modelo de execução de shell e *monkey-patching* (`pysandbox.py`), que não é barreira de segurança. |
| **Sketch-RNN**<br>`magenta/magenta` (`.../sketch_rnn`) | **Apache-2.0** | Branch `main` (Arquivado)<br>`c15687ebd1` (`2026-01-06`) | Baixo (formato `stroke-3`) / Extremo (rede TF) | Alto (rede TF legada) / Mínimo (formato `stroke-3`) | **descartar** *(biblioteca/modelo TF)* / **estudar padrão** *(codificação `stroke-3`)* | Repositório arquivado e dependente de TensorFlow 1.x / Python em tempo de execução. Descartar a biblioteca e o modelo Seq2Seq VAE. Adotar apenas o padrão de representação de desenhos como sequência de deslocamentos relativos `stroke-3` $(\Delta x, \Delta y, p_{\text{lift}})$ para renderização procedural leve em `CanvasItem`. |
| **Quick, Draw! Dataset**<br>`googlecreativelab/quickdraw-dataset` | **CC BY 4.0** *(dados)* / **Apache-2.0** *(exemplos)* | Branch `master` (Arquivado)<br>`5fe6c0a910` (`2025-03-11`) | Baixo (se curado offline) | Baixo (exige atribuição CC BY 4.0 e curadoria) | **estudar padrão** *(polilinhas simplificadas RDP)* | **Não baixar o dataset bruto** (dezenas de GBs e 50M de desenhos com ruído). Estudar o padrão de normalização $256 \times 256$ e simplificação Ramer-Douglas-Peucker ($\varepsilon = 2{,}0$). Caso um micro-catálogo curado (< 50 ícones) seja extraído futuramente, exigir registro SHA256 e atribuição CC BY 4.0 a Google, Inc. |
| **OpenC2E**<br>`openc2e/openc2e` | **LGPL-2.1-or-later** | Branch `main`<br>`dfcd46f2d6` (`2026-10-07`) | Médio (em GDScript próprio) | **Alto (se copiado C++/LGPL)** / **Baixo (Clean-Room)** | **estudar padrão** | **DECLARAÇÃO LGPL/GPL EXPLÍCITA:** Proibido copiar, traduzir ou portar código C++ do OpenC2E. Estudar e reimplementar por requisitos os padrões biológicos da série *Creatures*: meia-vida exponencial de substâncias/estados, acoplamento emissor→reação→receptor, custo energético metabólico proporcional à complexidade genética e reforço por redução de drive. |

> **Nota Síntese sobre a Coluna "Reutilizar Biblioteca":** Nenhuma das 8 referências estudadas nesta rodada deve ser acoplada como biblioteca de terceiros em tempo de execução (`reutilizar biblioteca = Nenhuma`), pois todas ou usam stacks externas incompatíveis com o contrato *No Python / No Network at runtime* (Python/PyQt, Tauri/Rust/Svelte, Convex/Node, TensorFlow 1.x, C++17/SDL2) ou possuem licenças copyleft (`GPL-2.0`, `GPL-3.0-or-later`, `LGPL-2.1-or-later`). O ganho máximo de engenharia para o EvoWorld 3.0 está em **estudar os padrões algorítmicos validados** e implementá-los de forma limpa, enxuta e determinística sobre os módulos GDScript existentes.

---

## 4. Padrões Concretos Adotáveis em GDScript para o EvoWorld 3.0

Todos os padrões abaixo foram desenhados especificamente para se integrarem aos contratos existentes de [`SimWorld`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/scripts/world/sim_world.gd), [`SimCreature`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/scripts/creature/sim_creature.gd), [`Personality`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/scripts/behavior/personality.gd), [`QBrain`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/scripts/behavior/q_brain.gd), [`Ensino`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/scripts/interaction/ensino.gd) e [`Dialogo`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/scripts/communication/dialogo.gd), preservando determinismo por semente (`SimRng`), precisão truncada via `snappedf(..., 0.000001)` e zero alocação desnecessária por tick.

---

### Padrão 1: Score de Recuperação de Memória Multicritério (`recência + relevância + importância + confiança`)

**Inspiração:** AI Town (`rankAndTouchMemories`), HermitClaw (`MemoryStream.retrieve`) e Pet Mochi (`search_memories`).
**Onde aplicar no EvoWorld:** Em [`scripts/behavior/personality.gd`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/scripts/behavior/personality.gd) e [`scripts/communication/dialogo.gd`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/scripts/communication/dialogo.gd) para selecionar quais episódios dentre os `EPISODE_LIMIT = 32` (ou vínculos em `bonds`) fundamentam uma decisão atual ou uma resposta de diálogo ao jogador.

**Formulação Matemática Determinística (sem embeddings externos):**
Para cada episódio $e$ armazenado em `personality.episodes` no tick atual $T$, diante de um contexto consultado $C_{\text{atual}} = (\text{food\_type}, \text{energy\_bucket}, \text{hydration\_bucket}, \text{action\_filter})$:

1. **Recência ($R \in [0, 1]$):** Decaimento exponencial discreto baseado na idade em ticks ($\Delta t = T - e.\text{tick}$), usando meia-vida de 600 ticks (60 segundos simulados):
   $$R(e, T) = \text{clamp}\left(0{,}9988^{\Delta t},\; 0{,}0,\; 1{,}0\right)$$
2. **Relevância Contextual ($S \in [0, 1]$):** Similaridade estrutural exata (dispensa vetores de embedding):
   - $+0{,}50$ se $e.\text{context.food\_type} == C_{\text{atual}}.\text{food\_type}$ (ou mesmo parceiro social);
   - $+0{,}25$ se $e.\text{context.energy} == C_{\text{atual}}.\text{energy}$;
   - $+0{,}25$ se $e.\text{context.hydration} == C_{\text{atual}}.\text{hydration}$.
3. **Importância Biológica ($I \in [0, 1]$):** Derivada diretamente da magnitude física da consequência medida no episódio:
   $$I(e) = \text{clamp}\left(\frac{|e.\text{consequence.energy}|}{25{,}0} + \frac{|e.\text{consequence.hydration}|}{25{,}0} + |e.\text{consequence.fatigue}| + b_{\text{fonte}},\; 0{,}0,\; 1{,}0\right)$$
   onde $b_{\text{fonte}} = 0{,}35$ para eventos raros (`toxic_food`, `player_contact`, `resource_contention`, `encounter`) e $0{,}0$ para metabolismo rotineiro (`body`).
4. **Confiança Estatística ($C \in [0, 1]$):** Calculada a partir da consistência histórica daquele par `(contexto, ação)` com $n$ observações registradas:
   $$C(e) = \left(1{,}0 - \frac{1{,}0}{\sqrt{\max(1, n)}}\right) \cdot \text{clamp}\left(\frac{|\mu_{\Delta}|}{\sigma_{\Delta} + 1{,}0},\; 0{,}0,\; 1{,}0\right)$$
5. **Score Combinado:**
   $$\text{Score}(e) = \text{snappedf}\left(0{,}25 \cdot R + 0{,}35 \cdot S + 0{,}25 \cdot I + 0{,}15 \cdot C,\; 0{,}000001\right)$$
   *(Em caso de empate, desempata-se deterministicamente pelo maior `e.tick` e, persistindo o empate, pelo menor índice na fila).*

---

### Padrão 2: Rótulos de Confiança e Decomposição de Decisão (`Score Base` vs. `Score Modificado`)

**Inspiração:** Dosidicus (`decisions_panel.py` / `neural_provenance.py`).
**Onde aplicar no EvoWorld:** Na escolha de ação em [`scripts/world/sim_world.gd`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/scripts/world/sim_world.gd) / [`scripts/behavior/q_brain.gd`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/scripts/behavior/q_brain.gd) e na visualização em [`scripts/ui/personality_inspector.gd`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/scripts/ui/personality_inspector.gd), com textos localizados em [`scripts/core/textos.gd`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/scripts/core/textos.gd).

**Especificação do Mecanismo:**
1. **Registro Duplo por Candidato (`base_score` e `final_score`):**
   - Ao avaliar candidatos de ação (ex.: buscar alimento A vs. alimento B, aproximar vs. evitar outra criatura, descansar vs. explorar), o simulador calcula:
     - `base_score`: utilidade fisiológica/heurística bruta (ex.: proximidade e valor energético nominal antes da experiência individual);
     - `modifier_delta`: contribuição somada de `personality.preferences`, `personality.conditioning`, `personality.habituation` e `personality.bonds`;
     - `final_score = clampf(base_score + modifier_delta, 0.0, 2.5)`.
   - Isso permite à interface desenhar, na mesma barra de decisão, um traço vertical indicando *o que uma criatura ingênua faria* (`base_score`) e a barra preenchida indicando *o que esta criatura escolheu após suas experiências* (`final_score`).
2. **Margem de Confiança e Rótulo Qualitativo Honestamente Fundamentado:**
   - Sejam $s_1 \ge s_2 \ge 0$ os dois maiores `final_score` entre as ações candidatas no tick atual. Define-se a margem relativa de decisão:
     $$m = \text{clamp}\left(\frac{s_1 - s_2}{\max(0{,}001,\; s_1)},\; 0{,}0,\; 1{,}0\right)$$
   - Mapeamento para chaves estáveis (com tradução em `textos.gd` usando linguagem observacional "aparenta"):
     - $m < 0{,}12 \implies$ `"torn"` (*"Aparenta dividido entre opções próximas"*);
     - $0{,}12 \le m < 0{,}32 \implies$ `"leaning"` (*"Aparenta inclinado a esta escolha"*);
     - $0{,}32 \le m < 0{,}60 \implies$ `"fairly_sure"` (*"Aparenta seguro na escolha"*);
     - $0{,}60 \le m < 0{,}85 \implies$ `"confident"` (*"Aparenta confiante"*);
     - $m \ge 0{,}85 \implies$ `"decisive"` (*"Aparenta decisivo"*).

---

### Padrão 3: Estados Afetivos e Mudança de Política com Causa Explícita (Contingência vs. Deriva Basal)

**Inspiração:** Dosidicus (`causal_learning.py`, `neural_provenance.py`) e Pestinha (atribuição retroativa).
**Onde aplicar no EvoWorld:** Em [`scripts/behavior/personality.gd`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/scripts/behavior/personality.gd) (`expression()`, `ingest()`, `meet()`) e no inspetor científico.

**Especificação do Mecanismo:**
1. **Contingência Descontada da Deriva Basal:**
   - Em [`SimWorld`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/scripts/world/sim_world.gd), o metabolismo basal drena energia e hidratação continuamente a cada tick mesmo quando a criatura apenas caminha.
   - Para que a criatura (e o painel científico) diferencie *correlação temporal* de *causa real*, cada atualização de preferência ou condicionamento registra o ganho líquido **acima da deriva metabólica esperada por tick** ($\Delta_{\text{líquido}} = \Delta_{\text{observado}} - \Delta_{\text{basal}}$).
2. **Vetor de Causas de Estado Afetivo (`affect_causes`):**
   - Atualmente, `Personality.expression(creature)` retorna `{"valence": ..., "arousal": ...}`.
   - Estende-se o retorno (ou método auxiliar de leitura `explain_expression(creature)`) para decompor a valência e a excitação nas suas **parcelas causais exatas**:
     - `hunger_pull`: $-0{,}65 \times \text{fome}$ (se dominante $\to$ causa primária: `"deficit_hunger"`);
     - `thirst_pull`: $-0{,}65 \times \text{sede}$ (se dominante $\to$ causa primária: `"deficit_thirst"`);
     - `fatigue_pull`: $-0{,}65 \times \text{fatigue}$ (se dominante $\to$ causa primária: `"deficit_fatigue"`);
     - `loneliness_pull`: $-0{,}15 \times \text{loneliness}$ (`"social_isolation"`);
     - `boredom_pull`: $-0{,}10 \times \text{boredom}$ (`"low_novelty"`);
     - `recent_event_pull`: $+0{,}45 \times \text{event\_valence}$, vinculado ao último episódio não rotineiro (`last_significant_episode`).
   - Assim, todo estado afetivo exibido na UI vem acompanhado de sua causa verificável: ex.: *"Valência -0,42 (causa principal: sede elevada [-0,38] e último encontro competitivo com #4 no tick 1280 [-0,18])"*.
3. **Registro de Proveniência de Mudança de Política (`policy_delta_log`):**
   - Sempre que `preferences[food_type]`, `conditioning[key]`, `bonds[id]` ou `goal_q[cell]` sofrer variação $|\Delta w| \ge 0{,}01$, anexa-se a um buffer circular pequeno (ex.: `PROVENANCE_LIMIT = 16`) uma tupla `{tick, target_key, before, after, delta, rule, episode_tick}` onde `rule` $\in$ `{"rescorla_wagner_ingest", "social_encounter", "monte_carlo_teaching", "habituation_decay"}`.

---

### Padrão 4: Portão de Saliência (*Salience Gate*) e Cooldown em Camadas para Expressão e Eventos

**Inspiração:** Pet Mochi (`salience.ts`, `nudges.ts`, `autonomousGate.ts`) e AI Town (`CONVERSATION_COOLDOWN`).
**Onde aplicar no EvoWorld:** Em [`scripts/communication/dialogo.gd`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/scripts/communication/dialogo.gd), nos balões/notificações da UI e como contrato de fronteira caso um verbalizador local opcional seja acoplado no futuro.

**Especificação do Mecanismo:**
1. **Separação Estrita entre Tick de Simulação e Camada Expressiva:**
   - O passo `SimWorld.step()` (0,1s) executa 100% em GDScript puro e síncrono.
   - Emissões de balões narrativos espontâneos ou resumos de eventos na UI passam por uma função pura `should_emit_salient_notice(event_type, creature, tick)`:
     $$\text{saliência} = w_{\text{evento}}(\text{event\_type}) + 40{,}0 \cdot \max(\text{fome}, \text{sede}, \text{fatigue}) + 30{,}0 \cdot \text{bond\_familiarity}$$
   - O aviso só é disparado se $\text{saliência} \ge 70{,}0$ **E** `tick - last_any_notice_tick >= GLOBAL_COOLDOWN_TICKS` (ex.: 150 ticks = 15s) **E** `tick - last_kind_notice_tick.get(event_type, -9999) >= KIND_COOLDOWN_TICKS` (ex.: 600 ticks = 60s).
2. **Coreografia de Catálogo Fechado:**
   - Qualquer reação expressiva escolhe exclusivamente identificadores de um conjunto finito auditado (`CLOSED_REACTIONS = ["approach", "recoil", "rest_curl", "curious_tilt", "share_yield", "alert_pulse"]`), garantindo que saves ou módulos de diálogo nunca injetem estados inválidos na simulação.

---

### Padrão 5: Consolidação e Reflexão Hierárquica durante o Repouso (`rest`)

**Inspiração:** AI Town (`reflectOnMemories`), HermitClaw (hierarquia `depth 0 -> depth 1`) e Dosidicus (`sleep_consolidation.py`).
**Onde aplicar no EvoWorld:** Em [`scripts/behavior/personality.gd`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/scripts/behavior/personality.gd) quando `creature.last_action == "rest"`.

**Especificação do Mecanismo (100% Determinístico, sem LLM):**
1. **Acumulador de Importância (`importance_sum`):**
   - Cada episódio não rotineiro gravado em `Personality.record()` incrementa `importance_sum += I(e)`.
2. **Gatilho de Consolidação em Repouso:**
   - Quando a criatura está em estado `"rest"` e `importance_sum >= REFLECTION_THRESHOLD` (ex.: `3.5`), executa-se um passo determinístico de síntese sobre a janela recente de episódios (`depth = 0`):
     - Agrupam-se episódios pelo par `(context_key, action)` ou `(reward_source, event)`;
     - Se um grupo possui $\ge 3$ ocorrências com consequência média consistente ($|\mu_{\Delta E}| \ge 2{,}0$ ou valência social consistente), os episódios redundantes de nível `depth = 0` são compactados em um único episódio-síntese de nível `depth = 1` contendo `{"count": k, "mean_energy": mu_e, "source_ticks": [t1, t2, ...]}`, aplicando um pequeno reforço de consolidação ($+5\%$ na direção da média comprovada) em `preferences` ou `conditioning`, e zerando `importance_sum`.
   - **Benefício:** Libera espaço no buffer `EPISODE_LIMIT = 32` sem perder aprendizados de longo prazo e cria "hábitos consolidados" que o jogador pode inspecionar no painel do pet.

---

### Padrão 6: Interesses Inatos Semeados pelo Genoma, Zonas do Habitat e Trava de Exploração Improdutiva

**Inspiração:** HermitClaw (`identity.py`, `ROOM_LOCATIONS`, `_consecutive_research_cycles`).
**Onde aplicar no EvoWorld:** Em [`scripts/creature/sim_creature.gd`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/scripts/creature/sim_creature.gd) / [`scripts/behavior/personality.gd`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/scripts/behavior/personality.gd).

**Especificação do Mecanismo:**
1. **Afinidades Inatas Determinísticas (sem quebrar saves antigos):**
   - A partir de `creature.genome.id` e `world.seed` (ou dos genes contínuos já existentes), deriva-se deterministicamente uma afinidade inicial leve ($\pm 0{,}08$) por um bioma/recurso ou estação do mapa, que pode ser livremente superada pela experiência real via Rescorla-Wagner (`ingest`).
2. **Contador de Exploração Sem Ganho (`unproductive_explore_ticks`):**
   - Se a criatura permanece em ação `"explore"` por mais de $N$ ticks consecutivos (ex.: 120 ticks) na mesma região sem descobrir célula nova e sem encontrar recurso, um viés de redirecionamento aumenta a penalidade de habituação da zona atual (`zone:x:y`), forçando a mudança de direção ou retorno a uma área segura conhecida.

---

### Padrão 7: Desenho e Glifos Procedurais como Sequência de Traços (`stroke-3`)

**Inspiração:** Sketch-RNN (`utils.py:strokes_to_lines`) e Quick, Draw! Dataset (polilinhas simplificadas).
**Onde aplicar no EvoWorld:** Em [`scripts/render/world_view.gd`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/scripts/render/world_view.gd) ou em um futuro painel de expressão/sinais da criatura.

**Especificação do Mecanismo:**
- Cada glifo de sinal (`symbol 0..7`) ou rabisco expressivo é representado estaticamente em GDScript como um array compacto de tuplas `[dx, dy, pen_lift]` normalizadas em $[-16, +16]$:
  ```gdscript
  # Exemplo conceitual de renderizador determinístico stroke-3 em CanvasItem:
  static func build_polylines(strokes: Array, origin: Vector2, scale_px: float, jitter: float, rng) -> Array:
      var polylines: Array = []
      var current := PackedVector2Array()
      var cursor := origin
      current.append(cursor)
      for step in strokes:
          var jx: float = rng.between(-jitter, jitter) if jitter > 0.0 and int(step[2]) == 0 else 0.0
          var jy: float = rng.between(-jitter, jitter) if jitter > 0.0 and int(step[2]) == 0 else 0.0
          cursor += Vector2(float(step[0]) * scale_px + jx, float(step[1]) * scale_px + jy)
          current.append(cursor)
          if int(step[2]) == 1:
              if current.size() >= 2:
                  polylines.append(current)
              current = PackedVector2Array()
      if current.size() >= 2:
          polylines.append(current)
      return polylines
  ```
- O parâmetro `jitter` é modulado diretamente por `fatigue` ou `arousal` da criatura, produzindo variação orgânica honesta (traço trêmulo quando exausta/assustada, traço firme quando descansada e confiante) com custo de renderização próximo de zero.

---

### Padrão 8: Acoplamento Bioquímico Emissor → Reação → Receptor e Meia-Vida Uniforme

**Inspiração:** OpenC2E (`Biochemistry.cpp`: meia-vida exponencial, custo energético de órgãos e redução de drive).
**Onde aplicar no EvoWorld:** Na evolução da fisiologia em [`scripts/world/sim_world.gd`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/scripts/world/sim_world.gd) e [`scripts/environment/food_catalog.gd`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/scripts/environment/food_catalog.gd).

**Especificação do Mecanismo:**
- Caso o EvoWorld 3.0 introduza efeitos metabólicos temporários (ex.: toxina residual após ingerir `cogumelo` ou adrenalina após fuga/competição), em vez de criar timers booleanos avulsos, modelá-los como **concentrações internas normalizadas $[0{,}0, 1{,}0]$ com meia-vida exponencial determinística por tick**:
  - Ingestão de alimento com `toxicity > 0` atua como *emissor* elevando `toxin_level`;
  - A cada tick, `toxin_level = snappedf(toxin_level * HALF_LIFE_MULT, 0.000001)` (onde `HALF_LIFE_MULT` depende da resistência metabólica);
  - Enquanto `toxin_level > THRESHOLD`, um *receptor* aplica uma drenagem proporcional de energia/hidratação e eleva o impulso de repouso (`fatigue`), mantendo total rastreabilidade física e compatibilidade com o contrato de que apenas eventos físicos alteram a fisiologia.

---

## 5. Conformidade de Proveniência e Regras de Segurança

1. **[FATO] Zero Arquivos Incorporados:** Nenhum código-fonte, peso neural, sprite ou arquivo de dataset das 8 referências acima foi copiado ou baixado para o repositório EvoWorld.
2. **[FATO] Registro em `docs/ASSET_PROVENANCE.md`:** Todas as 8 referências inspecionadas foram catalogadas na tabela de auditoria de [`docs/ASSET_PROVENANCE.md`](file:///C:/Users/Yurtachi/orca/workspaces/EvoWorld/evo3-m0c/docs/ASSET_PROVENANCE.md) com URL, commit exato, data, licença confirmada, exigências de atribuição e status `Nenhum arquivo incorporado`.
3. **[FATO] Proteção contra Contaminação de Licença e Riscos de Execução:**
   - Repositórios sob `GPL-2.0` (**Dosidicus**), `GPL-3.0-or-later` (**Pestinha**) e `LGPL-2.1-or-later` (**OpenC2E**) estão bloqueados contra qualquer cópia ou tradução de código.
   - O antipadrão de execução de comandos shell / *monkey-patching* do **HermitClaw** está expressamente banido da arquitetura do EvoWorld.
