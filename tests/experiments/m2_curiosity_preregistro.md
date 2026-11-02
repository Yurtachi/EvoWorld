# M2 / X3 — protocolo congelado antes do holdout

[FATO] Implementação própria, sem código externo. TRAIN 106101–106104; DEV
106201–106206; HOLDOUT 107301–107324 (24 seeds inéditas, pareadas em todos os
braços). Nunca executar holdout em desenvolvimento. O avaliador escreve e
sincroniza um marcador antes do primeiro ensaio e recusa reabertura.

[HIPOTESE] H1: um objeto novo visível a 24 px produz interação física sem
comandos em pelo menos 70% dos ensaios completos, em janela de 36 ticks.
Latência = primeiro tick de interação; ausências são censuradas em 36.
H2: oito apresentações físicas anteriores do mesmo tipo reduzem a proporção
de investigação em pelo menos 25 pontos percentuais frente ao objeto novo.
H3: histórico aversivo reduz a investigação em pelo menos 25 pontos percentuais
frente ao neutro, mantendo corpo, fisiologia, afeto atual, RNG e cenário iguais.
H4: desativar memória remove pelo menos 80% do contraste de H3.
H5: remover curiosidade reduz H1 em pelo menos 25 pontos percentuais.
H6: remover afeto reduz em pelo menos 10 pontos percentuais o contraste entre
doadores com entusiasmo e receio adquiridos por consequências físicas.

[FATO] Braços: completo, sem memória, sem afeto, sem curiosidade, aleatório,
sempre investiga, nunca investiga. Controles sempre/nunca usam o mesmo executor
físico; não contam como iniciativa endógena. Aleatório sorteia o objetivo pelo
RNG mental. Todos recebem as mesmas seeds. Janela 36 ticks, sem ensino/ordens.
Aquisição: oito contatos físicos com objeto neutro/aversivo; transplanta-se
somente a memória para clones de estado atual idêntico. O afeto do contraste
H6 é transplantado separadamente de doadores neutro/aversivo/recompensador.
Objeto de teste neutro da mesma categoria visual: propriedades não são sensores.
Habitação pode recuperar parcialmente após 600 ticks; teste unitário verifica.

[FATO] Métricas por seed/condição: ocorrência, latência censurada, número de
interações, objetivos e ações físicas; agregados: proporção, média de latência,
contrastes pareados e critérios acima. Sem inferir generalização ecológica a
partir de seeds em geometria controlada. Falhas permanecem no relatório.

[FATO] Persistência: round trip e continuação determinística; migrações v1–v8,
golden M1, limites, NaN/tipos. CPU serial: 12/30/60/100 criaturas, 32 objetos,
mente desligada ou só pet, 100 warmup + 400 ticks; média/p95 ms/tick.
Motor e avaliador terão commit separado antes do holdout. Resultado conserva
hash SHA256 do protocolo e dos arquivos congelados; auditoria verifica ordem.

[LACUNA] Protocolo não promete sucesso universal nem subjetividade; afeto é
computacional. Ausência de comandos é inspecionável pela fixture e mind_log.
