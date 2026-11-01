# Estudo Arquitetural e Auditoria de Licenças: Projeto Pestinha

**Data da Auditoria:** 01 de novembro de 2026  
**Repositório Analisado:** `https://github.com/mille-okws/pestinha`  
**Escopo do Estudo:** Somente leitura de conformidade e engenharia conceitual (Clean-Room Study).  
**Documentos Base Inspecionados:** `LICENSE`, `README.md`, `assets/LEIA-ME.txt`, `docs/ARQUITETURA.md`, `docs/REDE_NEURAL.md`, bem como os módulos de referência conceitual `core/homeostasis.py`, `core/conditioning.py`, `core/episodic.py` e `core/nervous_system.py`.

---

## 1. Licença Real do Código

O código-fonte do projeto Pestinha está licenciado formalmente sob a **GNU General Public License v3.0 or later (GPL-3.0-or-later)**, conforme declarado nos metadados do repositório e no arquivo raiz `LICENSE`.

### Implicações e Efeitos Legais de Copyleft:
- **Copyleft Forte:** A licença GPLv3 exige que qualquer trabalho derivado direto, porte, modificação ou combinação que incorpore código GPL seja distribuído integralmente sob os termos da própria GPLv3, acompanhado do código-fonte completo.
- **Incompatibilidade com Reuso Literal no EvoWorld:** O projeto EvoWorld utiliza uma arquitetura baseada em licenças permissivas e domínio público (MIT na engine Godot, CC0 nos pacotes de assets visuais Kenney). A cópia literal de qualquer rotina, script ou módulo do Pestinha forçaria a reclassificação de todo o repositório EvoWorld sob a GPLv3.
- **Parecer Legal:** **Nenhum arquivo de código, função, classe ou trecho textual do repositório Pestinha pode ser copiado, transcrito ou incorporado** ao EvoWorld. O repositório Pestinha atua unicamente como literatura técnica e fonte de inspiração de alto nível para modelos conceituais amplamente conhecidos na ciência da computação e na neurociência computacional.

---

## 2. Estado dos Direitos de Assets

A situação jurídica dos assets de mídia (imagens, cartazes, post-its, memes, ícones e arquivos sonoros) do Pestinha é de **direitos autorais incertos e não confirmados**.

### Evidências Documentais no Próprio Projeto:
- O arquivo raiz `README.md` ressalta expressamente na seção de Licença:
  > *"As imagens e os textos de `assets/` não estão cobertos por esta licença [GPL-3.0] até que os direitos de cada arquivo sejam confirmados."*
- O arquivo `assets/LEIA-ME.txt` adverte os colaboradores:
  > *"DIREITOS: só coloque imagens suas ou com licença que permita redistribuir, se for publicar."*
- Além disso, grande parte do acervo gráfico e textual dos personagens consiste em memes da internet, fotos de terceiros e materiais gráficos recolhidos sem cadeia de custódia ou cessão contratual de direitos patrimoniais.

### Conclusão e Risco:
A redistribuição ou reutilização de qualquer arquivo da pasta `assets/` ou `pets/` do Pestinha apresenta **risco crítico de infração de propriedade intelectual e violação de direitos autorais**. Nenhum arquivo visual, auditivo ou textual do Pestinha entra no repositório EvoWorld.

---

## 3. Resumo Original dos Mecanismos Cognitivos e Arquiteturais

A seguir, apresenta-se uma síntese puramente conceitual dos mecanismos de comportamento observados no Pestinha, descritos inteiramente em palavras próprias, sem colagem de código ou de identificadores privados:

### A. Homeostase (Regulação de Necessidades Internas)
- **Princípio Fisiológico:** Em vez de usar temporizadores artificiais para disparar ações, o sistema monitora um conjunto de grandezas internas vitais contínuas (como reserva energética, grau de estimulação externa e demanda por interação social/contato).
- **Dinâmica Temporal:** 
  - Estar acordado e em movimento consome energia gradativamente; o estado de repouso ou sono restaura essa reserva.
  - A monotonia do ambiente ou a ausência de eventos faz o nível de estimulação decair, acumulando um déficit interno que se traduz em impulso de busca por novidades (tédio).
  - O isolamento prolongado eleva a carência de interação, a qual é mitigada por toques, gestos e proximidade do usuário.
- **Interocepção:** Os déficits homeostáticos não atuam como ordens rígidas, mas como entradas sensoriais internas (sinais de 0 a 1) enviadas ao sistema decisor. Quando uma necessidade atinge um patamar crítico, ela gera um viés motivacional que orienta o comportamento em direção à restauração do equilíbrio interno.

### B. Habituação (Fadiga e Recuperação Sensorial)
- **Princípio Neurobiológico:** A habituação consiste na diminuição adaptativa da resposta a estímulos repetidos e inócuos, distinguindo fatos novos de rotinas redundantes.
- **Mecanismo:** Cada canal sensorial possui uma capacidade de transmissão que sofre uma pequena redução percentual a cada disparo consecutivo (depressão sináptica). Na ausência continuada daquele estímulo específico, o canal recupera sua sensibilidade plena seguindo uma curva de relaxamento temporal lenta.
- **Seletividade:** Canais informativos transitórios (como toques repetitivos ou trocas frequentes de janela) habituam-se com facilidade para não saturar o sistema nervoso, enquanto canais ligados a estados vitais críticos (como exaustão extrema ou carência aguda) permanecem imunes à habituação, garantindo a preservação do organismo.

### C. Condicionamento Clássico (Modelo Rescorla-Wagner)
- **Princípio Associativo:** Aprendizado preditivo em que o organismo descobre correlações temporais entre pistas contextuais antecedentes (estímulos condicionados, como a aproximação de um objeto ou gesto) e desfechos posteriores relevantes (estímulos incondicionados, como um impacto, captura ou recompensa).
- **Regra de Atualização:** A cada episódio em que uma pista antecede um evento, a força associativa acumulada ($V$) é corrigida proporcionalmente ao erro de predição temporal — a diferença entre a consequência observada ($\lambda \in \{0, 1\}$) e a expectativa prévia ($V$).
- **Extinção:** Se a pista ocorrer repetidas vezes sem ser sucedida pelo desfecho habitual, o erro negativo faz a associação regredir rumo a zero.
- **Efeito Comportamental:** A expectativa gerada pela pista entra como um sinal antecipatório no tom motor ou nas emoções, permitindo que a criatura se esquive, se prepare ou reaja antes mesmo da ocorrência física da consequência.

### D. Memória Episódica e Tomada de Decisão
- **Registro de Experiências:** Cada intervenção relevante gera um episódio autônomo estruturado em uma tupla contextual contendo o estado do ambiente e do humor, a ação realizada, o desfecho objetivo obtido e a valência afetiva resultante (pontuação escalar entre -1,0 e +1,0).
- **Seleção Contextual (Bandit Contextual):** Quando uma decisão precisa ser tomada em determinada situação, o histórico prévio é consultado. Ações que renderam valência positiva naquele contexto recebem preferência proporcional, com uma taxa controlada de exploração ($\epsilon$-greedy) para permitir novas descobertas.
- **Atribuição Retroativa e Consolidação:** Caso uma punição ou repreensão ocorra logo após uma ação, o último episódio ainda em memória é retroativamente penalizado, rebaixando a utilidade daquela escolha naquele contexto. Durante períodos de sono/inatividade, a memória é consolidada, reconstruindo médias históricas com peso ponderado exponencialmente a favor de eventos recentes.

### E. Plasticidade Modulada por Recompensa (Regra de Três Fatores)
- **Mecanismo de Plasticidade:** Diferente do aprendizado hebbiano puro (baseado apenas na coativação local), o ajuste das conexões depende da convergência de três elementos distintos:
  1. O sinal de ativação do neurônio pré-sináptico (contexto sensorial de entrada).
  2. O estado ou polaridade do circuito pós-sináptico (grupo motor ou emocional receptor).
  3. Um sinal neuromodulador global de reforço/recompensa (escalar positivo em caso de sucesso/afeto, ou negativo em rejeição/castigo).
- **Traço de Elegibilidade:** Quando um estímulo acontece, as sinapses envolvidas mantêm uma "marca temporária" (elegibilidade) que decai em poucos segundos. Se um sinal de recompensa ou punição chegar dentro dessa janela, apenas as conexões marcadas sofrem alteração de peso. Assim, associa-se o contexto anterior ao benefício posterior sem necessidade de retropropagação artificial de gradientes.

### F. O que é Fixo vs. O que é Aprendido
Uma das forças fundamentais da arquitetura é a demarcação explícita entre a estrutura rígida de sustentação e os processos adaptativos:

| Dimensão | Componentes Fixos (Programados / Invariantes) | Componentes Aprendidos (Plásticos / Adaptativos) |
|---|---|---|
| **Física e Espaço** | Leis do movimento, gravidade, limites de borda do terreno, colisões sólidas, alcance de interação e velocidades máximas. | *(Nenhum — a criatura não aprende a violar a física).* |
| **Fisiologia / Necessidades** | Curvas basais de consumo energético, limiares de sono profundo, taxas de recuperação e capacidade estomacal/hídrica. | Pistas e locais associados à saciedade, preferências de dieta adquiridas por consequências digestivas. |
| **Tomada de Decisão** | Hierarquia de sobrevivência: comandos do usuário são suprimidos se a fome/sede ultrapassar o limiar de emergência; regras que impedem ações fisicamente impossíveis. | Valência associada a cada ação em cada contexto (memória episódica), escolha da resposta comportamental ótima. |
| **Circuitos / Conexões** | Topologia da rede neural, populações neurais, inibições laterais estruturais e sentidos corporais básicos. | Força sináptica modulada por reforço (plasticidade por 3 fatores), intensidade de antecipação (Rescorla-Wagner). |
| **Identidade Individual** | Semente pseudoaleatória, predisposições inatas de temperamento (sensibilidade basal a estímulos). | Histórico pessoal de interações, afinidade com o cuidador, hábitos de rotina e aversões aprendidas. |

---

## 4. O Que Pode Ser Reimplementado por Ideia vs. O Que é Proibido Copiar

Para assegurar total higidez jurídica e independência autoral do projeto EvoWorld, estabelecem-se as seguintes diretrizes:

### A. Permitido Reimplementar por Ideia (Clean-Room Implementation):
1. **Modelos Matemáticos de Domínio Público:**
   - O algoritmo de condicionamento preditivo baseado no erro de predição de Rescorla-Wagner (1972).
   - O modelo de homeostase com variáveis de impulso contínuo e satisfação por ações corporais reais.
   - O modelo de habituação com depressão e recuperação assintótica.
   - O bandit contextual tabular com exploração $\epsilon$-greedy para memória episódica.
   - O princípio da plasticidade sináptica dependente de três fatores com traço de elegibilidade temporal.
2. **Arquitetura de Isolamento de Responsabilidades:**
   - O conceito de separar estritamente a física e as restrições biológicas inegociáveis (invariantes de sobrevivência) das tendências comportamentais aprendidas.
   - A persistência de perfis individuais de temperamento serializados em formato aberto (JSON), mantendo determinismo com semente única de RNG.
3. **Forma de Expressão:**
   - Todo código escrito para o EvoWorld é elaborado do zero em GDScript nativo, formatado de acordo com o contrato `RefCounted` determinístico da classe `SimWorld`.

### B. Proibido Copiar ou Incorporar:
1. **Código-Fonte:** Proibido copiar, transcrever, traduzir ou portar arquivos `.py` ou métodos do Pestinha para GDScript.
2. **Pesos e Tabelas Numéricas Serializadas:** Proibido copiar matrizes sinápticas, tabelas de conexão exatas ou pesos pré-treinados do Pestinha.
3. **Textos e Expressões Literárias:** Proibido copiar diálogos, frases de cartazes, listas de memes, textos de interface ou manuais de autoria do projeto original.
4. **Assets Gráficos e Mídias:** Proibido copiar qualquer imagem (`.png`, `.svg`), spritesheet, textura ou áudio presente no repositório `mille-okws/pestinha`.
5. **Inclusão de Dependências com Licença Contaminante:** Nenhuma biblioteca de terceiros sob GPL deve ser vinculada à simulação do EvoWorld.

---

## 5. Diretrizes para a Fase E1 e Evolução do EvoWorld 2.0

1. **Simulação Pura e Determinística:** No EvoWorld, toda alteração de energia ou hidratação provém unicamente de ações físicas comprovadas no grid espacial (`comer`, `beber`, `mover`). Nenhum reforço social ou clique na interface concede energia mágica.
2. **Prioridade de Sobrevivência:** Preserva-se e expande-se a trava de sobrevivência já implementada: necessidades críticas suprimem ordens do jogador, impedindo a morte acidental do organismo.
3. **Padrão Textual e Idioma:** Todo texto exibido na interface do usuário é centralizado em `scripts/core/textos.gd` em língua portuguesa (pt-BR), enquanto identificadores e chaves internas permanecem em inglês estável.
4. **Proveniência Rastreável:** Todo e qualquer asset incorporado ou gerado deve possuir registro formal em `docs/ASSET_PROVENANCE.md`, identificando autor, URL, licença permissiva/CC0 e hash criptográfico SHA256 auditável.
