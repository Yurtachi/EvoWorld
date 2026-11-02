# P1b — revisão de expectativa (pré-registro, 02/11/2026)

[FATO] P1 permanece PARTIAL e imutável; este é outro experimento. A revisão
independente estimou busca cega em aproximadamente 21–23% em 180 ticks, perto
do teto geométrico desta arena. A vantagem A mede recordação de um lugar,
não aprendizado de navegação nem superioridade em buscas longas.

## Separação e abertura

DEV: 382101, 382102, 382103, 382104, 382105, 382106.
HOLDOUT (24 inéditas): 382401, 382402, 382403, 382404, 382405, 382406,
382407, 382408, 382409, 382410, 382411, 382412, 382413, 382414, 382415,
382416, 382417, 382418, 382419, 382420, 382421, 382422, 382423, 382424.
Diagnósticos: 382090–382099; testes unitários: 382010–382029.
Antes do freeze, inventariar seed/world_seed/seeds/dev_seeds/holdout_seeds em
todos os JSON de reports e tests/experiments, incluindo os freezes históricos,
e procurar as seeds novas em todos os arquivos já versionados na base 5d78967.
Qualquer colisão impede abertura; não substituir seeds silenciosamente.
Pré-registro em commit separado anterior ao motor; freeze em outro commit;
marcadores exclusivos impedem segunda abertura mesmo após falha/interrupção.

## Protocolo e braços fixos

Mesma família de P1: arena aberta 900×600, sem reposição/reprodução/água,
visão 70, FOV 1,5π, velocidade 55, tamanho 8, metabolismo 0,5. L uniforme em
[100,800]×[100,500]; L2 também uniforme, a pelo menos 250 de L. Treino com oito
ingestões físicas de fruta em L, partidas a 25–60 unidades. A usa três partidas
inéditas sorteadas, distância >=180 de L, fome 0,65, horizonte 180. Registra
ingestão, latência censurada 181, trajetória, buscas/falhas e memória.
C repete A após JSON save/load. D oferece oito ingestões físicas de alimento
legacy mais rico em L2 e compara a escolha a partir do ponto médio.

Braços A pareados: treinado, memória desligada, não treinado, sistemático,
estratégia de um lugar, oráculo. Sistemático usa a varredura existente,
verificada por cobertura >=90% de 600 pontos em 2000 ticks com FOV real.
Estratégia: guarda somente a posição da última ingestão do treino e volta
sempre a ela quando não vê comida, sem expectativa/revisão/aprendizado forte;
segue comida visível e ingere pelas mesmas APIs físicas. O avaliador mantém
esse controlador separado do motor e nunca lhe informa a posição atual de
comida oculta. Oráculo conhece L deliberadamente; teto separado, excluído da
seleção de baseline e dos testes estatísticos. Braços duplicados não contam
como evidências independentes. Trajetórias distintas dão sensores distintos.

B compara treinado e estratégia a partir do mesmo estado treinado: remover
comida e executar exatamente K=5 tentativas de 180 ticks, cada uma começando
na primeira partida A, fora da visão de L, preservando a memória entre elas.
Interromper cada tentativa na primeira inspeção vazia completa; sem inspeção,
usar todos os 180 ticks. Não parar as cinco tentativas ao cruzar o limiar.
Registrar inspeções, entradas na região de raio 25, expectativa ao fim de cada
tentativa, tempos e trajetórias; contar entradas desde fora também após cada
reposicionamento. Após a quinta, observar mais 180 ticks sem reposicionar,
registrando novas entradas e ocupação da região. A estratégia não reduz a
expectativa (valor descritivo fixo 1), e completa inspeção após 16 ticks no
local, continuando a retorná-lo nas próximas tentativas. Reposicionamento e
energia inicial são condições do ensaio, nunca consequências cognitivas.

## Critérios falsificáveis fixados antes dos resultados

H-A: sucesso treinado >= melhor dos três controles sem memória +0,20;
latência <=0,75 da menor latência desses controles; teste exato unilateral
dos sinais sobre médias por seed, p<0,05, empates excluídos.
Não exigir superar a estratégia em A: recordar um lugar basta para ambos.
H-B: em >=90% das seeds, expectativa <0,25 até o fim das cinco tentativas,
1–2 inspeções vazias reais, <=2 entradas no total das tentativas, <=1 retorno
nos 180 ticks posteriores, e pelo menos duas entradas a menos que a estratégia.
Esse contraste testa revisão/abandono, não apenas recordar L.
H-C: sucesso após save >=95% do anterior e latência <=110% da anterior.
H-D: preferência por L2 em >=75% das seeds.
H-E: cobertura >=90%, CPU headless média <2 ms/tick (500 ticks com tabela
espacial cheia), isolamento sensorial estático/dinâmico inclusive ecossistema,
rejeição diagnosticável de spatial hostil e determinismo dos mundos antigos.
PASS exige todos; PARTIAL se qualquer hipótese comportamental/CPU/cobertura
falhar com integridade preservada; FAIL se integridade sensorial/save falhar.

[HIPOTESE] Inspeção ampla é evidência negativa mais forte que visão parcial;
espera de revisita curta e limitada permite abandonar após poucas falhas,
sem impedir uma sondagem futura de local anteriormente bom. Isso é uma regra
de revisão programada, não aprendizado de uma estratégia nova.
[LACUNA] Não mede descoberta espontânea de L2, sobrevivência longa, consciência
nem compreensão. Não consultar ou reexecutar o holdout P1 para ajustar P1b.
Após a abertura, somente relatório/auditoria: motor, avaliador, critérios,
cenário e métricas congelados, inclusive se o resultado for PARTIAL/FAIL.
