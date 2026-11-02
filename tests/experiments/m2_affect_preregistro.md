# M1b — pré-registro de causalidade afetiva

[FATO] Protocolo novo; não substitui nem altera o pré-registro M1. Implementação
original baseada na especificação local, sem código externo incorporado.

## Partições, congelamento e abertura

TRAIN: 93601–93604; DEV: 93701–93706; HOLDOUT inédito: 94831–94850.
Seeds distintas de M1 (81001–81006/82401–82420), pareadas entre braços.
Commit separado deste protocolo antes dos ensaios; commit de motor, testes e
avaliador após TRAIN/DEV e antes do HOLDOUT. Abrir HOLDOUT uma única vez;
marcador durável antes do primeiro ensaio em reports/M1b_afeto_eval.json.
Não alterar motor, avaliador, critérios ou seeds após a abertura. Falha de
qualquer critério primário implica resultado científico PARTIAL, com números
residuais. Git comprova ordem e hashes, não ausência universal de ensaios ocultos.

## Separação causal

Memória: episódios recuperados por recência/relevância/importância modulam
utilidade dos candidatos. Afeto: limiares de ativação, histerese e persistência;
nenhum estado afetivo altera o corpo diretamente. Fome/sede críticas prevalecem.
Mesmos traços (0,5), recursos, RNG inicial e geometria em todos os contrastes.
Braços completo, sem afeto, sem memória, sem ambos, aleatório e fixo.
Ablar somente na avaliação, preservando históricos adquiridos nos doadores.

## X1b — fatorial de estado e recuperação

Doadores adquirem afetos por 100 observações físicas: contato prolongado
(saturação) ou ausência (solidão). Doadores de memória adquirem 3 episódios
reais de encontro positivo ou disputa de alimento; 61 observações, sem ação
comandada. Observação controlada avança tick mas não metabolismo, declarada
como aquisição experimental, não trajetória ecológica livre.
Transplantar separadamente afeto e episódios desses doadores para cópias do
mesmo mundo de avaliação, com vizinho ao alcance e fisiologia igual. Cruzar
2 estados afetivos × 2 memórias; manter RNG, tempo inicial e temperamento iguais.
Fontes de memória referem-se ao mesmo ID físico do vizinho. Avaliar 36 ticks
autônomos, sem ensino/ordem, contando contato físico com linha de visão,
objetivos e ações efetivamente executadas. Save/load no tick 18 e continuação
exata até 36 em todos os braços/células.

Efeito afetivo A = média(contato solidão − contato saturação), sobre as duas
memórias. Efeito de memória M = média(contato memória positiva − negativa),
sobre os dois afetos. Primários: A completo >=0,20; M completo >=0,10;
ambos positivos em >=75% das seeds; sem afeto remove >=80% de |A|; sem memória
remove >=80% de |M|. Especificidade: sem memória conserva >=50% de A completo,
sem afeto conserva >=50% de M completo. Sem ambos/fixo/aleatório: |A| e |M|
<=0,05. Não exigir que a ablação remova todas as mudanças de score: os canais
são independentes e o efeito residual é reportado. Interações podem falsificar
os critérios de especificidade e devem constar do resultado.

## X2b — persistência autônoma após bloqueio

Adquirir frustração por 10 tentativas físicas rejeitadas pela geometria, via
executor físico simples, sem atribuir afeto diretamente. Neutralizar apenas a
memória episódica de bloqueio para isolar afeto. Avaliação começa com objetivo
explorar comprometido no tick corrente, doador frustrado versus doador neutro,
mesmo corpo/obstáculo/RNG; 12 ticks de autonomia normal. Medir primeiro tick de
troca de objetivo e número de ticks mantendo explorar (não softmax). Sem afeto,
sem memória e sem ambos são controles pareados.
Primário: frustração encurta a primeira permanência >=4 ticks na média e em
>=75% das seeds; sem afeto remove >=80% desse contraste; sem memória conserva
>=75%. Recuperação: após retirar obstáculo e 96 ticks autônomos, frustração cai
>=50% do pico em >=90% das seeds completas. Reportar ações reais e expressão,
sem tratá-las como prova de experiência subjetiva.

## Verificação, custo e limites

Testar receio, satisfação, saturação, solidão e urgências críticas por
intervenções unitárias controladas; receio deve favorecer afastamento quando
há vizinho e cautela/repouso sem companhia; satisfação reduz urgência de
exploração. Não atribuir identidade espacial de risco se o sensor não a fornece.
Rodar testes completos (17 existentes + nova suíte), golden legado e saves v1–v8.
CPU serial, seed TRAIN 93604, 100 ticks de aquecimento + 400 medidos, 12/30/60/100
criaturas, desligado/pet/todas; reportar média e p95 ms/tick e população final.
Critério operacional: pet acrescenta <=2 ms/tick médio a cada população;
todas/100 é descritivo, sem alegar FPS gráfico ou orçamento de produto.
Relatório pt-BR com [FATO]/[HIPOTESE]/[LACUNA] em reports/M1b_afeto.md.
