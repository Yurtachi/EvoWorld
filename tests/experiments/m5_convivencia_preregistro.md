# X8 — convivência, vínculos e reprodução voluntária (pré-registro)

[FATO] Protocolo registrado em commit estritamente anterior à implementação do motor/avaliador e à abertura única do holdout. Nenhum avaliador fechado anterior será executado. Implementação própria, sem LLM no ciclo biológico, sem dados externos.

## Partições e congelamento
Treino: 151101–151104 (4 seeds).
Desenvolvimento: 151201–151206 (6 seeds).
Holdout inédito: 151401–151424 (24 seeds pareadas).
Todas as seeds são inéditas e distintas das séries utilizadas em M0 a M4 (140xxx, 154xxx, 93xxx, etc.).
O avaliador e as alterações no motor serão commitados em etapa separada após este pré-registro.
O holdout terá abertura única com árvore limpa, gravando o marcador `opened` antes dos ensaios e checando a correspondência exata do hash SHA256 deste protocolo e do commit congelado.
Qualquer falha será reportada honestamente (PARTIAL ou FAIL). Não haverá reabertura nem ajuste de parâmetros pós-holdout.

## Cenário 1: Vínculo e convivência em situação nova (F7)
A criatura A passa por histórico pareado de interação com duas criaturas:
- Criatura B: histórico de encontros positivos (contato pacífico sem disputa de alimento, gerando valência > 0, familiaridade e afinidade no vínculo).
- Criatura C: histórico de encontros negativos (disputa de recurso alimentar, gerando valência < 0 e aversão no vínculo).

Em seguida, a criatura A é colocada numa SITUAÇÃO NOVA de prova: arena equidistante a B e C com recurso compartilhado disponível, sem histórico anterior nesta posição espacial.
Mede-se a atitude social de A em relação a B versus C (aproximação/partilha com B vs evitação/competição com C).

Braços experimentais pareados (mesmas seeds):
1. `completo`: motor cognitivo integral com memória de vínculos e modulação afetiva.
2. `sem_memoria`: ablação de memória episódica/vínculos (`memory_enabled = false`, vínculos zerados).
3. `sem_afeto`: ablação de afeto (`affect_enabled = false`).
4. `aleatorio`: política estocástica (`policy_mode = "random"`).
5. `parametros_fixos`: parâmetros de temperamento e política fixos (`policy_mode = "fixed"`). Se a diferenciação entre B e C ocorrer apenas por características intrínsecas fixas sem depender de experiência prévia, classifica-se como "predisposição" e não como aprendizado social.

## Cenário 2: Reprodução voluntária, consentimento e herança
Avalia-se a regra fictícia de reprodução voluntária da simulação:
A criatura só reproduz se:
- Fisiologia apta: energia >= 90% da capacidade, idade >= min_reproduction_age (300 ticks), cooldown == 0, sem fome crítica (hunger <= 0.55) e sem sede crítica (thirst <= 0.55).
- Vínculo com parceiro: familiaridade >= limiar (0.12) e aversão baixa (aversion <= 0.2).
- Estado mental favorável: afeto sem frustração crítica (< 0.45), sem receio excessivo (< 0.4) e sem saturação social (< 0.6).
- Consentimento mútuo do parceiro: o parceiro avalia as mesmas restrições e pode recusar; se recusar, o nascimento não ocorre.
- Controle 'só energia': regra antiga (herança assexuada automática ao atingir energia sem exigência de vínculo, parceiro ou estado mental).

Herança e não-herança do filhote:
- Herança comprovada: filhote herda genoma e temperamento do genitor com mutação gaussiana delimitada (|delta| <= 3 desvios padrão).
- Não-herança estrita: filhote NÃO herda memórias episódicas, vínculos, conhecimento de biblioteca, habilidades de desenho ou histórico de terminal.
- Mente do filhote: ativa apenas se configurada explicitamente; por padrão inativa fora da seleção principal.

## Hipóteses falsificáveis
- H-a (diferenciação por vínculo): no braço completo, em pelo menos 18/24 (75%) das seeds de holdout, a criatura A adota atitude favorável com B (partilha/aproximação) e desfavorável com C (evitação/competição), com contraste médio pareado B vs C > 0.
- H-b (causalidade da memória): no braço `sem_memoria`, a diferenciação entre B e C desaparece ou fica abaixo de 0.10 em pelo menos 18/24 seeds, provando que o vínculo depende de memória dos encontros.
- H-c (aprendizado vs predisposição fixa): no braço `parametros_fixos`, a criatura não diferencia B de C (diferença <= 0.10 em pelo menos 18/24 seeds), confirmando que a atitude em situação nova é efeito da experiência e não mera predisposição inata.
- H-d (condicionamento mental da reprodução): na condição voluntária favorável (parceiro familiar, consentimento mútuo, afeto favorável), ocorrem nascimentos em pelo menos 18/24 seeds; na condição desfavorável (parceiro estranho/adverso ou afeto desfavorável), nascimentos são recusados (taxa zero de nascimentos). No controle 'só energia', nascimentos ocorrem independente do parceiro.
- H-e (herança de temperamento): filhotes nascidos na condição voluntária apresentam temperamentos correlacionados com o genitor (r > 0.85 ou desvios consistentes com mutação gaussiana pré-existente).
- H-f (não-herança de memória e cultura): em 24/24 seeds de holdout, os filhotes nascem com exatamente 0 memórias episódicas, 0 vínculos, 0 livros/fatos conhecidos, 0 desenhos/traços e 0 comandos de terminal herdados.
- H-g (integridade de save v14 e genealogia): mundos gerados com nascimentos voluntários salvam em v14 e recarregam com round-trip determinista, sem IDs duplicados, com genealogia válida e rejeitando dados corrompidos sem SCRIPT ERROR.

## Critérios de veredicto
- PASS: todas as hipóteses H-a até H-g validadas no holdout único.
- PARTIAL: H-d a H-g aprovadas, mas diferenciação social H-a/H-b/H-c apresentar efeito parcial ou forte predisposição basal.
- FAIL: integridade de save falhar, filhotes herdarem memórias indevidamente, ou ausência de causalidade reprodutiva.

## Custo computacional
Benchmark medido em ticks de simulação para populações de 12, 30, 60 e 100 criaturas com mentes ativas e inativas, registrando mediana e p95 de ms/tick em 200 ticks de prova após 40 de aquecimento.
