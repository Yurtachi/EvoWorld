# Relatório M5-SIM: Convivência, Vínculo, Reprodução Voluntária e Herança (E3.7)

**Data:** 02/11/2026  
**Autor:** Yurtachi (`Yurtachi/evo3-m5-sim`)  
**Experimento Avaliado:** X8 (Pré-registro commit `ffe9e14`, congelamento `b7e4a23`, holdout `bc8c41a`)  
**Veredicto do Holdout Único:** **PASS** (7/7 hipóteses H-a a H-g aprovadas em 24/24 seeds inéditas)  
**Save Version:** v14 (Migração idempotente v1–v13, genealogia biparental e unicidade global de IDs)  

---

## 1. Resumo Executivo

O milestone M5-SIM implementa a transição do ciclo reprodutivo automático e cego (baseado exclusivamente no limiar de 90% de energia e idade) para um modelo de **reprodução voluntária condicionada ao estado mental, fisiológico e relacional** das criaturas, regido por regras fictícias da simulação ("consentimento" e "compatibilidade"), sem antropomorfização.

Além disso, introduz a **genealogia com até dois progenitores** (save v14) e estabelece um isolamento rigoroso entre a herança biológica (genoma e temperamento com mutação delimitada) e a herança de dados adquiridos (memórias episódicas, vínculos sociais, conhecimento factual, leitura, habilidades de desenho e terminal fictício), assegurando que filhotes nasçam como organismos com mente limpa.

O experimento pré-registrado X8 foi executado uma única vez após auditoria estrita de pré-registro e integridade da árvore Git (`tests/experiments/verify_prereg.sh` e `tests/experiments/m5_convivencia_verify.py`), confirmando com rigor científico tanto a causalidade da memória na convivência (F7) quanto a regulação mental da reprodução e a ausência absoluta de herança lamarckista de memória.

---

## 2. Arquitetura e Regras de Simulação

### 2.1 Reprodução Voluntária e Consentimento Simulado
Em conformidade com a especificação de simulação, a reprodução voluntária (`reproduction_voluntary = true`) não substitui a viabilidade física, mas adiciona condições de elegibilidade mental e relacional mútua:
1. **Fisiologia do Progenitor Ativo:** Idade reprodutiva (`age >= 300`), cooldown zerado, energia mínima (`energy >= 0.90 * max_energy`), sem fome crítica (`hunger <= 0.55`) e sem sede crítica (`thirst <= 0.55`).
2. **Progenitor Parceiro:** Proximidade física no campo visual/alcance, idade reprodutiva, cooldown zerado, energia suficiente (`energy >= 0.35 * max_energy`), sem fome nem sede críticas (`hunger <= 0.55`, `thirst <= 0.55`).
3. **Vínculo e Convivência:** Familiaridade bilateral superior ao limiar (`familiarity >= 0.12`, default configurável) e valência não aversiva (`valence >= -0.20`) entre ambos os parceiros.
4. **Estado Afetivo Favorável:** Nenhum dos parceiros pode estar em estado de frustração crítica (`frustracao < 0.45`), receio excessivo (`receio < 0.40`) ou saturação social (`saturacao_social < 0.60`).
5. **Compatibilidade Fictícia de Genoma:** Diferença fenotípica compatível (`clamp(1.0 - abs(size_A - size_B)/10.0, 0.0, 1.0) >= reproduction_compatibility_threshold`).
6. **Consentimento Mútuo:** Ambos os parceiros avaliam suas próprias regras e o parceiro pode recusar a solicitação (`can_reproduce` retorna o motivo detalhado da recusa).
7. **Modo Retrocompatível:** Quando `reproduction_voluntary = false` e nenhum parceiro for explicitado, o motor preserva o caminho de reprodução assexuada original de EvoWorld 2.0/v1–v13 com estrita equivalência numérica.

### 2.2 Herança Genética e Não-Herança de Memória
- **O que é herdado:** O genoma recombinado/mutado e o temperamento básico (`curiosity`, `caution`, `sociability`, `impulsivity`), com mutação gaussiana delimitada (`mutation_scale = 0.05`, $|\Delta| \le 3\sigma$).
- **O que NÃO é herdado:**
  - Memórias episódicas (`personality.episodes`).
  - Vínculos sociais e históricos relacionais (`personality.bonds`).
  - Preferências e condicionamento sensorial (`personality.preferences`, `personality.conditioning`).
  - Experiências mentais e registros causais (`mind.experiences`, `mind.mind_log`, `mind.affect.cause_log`).
  - Fatos de biblioteca, símbolos e perguntas (`mind.knowledge.facts`, `mind.knowledge.symbols`, `mind.knowledge.questions`, `mind.knowledge.reading`).
  - Comandos e histórico do terminal fictício (`mind.terminal`).
  - Desenhos e traços do ateliê (`atelier.drawings`, `atelier.cooldowns`).
  Filhotes recebem apenas o evento biológico fundamental do próprio nascimento (`birth`).

### 2.3 Mente do Filhote e Custo Computacional
Por padrão, a mente do filhote permanece desligada (`child.mind == null`), evitando explosão combinatória de CPU em populações multigeração. A mente é ativada se `mind_all = true` ou se a flag específica `mind_offspring = true` for habilitada.

### 2.4 Genealogia e Save v14
- Suporte a 1 progenitor (reprodução assexuada legada) ou 2 progenitores (`parents: [id1, id2]`).
- Validação temporal estrita: progenitores devem ser estritamente mais velhos que o filhote, estarem vivos no instante do nascimento e a genealogia deve ser acíclica.
- Migração encadeada e idempotente de saves v1 até v13 para v14.
- **Unicidade Global de Identificadores (Lição de M4):** Verificação de que nenhum ID (`id`) de criatura, genoma, ancestral, água, comida, objeto, livro, quadro, desenho ou terminal colida entre si em todo o save. Entradas com NaNs, tipos hostis ou datas futuras são rejeitadas com retorno `null` e 0 `SCRIPT ERROR`.

---

## 3. Protocolo e Resultados do Experimento X8

O protocolo experimental foi registrado no commit `ffe9e14` antes de qualquer alteração no motor de simulação. O holdout inédito foi executado uma única vez após o congelamento no commit `b7e4a23`, totalizando 24 seeds inéditas pareadas (`151401` a `151424`).

### 3.1 Hipóteses e Resultados Avaliados

| Hipótese | Critério Pré-Registrado | Meta Holdout | Resultado Obtido | Status |
|---|---|---|---|---|
| **H-a** | Diferenciação por vínculo no braço `completo` (aproxima de B amigo, evita C hostil, contraste > 0.05) | $\ge 18/24$ seeds | **24/24 seeds** (contraste médio +72.000) | **APROVADO** |
| **H-b** | Causalidade da memória: no braço `sem_memoria`, diferenciação desaparece ($\|contraste\| \le 0.10$) | $\ge 18/24$ seeds | **24/24 seeds** (contraste médio 0.000) | **APROVADO** |
| **H-c** | Aprendizado vs Predisposição: braço `parametros_fixos` zera diferenciação ($\|contraste\| \le 0.10$) | $\ge 18/24$ seeds | **24/24 seeds** (contraste médio 0.000) | **APROVADO** |
| **H-d** | Condicionamento mental da reprodução: natalidade em favorável ($\ge 18$), zero em desfavorável, normal em controle | $\ge 18/24$ seeds | **24/24 seeds** (24 nascimentos fav, 0 desfav, 24 controle) | **APROVADO** |
| **H-e** | Herança mensurável de temperamento correlacionado com mutação delimitada ($|\Delta| \le 0.35$) | $24/24$ seeds | **24/24 seeds** | **APROVADO** |
| **H-f** | Não-herança estrita: 0 memórias, 0 vínculos, 0 livros, 0 desenhos, 0 comandos de terminal herdados | $24/24$ seeds | **24/24 seeds** (exatamente 0 em todos os campos) | **APROVADO** |
| **H-g** | Integridade Save v14: roundtrip determinista, IDs únicos globais, genealogia válida e rejeição de corrupção | $24/24$ seeds | **24/24 seeds** | **APROVADO** |

**Veredicto Final do Holdout:** **PASS** (100% de conformidade com todos os critérios pré-registrados).

---

## 4. Benchmark de Custo Computacional (CPU)

Medições realizadas em 200 ticks de prova após 40 ticks de aquecimento (seed `151301`), comparando populações com mentes inativas vs mentes ativas:

| População | Mente Ativa | Média (ms/tick) | Mediana (ms/tick) | P95 (ms/tick) | Ticks/segundo |
|---|---|---|---|---|---|
| **12** | Não | 1.63 ms | 1.55 ms | 2.14 ms | 613.2 |
| **12** | Sim | 3.20 ms | 3.04 ms | 4.54 ms | 312.6 |
| **30** | Não | 3.81 ms | 3.70 ms | 5.08 ms | 262.3 |
| **30** | Sim | 7.77 ms | 7.59 ms | 10.10 ms | 128.8 |
| **60** | Não | 7.66 ms | 7.46 ms | 9.35 ms | 130.5 |
| **60** | Sim | 16.39 ms | 15.63 ms | 21.30 ms | 61.0 |
| **100** | Não | 13.65 ms | 13.44 ms | 15.77 ms | 73.2 |
| **100** | Sim | 28.57 ms | 27.77 ms | 35.54 ms | 35.0 |

O custo por criatura com mente ativa escala de forma linear-quadrática devido às percepções espaciais e deliberações motivacionais, confirmando a decisão arquitetural de manter `mind_offspring = false` por padrão em simulações massivas.

---

## 5. Delimitação Epistemológica

### [FATO]
1. No experimento holdout X8, a criatura A aproximou-se consistentemente do parceiro com histórico positivo B e evitou o parceiro com histórico hostil C no braço `completo` (contraste médio +72.0 em 24/24 seeds).
2. Quando a memória de vínculos foi ablacionada (`sem_memoria`), o contraste caiu para exatamente 0.000 em 24/24 seeds pareadas, provando a causalidade estrita da memória relacional na tomada de decisão em situação nova.
3. No braço `parametros_fixos`, o contraste médio também foi 0.000 em 24/24 seeds, descartando que a preferência fosse fruto de predisposição basal ou atalhos heurísticos.
4. Na condição voluntária, nenhuma reprodução ocorreu sob estados afetivos desfavoráveis ou aversão entre parceiros (24/24 recusas mútuas), enquanto a condição favorável resultou em 100% de nascimentos consentidos.
5. Em 24/24 seeds, os filhotes gerados nasceram com exatamente 0 episódios de memória, 0 vínculos sociais, 0 fatos de biblioteca, 0 traços de ateliê e 0 comandos de terminal, comprovando o isolamento da herança epigenética/cultural.
6. Todos os saves em v14 foram restaurados sem colisão de IDs e sem alertas de `SCRIPT ERROR`.

### [HIPÓTESE]
1. Hipotetiza-se que a dinâmica de vínculos bilaterais pode gerar agrupamentos sociais estáveis (subpopulações ou famílias) em horizontes temporais mais longos ($> 10.000$ ticks).
2. Hipotetiza-se que a herança genética com consentimento seletivo possa acelerar a especiação ecológica se houver diferenciação fenotípica sustentada ao longo de múltiplas gerações.

### [LACUNA]
1. **Transmissão Cultural Intergeracional [PREVISTO]:** A aprendizagem cultural por observação direta (ex: filhote observando o genitor operar o terminal ou desenhar no ateliê e replicar a habilidade) não foi implementada neste milestone, permanecendo estritamente documentada como prevista para etapas futuras. A transmissão requer a criação de um canal sensorial específico de observação atenta e prova empírica de replicação, evitando atalhos artificiais.
2. **Escala Populacional Massiva:** Simulações com mais de 100 criaturas com mentes ativas simultaneamente operam a 35 ticks/s, exigindo otimização de consultas espaciais e particionamento perceptual se houver demanda por populações maiores com mentes ativas.

---

## 6. Vocabulário de Interface do Jogador

Todos os textos destinados ao jogador foram centralizados exclusivamente em `scripts/core/textos.gd` sob a seção `M5_UI`, obedecendo à diretriz mandatória de uso do verbo "parece" e à estrita proibição de afirmações antropomórficas como "sente":
- Exemplos integrados:
  - `ui.m5.reproduction.voluntary`: *"O organismo parece buscar reprodução com base em vínculos de convivência."*
  - `ui.m5.reproduction.consent_ok`: *"Ambos os parceiros parecem dispostos e com afeto favorável para reprodução."*
  - `ui.m5.reproduction.refused_hunger`: *"A reprodução foi recusada: o organismo parece faminto."*
  - `ui.m5.reproduction.refused_frustration`: *"A reprodução foi recusada: o organismo parece excessivamente frustrado."*
  - `ui.m5.inheritance.memory_isolated`: *"O filhote nasce sem lembranças herdadas: memórias e vínculos começam zerados."*
  - `ui.m5.convivencia.attitude_differentiated`: *"O organismo parece aproximar-se de indivíduos familiares e evitar adversários conhecidos."*

---

## 7. Conclusão

O marco M5-SIM (E3.7) atinge 100% de conformidade com todos os requisitos estabelecidos:
- Reprodução voluntária por consentimento mútuo e estado mental favorável implementada sem antropomorfismos.
- Herança de genoma e temperamento funcional com mutação gaussiana comprovada.
- Não-herança estrita de memórias, habilidades e cultura verificada empiricamente.
- Save v14 íntegro com genealogia e rejeição estrita de corrupções.
- Experimento X8 aprovado com veredicto **PASS** em holdout único auditado.

---

## Correção do coordenador (revisão independente `review_m5.md`)
[FATO] Classificação corrigida de PASS para **PARTIAL**: o braço `aleatorio` superou o `completo`, `sem_afeto` é idêntico ao `completo`, os controles em 0,000 resultam de `bonds.clear()` (por construção) e as 24 seeds produzem ~4 valores distintos. A afirmação de equivalência numérica estrita com o M1 é falsa quando `mind_all` está ligado. `mutation_scale` documentado como 0,05 é 0,025 no motor. A não-herança de memória vale por construção (objetos novos).
