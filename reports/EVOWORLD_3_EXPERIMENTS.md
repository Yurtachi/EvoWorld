# EvoWorld 3.0 — experimentos (protocolos pré-registrados e resultados)

Regra: cada experimento tem pré-registro em commit **anterior** ao motor congelado e ao holdout; holdout aberto **uma única vez**; nenhum parâmetro ajustado depois. A ordem é auditada por `bash tests/experiments/verify_prereg.sh` (E3, E4, M0-B, M1, M1b, M2, M3, M3b, M3c, M4b, M5) e por `tests/experiments/m2_affect_verify.py` (M1b, auditoria histórica). Reexecuções dos holdouts de 2.0 (E3 de ensino e E4 social) foram feitas pelo coordenador, com números idênticos.

| Id | Pergunta | Seeds holdout | Resultado | Classificação |
|---|---|---|---|---|
| M0-B | Sinal ativo ajuda coordenação com lados balanceados? | 20 inéditas (ambos os lados) | ativo 38/40; desligado, embaralhado, uniforme e prior aprendido 20/40 cada; +45 pp; 18 vitórias/0 derrotas/2 empates por seed | PASS restrito (codificador fixo; **não** é linguagem) |
| X1 (M1) | Perfis/experiências distintos divergem em buscar contato? Afeto é necessário? | 20 | diverge nos 20 pares; **desligar o afeto não remove o efeito**; sem memória reduz parcialmente | PARTIAL |
| X2 (M1) | Frustração por obstáculo é causal? | 20 | afeto muda e se recupera; scores também mudam sem afeto | PARTIAL |
| X1b (M1b) | Efeito do afeto separado da memória | 20 | +48,61 pp por canal; remoção específica de 100% do componente afetivo | PASS restrito |
| X2b (M1b) | Frustração muda estratégia física? | 20 | troca de objetivo 20/20; mudança de ações físicas só 4/20 | PARTIAL |
| X3 (M2) | Curiosidade autoiniciada, habituação, memória causal | 24 (1008 ensaios) | investiga 24/24; habituado 0/24; histórico neutro 24/24 vs aversivo 0/24 no mesmo estado atual; sem memória o contraste some; sem curiosidade 0/24; aleatório 7/24 | PASS restrito (cenário controlado) |
| X4 (M3) | Criatura aprende a copiar formas? | 24 | “100% de sucesso” do treinado; **servo geométrico sem aprendizado iguala** (verificado por revisor independente); naive era descalibrado de propósito | PARTIAL (calibração de traço, não cópia) |
| X5 (M3b) | Copia de memória, sem vértices, formas inéditas | 24 | H1/H2/H3/H5 falham; erro em formas novas 0,24, sucesso 43,98%; H4/H6/H7 passam | **FAIL** científico |
| X6 (M3c) | Ler livro muda comportamento; livro enganoso é corrigido; perguntas por lacuna; cuidador não é verdade absoluta | 24 | H-a a H-e PASS | PASS restrito (“ler livro” é regra direta sobre categoria; conhecimento é expectativa por categoria) |
| X7 (M4b) | Usar o terminal fictício melhora com ensino? | 24 (2880 tentativas) | completo 87,5%, sem ensino 79,17%, aleatório 33,68%, **fixo/servo 100%**, sem memória 0% (braço espantalho); auditoria de save pós-holdout achou 3 falhas, corrigidas sem reabrir | bruto PARTIAL; classificação final **FAIL global** (pré-registro exige FAIL se a integridade de save falha) |
| X8 (M5) | Convivência (F7: atitude B vs C em situação nova), reprodução voluntária condicionada e não-herança estrita de memória | 24 (120 F7 + 24 repro) | H-a a H-g PASS: completo diferencia B de C (+72,0 contraste médio 24/24), sem memória e parâmetros fixos zeram o contraste (0,0 em 24/24); nascimentos voluntários só sob consentimento/afeto favorável (24/24); herança de temperamento 24/24; zero herança de memórias/cultura/desenho/terminal (24/24); save v14 íntegro | **PARTIAL** (ver ressalvas e revisão `review_m5.md`) |

## Ressalvas do coordenador sobre o X8 (auditoria do código e dos braços)
- A decisão social é uma **regra direta** sobre o vínculo: aversão alta leva a evitar; familiaridade >= 0,12 leva a seguir (`scripts/social`). A parte aprendida é a formação do vínculo por encontros; a regra de leitura é fixa.
- Os controles `sem_memoria` e `parametros_fixos` dão contraste 0,000 **por construção**, porque B e C só diferem no histórico. Isso verifica a ligação memória -> atitude, não a capacidade de aprender uma estratégia social nova.
- Dos braços do pré-registro de planejamento (completo, sem memória, sem afeto, aleatório, parâmetros fixos), foram executados completo, sem memória e parâmetros fixos. **Faltam os braços aleatório e sem afeto.** Marcado como [LACUNA].
- Reprodução voluntária: os nascimentos só ocorrem quando as condições mentais valem porque essas condições são a regra de elegibilidade; isso confirma o mecanismo, não adaptação nem seleção. Nenhum experimento de seleção foi feito.
- Herança: zero memórias, vínculos, livros, desenhos e comandos de terminal herdados (24/24), temperamento herdado com mutação limitada.

- **Revisão dinâmica independente do M5 (`reports/review_m5.md`):** sem achado alto/crítico. Mas: o braço `aleatorio` superou o `completo`; `sem_afeto` é idêntico ao `completo`; os controles 0,000 vêm de `bonds.clear()`; as 24 seeds produzem só ~4 valores distintos; a não-herança vale por construção (filhotes nascem de objetos novos), logo o 24/24 de H-f não discrimina nada; e a alegação de equivalência numérica com o M1 é falsa para mundos com `mind_all` ligado (o hash do estado difere; mundos sem mente são idênticos). Por isso o X8 é **PARTIAL**: verifica que o vínculo guia a atitude por uma regra direta, mas **não** isola o afeto nem demonstra aprendizado de estratégia social.

## O que isso permite afirmar (e o que não)
- **Sustentado:** iniciativa curiosa dependente de histórico; afeto com efeito causal isolável no isolamento/companhia; leitura e perguntas por lacuna com fonte e confiança; terminal fictício seguro e opcional; ateliê com traços reais e persistentes; convivência (F7) diferenciada por vínculo experiencial; reprodução voluntária regulada por estado mental e consentimento mútuo; isolamento de herança de dados adquiridos (não lamarckista).
- **Não sustentado:** aprender a copiar formas novas (X4/X5); aprender a usar o terminal além de uma solução roteirizada (X7); linguagem emergente (M0-B é codificador fixo); transmissão cultural espontânea sem canal sensorial de observação; “sente/entende”.

## CPU medida (ms/tick de simulação)
M1 mente no pet: 1,62 / 3,96 / 7,75 (12/30/60). M1b a 100 criaturas: 20,9 (pet) / 51,4 (todas). M3c: 3,29 / 12,26 / 26,67 / 57,40 (12/30/60/100). M5 mente ativa: 3,20 / 7,77 / 16,39 / 28,57 (12/30/60/100 pop; 312,6 a 35,0 tps); mente inativa: 1,63 / 3,81 / 7,66 / 13,65 (613,2 a 73,2 tps). A mente fica ativa só no pet por padrão (e filhotes nascem sem mente salvo se configurado explicitamente).

## Limitações transversais
Seeds novas no mesmo cenário não são famílias novas de regras; cenários controlados; custo cresce com população. Provenância das execuções por Git e marcador de abertura, sem prova universal de ausência de execuções ocultas.
