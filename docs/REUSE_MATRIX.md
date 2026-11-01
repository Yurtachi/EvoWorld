# EvoWorld — Matriz de Reuso (Make / Adapt / Use)

Data da auditoria: 2026-11-01  
Responsável: REUSE worker  
Documentos de referência: `docs/ARCHITECTURE.md`, `docs/mission/01_EVOWORLD_VISAO_ARQUITETURA_GDD.md`, `docs/mission/02_EVOWORLD_ORCA_GOAL_SONNET.md`.

---

## 1. Visão Geral e Princípios Arquiteturais de Decisão

O desenvolvimento do EvoWorld prioriza entregas incrementais, testáveis e seguras, obedecendo a contratos fundamentais:
1. **Simulação determinística e desacoplada:** A simulação (`SimWorld`) é puramente lógica em GDScript (`RefCounted`), sem nós visuais (`Node`), operando em ticks fixos com RNG proprietário seedado.
2. **Execução local e offline:** Zero dependências de rede em tempo de execução, zero chamadas de API externas e **nenhum interpretador Python em tempo de execução** para a experiência do jogador.
3. **Genoma procedural e honestidade visual:** A morfologia dos organismos (tamanho, cor, velocidade, campo de visão) deve ser expressa de forma procedural a partir dos genes (`Genome`), impedindo que sprites fixos mascarem mutações invisíveis.
4. **Licenciamento auditado:** Todos os assets e bibliotecas incorporados devem possuir licenças permissivas verificadas (CC0, MIT, BSD, Apache) com integridade criptográfica comprovada.

A matriz abaixo classifica cada recurso nas categorias:
- **USE (Usar diretamente):** Incorporar diretamente sem modificações estruturais significativas.
- **ADAPT (Adaptar):** Reutilizar conceitos, schemas de dados, exportações ou referências visuais, adaptando para a arquitetura em GDScript puro / offline.
- **MAKE (Construir internamente / Rejeitar reuso externo):** Rejeitar a dependência externa e implementar solução interna em GDScript puro para evitar riscos técnicos, de desempenho ou de incompatibilidade.

---

## 2. Matriz Comparativa Sintética

| Componente / Recurso | Licença | Decisão | Custo de Integração | Risco Arquitetural | Racional Técnico Principal |
|---|---|---|---|---|---|
| **Godot Engine 4.7.2** | MIT | **USE** | Muito Baixo | Baixo | Motor 2D estável, suporte nativo headless no Windows, GDScript desacoplado e sem dependências externas. |
| **Kenney Roguelike/RPG Pack** | CC0 | **USE** | Baixo | Mínimo | Conjunto completo de tiles 16x16 para terreno, obstáculos e ícones de comida/recursos. Licença pública irrestrita. |
| **Kenney Animal Pack Remastered** | CC0 | **USE / ADAPT** | Baixo | Mínimo | Utilizado como referência visual morfológica para renderização procedural, garantindo coerência visual sem quebrar herança genética. |
| **Kenney Pixel Pack** | CC0 | **USE (Utilitário)** | Mínimo | Mínimo | Pack de pixels 1x1 (April Fools' 2019). Útil para tintura procedural e texturas sólidas 1x1, mas não fornece objetos de cena. |
| **neat-python** | BSD-3-Clause | **ADAPT** | Médio | Médio | Ótimo para neuroevolução offline e prototipagem. O forward pass no jogo deve ser feito em GDScript puro (~100 LOC) importando o JSON do modelo treinado. |
| **godot_rl_agents** | MIT | **ADAPT (Offline)** | Alto | Alto | Framework Python para RL. Incompatível com o runtime desktop do jogo ("No Python at runtime"); reservado exclusivamente para Fase 6 (Colab) com export ONNX/pesos. |
| **godot_rl_agents_plugin** | MIT | **MAKE (Interno)** | Alto | Muito Alto | Plugin acopla nós de cena e sockets TCP. Viola o contrato de simulação pura `RefCounted` headless e offline do EvoWorld. Substituído por sensores puros em GDScript. |
| **Brax** | Apache-2.0 | **MAKE (Rejeitado)** | Extremo | Extremo | Simulação em JAX/GPU não mantida (`brax/envs`). Completamente inadequada para engine desktop 2D local. |

---

## 3. Avaliação Técnica Detalhada por Componente

### 3.1 Godot Engine (v4.7.2-stable ed1daf0bf)
- **Licença:** MIT
- **Decisão:** **USE**
- **Justificativa:** O executável oficial de console (`Godot_v4.7.2-stable_win64_console.exe`) já se encontra instalado via WinGet na máquina local e foi validado em modo headless com tempo de resposta inferior a 2 segundos e saída de erro nula. Possui pipeline maduro para 2D, manipulação de TileMaps, compilação GDScript rápida e suporte nativo a JSON e exportações desktop Windows.
- **Risco:** Baixo. Qualquer divergência de API futura é mitigada fixando a versão 4.7.2 durante todo o ciclo do projeto.

---

### 3.2 Kenney Roguelike/RPG Pack
- **Licença:** CC0 1.0 Universal (Domínio Público)
- **Decisão:** **USE** (subset curado)
- **Justificativa:** O pacote fornece mais de 1.700 assets em grade de 16x16 com espaçamento de 1px. Ele atende perfeitamente à necessidade do EvoWorld por:
  - Terreno orgânico top-down: grama, terra, areia, água;
  - Obstáculos ambientais: árvores, troncos, pedras grandes e pequenas, arbustos;
  - Recursos e alimentos consumíveis: maçãs, bagas, sementes, carne, folhas.
- **Implementação:**
  - O spritesheet mestre transparente oficial (`roguelikeSheet_transparent.png`, 94 KB) foi importado para `assets/external/kenney/roguelike-rpg-pack/Spritesheet/`, permitindo uso direto via `TileSet` ou `AtlasTexture`.
  - Um subset curado de 14 tiles individuais essenciais foi fatiado e disponibilizado em `tiles/terrain/`, `tiles/food/` e `tiles/obstacles/` para consumo direto pelo trabalhador de UI/Render.
- **Risco:** Mínimo. Zero exigência de royalties ou atribuição legal obrigatória (embora creditado por cortesia).

---

### 3.3 Kenney Animal Pack Remastered
- **Licença:** CC0 1.0 Universal (Domínio Público)
- **Decisão:** **USE / ADAPT** (referência morfológica)
- **Justificativa:** O pacote contém 31 animais em formato circular estilizado. O GDD estabelece uma regra estrita: *criaturas devem ter corpos procedurais gerados a partir do genoma* (para que mudanças em tamanho, cor, metabolismo e órgãos sensoriais sejam visíveis). Sprites estáticos não podem substituir a geração procedural.
- **Implementação:**
  - Incorporado subset de 8 animais de referência (`bear`, `chicken`, `cow`, `dog`, `duck`, `frog`, `pig`, `rabbit`) em `assets/external/kenney/animal-pack-remastered/`.
  - Servem como base de proporções, paletas e inspiração para o shader / composição procedural de criaturas (`assets/procedural/`), além de avatares de placeholder configuráveis.
- **Risco:** Mínimo.

---

### 3.4 Kenney Pixel Pack
- **Licença:** CC0 1.0 Universal (Domínio Público)
- **Decisão:** **USE (Utilitário)**
- **Justificativa:** Auditoria minuciosa da fonte oficial (`https://kenney.nl/assets/pixel-pack`) revelou que este pacote foi lançado no dia da mentira (April Fools' Day 2019) e consiste literalmente em arquivos PNG de 1x1 pixel em várias tonalidades sólidas.
- **Implementação:**
  - Preservado em `assets/external/kenney/pixel-pack/` com `README.md` explicativo e amostra de pixels (`black01.png`, `white01.png`, etc.).
  - Serve como utilitário leve para texturas neutras de 1x1 pixel (para modulação procedural de cor no CanvasItem do Godot), mas o projeto não deve esperar elementos de cenário complexos deste pacote.
- **Risco:** Nenhum (conhecimento explícito de seu formato 1x1).

---

### 3.5 neat-python (v2.0.1)
- **Licença:** BSD-3-Clause
- **Decisão:** **ADAPT**
- **Justificativa:** O NEAT (NeuroEvolution of Augmenting Topologies) é uma técnica consagrada para evolução de topologias neurais que se adequa aos objetivos de longo prazo das Fases 2 e 3. Contudo, incluir `neat-python` diretamente na árvore do jogo violaria o princípio de integridade e o contrato de *No Python at runtime*.
- **Estratégia de Integração:**
  1. *Fase 1 e Baseline:* Manter a política heurística determinística pura em GDScript (`scripts/creature/` e `scripts/behavior/`).
  2. *Fase 2 / Prototipagem:* Usar `neat-python` apenas em scripts externos / experimentais fora da pasta de build do jogo. O resultado da rede vencedora (nós, conexões, pesos e ativações) é serializado em JSON com schema estrito.
  3. *Inferência em GDScript:* Implementar um avaliador de grafo feedforward puro em GDScript (~80 a 120 linhas de código em `RefCounted`), que consome o JSON exportado e executa a inferência em poucos microssegundos sem dependência de Python.
- **Custo e Risco:** Custo médio; risco baixo a médio (sem dependência externa no build do jogo).

---

### 3.6 godot_rl_agents e godot_rl_agents_plugin
- **Licença:** MIT
- **Decisão:** **MAKE (Construir internamente) para Runtime; ADAPT para Fase 6 (Colab)**
- **Justificativa:**
  - O `godot_rl_agents_plugin` opera via sincronização remota por sockets TCP/WebSocket entre a engine e um processo de treinamento Python (ex.: SB3, CleanRL). Ele exige que cada agente seja um `Node3D`/`Node2D` na árvore de cenas (`SceneTree`).
  - O `SimWorld` do EvoWorld foi projetado e validado como uma simulação puramente matemática baseada em `RefCounted`, capaz de executar centenas de ticks em frações de segundo sem interface gráfica e sem sobrecarga do servidor de nós do Godot.
  - Acoplar `godot_rl_agents_plugin` quebraria o determinismo da simulação, violaria o sandbox offline ("No network") e adicionaria uma dependência pesada de rede local desnecessária.
- **Estratégia:**
  - O cálculo de sensores (alcance, campo de visão e oclusão por obstáculos) já foi implementado com perfeição pelo SIM worker em GDScript puro (`SimWorld.sense(creature)`).
  - Caso haja experimentos de RL por reforço na Fase 6 (Google Colab), eles serão encapsulados em ambiente isolado, convertendo os pesos resultantes para tensores lineares ou ONNX avaliados de forma nativa.
- **Custo e Risco:** Evita risco crítico de quebra arquitetural e dependência de rede local.

---

### 3.7 Brax
- **Licença:** Apache-2.0
- **Decisão:** **REJEITADO / MAKE**
- **Justificativa:** Brax é um motor de física diferenciável em JAX para GPU. Além de estar com os ambientes em manutenção (`maintenance mode`), sua stack exige CUDA, Linux/JAX e Python de ponta. É totalmente incompatível com um jogo de vida artificial 2D top-down executado localmente em desktop Windows em Godot.
- **Custo e Risco:** Extremo. Rejeição imediata conforme diretriz do GDD.

---

## 4. Recomendações e Próximos Passos para as Fases do Projeto

1. **Para o UI Worker (Fase 1 - Vertical Slice):**
   - Utilizar diretamente os tiles fatiados em `assets/external/kenney/roguelike-rpg-pack/tiles/` para compor o mapa visual do ecossistema e ícones de comida/obstáculos.
   - Para as criaturas, manter a regra de renderização procedural (`assets/procedural/`) baseada nos genes de tamanho, velocidade e matiz (`hue`), utilizando os sprites de `animal-pack-remastered` como silhuetas de referência.
2. **Para o SIM Worker (Fase 2 - Aprendizado):**
   - Implementar o cérebro / rede neural simples nativamente em GDScript (`scripts/creature/brain.gd`), garantindo serialização direta em JSON compatível com `to_dict()` e `from_dict()`.
3. **Para Experimentos Offline (Fase 6 - Colab Opcional):**
   - Utilizar `neat-python` ou `godot_rl_agents` apenas em notebooks externos se houver ganho comprovado em relação à baseline heurística, exportando sempre artefatos estáticos (JSON/ONNX) sem embutir código Python no executável final.
