# P1 — memória espacial do pet

Base `evo4/pet` @ `6f12c7a`; trabalho local em `Yurtachi/evo4-p1-sim`,
Godot 4.7.2 console, Windows, 02/11/2026. Sem push ou merge.

## [FATO] Implementação e fronteira sensorial

`scripts/spatial/spatial_memory.gd` guarda evidência por criatura; a política em
`spatial_policy.gd` recebe somente corpo, sensores, memória, tick e dimensões.
Não recebe referência ao mundo. A visão existente filtra comida e margem de
água por distância, FOV e oclusão antes de qualquer codificação. Alimentadores
não são objetos percebidos pela mente: somente sua comida física pode ser vista.

Percepção é o dicionário transitório de sensores. Lembrança é o registro limitado
de lugar e fonte. Expectativa é uma estimativa numérica sujeita a revisão e
confiança, sem garantia de recurso atual. A verdade física permanece no mundo,
usada na ingestão, colisão e avaliação, nunca para recuperar um alvo escondido.
O teste estático percorre mind/spatial/behavior e os ganchos de decisão do mundo;
recusa acessos diretos `world.foods/waters/feeders/objects` e indexação equivalente.
O teste dinâmico desloca um alimentador oculto entre dois clones e exige estado
inteiro da criatura idêntico após dez ticks. Isso cobre a fronteira explícita;
não constitui análise de fluxo de dados de código deliberadamente ofuscado.

## [FATO] Evidência, revisão e decisão

Cada célula tem largura `vision_range/2` (22,5–120 unidades). Até 64 registros
guardam recurso, posição efetivamente observada/interagida, visitas, achados,
falhas, último tick, ganho médio, expectativa, confiança, fonte e estatísticas
do estimador. A consolidação agrega encontros da mesma célula; observações
estacionárias a menos de 60 ticks não multiplicam evidência. `visitas` conta
encontros codificados, inclusive observações, não apenas chegadas físicas.

Prior beta fraco α=β=0,5. Sucesso desconta ambas as estatísticas por 0,7 e
acrescenta um a α; falha desconta por 0,45 e acrescenta um a β. Expectativa é
α/(α+β). Confiança depende da evidência, com teto 0,98, e cai com a idade da
última evidência; registros expiram em 36.000 ticks. Ganho médio usa somente
consequência de ingestão física, média móvel com peso 0,6 para o novo ganho.
Não há escrita cognitiva em energia, hidratação ou posição.

Com fome/sede e sem recurso visível, recuperar exige pelo menos três achados.
O valor compara expectativa × confiança × ganho / (40 + distância) com
oportunidade de exploração 0,015. A necessidade continua sendo objetivo
`comer`/`beber` da motivação; sua execução busca o lugar e registra justificativas
`spatial.expected/inspect/failure/explore` no `mind_log`. Recurso visível ganha
a execução física habitual. Necessidades críticas continuam acima de comandos
e outras atividades; com fome >0,75 a busca incerta cede à exploração de emergência.

Chegar ao lugar vazio inicia 16 ticks de inspeção girando 360° antes de registrar
falha. Falha reduz expectativa, impõe cooldown crescente e 90 ticks de exploração;
três falhas consecutivas abandonam o alvo até nova observação positiva. Desvios
físicos de obstáculo são preservados por 30 ticks, evitando reorientar contra
a mesma rocha a cada tick. Não há rotas persistidas entre lugares (P2).

Durante DEV, o retorno a itens isolados e a anulação do desvio físico causaram
regressão em seeds P0; isso foi corrigido antes do congelamento. Os quatro testes
P0 de 5.000 ticks passaram, preservando seus critérios e goldens.

## [FATO] Save v16 e API

O estado espacial e a navegação transitória entram em `mind.spatial`. Migração
v15→v16 copia sem alterar entrada, população, RNG ou regras antigas; a cadeia
v1–v15 permanece testada e idempotente após normalização. Leitura valida tipos,
NaN/INF, limites, timestamps, contadores, IDs discretos duplicados e posições
fora do mundo; posterior salvo precisa concordar com α/β. O envelope SaveStore
mantém validação temporária, checksum, backup e limites anteriores.

Novos pets recebem memória ativa. Criaturas adicionais podem chamar
`creature.enable_spatial_memory()`. [LACUNA] Saves antigos preservam a política
anterior: a memória espacial precisa ser ativada explicitamente por essa API;
não foi acrescentado controle de UI neste worker.

`creature.spatial_snapshot()` retorna cópia independente:

```gdscript
{
  "lugares": [{"id": "comida:2:2", "pos": [100, 100], "recurso": "comida",
    "expectativa": 0.8, "confianca": 0.7, "visitas": 4, "achados": 3,
    "falhas": 1, "ultimo_tick": 100, "ganho_medio": 24, "fonte": "interagido"}],
  "objetivo_atual": "comida:2:2", "motivo": "spatial.expected"
}
```

Campos extras de auditoria são intencionais; `objetivo_atual` identifica o lugar
lembrado, não uma comida atualmente existente. Valores são estimativas. Traduções
de ações/motivos estão somente em `scripts/core/textos.gd`, em pt-BR. Nenhum
arquivo de `scripts/ui` ou `scripts/render` foi alterado.

## [FATO] Pré-registro e controles

Pré-registro separado `2ad7ba4`; motor `111a576`; normalização pré-abertura
dos hashes Windows/LF `f58a85b`; freeze `0054d4f`. A abertura ocorreu depois,
auditáveis por `tests/experiments/p1_verify.py` e `verify_prereg.sh`.
Marcadores exclusivos em disco sobrevivem a interrupção; o avaliador também
recusa início já registrado. Não se reabre um holdout para corrigir resultado.

DEV 271101–271106 foi separado do HOLDOUT 271401–271424. O inventário automático
registrado no freeze contém 311 seeds extraídas dos JSON históricos, com arquivos
de origem por seed. Inclui 263101–263108/263201–263208/263901–263920, além das
faixas históricas listadas no pré-registro e relatórios consultados; nenhuma
colide com P1. Seeds de sondagens e testes P1 também estão fora do holdout.

L e L2 são sorteados por seed; cada par usa mesmo genoma, estado corporal,
partidas e mundo. Treino tem oito aproximações e ingestões físicas. A tem três
partidas inéditas fora da visão e horizonte 180; C repete A após JSON save/load;
B remove comida e mede falhas, expectativa e retornos; D oferece oito experiências
reais em L2 com ganho maior. Trajetórias por tick ficam nos JSON de DEV/HOLDOUT.

Sem memória mantém o motor treinado, porém desabilita recuperação/codificação
espacial. Não treinado substitui mente e personalidade por estados sem experiência,
mantendo genoma, idade e RNG biológico pareados. O sistemático usa varredura em
faixas com passo <= alcance visual, sem lembrar entre episódios, e segue comida
vista pelas mesmas regras físicas. O oráculo recebe L deliberadamente e é teto
separado, excluído de toda seleção de baseline e teste estatístico.

O controle sistemático percorre amostras de toda a arena sob FOV e movimento
reais em diagnóstico de 2.000 ticks; o diagnóstico é de cobertura geométrica,
não de sobrevivência 2.000 ticks sem alimento. Os ensaios A preservam metabolismo.
Trajetórias diferentes geram observações diferentes; o pareamento garante o
mesmo canal sensorial e ambiente, não imagens artificialmente idênticas.

[HIPOTESE] O mecanismo aprende uma associação entre lugar e recurso. A regra de
recuperação e o esquema de exploração são programados; os resultados não
demonstram aprendizado de algoritmo de navegação, entendimento ou consciência.

## [FATO] Verificação de engenharia

Suíte completa: **27/27**, exit 0, sem `SCRIPT ERROR` ou `ERROR:`; log durável
`tests/experiments/p1_engine_tests.txt`. P1 cobre percepção, ingestão, repetição,
revisão, esquecimento, tamanho, ablação, snapshots, save em disco/JSON,
continuação determinista e dados hostis. As 26 suítes anteriores continuam
ativas. Por autorização expressa do coordenador, somente a asserção de versão
literal 15 em `test_sim_p0.gd` passou a `World.SAVE_VERSION`; critérios de
sobrevivência e hashes históricos não mudaram. Avaliadores fechados antigos não
foram executados; JSON históricos de `reports/` permaneceram intactos.

## Resultados do holdout

[FATO] **PARTIAL**. Uma abertura das 24 seeds, 432 episódios A/C registrados,
zero erros de execução. Os cinco braços A têm 72 ensaios cada (três partidas
por seed); C tem mais 72. B/D são 24 avaliações por fase. O arquivo bruto é
`tests/experiments/p1_holdout.json`; contém trajetórias de treino, busca,
revisão e diagnóstico de cobertura. Métricas derivadas estão em `p1_metrics.json`.

| Braço | A: sucesso | Latência média censurada (ticks) | Caminho / reta até centro |
|---|---:|---:|---:|
| Treinado com memória | 72/72 (100%) | 69,99 | 0,969 |
| Memória espacial desligada | 13/72 (18,06%) | 166,21 | 2,586 |
| Não treinado | 13/72 (18,06%) | 166,21 | 2,586 |
| Explorador sistemático | 14/72 (19,44%) | 168,89 | 2,682 |
| Oráculo — teto separado | 72/72 (100%) | 69,99 | 0,969 |
| Treinado após save/load (C) | 72/72 (100%) | 69,99 | 0,969 |

[FATO] H-A passou: +80,56 pontos percentuais sobre o maior sucesso sem memória
(sistemático), e 57,89% menos latência que o controle mais rápido sem memória
(166,21→69,99). Teste exato unilateral dos sinais sobre a latência média de
cada seed: 24 vitórias, zero derrotas/empates, p=5,9605×10⁻⁸. Os 72 episódios
não foram tratados como 72 seeds independentes. Cada recordação treinada teve
uma busca de memória e nenhuma falha. Razão de caminho inferior a um ocorre
porque ingestão é permitida a 13 unidades do centro do recurso.

[FATO] **H-B falhou: 0/24 seeds** atingiram expectativa <0,25 na janela de cinco
tentativas de visita ×180 ticks. Todas acumularam duas inspeções vazias reais,
reduzindo a expectativa para **0,309529**, sem cruzar o limiar. Não se pode
afirmar que o abandono foi suficientemente rápido. Após mais 180 ticks,
12/24 completaram a terceira falha e chegaram a 0,150606; as outras 12 ainda
tinham duas falhas. Houve 14 entradas na região do antigo local nesse período
(média 0,5833 por seed; 14 seeds com uma, dez sem retorno). Esses dados posteriores
não foram usados para converter H-B em PASS. A linha `B_failures` refere-se à
janela principal; `B_post_failures` é separada, evitando atribuir a expectativa
pós-janela ao número anterior de falhas.

[HIPOTESE] Cooldowns crescentes, exploração após falha e distância inicial
retardam a terceira inspeção. A estimativa se reduz quando recebe evidência
(o teste unitário confirma queda abaixo do limiar em três falhas), mas a
política nem sempre coleta essa evidência dentro do horizonte. Este é um
problema operacional de revisão, não justificativa para relaxar o critério.
[LACUNA] Corrigir isso exige outro ciclo de desenvolvimento e novo pré-registro/
holdout; nenhum parâmetro foi ajustado após esta abertura.

[FATO] H-C passou: retenção de 100% do sucesso e mesma latência, acima da fração
mínima de 95%. H-D passou: após oito experiências físicas no segundo local
mais energético, 24/24 preferiram L2 ao comparar a partir do ponto médio.
Essa fase confirma atualização de preferência após experiência percebida;
[LACUNA] não mede descoberta espontânea de L2 distante e inicialmente oculto.

[FATO] O sistemático cobriu **100% das 600 amostras geométricas** da arena em
até 2.000 ticks, superando o piso de 90%. Ele é uma varredura espacial com
cobertura verificada, embora o horizonte alimentar curto de 180 ticks limite
seu sucesso a 19,44%. [LACUNA] Não se demonstrou optimalidade dessa heurística
nem cobertura contínua entre todas as amostras. A vantagem é restrita a esta
família de arenas abertas, locais sorteados e experiência repetida em L.

[FATO] CPU do pet com memória, 500 ticks e 64 inserções de evidência antes da
medição (até 64 lugares): **0,38658 ms/tick**, abaixo de 2 ms, pet vivo ao final.
É custo total headless médio, não somente custo incremental de memória, nem
percentil de tempo de renderização. As sondagens P0 de sobrevivência mediram
aproximadamente 0,43–0,58 ms/tick nas execuções completas deste worker.

[FATO] O resultado sustenta associação experiencial de lugar com recurso e
recordação persistente neste cenário; supera o sistemático aqui. O mecanismo
de revisão existe, mas sua rapidez operacional **não passou** o critério.
O veredito permanece PARTIAL, mesmo com A/C/D aprovados e o oráculo igualado.
