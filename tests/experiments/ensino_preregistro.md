# E3 — pré-registro de avaliação de ensino

[HIPOTESE] Uma política Q condicionada à habilidade e à direção/distância relativa,
treinada por demonstrações físicas recompensadas somente após conclusão, generaliza
para posições e orientações inéditas melhor que a mesma política sem treinamento.
Não se prevê superioridade sobre a heurística geométrica.

Este documento e o protocolo `ensino_eval.gd` devem estar em commit local separado
antes da primeira execução de HOLDOUT. Nenhum resultado HOLDOUT autoriza retunar
hiperparâmetros, sementes, horizonte, métricas ou critérios desta avaliação.

- Habilidades primárias: `ir_ate_local` e `buscar_agua` (bebida física positiva).
- TRAIN: seeds 41001–41016, seis repetições por habilidade (96 episódios cada).
- HOLDOUT inédito: 93001–93020, um episódio por habilidade e braço (40 pares).
- Cinco braços: `aleatorio`, `heuristica`, `naive`, `trained_frozen`, `trained_online`.
- Mesmas seeds, geometria e horizonte de 140 passos por episódio em todos os braços.
- Mundo controlado de 640×480, corpo de tamanho 8, velocidade 30, visão 360°/240,
  metabolismo 1, energia inicial 80% da capacidade e hidratação inicial 65.
  Posição inicial sorteada em [220,420]×[160,320], orientação em [-pi,pi],
  alvo a 90–140 unidades em direção sorteada; água de raio 18 no alvo.
  Sem alimentos, obstáculos, reprodução ou personalidade; física e custos normais.
- TRAIN: todos os episódios são demonstrações assistidas pelo controlador geométrico;
  o reforço é pedido após sucesso físico. A política começa zerada e é transferida
  entre episódios; corpos, recursos e RNG são novos por episódio.
- Q de ensino: alpha 0,25; gamma 0,97; epsilon 0,15 durante aprendizado,
  exploração zero quando congelado. Retorno terminal 1, sem shaping de distância,
  sem atualização por fracasso ou recompensa sem conclusão, sem alterações fisiológicas.
- Estados: habilidade × 13 faixas de ângulo relativo (passo 0,5 rad, -6…6)
  × 3 faixas de distância (alcance, até 60, acima de 60) × obstáculo à frente.
- HOLDOUT: nenhuma assistência em qualquer braço. `trained_frozen` não atualiza;
  `trained_online` começa de cópia idêntica, atualiza somente após êxito de cada
  episódio e conserva sua tabela entre episódios, na ordem crescente de seeds.
  `naive` é Q zerado congelado. Heurística usa a mesma observação relativa.
- Métricas por episódio: conclusão real (0/1), passos até concluir ou censura em
  140, energia final/delta, sobrevivência, número de ações assistidas, atualizações.
  Proximidade, retorno e demonstração assistida nunca substituem sucesso autônomo.
- Comparação primária: `trained_frozen` versus `naive`, por seed/habilidade.
  Vitória = sucesso contra fracasso; empate se resultados de sucesso iguais.
  Teste de sinais binomial exato bilateral nos pares discordantes; p=1 sem discordâncias.
- Critério PASS de eficácia: sucesso congelado ≥70% em **cada** habilidade,
  ganho agregado ≥30 pontos percentuais sobre naive, p<0,05 e assistência HOLDOUT=0.
  Reportar também vitórias pareadas dos demais braços contra naive, sem redefinir
  o critério ou fazer afirmação confirmatória sobre comparações secundárias.
- Reportar honestamente PARTIAL/FAIL se qualquer critério falhar. Dados e sumário
  em `reports/E3_ensino_eval.json`; relatório humano `reports/E3_sim.md`.

[LACUNA] Cenário aberto controlado: não estabelece navegação em labirintos,
retenção vitalícia, generalização para corpos muito distintos ou eficácia ecológica.
