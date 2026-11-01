# ORCA GOAL — EvoWorld: laboratório de vida artificial evolutiva jogável

**Cole integralmente esta missão no Orca com Claude Sonnet selecionado como coordenador.** A seleção de Sonnet é uma exceção explícita para este projeto, solicitada pelo usuário; não altera o coordenador padrão de outros projetos. O orquestrador deve validar seus comandos e capacidades no runtime instalado antes de enviar workers. Esta missão é deliberadamente autônoma para trabalho local seguro; nenhuma ação externa/destrutiva é autorizada por inferência.

## GOAL / Resultado final exigido
Construa um produto real e jogável, provisoriamente chamado **EvoWorld**, um sandbox desktop 2D em que o jogador adota uma criatura principal, a nomeia, alimenta, interage e ensina; pode introduzir outros organismos e manipular um ecossistema; observa agentes independentes que aprendem durante a vida e linhagens que evoluem entre gerações; inspeciona genética, memória, relações, genealogia e eventos; observa comunicações/sinais entre criaturas e consegue dialogar com a criatura principal de maneira fundamentada no estado real dela. O mundo deve ser salvo/retomado. É obrigatório implementar e validar comportamento, não apenas gerar documentos, screenshots ou animações roteirizadas.

A prioridade é **produto jogável, arquitetura sustentável, experiência visual convincente e aprendizado/evolução comprováveis**. Reutilize e adapte componentes open-source e assets reais para ganhar velocidade, mas sem comprometer licenças, compatibilidade ou originalidade. Trabalhe em iterações testáveis e preserve a continuidade. Não anuncie como concluída uma funcionalidade apenas planejada.

## 0. Identidade, papéis e gate de orquestração
- **Coordenador requerido:** Claude Sonnet (ID/versão/CLI descobertos e confirmados no Orca da máquina). Pedido explícito do usuário substitui o default Codex **somente nesta missão**. Sonnet é responsável pelo planejamento, distribuição de tarefas, integração e critérios de aceite.
- Antes de coordenar: consultar `orca status --json` e a skill `orca skills get orchestration --full` **se disponíveis e suportados na versão instalada**. Não inventar flags, IDs de agentes, Runs/Tasks/Dispatches nem assumir que abrir três terminais é orquestração efetiva. Confirmar autenticação, modelo, quota, permissões, cwd, root Git, worktrees e capacidade real de dispatch. Se esses comandos diferirem, usar as instruções oficiais do runtime local. Se o gate falhar, PARAR a coordenação, preservar tudo e reportar o bloqueio, sem encenar workers ou trocar gerente silenciosamente.
- **Workers candidatos**, somente se conectados, adequados e autorizados: Codex para implementação e testes; Antigravity/AGY como revisão independente e investigação; outro worker disponível para game/UI/experimentos. Não pressupor nomes de modelos ou disponibilidade. Claude Opus somente para consulta excepcional justificada, não para polling, evitando custo desnecessário.
- Até **3 workers simultâneos**, além de Sonnet, apenas quando as tarefas forem independentes e a máquina suportar. Cada escritor em branch/worktree própria, nunca dois escritores na mesma worktree. Revisor não pode ter implementado o patch que aprova.
- Criar Run/Tasks/Dispatches reais conforme skill, com owner, estado, critérios de aceite e recibos. Acompanhar workers até resultado, preservar diffs/testes antes de ACK/encerramento e relatar fatos comprovados.

## 1. Reconhecimento obrigatório antes de qualquer escrita
1. Descobrir o workspace do Orca e verificar se há projeto/repositório pré-existente. Confirmar root, remote, branch, HEAD, status incluindo untracked, worktrees, locks, origem do baseline, instruções locais (`AGENTS.md`, `CLAUDE.md`, README, ADR, documentação). **Não presumir um caminho do Windows, nem sobrescrever um repo de outro produto.** Se o workspace estiver vazio e autorizado para EvoWorld, inicializar projeto local isolado; se contiver projeto não relacionado, não invadir: reportar e exigir um diretório autorizado.
2. Confirmar versão de Godot instalada, executáveis disponíveis, renderização/headless, Python, Git, OS/CPU/RAM/GPU e rede, sem coletar credenciais. Não substituir versões já fixadas sem necessidade.
3. Checar licença, versões, commits e compatibilidade dos projetos externos listados abaixo; registrar matriz make/adapt/use com custo e risco. Consultar documentação oficial, changelogs, issues e exemplos. Se não houver rede, registrar `[LACUNA]` e usar alternativas locais sem inventar resultados.
4. Definir um plano incremental com tarefas e critério de aceite para uma primeira vertical slice; começar a implementar na mesma missão, se gates permitirem. Não gastar toda a execução apenas escrevendo planos.

## 2. Reuso obrigatório antes de implementação customizada
Pesquisar e avaliar:
- Godot engine (MIT): https://godotengine.org/license/ — principal candidata, versão estável instalada/comprovada.
- Godot RL Agents (MIT): https://github.com/edbeeching/godot_rl_agents — bridge Python/Godot, 2D, exemplos RL, possível export ONNX. Avaliar compatibilidade real antes de integrar.
- Plugin Godot 4 (MIT): https://github.com/edbeeching/godot_rl_agents_plugin — usar só após POC isolada.
- neat-python (BSD-3-Clause): https://github.com/CodeReclaimers/neat-python — evolução offline de redes, exportação JSON; **não assumir inferência GDScript pronta**.
- Kenney Roguelike/RPG Pack (CC0): https://kenney.nl/assets/roguelike-rpg-pack — terreno, cenário, ícones e objetos.
- Kenney Animal Pack Remastered (CC0): https://kenney.nl/assets/animal-pack-remastered — animal sprites de referência, avaliar se consistentes com biologia procedural.
- Kenney Pixel Pack (CC0): https://kenney.nl/assets/pixel-pack — recursos complementares.
- Brax (Apache-2.0): https://github.com/google/brax — somente para pesquisa de treinamento futuro; o projeto informa que `brax/envs` não é mantido como antes, portanto evitar dependência ingênua.
- Exemplos oficiais de Godot/Godot Asset Library e projetos abertos similares relevantes identificados na pesquisa; incluir somente se licença/saúde comprovadas.

Para cada asset/lib escolhido: URL oficial, licença, versão/tag/commit, data, hashes quando fizer sentido, compatibilidade, arquivos, riscos de supply chain e atribuições obrigatórias no `docs/ASSET_PROVENANCE.md`. Manter notices exigidos. Preferir CC0/MIT/BSD/Apache compatíveis, mas checar licenças de assets individuais. Não copiar assets/código de The Bibites, Spore, Pokémon ou jogos comerciais; são apenas referências conceituais. Não raspar imagens sem licença clara. Não criar arte visual nova se houver assets adequados, exceto para características procedurais genuínas do genoma.

## 3. Produto e funcionalidades — exigência funcional
### 3A. Mundo jogável
Um mundo 2D top-down com câmera, zoom/pan, recursos renováveis (comida, água), obstáculos, ambiente configurável, relógio/ticks e pausa/velocidade. Usuário pode inserir/remover objetos de modo seguro, introduzir novas criaturas e acompanhar sua simulação em tempo real. Design agradável e coerente; UI legível, layouts bem acabados, sem sobrecarga de texto de depuração.

### 3B. Pet principal e outros organismos
Pet inicial com nome, ID estável, avatar procedural, estatísticas, sensores e ações. Vínculo/afinidade com usuário ancorado em eventos reais; opções alimentar, chamar, brincar, proteger, acompanhar e inspecionar. Outros organismos com as mesmas regras fundamentais, podendo variar em genoma, comportamento e ecologia. Modo protegido versus sobrevivência configurável; sinalizar claramente morte e consequências quando proteção estiver desligada.

### 3C. Aprendizado individual REAL
Criaturas têm observações limitadas (não oniscientes), ações com custos/efeitos, estados internos, memória curta e um mecanismo de aprendizado ou política treinável. Implementar primeiro uma política baseline simples e reproduzível. Depois demonstrar melhoria real em ao menos uma tarefa (p.ex., distinguir alimento nutritivo de item neutro, buscar comida, evitar área de risco) comparando com baseline de mesma seed e seeds fora do treino. Não chamar heurística fixa de "IA que aprende".

### 3D. Evolução hereditária REAL
Genoma serializável com traços herdáveis dentro de limites, reprodução, mutação, registro de genitores/filhos, gerações, envelhecimento e dinâmica ecológica real. Hereditariedade deve afetar fenótipo/comportamento (ex.: alcance sensorial, tamanho, cor, velocidade, metabolismo e parâmetros neurais), não apenas mudar uma etiqueta. Acompanhar árvores familiares e diversidade; limitar população e evitar seleção artificial oculta que distorça o sandbox.

### 3E. Comunicação entre criaturas
Canal de 4–8 sinais discretos, percebidos com alcance/ruído/custo configuráveis e possibilidade de aprender reação. Registrar quem emitiu, quem ouviu, contexto e mudança de ação. Definir experimento de ablação (canal ativo vs desligado). **Não atribuir significado sem evidência**: um sinal não é automaticamente "perigo" ou "comida". Comunicação emergente complexa é hipótese de pesquisa, não garantia. Evoluir para proto-linguagem somente após resultados básicos.

### 3F. Comunicação entre jogador e criatura
Expor interface de interação textual, inicialmente por intents reais (chamar, oferecer comida, perguntar sobre estado, seguir/parar), com respostas em português derivadas de estado, eventos e memória autorizada. Não afirmar consciência, emoções literais ou memórias inexistentes. Se for incorporado um LLM opcional para verbalização natural, ele é estritamente uma camada de expressão com dados delimitados e sem controlar biologia/estado por respostas livres; opcional e desligado por padrão.

### 3G. Visualização científica e observabilidade
Painéis para organismo, espécie/linhagem, genealogia, memória, decisões recentes, sinais recebidos, nascimento/morte, recursos, população e séries simples. Exibir taxa de ticks/FPS, número de entidades, seed e versão da simulação. UI de cuidador e UI de laboratório separadas por toggle, sem bloquear o gameplay.

### 3H. Persistência e exportação
Novo mundo, salvar, carregar, autosave com segurança, backups/versionamento de formato, ID e memória do pet, genome e estado da simulação, linhagens; controles de import/export com schema validado. Evitar execução de código arbitrário em saves e carregar dados malformados. Validação de round-trip e recuperação de save inválido.

## 4. Arquitetura (proposta sujeita a descoberta)
- **Game/render/UI:** Godot 4 + GDScript, desktop Windows offline por padrão.
- **Core:** world step com tick fixo e RNG seeded; contratos explícitos de sensores, ações, eventos, genoma, cérebro e save; desacoplamento de lógica/visualização; spatial hashing ou estrutura simples quando necessário.
- **Behavior:** policy baseline e policy treinável por agente; decisão sem Python em tempo real salvo POC justificada; proteção contra custo O(N²) desnecessário.
- **Evolution:** herança/mutação, seleção emergente via recursos/sobrevivência/reprodução, linhagens auditáveis. NEAT pode ser usado no treinamento offline, não pressupor uso obrigatório nem migrar de engine sem evidência.
- **Communication:** sinais simbólicos + logs e métricas, desacoplados do narrador em português.
- **UI:** controle criativo + painel do pet + laboratório, com animações sutis e acessibilidade.
- **Persistence:** schema versionado, checksum/backups, validação e migração.
- **Labs:** experimentos Python/Jupyter reproduzíveis; integração Colab **posterior**, não necessária para abrir ou jogar.

Não exigir todos os diretórios teóricos; priorizar organização simples, sólida e sem abstrações prematuras. Usar documentação real da versão de Godot para comandos, APIs, testes e export, sem inventar flags.

## 5. Ordem de implementação e gates progressivos
**G0 — audit/readiness:** workspace correto, baseline protegido, licença/stack confirmados e Run/Tasks reais. Se bloqueado, não alterar.

**G1 — vertical slice jogável:** mundo renderiza, pet selecionável/nomeável, organismos autônomos, alimentação, spawn, UI, salvar/carregar; teste de retomada real e screenshot nova do build. Não sair sem a experiência mínima utilizável.

**G2 — aprendizado:** baseline vs agente que aprende em pelo menos uma tarefa com experimento reprodutível, métricas, seeds de avaliação separados, save do cérebro e visualização básica de decisão.

**G3 — evolução:** reprodução, genomas, mutações, fenótipos, pelo menos três gerações observáveis e linhagem persistente. Demonstrar dados concretos de herança sem declarar adaptação não medida.

**G4 — comunicação:** sinais agente-agente e experimento canal ligado/desligado; UI de observação; pet responde a interações do jogador com intents/estado verificáveis.

**G5 — produto polido:** UI coerente, fluxos novos/carregar/configurar, ferramentas de mundo, performance, cenários de teste, instruções de instalação/execução e build jogável comprovado.

**G6 — Colab opcional:** investigar apenas após G1–G4 comprovados. Confirmar GPU efetiva, VRAM, CCUs, dependências e política do serviço; notebook reproduzível, checkpoints de modelo, export/import em contrato estável e performance comparada no jogo. Sem servidor permanente/túnel a partir do Colab. Se os experimentos não exigirem GPU, NÃO gastar CCUs; justificar CPU local.

As fases G1–G4 são compromisso de escopo do **objetivo final**, não promessa de execução num único ciclo independente de quotas, ferramentas ou blockers. Progredir a cada fase pronta, reportar o que falta, preservar estado, continuar conforme runtime e autorização. Não completar artificialmente campos de sucesso.

## 6. Paralelismo recomendado por ondas
**Primeira onda, após G0:**
- Worker A — pesquisa de reuso/licenças + POC de recursos externos e matriz de compatibilidade (read-only inicialmente).
- Worker B — cenário Godot/UX/arte e vertical slice, em worktree exclusiva.
- Worker C — modelo de entidade/biologia/simulação/testes determinísticos, em worktree exclusiva.
Sonnet integra apenas com interfaces combinadas e revisões independentes. Evitar merge de alterações que mexam nos mesmos recursos/scene files sem ownership.

**Segunda onda, após G1:**
- Behavior/learning; genetics/evolution; UI científico/persistência em escopos separados, com uma fonte canônica de schema e integração sequenciada.

**Terceira onda:**
- Comunicação/sinais; testes de aprendizado/evolução; polimento/QA. Verificações de save e regressão após cada integração.

Escolher workers por capacidades verdadeiramente disponíveis; nunca inventar profissionais, skills, modelos, custos ou resultados. Sonnet deve supervisionar, não executar tudo nem ficar em polling caro. Resumir mensagens, acionar especialistas sob demanda, preservar evidências.

## 7. Testes e critérios de aceite não negociáveis
- Instalação/boot no ambiente real, logs de erro claros, testes unitários e integração proporcionais à fase.
- Usuário consegue: adotar pet, alimentá-lo, introduzir outras criaturas, alterar ambiente, observar comportamento, salvar/carregar, examinar linhagem, ver sinais e interagir por comandos/diálogo ancorado em estado.
- Sem alegar IA antes de comprovar aprendizado vs baseline; comparações com seeds de treino e holdout, sem cherry-picking.
- Filhotes têm ID próprio, genes herdados/mutados dentro dos limites, genitores e árvore persistente, fenótipo reflete herança.
- Comunicação medível com receptor, contexto e ação; comparar experimento sem canal.
- Save/restore conserva pet, mundo, memória/cérebro e genealogia, ou relatório honesto sobre limitações suportadas.
- Performance medida em máquina real; meta inicial de 30 criaturas fluentes é provisória e será revista após baseline. Sem promessa de milhares de agentes.
- Testar falhas: população vazia, sem alimento, excesso de entidades, save corrompido, replay, restrições de recursos, signals inválidos.
- Checar `git diff --check`, diffs, evidência de testes (comando e exit code), dependências/licenças, review independente de patches críticos, screenshots **do build atual**.
- Cada fase tem **prova funcional de comportamento observável**; vídeos/screenshots não substituem testes lógicos.

## 8. Segurança, Git, licenças e rollback
- Preservar trabalho do usuário e worktrees existentes. Nunca usar `reset --hard`, `git clean`, remoção/arquivamento destrutivo, stash/rebase destrutivos, `git worktree remove --force`, apagar backup ou auto-resolver conflitos sobrescrevendo.
- Criar checkpoints verificáveis antes de qualquer operação do ciclo de vida do workspace. Se uma worktree desaparecer ou houver branch-base divergente, PARAR e reportar; não recriar silenciosamente.
- Escritores em worktrees/branches distintas; staged files seletivos; não incluir `.env`, chaves, logs e arquivos de configuração privada. Commits locais **apenas se autorizados pelas regras do repo e missão**, sem modificar identidade Git e sem trailers de créditos de IA (`Co-Authored-By`, `Generated-By`, `Assisted-By` etc.).
- **Proibido por padrão:** push, PR, merge remoto, deploy, upload de dados privados, mudança de contas/cloud/SSM/IAM, remoção de worktrees, bypass de sandbox ou controles de segurança. Não executar ações externas irreversíveis por interpretação ampla de "chegar até lá".
- Uso de rede para consultar documentação e baixar dependências/assets públicos com licença comprovada dentro do workspace autorizado é permitido conforme permissões e política local. Downloads executáveis devem ser verificados, não executar scripts aleatórios da internet. Registrar fonte e versão. Evitar dependências vulneráveis e licenças incompatíveis.
- Tratamento de imagens/áudio de terceiros conforme licenças e direitos; sem copiar identidade visual de jogos proprietários.
- Antes de integração: testes + review + contrato validado; rollback por checkpoint; relatórios de dependências e riscos.

## 9. Mecanismo Colab
O jogo deve funcionar totalmente offline. Colab é um **acelerador opcional de experimentos**, não runtime online do pet. Treinos reproduzíveis com configs/seeds e limites, sem API permanente, sem Cloudflare Tunnel/ngrok de servidor de inferência. Exportar modelo/genes/normalizadores com versões e hashes; exigir equivalência de contrato no jogo; comparar resultados. Se treinamento não for mais rápido/útil em GPU, ficar em CPU e economizar CCUs.

## 10. Entrega e handoff
A cada gate concluído fornecer relatório conciso:
```
Status: PASS | PARTIAL | BLOCKED
[FATO] Root/repo/remote/branch/HEAD/worktree
[FATO] Orquestrador Sonnet real (modelo, skill Orca, Run/Tasks/Dispatches, workers)
[FATO] Reuso/libs/assets aprovados e respectivas fontes/licenças
[FATO] Código/artefatos alterados, diff/commits locais autorizados
[FATO] Funcionalidade jogável demonstrada, comandos de build e testes + exit codes
[FATO] Métricas de simulação/IA e resultados de experimentos com seeds
[FATO] Verificação visual atual e desempenho observado
[HIPÓTESE] Comportamentos emergentes ainda não demonstrados
[LACUNA] Compatibilidade, quota, recursos, revisão ou limitações
Decisões do usuário realmente indispensáveis
Próximo gate/ação segura
```
Entregar um README para abrir/rodar o jogo, arquivos no workspace autorizado, documentação de arquitetura concisa, proveniência dos assets, testes, save e uma demo reproduzível. Reportar honestamente o estado; não prometer execução assíncrona nem inventar workers.

## 11. Conduta de execução
- Começar por descoberta e implementação de G1, não por discussões sem fim ou pela criação de 30 arquivos de especificação.
- Escolher soluções existentes que economizem trabalho **quando devidamente validadas**, mas preservar identidade própria do produto.
- Entregar incrementos executáveis e corrigir defeitos reportados até os critérios de aceite do gate; não saltar adiante se o anterior estiver quebrado.
- Se algum requisito envolver risco, acesso ou autorização faltante, **bloquear somente a ação afetada**, continuar tarefas independentes seguras quando possível e comunicar uma próxima ação objetiva.
- O objetivo final é G1–G5 com evidências. G6 é opcional conforme ganho técnico. Respeitar quota, custo e tempo; qualidade maior que consumo de agentes.

**GOAL OPERACIONAL IMEDIATO:** validar o Sonnet como coordenador real do Orca, reconhecer o workspace, confirmar a stack e produzir **a primeira vertical slice jogável G1**, já aproveitando recursos abertos auditados; então avançar em gates até chegar ao sandbox com aprendizagem, evolução e comunicação. Não parar apenas após redigir um plano se a implementação estiver autorizada e tecnicamente viável.
