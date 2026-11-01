# E4 — pré-registro de informação assimétrica

[FATO] Protocolo fixado antes de executar HOLDOUT. Treino e desenvolvimento usam
somente seeds 51001–51008; HOLDOUT inédito usa 91501–91520, uma execução final,
sem ajuste posterior. O commit deste arquivo antecede implementação/avaliação.

[HIPOTESE] Um sinal condicionado à observação exclusiva do emissor permite ao
receptor aprender uma escolha que aumenta a chegada e bebida reais. Não se testa
emergência espontânea de linguagem: o emissor usa um codificador experimental
fixo de dois símbolos neutros (permutação 1,0). Só o decodificador é aprendido.
Nenhum símbolo será chamado de “água aqui” ou entendido como linguagem.

- Mundo aberto 640×400, dois corpos, sem alimento, reprodução ou personalidade.
  Receptor em (320,200), emissor em (320,100). Uma região de água com raio 18
  em (140,200) ou (500,200), sorteada pela seed. Emissor tem visão 500/TAU;
  receptor 30/TAU e inicialmente não vê água. Os dois destinos são marcos
  públicos fixos; a escolha não lê posição/ID da água oculta.
- Emissor lê somente sua observação sensorial; emite uma vez antes da decisão
  do receptor. Canal real: alcance 200, custo 0,3, perda 10%, validade 100 passos.
  Receptor escolhe uma vez por símbolo ou ausência e anda fisicamente ao marco;
  bebe somente quando a observação local permite. Horizonte 100 passos, dt 0,1,
  velocidade 40. Sem teleporte, recompensa por sinal ou assistência do jogador.
- Treino: 12 passagens por 8 seeds, ordem fixa, epsilon 0,2; Q por símbolo/ausência
  e destino, alpha 0,3, inicial zero. Recompensa 1 apenas se houve bebida real,
  0 no fracasso. Custo energético é medido separadamente. Política congelada.
- Braços pareados por seed e mesmo checkpoint: ativo; desligado (emissão
  recusada, sem custo); embaralhado (mesma tentativa/custo/perda, símbolo
  substituído por sorteio independente do local, RNG separado). Comparação com
  embaralhado isola conteúdo; desligado também remove custo do emissor.
- Métricas por episódio: observações iniciais de ambos, símbolo enviado/recebido,
  destino escolhido, chegada à região verdadeira, bebida, passos até sucesso
  (fracassos censurados em 100), energia consumida por receptor/emissor e custo
  da emissão. Sucesso primário = beber (evento físico do receptor).
- Gate PASS exige ativo >=75% de bebida, ganho >=25 pontos percentuais contra
  CADA controle e >=7 vitórias estritas pareadas contra CADA controle. Demais
  métricas são descritivas. Se não passar: PARTIAL, sem retuning ou resgate.
- Fixture determinista testa todos os pares local/símbolo independente: canal
  embaralhado acerta 50%, sem vantagem sobre ausência; desligado não entrega
  observação nem cobra energia. Determinismo e saves são testes separados.

[LACUNA] Cenário binário aberto, emissor codificado por projeto, sem risco,
negociação, labirintos ou aprendizagem conjunta. Resultado não prova cooperação
geral nem semântica emergente no ecossistema. Sem reexecutar ensino_eval/learn_eval.

Comandos: `godot --headless --path . -s tests/experiments/social_eval.gd -- --dev`
(somente TRAIN), depois o mesmo sem `--dev`. Dados em `reports/E4_social_eval.json`.
