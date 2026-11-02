# M1 — pré-registro X1/X2

Protocolo congelado antes da implementação e da abertura única do HOLDOUT.
Implementação própria por requisitos; nenhuma fonte GPL incorporada.

## Partições e execução

TRAIN/DEV: seeds 81001–81006. HOLDOUT inédito: 82401–82420 (20 seeds pareadas).
Não executar HOLDOUT antes de commit separado do avaliador e do motor; executar
uma única vez, conservar todos os braços e registrar SHA256 deste protocolo.
Não ajustar parâmetros nem critérios após abrir HOLDOUT. Resultados negativos
são resultados; falha de critério não implica defeito do executor.

## X1 — companhia oferecida

Dois perfis: A sociabilidade 0,9/cautela 0,2 com contato anterior benéfico;
B sociabilidade 0,2/cautela 0,9 com contato anterior adverso. Curiosidade e
impulsividade iguais (0,5). Recursos/ameaças iguais, ambiente aberto, sem
reprodução; um vizinho oferecido em posição fixa por ensaio e sem política
autônoma (resto físico normal). Histórico resulta de encontros físicos reais,
com competição por recurso no perfil B e contato sem competição em A.
Depois da aquisição removem-se alimentos disputados e restaura-se a mesma
fisiologia para os dois perfis. Isso é intervenção experimental, não recompensa.

Braços: completo; sem afeto (affect_enabled=false); sem memória
(memory_enabled=false); aleatório uniforme sobre candidatos executáveis;
parâmetros fixos (temperamento 0,5, sem afeto/memória). Mesmas seeds e
geometria em todos. 240 ticks de avaliação; fração dos ticks em alcance físico
de contato com linha de visão. Save/load JSON no tick 120; medir igualdade
exata da continuação com cópia sem interrupção, incluindo RNG e logs.

Critérios falsificáveis: completo A−B >=0,15 na média e positivo em >=15/20
seeds; cada ablação deve reduzir a diferença absoluta a <=50% da diferença
completa para afirmar que remove o efeito. Reportar diferenças residuais,
inclusive porque temperamento diferente pode preservar divergência sem afeto
ou memória. Comparar também aleatório e parâmetros fixos. Não interpretar
divergência entre perfis diferentes como prova isolada de aprendizagem.

## X2 — frustração por impedimento físico

Mesmas 20 seeds pareadas, completo/sem afeto. Pet tenta movimento contra
geometria física por 24 ticks; obstáculo removido e observação por 96 ticks.
Nenhum incremento direto de afeto pelo avaliador. Medir frustração antes,
máxima durante bloqueio e após liberação; expressão valência/ativação e
probabilidade normalizada dos escores de explorar/brincar/descansar.
Critérios: aumento >=0,10 em >=18/20 seeds; queda >=50% do pico após
liberação em >=18/20; mudança de probabilidade ou valência >=0,05; no braço
sem afeto frustração e contribuição afetiva/expressão afetiva iguais a zero.
Probabilidades são softmax dos escores, não frequência empírica de ações;
registrar ambas quando disponíveis, sem trocar uma pela outra.

## CPU e limites

Medir ms/tick com 12/30/60 criaturas em três condições: desligado, só pet,
todas. Mesmo cenário/seed, 100 ticks de aquecimento + 400 medidos; não
extrapolar CPU headless para FPS gráfico. Testes de compatibilidade usam
snapshot de mundos v7 capturado no HEAD b5c27dc antes das mudanças.

## Proveniência

Registrar commits separados de protocolo, implementação/avaliador e resultado.
verify_prereg.sh verifica ancestralidade estrita e blob/checksum imutáveis;
Git comprova ordem de commits, não ausência de execuções locais ocultas.
