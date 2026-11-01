# Sinais — gate G4

## Pré-registro, antes dos resultados

Data: 01/11/2026. Este protocolo será commitado antes da primeira execução do
experimento completo. Não será ajustado após observar as sementes de avaliação.

Hipótese: disponibilizar um canal de símbolos neutros ao Q-learning pode melhorar
forrageamento e sobrevivência e alterar sincronização. Não há significado associado
a nenhum símbolo, recompensa por emissão ou resposta reflexiva programada.

- Treino: sementes 2101–2106, duas passagens, até 1500 passos por episódio.
- Avaliação: treino nas mesmas seis sementes; holdout 8101–8110, nunca usado
  para treinar, depurar ou ajustar parâmetros. Políticas congeladas na avaliação.
- Mundo 600×420, oito organismos, 40 alimentos iniciais, capacidade 60, reposição
  de um alimento a cada dez passos, quatro obstáculos, sem reprodução.
- Canal: quatro símbolos, alcance 180, custo 0,3 de energia por emissão,
  perda independente de pacote de 5% por receptor, validade de dez passos.
- Treinamento reúne tabelas de oito corpos; cada corpo mantém transição própria.
  Q-learning usa os parâmetros herdados, sem recompensa adicional ou significado
  fixado. A tabela inicia em zero. Não usa o checkpoint do experimento G2.
- Avaliação pareada por semente com o mesmo checkpoint: `enabled` (canal ligado),
  `disabled` (canal desligado, emissões indisponíveis, nenhum custo de sinal),
  `muted` (canal ligado com perda de 100%, mesmas ações/custos que `enabled`).
  `muted` é controle secundário para distinguir custo/ações de disponibilidade de
  informação. O desligamento operacional também muda o conjunto de ações;
  portanto não isola sozinho a informação recebida.
- Métricas por episódio: alimento consumido por organismo inicial; média da idade
  na morte/fim; sincronização = fração de pares vivos com a mesma última ação por
  passo, somada e dividida pelo número total de pares observados; emissões,
  recepções e fração de primeiras ações após recepção diferentes da ação anterior.
  Pares incluem descanso; sincronização não implica cooperação ou benefício.
- Unidade de análise: semente, comparação pareada. Empates não são vitórias.
- Critério global de evidência de benefício (apenas holdout): `enabled` supera
  `disabled` em alimento em pelo menos 9/10 sementes; sobrevivência média pelo
  menos 1,05×; sincronização média aumenta pelo menos 0,02; há recepções e
  mudanças de ação registradas. Todos os critérios devem passar. A comparação
  `muted` e as métricas em treino são descritivas, sem resgatar falha global.
- Falha será declarada sem mudar critérios ou atribuir semântica aos símbolos.
  Mudança após recepção é temporal; não comprova causalidade individual.

Comando: `godot --headless --path . -s tests/experiments/signal_ablation.gd`.
Saída durável: `tests/experiments/results/signal_ablation_results.json`.
O comando termina com 0 se a execução/gravacão foi válida, mesmo quando a hipótese
falha; o campo `success` registra o resultado científico.
