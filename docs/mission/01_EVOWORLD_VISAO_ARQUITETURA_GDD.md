# EVO WORLD — Visão, GDD e arquitetura de implementação

**Estado:** proposta de missão — NÃO é um jogo já implementado.
**Data da pesquisa:** 2026-11-01.
**Premissa explícita:** jogo pessoal single-player, Windows como primeiro alvo, mundo 2D top-down, execução local/offline. **Risco:** a plataforma, a GPU e o repositório reais ainda não foram inspecionados pelo Orca; validar antes de escolher versões e integrar dependências.

## 1. Objetivo de produto
Criar um sandbox de vida artificial **jogável**, no qual o jogador adota uma criatura persistente e introduz outros organismos em um ecossistema. Criaturas percebem o mundo, agem autonomamente, desenvolvem aprendizado individual, interagem, reproduzem-se, herdam e sofrem mutações. Canais de comunicação de sinais podem adquirir utilidade observável por aprendizado/evolução. O jogador pode intervir no mundo e examinar as causas verificáveis dos comportamentos.

**Princípio de honestidade:** criaturas não são conscientes; emoção, amizade, linguagem, emergências e adaptação não devem ser anunciadas como comprovadas sem comportamentos e métricas que sustentem essas descrições. Não falsificar aprendizado usando animações roteirizadas.

### Pilares
1. **Pet com identidade:** nome, idade, saúde, fome, energia, características, memória, vínculos, histórico, proteção configurável; você pode dar comida, interagir e ensinar.
2. **Ecologia autônoma:** outras criaturas, recursos renováveis/escassos, obstáculos, morte/renascimento/linhagens e relações ecológicas.
3. **Aprendizado mensurável:** os agentes mudam escolhas após experiências; comparar contra baseline sem aprendizado com mesmas condições e seeds.
4. **Evolução hereditária real:** traços/genomas variam entre descendentes; efeitos fenotípicos perceptíveis; fitness não equivale a uma barra decorativa.
5. **Comunicação observável:** sinais de curto alcance/canal simples, feedback entre emissores e receptores e métricas que indiquem utilidade; linguagem humana opcional, não constitutiva da evolução.
6. **Ferramentas de criador:** mundo editável, velocidade, pausa, câmera, métricas, genealogia, checkpoints, clonagem de laboratório sem alterar o mundo principal inadvertidamente.

## 2. Experiência do jogador — fluxos obrigatórios
**Primeiro uso:** iniciar novo mundo → nomear mundo → seed visível/opcional → escolher criatura inicial → nomeá-la → visualizar painel de estado → colocar comida → ver percepção e reação → salvar → fechar/abrir com estado restaurado.

**Sandbox:** selecionar ferramenta (comida, água, abrigo, objeto neutro, obstáculo, nova criatura, condições ambientais) → prévia visual da ação → aplicar com custo/regra visíveis → observar consequência → desfazer ações editoriais quando tecnicamente seguro (sem reverter automaticamente eventos ecológicos), ou carregar checkpoint.

**Evolução:** introduzir organismos compatíveis → observar reprodução → identificar descendente, genitores, mutações e aparência/herança → comparar genes/fenótipos → visualizar genealogia e gerações. Não prometer que uma mutação gera algo útil.

**Comunicação:** observar emissão de sinal da criatura A → criatura B percebe o sinal e muda uma ação → interface registra emissor, símbolo, contexto e reação → comparar estatisticamente ao caso sem canal de comunicação. Ao conversar com o pet, entrada do jogador deve ser interpretada por comandos/intents controlados; respostas em português devem ser descrições fundamentadas em estado/observações, não leitura literal da mente.

**Modo observador:** câmera livre, seguimento da criatura, play/pause, velocidade 1x/2x/5x (limitada por benchmark), HUD com população, recursos, saúde média, reprodução, genomas/linhagens, eventos relevantes.

**Modo de cuidado:** opção explícita de pet protegido ou modo sobrevivência (mortalidade real). Nunca excluir uma criatura favorita sem aviso quando a proteção está ativa; registre efeitos dessa intervenção sobre a seleção natural.

## 3. Escopo de versões e aceitação
### Fase 0 — Reconhecimento + vertical slice técnico
- Validar runtime Orca, agentes e permissões; localizar workspace/repo, Godot instalado e dependências.
- Provar Godot 2D abre localmente; executar ao menos uma simulação headless e teste automatizável.
- Pesquisar projetos/reuso e registrar escolha, licença, versão/commit, risco e razão técnica.
- Entregar plano de integração com ownership de arquivos sem começar arquitetura enorme.
**Gate:** baseline confirmado, nenhuma modificação destrutiva, boot do projeto comprovado ou bloqueio registrado.

### Fase 1 — Sandbox mínimo, MAS jogável
- Mundo 2D com câmera, terreno, biomas simples, comida, água/energia e obstáculos.
- Criatura principal selecionável/nomeável, 8–20 outras criaturas (parâmetro ajustável), visão/sensores limitados, fome e energia.
- Comportamento baseline heurístico observável; ações de colocar comida e nova criatura, painel pet, pause/play, salvar/carregar.
- Arte coerente (assets licenciados + corpo procedural) e UI usável, sem gráficos de debug como interface final.
**Aceite:** um usuário instala/abre, nomeia criatura, alimenta, adiciona 3 organismos, observa movimento autônomo, salva e retoma sem perder identidade.

### Fase 2 — Aprendizado individual
- Introduzir memória e/ou modelo leve com escolha de ações conforme observações; recompensa por sobrevivência/ingestão/evitar risco, evitando reward hacking.
- Comparar comportamento após treinamento contra agentes sem aprendizado (seeds fixas e novos ambientes), publicar curvas e falhas.
- Aprendizado durante a vida sem depender de API externa; persistir estado do cérebro/parametrização.
**Aceite:** melhoria significativa mensurável *definida antes do teste* em pelo menos uma tarefa simples; se falhar, relatar e replanejar, não simular aprendizado.

### Fase 3 — Genética e evolução
- Genoma serializável com ID estável, genitores, geração, traços e variação fenotípica.
- Reprodução inicial simples (assexuada, ou sexuada se houver justificativa), mutações limitadas, nascimento, envelhecimento, morte ecológica, árvore genealógica e métricas de diversidade.
- Exposição real à seleção: custo energético, competição, escassez, espaço e mortalidade.
**Aceite:** pelo menos 3 gerações rastreáveis, herança comprovada, mutações registradas, fenótipo refletindo genes e ausência de crescimento ilimitado sem consumo de recursos.

### Fase 4 — Comunicação e sociabilidade
- Canais de sinais abstraídos (até 4–8 símbolos iniciais), percepção por distância/ruído, custo de emissão e registro de contexto/resposta.
- Interações entre indivíduos: proximidade, fuga, seguir/evitar, cooperação em tarefas simples; afinidade baseada em histórico real.
- Experimento com canal habilitado vs desabilitado e métricas de cooperação/sobrevivência ou sincronização.
- Chat com jogador: interface texto → intenção delimitada (chamar, oferecer, brincar, recuar, proteger); resposta com evidência real do estado; não gerar livre arbítrio fictício.
**Aceite:** mensagens circulam entre organismos, influenciam observações; há experimento controlado sobre sua utilidade; sem confundir token emitido com português.

### Fase 5 — Ferramentas avançadas e ecossistema
- Clima/ciclo dia-noite se não prejudicar framerate, ecossistemas com nichos, modos sandbox/observador, gráfico evolutivo, painel de linhagens, exportação/importação e benchmarks.
- Asset polish, suporte a controle de escala, acessibilidade, UX, configurações, undo/checkpoint, observabilidade.
**Aceite:** regressões cobertas; continuidade do save; uso de recursos e FPS medidos no hardware real.

### Fase 6 — Google Colab (opcional, somente quando houver vantagem)
- Encaminhar simulação/treinamento para notebook reproduzível com configuração de versões, seeds, orçamento de CCUs e export de checkpoint.
- Integrar **somente modelos realmente validados** na simulação local, com contrato de sensores/ações/normalização idêntico ao usado no treino.
- Comparar política importada vs baseline dentro do Godot. Evitar dependência permanente do Colab, servidor/túnel de API ou cópia de dados privados.
**Aceite:** treinamento executado e comprovado pelo operador; checkpoint exportado com hash e metadata; import local validado; comparativo com baseline.

## 4. Modelo biológico/IA — contrato conceitual
O mundo avança por steps lógicos com delta fixo, idealmente desacoplados dos frames de renderização. Agentes consultam apenas sensores próximos, com custo de percepção e range por gene; nada de conhecimento onisciente sobre todos os alimentos e predadores.

**Observações:** energia normalizada, fome, saúde, idade, velocidade, orientação, recurso visível mais próximo (distância/direção/tipo), outro organismo visível (distância/direção/sinal/afinidade), condições locais, últimos sinais recebidos e memória compacta.

**Ações discretas/parametrizadas:** girar, acelerar, parar, comer, beber, aproximar, fugir, descansar, explorar, sinalizar, interagir e reproduzir quando biologicamente elegível. Ações inválidas não devem produzir efeitos.

**Genome inicial:** tamanho, cor/padrão, velocidade máxima, metabolismo, campo de visão, sensibilidade a sinais, impulsos iniciais e parâmetros de aprendizado/cérebro. Genes com bounds físicos/biológicos e mutações versionadas; nenhum gene puramente cosmético deve ser apresentado como vantagem adaptativa.

**Memória:** eventos de encontro/objeto/recompensa com limites de capacidade e esquecimento; não persistir milhares de logs brutos por criatura desnecessariamente.

**Seleção:** decisões individuais têm custos/benefícios dentro das mesmas regras; reprodução depende de energia/idade; descendentes recebem herança e variação. Métricas: recursos ingeridos, longevidade, descendência, diversidade, taxas de mortalidade e performance por cenário. Não criar fitness mágico que decrete o vencedor sem interação ambiental.

**Comunicação:** separar (a) sinais observáveis, (b) interpretação estatística do sistema, (c) narração ao jogador. Exibir "sinal 3 enviado; 2 receptores; um se aproximou" como fato; "avisou sobre comida" só como hipótese se demonstrado e testado. Não alegar consciência ou linguagem humana emergente.

**Modo diálogo:** primeiro usar intents e respostas estruturadas baseadas em estado — por exemplo "Estou com pouca energia" apenas se a energia estiver baixa. Futuramente, modelo de linguagem opcional pode verbalizar esse estado, mas não deve injetar ações nem inventar memória. Distinguir diálogo simulado de comunicação emergente entre agentes.

## 5. Arquitetura modular provisória
```text
evoworld/
  project.godot
  scenes/
    main.tscn
    world.tscn
    creature.tscn
    ui/
  scripts/
    core/          # simulation clock, ids, events, RNG, contracts
    world/         # resources, climate, spawning, spatial index
    creature/      # organism entity, genome, traits, metabolism
    behavior/      # sensors, actions, baseline policy, reward, memory
    communication/ # signal emission, receivers, event telemetry
    evolution/     # inheritance, mutation, reproduction, genealogy
    persistence/   # schema, validation, checkpoint, migration
    ui/            # viewport, HUD, pet panel, controls, inspector
  assets/
    external/      # only approved assets + licenses/provenance
    procedural/    # generated creature compositions and shaders
  tests/
    unit/
    integration/
    simulation/
  experiments/
    fixtures/      # synthetic samples, seeds, baselines
    notebooks/     # optional Colab when validated
  docs/
    ARCHITECTURE.md
    ASSET_PROVENANCE.md
    TEST_PLAN.md
    CHANGELOG.md
```
**Atenção:** é uma proposta. Se houver um repositório real, respeitar sua arquitetura e convenções; não criar pastas vazias/desnecessárias por obrigação.

### Contratos
- Saves JSON ou equivalente versionado, schema com `save_version`, `world_seed`, `tick`, `entities`, `genomes`, `brains`, `relations`, `events` sumarizados, `ancestry`, `rng_state` onde suportado.
- Export de genoma/cérebro com `model_version`, `observation_schema_version`, `action_schema_version`, `training_seed`, `checksum`, `provenance` e limites válidos.
- Import rejeita schema incompatível ou malformado; não executar scripts externos serializados.
- Checkpoint gravado com arquivo temporário + rename/backup conforme viabilidade de plataforma, com validação e recuperação; impedir corrupção em saves interrompidos.
- RNG local seeded; consistência de replays depende de física, versão e plataforma, portanto não prometer determinismo bit a bit universal.
- Telemetria local de simulação, não analítica de usuário: TPS/FPS, população, recursos, nascimentos, mortes, diversidade, motivos de ação, sinais e tempos de update.

## 6. Interface, estética e UX
**Direção:** laboratório natural acolhedor, com mundo orgânico, criaturas carismáticas mas biologicamente legíveis. O painel de inspeção deve ter apresentação profissional, sem cara de debug de protótipo.
- Zoom e pan, seleção de entidade, overlay de sensores, seguimento de pet, tooltips, acessibilidade e contraste.
- Painel de pet: nome, geração, linhagem, necessidades, curiosidade, episódios registrados, ações disponíveis.
- Painel científico: genética, linhagem, neurônios quando disponíveis, eventos com timestamp, observações/ações/causas e qualidade de comunicação.
- Edição: colocar recursos, criar/duplicar entidade autorizada, ajustar densidade, pausar, retomar, snapshot, simulação rápida.
- Quando genes alterarem tamanho/forma/cor, corpo procedural deve refletir visivelmente tais mudanças. Assets externos usados como **cenário e adornos**, não como desculpa para criaturas com genomas invisíveis.
- A identidade visual original não copia os layouts exclusivos de The Bibites ou Spore.

## 7. Reutilização de recursos externos (pesquisa verificada em 01/11/2026)
| Recurso | Fonte oficial | Licença verificada | Uso sugerido / cautela |
|---|---|---|---|
| Godot Engine | https://godotengine.org/license/ | MIT | base da simulação e editor 2D; escolher versão instalada/estável compatível |
| Godot RL Agents | https://github.com/edbeeching/godot_rl_agents | MIT | bridge Godot/Python com exemplos; não incluir sem POC e compatibilidade |
| Plugin Godot RL Agents | https://github.com/edbeeching/godot_rl_agents_plugin | MIT | adaptação Godot 4; testar com versão exata e cenário headless |
| neat-python | https://github.com/CodeReclaimers/neat-python | BSD-3-Clause | evolução offline; suporte a export JSON, não assumido plug-and-play com GDScript |
| Kenney Roguelike/RPG | https://kenney.nl/assets/roguelike-rpg-pack | CC0 | tiles, terreno e objetos; estilo 16x16 é opção, não obrigatória |
| Kenney Animal Pack Remastered | https://kenney.nl/assets/animal-pack-remastered | CC0 | sprites de referência/início; procedurais necessários para morfologia |
| Kenney Pixel Pack | https://kenney.nl/assets/pixel-pack | CC0 | objetos 2D adicionais com auditoria visual |
| Brax | https://github.com/google/brax | Apache-2.0 | candidato apenas para treino avançado; repositório alerta que envs não têm manutenção ativa, usar alternativas recomendadas conforme caso |

Não importar repositórios completos como dependências indiscriminadas. Para cada dependência/asset registrar: URL original, commit/tag, data, hash se pertinente, autor, licença, condições, arquivos incorporados, necessidade de avisos de copyright, funcionamento verificado e motivo da escolha. Omitir recursos desconhecidos/sem licença verificável. O The Bibites é **inspiração funcional, não fonte de assets/código**.

## 8. Estratégia de testes e evidências
- **Smoke Godot:** abrir projeto, iniciar cena, shutdown sem erro, logs capturados, teste headless quando suportado.
- **Testes simulados:** seeds fixas em cenários com/sem comida, múltiplos agentes, escassez, sinais e reprodução; sobrevivência, conservação de energia, limites populacionais e eventos válidos.
- **Treinamento:** comparar agentes com e sem aprendizagem em seeds de validação não usados no treino; reward hacking e generalização.
- **Genética:** ID único, árvore de pais sem ciclos, valores dentro dos limites, herança e mutações observáveis, nenhuma reprodução de entidades mortas.
- **Comunicação:** integridade do canal, alcance/custo/ruído, correlação sinal→comportamento; experimento com canal desligado.
- **Persistência:** round-trip completo do save; versionamento, corrupção, migração compatível, backup; memória e pet preservados.
- **UI:** captura nova do build atual, controles operáveis, conteúdo legível, zoom, eventos, responsividade da janela; não aceitar screenshot antigo como prova.
- **Performance:** registrar FPS/TPS/CPU/RAM, quantidade de entidades e tempo de simulação no hardware real. Meta provisória inicial: 30 criaturas rodando sem travamentos graves; refinar após medir baseline.
- **Segurança:** sem chaves em arquivos, dependências auditadas, sem execução arbitrária de arquivos importados, sem telemetria externa por padrão.

## 9. Riscos e mitigação
1. **Simulação visual falsa:** começar com baseline explícito e evidências de aprendizado/evolução, testes de ablação e relatório de limites.
2. **Escopo infinito:** evolução por fases; entregar vertical slice jogável primeiro; cada fase termina em build/teste, não só plano.
3. **Dependências incompatíveis:** POCs isoladas, pin de versão, fallback para comportamento/GDScript puro, sem manter Python em runtime por padrão.
4. **Performance de milhares de organismos:** começar em dezenas, spatial index, atualização por ticks de sim, LOD de decisões, benchmarks e travas de população.
5. **Aparência incoerente com genética:** representação procedural dos traços, não apenas sprite fixo.
6. **Save corrompido:** save atômico/backup, versões, migração e validação.
7. **Perda de workspace/Git:** checkpoint, worktree isolada, sem comandos destrutivos nem push implícito.
8. **Privacidade/custos:** execução local por padrão; Colab opcional; exportações sem dados sensíveis; CCUs medidas, não pressupostas.

## 10. Critério de "produto atingido"
Não anunciar projeto concluído porque a UI abre ou porque há código de IA. É considerado **sandbox funcional** quando: (a) usuário adota/cria pet; (b) pode adicionar organismos e recursos; (c) eles agem independentemente; (d) interações têm consequência; (e) aprendizado em pelo menos uma tarefa tem evidência comparativa; (f) linhagens reproduzem/herdam/mutam; (g) comunicação entre organismos é rastreável e afeta observações/ações; (h) o usuário interage via comandos ou diálogo ancorado em estado; (i) salva e retoma; (j) há build jogável, testes, métricas e limitações documentadas. A evolução aberta e a formação de linguagem complexa são **objetivos científicos**, não garantias do sistema.
