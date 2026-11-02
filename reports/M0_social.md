# M0-B — E4 social contrabalanceado

[FATO] **PASS restrito no NOVO protocolo E4 contrabalanceado.** HOLDOUT único:
ativo **38/40**, desligado **20/40**, embaralhado **20/40**, uniforme **20/40**,
decoder sem sinal com prior aprendido **20/40**. O ganho de **45 pp** contra
cada controle persistiu com lados igualmente frequentes. O resultado antigo
18/20 vs 8/20 vs 10/20 não é o resultado deste protocolo.
Base local `evo2/e1-base` @ `7c6ea98`, branch `Yurtachi/evo3-m0b`, identidade
Yurtachi; sem push/merge. Lidos `docs/mission/`, `docs/EVOWORLD_2_SPEC.md` e
`reports/EVOWORLD_2_STATUS.md`. Implementação própria, sem incorporar código GPL;
nenhuma alteração em persistência, UI ou dinâmica social de produção.

[FATO] Pré-registro separado:
[`social_balanced_preregistro.md`](../tests/experiments/social_balanced_preregistro.md),
commit `33bc81efd77dc95e7afa4161a7a1830ad46abdbd`, anterior à implementação
e a todas as execuções novas. O protocolo original permanece intacto.

[HIPOTESE] O conteúdo do sinal, com encoder fixo e decoder aprendido,
melhora bebida física em relação a quatro controles sem informação do lado,
com distribuição exatamente 50%/50% dentro de cada seed.

[FATO] TRAIN 263101–263108: 192 episódios (12 passagens, ambos os lados),
alpha 0,3, epsilon 0,2, 146/192 bebidas exploratórias. Prior TRAIN: contagens
96/96, probabilidades 0,5/0,5. MAP desempata por sorteio uniforme de RNG
separado; não se fixa esquerda nem se consulta o lado do episódio de avaliação.
DEV 263201–263208: ativo 16/16 (8/8 em cada lado), cada controle 8/16.
Saída DEV: PASS pelos limiares do protocolo; não é confirmação HOLDOUT.
Checkpoint completo e trajetórias em [`M0_social_checkpoint.json`](M0_social_checkpoint.json)
e [`M0_social_dev.json`](M0_social_dev.json).

[FATO] HOLDOUT executado: 263901–263920, 20 seeds novas, dois lados por seed,
40 episódios por braço e 200 no total. Cinco braços: ativo, desligado,
embaralhado, uniforme e decoder sem sinal com prior TRAIN. A mesma escolha
independente do lado é reutilizada nos dois episódios de uniform/prior;
o embaralhamento usa o mesmo sorteio por seed. Isso preserva a unidade
independente SEED e garante 50% agregado aos controles sem informação.

[FATO] Critério pré-registrado: ativo >=75% global e em cada lado;
ganho >=25 pp e >=7 vitórias estritas por seed contra CADA controle.
Qualquer falha implica PARTIAL e utilidade não demonstrada neste teste.
Estatísticas por episódio e por seed são distintas; não há p-valor calculado
com os 40 episódios como amostras independentes.

[FATO] O runner exige `--dev` ou `--holdout`, recusa abertura implícita,
verifica hashes das fontes/checkpoint DEV e cria diretório marcador por
operação exclusiva antes de simular HOLDOUT. O checkpoint é carregado,
não retreinado, no holdout. Resultado/marcador existentes impedem novas rodadas.

Comandos com Godot 4.7.2 console do despacho, na raiz:

```text
godot --headless --path . -s tests/experiments/social_balanced_eval.gd -- --dev
godot --headless --path . -s tests/run_tests.gd
# Após commit f7f90f4 da implementação e checkpoint (já executado uma vez):
godot --headless --path . -s tests/experiments/social_balanced_eval.gd -- --holdout
```

[FATO] TRAIN/DEV: exit 0. Suíte completa antes do HOLDOUT: **exit 0, 16 suítes
verdes**, incluindo regressões novas de contrabalança, ausência de sinal/custo,
prior MAP dos dois lados, agrupamento por seed e reprovação por lado insuficiente.
Log: [`M0_social_tests_pre.txt`](M0_social_tests_pre.txt). Avaliadores antigos
`social_eval`, `ensino_eval` e `learn_eval` não foram executados.

[FATO] HOLDOUT: exit 0, abertura única e sem retuning. Suíte completa depois
do HOLDOUT: **exit 0, 16 suítes verdes**, sem erro de script/parse. Log:
[`M0_social_tests_post.txt`](M0_social_tests_post.txt). `git diff --check`
passou; pré-registro original e JSON/log E4 antigos permanecem idênticos à base.
Resumo TRAIN/DEV derivado dos JSONs da execução, sem reexecutar:
[`M0_social_train_dev.txt`](M0_social_train_dev.txt).

## Resultado por lado e custos físicos

[FATO] Cada linha por lado contém 20 episódios. Chegada e bebida tiveram as
mesmas contagens; chegada significa alcançar a margem que permite beber.
Passos e energia são médias de TODOS os episódios, com fracasso censurado em
100 passos. Todos os sucessos ocorreram em 38 passos. Energia do emissor
inclui metabolismo até o término, além do sinal; custo menor também reflete
encerrar episódios mais cedo.

| Braço | Lado | Bebida/chegada | Sinal recebido | Passos | Energia receptor | Energia emissor | Custo sinal |
|---|---|---:|---:|---:|---:|---:|---:|
| Ativo | Esquerda | 18/20 | 18/20 | 44,2 | 4,0268 | 3,5708 | 0,3 |
| Ativo | Direita | 20/20 | 18/20 | 38,0 | 3,5520 | 3,1120 | 0,3 |
| Desligado | Esquerda | 0/20 | 0/20 | 100,0 | 8,3000 | 7,4000 | 0 |
| Desligado | Direita | 20/20 | 0/20 | 38,0 | 3,5520 | 2,8120 | 0 |
| Embaralhado | Esquerda | 12/20 | 18/20 | 62,8 | 5,4512 | 4,9472 | 0,3 |
| Embaralhado | Direita | 8/20 | 18/20 | 75,2 | 6,4008 | 5,8648 | 0,3 |
| Uniforme | Esquerda | 13/20 | 0/20 | 59,7 | 5,2138 | 4,4178 | 0 |
| Uniforme | Direita | 7/20 | 0/20 | 78,3 | 6,6382 | 5,7942 | 0 |
| Prior TRAIN | Esquerda | 7/20 | 0/20 | 78,3 | 6,6382 | 5,7942 | 0 |
| Prior TRAIN | Direita | 13/20 | 0/20 | 59,7 | 5,2138 | 4,4178 | 0 |

| Braço | Bebida total | Passos | Energia receptor | Energia emissor | Custo sinal |
|---|---:|---:|---:|---:|---:|
| Ativo | 38/40 (95%) | 41,1 | 3,7894 | 3,3414 | 0,3 |
| Desligado | 20/40 (50%) | 69,0 | 5,9260 | 5,1060 | 0 |
| Embaralhado | 20/40 (50%) | 69,0 | 5,9260 | 5,4060 | 0,3 |
| Uniforme | 20/40 (50%) | 69,0 | 5,9260 | 5,1060 | 0 |
| Prior TRAIN | 20/40 (50%) | 69,0 | 5,9260 | 5,1060 | 0 |

[FATO] A ausência de sinal aprendeu escolher DIREITA neste TRAIN, ainda um
prior degenerado que explica 0/20 à esquerda e 20/20 à direita. O resultado
novo também supera uniforme e prior TRAIN não fixado à esquerda; não depende
de distribuição 8E/12D. Ativo e embaralhado perderam quatro pacotes em 40
episódios (duas seeds, cada uma com os dois lados). Falhas ativas: esquerda
nas seeds 263905 e 263916; nesses mesmos casos a direita teve sucesso pela
escolha sem sinal. Não se ocultaram essas falhas.

| Ativo menos controle | Ganho global | Ganho esquerda | Ganho direita | V/D/E episódios | V/D/E seeds |
|---|---:|---:|---:|---:|---:|
| Desligado | +45 pp | +90 pp | 0 pp | 18/0/22 | 18/0/2 |
| Embaralhado | +45 pp | +30 pp | +60 pp | 18/0/22 | 18/0/2 |
| Uniforme | +45 pp | +25 pp | +65 pp | 18/0/22 | 18/0/2 |
| Prior TRAIN | +45 pp | +55 pp | +35 pp | 18/0/22 | 18/0/2 |

[FATO] Critérios satisfeitos sem alteração: 95% global, 90% esquerda e 100%
direita (mínimo 75%); +45 pp contra cada controle (mínimo 25 pp); 18 vitórias
por seed contra cada controle (mínimo 7). Embaralhado tem a mesma tentativa,
custo e perda do ativo: sua comparação isola o conteúdo informativo. O ganho
agregado permanece após contrabalança; não há superioridade ao desligado no
lado direito, onde esse controle já acerta tudo.

## Proveniência e auditoria

[FATO] Ordem local verificável: `33bc81e` pré-registro → `f7f90f4` fontes,
checkpoint e DEV congelados → abertura única em `2026-11-02T03:32:39` UTC →
commit de resultados. Não houve mudança das fontes após abrir HOLDOUT.

[FATO] Artefatos novos: [`M0_social_holdout.json`](M0_social_holdout.json),
[`M0_social_holdout.txt`](M0_social_holdout.txt),
[`recibo de abertura`](M0_social_holdout_opened/receipt.json) e
[`M0_social_audit.json`](M0_social_audit.json). Auditoria somente dos dados
salvos, sem simular HOLDOUT novamente: hashes coincidem com DEV/checkpoint;
20 seeds distintas de TRAIN, DEV e E4 antigo; cada seed tem um episódio por
lado em todos os braços; custos e resumos por lado recalculados; controles
sem entrega/custo; comparações por seed e critérios PASS conferidos (exit 0).

[FATO] SHA-256 do HOLDOUT bruto:
`9be22650e756a699ef5341d10133bc8d58cc7d5acc9756c1ffafa1269b2bb896`.
SHA-256 do checkpoint:
`b32d8adcc637f6e74b60884ea7db19b8e04bf8b66db75bf551f765d953477921`.
Hashes completos das quatro fontes estão no recibo e na auditoria. O hash
do working tree sozinho não prova ordem de registro: essa ordem é sustentada
pelos dois commits anteriores ao resultado. Arquivos de texto podem ter bytes
de fim de linha diferentes após checkout em outra configuração Git.

[LACUNA] Mesmo PASS só demonstra utilidade no cenário binário com codificador
projetado, sensores intervindos e navegação heurística. Não demonstra linguagem
emergente, cooperação no ecossistema, aprendizado conjunto ou utilidade de
canal em produção. Marcador/hashes asseguram procedimento local auditável;
não são isolamento externo nem impedem apagar arquivos deliberadamente.
