# P1b — revisão de expectativa espacial

[FATO] Base `evo4/pet` @ `5d78967`, branch local `Yurtachi/evo4-p1b-sim`,
Godot 4.7.2 console, Windows, 02/11/2026. Pré-registro separado `8141735`,
motor `a0c71dc`, correção de diagnóstico `2e0fb0e`, freeze `a18f597`.
Abertura única às 15:47:28 UTC, posterior a esses commits. P1 continua
PARTIAL: seu protocolo,
holdout e métricas não foram alterados nem seu avaliador reexecutado.

## Correção por princípio

[FATO] A ausência passa a valer proporcionalmente à fração inspecionada do
lugar lembrado. O canal sensorial testa 17 raios (centro e dois anéis de oito
pontos) com alcance, FOV e oclusão físicos; a política acumula a cobertura
durante uma volta de 16 ticks. Não recebe a verdade sobre recursos ocultos.
Cobertura zero não cria falha. Para fração c, o desconto é `0,35^c`, alpha
recebe esse desconto e beta recebe o desconto mais `1,5*c`. Evidência positiva
continua experiencial. Com oito recompensas, duas inspeções completas levam
a expectativa de aproximadamente 0,99 para 0,162824, sem escrever no corpo.

[FATO] A primeira ausência inconclusiva conserva uma tarefa de confirmação,
sem depender apenas do valor alimentar que acabou de cair. Cooldown entre
verificações é 45 ticks, exploração inicial 30; não cresce com as falhas.
Expectativa <0,25 ou três falhas consecutivas suspendem a busca habitual por
1800 ticks. A exploração evita atravessar imediatamente a região recém
inspecionada enquanto ela está suspensa. Depois desse intervalo o lugar pode
ser sondado novamente: a oportunidade de sondagem usa prior 0,5 somente na
seleção, sem inventar observação positiva nem elevar o posterior salvo.

[HIPOTESE] A agenda agora permite colher evidência negativa antes de repetir
uma expectativa já refutada. Isso é revisão programada de uma associação,
não aprendizado de algoritmo de navegação. [LACUNA] Dezessete raios aproximam
área inspecionada; não certificam cobertura contínua de cada ponto da célula.
A sondagem futura compete com outros lugares de maior valor e necessidades.

## Achados da revisão

[FATO] M1: memória espacial v2 é a feature flag dos novos presets. O vagar e
os desvios de colisão usam o RNG persistido da mente, já derivado de
`seed ^ (id * 104729)`. Memórias v1 e mundos carregados preservam a política
e os sorteios anteriores. Um save de pet capturado na base é continuado por
300 ticks e comparado por SHA-256 integral; os goldens históricos permanecem
na suíte. O teste de ecossistema compara 120 passos com sensores iguais e
quantidades ocultas diferentes, comprova RNGs do mundo divergentes e exige
estado inteiro da criatura idêntico. Comida visível é o controle positivo.

[FATO] B1: o teste novo recusa acesso por receptores arbitrários, como `w`,
`world_ref` e `self.world`, em notação por ponto, índice e `get`, para
foods/waters/feeders/objects/books/terminals/boards. Há 105 casos positivos
de aliases, mais campos nus nos ganchos do mundo e controles de canais
sensoriais permitidos. [LACUNA] É auditoria estática conservadora, não análise
completa de fluxo de dados contra ofuscação deliberada.

[FATO] B3: `spatial.visible` faz parte de `Mind.REASONS` e tem roundtrip
testado. `World.validation_error` identifica `mind.spatial` inválido antes da
rejeição genérica, inclusive NaN, tipos incorretos e posições fora do mundo.
A linha autorizada de SaveStore propaga esse diagnóstico; `Textos.mensagem`
o apresenta em pt-BR. Um envelope com checksum válido e campo espacial
inválido comprova erro claro e preservação integral de arquivo e entrada.
Rejeição estrita permanece: não se apaga experiência silenciosamente para
forçar a carga de um save inválido.

[FATO] Durante DEV houve regressão em P0: o novo vagar revelou sede ignorando
uma margem observada, pois a recuperação exigia três achados e valor acima
de busca cega. Na v2, água física persistente pode ser buscada a partir de
uma margem observada; comida mantém a exigência de três achados. Emergência
alimentar usa varredura física na v2, em vez de gastar o orçamento restante
vagando. Também foi
corrigida a criação com mente explicitamente desativada. Nenhum critério ou
golden P0 foi relaxado.

## Experimento novo

[FATO] DEV 382101–382106; HOLDOUT 382401–382424, listado individualmente no
pré-registro. O freeze registra 343 seeds históricas e a varredura por tokens
inteiros na base `5d78967`; não houve colisão. Inclui os JSON de reports e de
tests/experiments, os freezes antigos e suas listas DEV/HOLDOUT.
Os mesmos A (recordação), C (retenção JSON) e D (L2 mais rico) usam cenários
pareados; B executa cinco tentativas de 180 ticks e mais 180 sem reposicionar.
Braços: treinado, memória desligada, não treinado, sistemático, estratégia de
um lugar sem revisão, oráculo como teto separado. A estratégia guarda a
última ingestão real do treino, usa as mesmas APIs físicas e não recebe
evidência sintética. B exige redução de expectativa e menos entradas que a
estratégia, além de limites absolutos pré-fixados.

[FATO] A revisão independente estimou aproximadamente 21–23% de sucesso para
busca cega em 180 ticks, perto do teto geométrico desta arena. Igualar a
estratégia em A é esperado: lembrar L basta. O contraste de revisão é B.
Braços de trajetória idêntica não são tratados como evidências independentes.

## Validação e resultado

[FATO] **PASS**, conforme critérios fixados antes do motor e da abertura.
Uma execução de 24 seeds, 504 episódios A/C (sete grupos de 72), 24 pares B
e 24 avaliações D; zero erros de execução/integridade. Dados brutos e
trajetórias: `tests/experiments/p1b_holdout.json`. Métricas derivadas:
`p1b_metrics.json`; marcadores exclusivos `p1b_opened.json` e
`p1b_started.json` idênticos. Nenhum ajuste após abertura.

| Braço | A: ingestões | Latência média censurada | Caminho / reta |
|---|---:|---:|---:|
| Treinado com revisão | 72/72 (100%) | 77,11 | 0,972 |
| Memória desligada | 14/72 (19,44%) | 165,60 | 2,376 |
| Não treinado | 16/72 (22,22%) | 163,13 | 2,303 |
| Sistemático | 12/72 (16,67%) | 168,38 | 2,435 |
| Estratégia: sempre ao último local | 72/72 (100%) | 77,11 | 0,972 |
| Oráculo — teto separado | 72/72 (100%) | 77,11 | 0,972 |
| Treinado após JSON save/load (C) | 72/72 (100%) | 77,11 | 0,972 |

[FATO] H-A passou: +77,78 pontos percentuais sobre o melhor controle sem
memória (não treinado), latência 52,73% menor; teste dos sinais por seed:
24 vitórias, zero derrotas/empates, p unilateral = 5,96046×10⁻⁸. Os três
episódios por seed não foram tratados como três amostras independentes.
Igualdade entre treinado, estratégia e oráculo em A impede interpretar esse
resultado como superioridade sobre uma estratégia competente de um lugar.

[FATO] **H-B passou em 22/24 seeds (91,67%, mínimo registrado 90%)**.
Todas completaram duas inspeções vazias reais e reduziram a expectativa a
**0,162824** dentro das cinco tentativas. Vinte e duas tiveram exatamente
duas entradas no local, contra cinco da estratégia; 382412 e 382417 tiveram
três entradas e **falharam o critério individual**, apesar de revisar o
posterior. Nessas duas, a segunda tentativa de 180 ticks terminou sem
inspeção completa; a terceira concluiu a revisão. Não se retiraram essas
seeds nem se mudou o limite para converter falha individual em aprovação.

[FATO] Entradas médias nas cinco tentativas: revisão **2,0833**, estratégia
**5,0**. Nos 180 ticks posteriores houve zero novas entradas para ambos;
a estratégia permaneceu no local vazio por **180/180 ticks**, enquanto a
revisão teve **0/180 ticks** de ocupação. Portanto, zero novas entradas
isoladamente não demonstraria abandono: a estratégia já estava parada ali.
O contraste pré-registrado das entradas e a ocupação contextualizam B.

[FATO] H-C passou: retenção de 100% do sucesso e mesma latência. H-D passou:
24/24 preferiram L2 após oito ingestões reais mais ricas. H-E passou:
cobertura de 600/600 amostras em 2000 ticks, testes sensoriais/save/goldens
aprovados e CPU total headless média **0,390626 ms/tick**, 500 ticks após
64 inserções espaciais, pet vivo ao final. É média de simulação, não p95 de
renderização nem somente custo incremental da memória.

[FATO] A suíte `godot --headless --path . -s tests/run_tests.gd` preservou as
27 suítes anteriores e acrescentou P1b: **28/28, exit 0, zero diagnósticos
SCRIPT ERROR/ERROR** antes dos commits de motor, fix e freeze. Logs:
`p1b_engine_tests.txt`, `p1b_save_tests.txt`, `p1b_freeze_tests.txt`; o log
`p1b_final_tests.txt` documenta a validação anterior ao commit dos resultados.
O hash integral de continuação do save antigo por 300 ticks foi preservado:
`de67ecbeab0e41eff40b188f6901dae0f942e73f0d98b1df95163349cd11ecfc`.
Os quatro cenários P0 mantiveram o pet vivo por 5000 ticks. Nenhum arquivo de
scripts/ui ou scripts/render foi editado; textos novos ficam somente em
scripts/core/textos.gd. JSON históricos de reports permaneceram intactos.

[FATO] Auditoria somente de leitura: `python tests/experiments/p1b_verify.py`
verifica ancestralidade pré-registro→motor→freeze→resultado, hashes dos 102
arquivos congelados, marcadores, seeds, número de episódios e recálculo das
métricas. `verify_prereg.sh` inclui essa auditoria e preserva a verificação
histórica do P1 PARTIAL. Essas auditorias não executam avaliadores fechados.

[HIPOTESE] O resultado sustenta revisão operacional de expectativa por
evidência negativa nesta família de cenários, além da recordação persistente.
[LACUNA] B ainda falha individualmente em duas seeds: espera, distância e
inspeção podem atravessar uma janela. Reavaliação futura foi testada na API
e compete com outros alvos; B não cobre o intervalo de 1800 ticks. A/C/D
continuam restritos à arena aberta, treino repetido e L2 oferecido pelo
protocolo; não demonstram descoberta espontânea, navegação geral ou uma
estratégia aprendida. Oráculo compartilha o mecanismo de movimento e é teto
descritivo, não uma evidência independente.
