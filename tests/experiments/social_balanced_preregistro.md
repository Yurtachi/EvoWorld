# M0-B — novo pré-registro E4 contrabalanceado

[FATO] Protocolo novo, de 02/11/2026, distinto do E4 original
`social_preregistro.md` e dos resultados 91501–91520. Este arquivo será
commitado separadamente antes de implementar/executar o novo HOLDOUT. O
pré-registro e os resultados antigos serão preservados. Nenhuma seed abaixo
foi executada neste protocolo no momento deste registro.

[HIPOTESE] O conteúdo de um sinal produzido por codificador fixo permite ao
decodificador aprendido beber mais que controles sem informação sobre o lado,
mesmo quando a frequência dos lados é exatamente igual por seed.

- Fixture física original: mundo 640×400, receptor (320,200), emissor
  (320,100), marcos (140,200)/(500,200), água raio 18, visão 30/500 e TAU,
  velocidade 40, horizonte 100 ticks de 0,1 s. Bebida exige evento `drink`;
  não há teleporte nem recompensa fisiológica. Navegador comum aos braços.
- Cada seed define DOIS episódios, lado 0 e lado 1, sem sortear o lado.
  Ambos são executados em TODOS os cinco braços com o mesmo checkpoint e
  mesmo RNG físico inicial. Essa contrabalança garante 50%/50% por seed.
  Lados usam o mesmo ruído inicial de canal e sorteios externos pareados;
  não são tratados como duas amostras independentes.
- TRAIN: 263101–263108, 12 passagens, lados 0 e 1 nessa ordem, 192 episódios.
  Q 3×2 inicialmente zero, alpha 0,3, epsilon 0,2, RNG de exploração 263100.
  Recompensa 1 apenas após bebida, zero no fracasso. Codificador fixo 1−lado
  observado pelo emissor; aprende-se somente o decodificador.
- DEV: 263201–263208, dois lados por seed e cinco braços, sem atualização.
  Deve ser executado antes do HOLDOUT, gravando checkpoint e dados próprios.
  Se houver defeito que exija mudar este protocolo, registrar em NOVO arquivo
  e novo commit antes de abrir HOLDOUT; não substituir este registro.
- HOLDOUT inédito: 263901–263920, 20 seeds diferentes das seeds antigas
  51001–51008/91501–91520 e de TRAIN/DEV novos. 40 episódios por braço,
  200 no total. Abrir uma única vez após TRAIN/DEV e commit da implementação
  congelada; sem retuning, seleção de seeds, reexecução ou resgate pós-teste.
  O runner carregará o checkpoint DEV congelado; recusará sobrescrever um
  resultado e criará marcador exclusivo antes da primeira simulação HOLDOUT.
- Braços: `active` (canal real, custo 0,3, perda 10%, alcance 200, TTL 100);
  `disabled` (emissão recusada, Q da ausência do decodificador ativo);
  `shuffled` (mesmo custo/perda, símbolo uniforme independente do lado, RNG
  exclusivo seed+700001); `uniform` (canal desligado, escolha uniforme dos
  dois marcos, RNG exclusivo seed+800001); `prior` (canal desligado,
  decodificador sem sinal aprende frequências de lado somente do TRAIN e
  escolhe MAP; empate é quebrado por sorteio uniforme seed+900001).
  Uniform/prior não leem observação do emissor, lado ou água do HOLDOUT;
  um mesmo sorteio é reutilizado nos dois lados de cada seed.
- Prior treinado: contar lados nos episódios TRAIN (contagens e probabilidades
  salvas no checkpoint); não usar frequências DEV/HOLDOUT. Não é treino por
  sinal, nem pode consultar o lado atual para escolher. Acesso a rótulos fica
  restrito ao TRAIN. Empate 50/50 no treino é um resultado esperado do desenho.
- Métrica primária: proporção de episódios com bebida física. Registrar também
  chegada, escolha, símbolo emitido/recebido, entrega/perda, observações iniciais,
  passos (fracasso censurado em 100), energia dos dois corpos e custo do sinal.
  Publicar totais e métricas por lado para TODOS os braços, inclusive falhas.
- Comparações pareadas: diferença de bebida ativo−controle por seed/lado;
  ganhos agregados e por lado, vitórias/derrotas/empates em 40 episódios e
  em 20 SEEDS (soma dos dois lados maior/menor/igual). Sem p-valores tratando
  os 40 episódios como independentes.
- Critério falsificável PASS: ativo >=75% no total E em CADA lado; ganho
  agregado >=25 pontos percentuais contra CADA um dos quatro controles;
  >=7 vitórias estritas por SEED contra CADA controle. Nenhuma métrica
  descritiva substitui estes critérios. Se qualquer critério falhar: PARTIAL,
  utilidade do canal não demonstrada neste novo teste, sem resgate pelo E4 antigo.
- Auditoria: registrar hashes do pré-registro, runner, fixture e checkpoint,
  commits e logs de TRAIN/DEV/HOLDOUT. Suíte completa antes/depois; testes do
  desenho usam somente seeds TRAIN/DEV, nunca HOLDOUT. Não executar os
  avaliadores antigos nem alterar seus JSONs. Resultado novo em
  `reports/M0_social_holdout.json`; relatório `reports/M0_social.md`.

[LACUNA] Cenário binário aberto com sensores intervindos, codificador projetado,
decodificador congelado e navegação heurística. Mesmo PASS não demonstra
linguagem emergente, encoder aprendido, cooperação geral ou utilidade no
ecossistema autônomo. Seeds são públicas e a abertura única tem garantia local
de procedimento, não isolamento externo ou proteção contra apagar arquivos.
