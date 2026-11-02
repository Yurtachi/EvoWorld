# M0-B — E4 social contrabalanceado

[FATO] Novo experimento em preparação, **HOLDOUT ainda fechado** neste commit.
O resultado antigo 18/20 vs 8/20 vs 10/20 não é o resultado deste protocolo.
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

[FATO] HOLDOUT planejado: 263901–263920, 20 seeds novas, dois lados por seed,
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
# Após commit da implementação e checkpoint:
godot --headless --path . -s tests/experiments/social_balanced_eval.gd -- --holdout
```

[FATO] TRAIN/DEV: exit 0. Suíte completa antes do HOLDOUT: **exit 0, 16 suítes
verdes**, incluindo regressões novas de contrabalança, ausência de sinal/custo,
prior MAP dos dois lados, agrupamento por seed e reprovação por lado insuficiente.
Log: [`M0_social_tests_pre.txt`](M0_social_tests_pre.txt). Avaliadores antigos
`social_eval`, `ensino_eval` e `learn_eval` não foram executados.

[LACUNA] Mesmo PASS só demonstra utilidade no cenário binário com codificador
projetado, sensores intervindos e navegação heurística. Não demonstra linguagem
emergente, cooperação no ecossistema, aprendizado conjunto ou utilidade de
canal em produção. Marcador/hashes asseguram procedimento local auditável;
não são isolamento externo nem impedem apagar arquivos deliberadamente.
