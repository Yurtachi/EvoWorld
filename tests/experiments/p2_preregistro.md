# P2 — obstáculos, mapa local e planejamento (pré-registro, 02/11/2026)

[FATO] Este pré-registro define o protocolo experimental para o marco P2
(obstáculos físicos tipados, mapa local da criatura, planejador determinístico
A* otimista, memória de rotas reforçadas por uso e bloqueios, migração de save
v17). P1 e P1b permanecem com seus holdouts imutáveis e auditados.

## Separação de seeds e abertura

DEV (6 seeds): 592101, 592102, 592103, 592104, 592105, 592106.
HOLDOUT (24 inéditas): 592401, 592402, 592403, 592404, 592405, 592406,
592407, 592408, 592409, 592410, 592411, 592412, 592413, 592414, 592415,
592416, 592417, 592418, 592419, 592420, 592421, 592422, 592423, 592424.
Diagnósticos e desenvolvimento unitário: 592010–592029.

Varredura de colisão: todas as 373 seeds históricas de E3, E4, M1, M1b, M2, M3,
M3b, M3c, M4b, M5, P1 e P1b foram inventariadas; zero colisão com as seeds
selecionadas para DEV e HOLDOUT do P2. Qualquer colisão futura detectada no
freeze impede a abertura do holdout.
O pré-registro é versionado em commit isolado antes de qualquer alteração no
motor congelado. O freeze ocorre em commit subsequente registrando os hashes SHA-256
de todos os arquivos relevantes e dos marcadores. O holdout é aberto exatamente
uma vez, sem ajustes posteriores de código ou parâmetros.

## Protocolo experimental e ambiente

Arena 900×600 unidades, sem reposição natural de comida e sem reprodução.
Pet com parâmetros físicos padrão: visão 70, FOV 1,5π (270°), velocidade 55,
tamanho corporal 8, metabolismo 0,5, fome inicial 0,65 (motivação de busca ativa).
Partida do pet fixada em (120, 300). Alvo de alimento em (780, 300) suprido por
feeder físico, a uma distância em linha reta de 660 unidades (fora do alcance visual direto).
O pet possui experiência prévia com o recurso na posição alvo (8 ingestões de treino
em mundo livre ou memória pré-carregada de P1), mas nunca esteve no layout com barreiras.

Layout de obstáculos:
Uma parede vertical sólida de obstáculos tipados (`tipo: "parede"`, raio 24)
é posicionada em x = 450, estendendo-se de y = 50 até y = 550, bloqueando
completamente a linha de visada e a passagem direta entre partida e comida.
A parede contém exatamente UMA passagem (gap) desobstruída de largura 80 unidades,
posicionada em coordenada y sorteada deterministicamente pela seed:
`gap_y = 150 + (seed % 4) * 100` (posições possíveis: 150, 250, 350, 450).

## Ensaios (Testes 1 a 4)

- TESTE 1 (Primeira viagem):
  O pet parte de (120, 300) sem conhecimento prévio do mapa de obstáculos da arena.
  Deve navegar, detectar os obstáculos com seus sensores ou sofrer colisões, mapear
  o espaço em seu mapa local, encontrar a passagem e alcançar a comida em horizonte
  máximo de 600 ticks.
  Registra-se: comprimento da trajetória (unidades), tempo em ticks e contagem de colisões.

- TESTE 2 (Viagens repetidas — 5 tentativas):
  Após alcançar a comida na tentativa t, o pet é reposicionado na partida (120, 300)
  para iniciar a tentativa t+1, preservando a memória espacial, mapa local e rotas
  memorizadas (ou sem preservação, conforme a ablação de cada braço).
  Executam-se 5 tentativas consecutivas.
  Mede-se a convergência do comprimento da trajetória e do tempo para perto do ótimo
  geométrico conhecido (rota direta passando pelo centro da passagem), bem como a
  redução do número de colisões.

- TESTE 3 (Mudança do layout — adaptação):
  Imediatamente após a 5ª tentativa, a passagem original é fechada com novos obstáculos
  e uma nova passagem alternativa é aberta em posição diferente:
  `novo_gap_y = 150 + ((seed + 2) % 4) * 100`.
  O pet é posicionado na partida. Testa-se se o pet:
  (1) detecta a falha da rota memorizada ao chegar à passagem agora bloqueada;
  (2) registra o bloqueio em seu mapa e memória de bloqueios;
  (3) replaneja e explora alternativas até encontrar a nova passagem;
  (4) alcança o alimento na nova configuração em até K=3 tentativas de 600 ticks.

- TESTE 4 (Retenção após save/load):
  Após a consolidação da rota no Teste 2 (ou 3), o estado do mundo e da mente é
  salvo em disco usando o formato persistente v17 via SaveStore, e em seguida
  recarregado em uma nova instância limpa.
  Executa-se uma tentativa adicional para verificar se a memória de mapa, bloqueios
  e rotas sobreviveu integralmente ao ciclo de serialização e desserialização,
  mantendo o desempenho sem regredir para exploração cega.

## Braços pareados (mesmas seeds e layout)

(i) `completo`:
    Memória espacial ativa + mapa local de células {desconhecida, livre, bloqueada}
    preenchido exclusivamente por percepção sensorial e colisões físicas + planejador A*
    determinístico sob hipótese otimista ("desconhecido = livre") + memória de bloqueios
    e de rotas bem-sucedidas com reforço e esquecimento.
(ii) `sem_memoria`:
    Planejador reativo que reconstrói o mapa local do zero a cada viagem; não mantém
    memória entre tentativas (esquece obstáculos encontrados em viagens anteriores e não
    armazena rotas).
(iii) `seguidor_parede`:
    Heurística clássica competente para contorno de obstáculos (algoritmo tipo "Bug"):
    move-se em direção ao alvo; ao encontrar obstáculo, contorna a borda da parede
    mantendo contato e avança até que a linha até o alvo esteja desobstruída ou condição
    de partida seja satisfeita. Heurística determinística sem mapa nem memória de rotas.
(iv) `aleatorio`:
    Controle com desvio aleatório ao sofrer colisão física (vagar com recuo), sem
    planejamento e sem mapa.
(v) `oraculo`:
    Planejador A* omnisciente que lê o mapa verdadeiro do mundo; teto analítico de
    desempenho reportado separadamente, EXCLUÍDO de qualquer teste de baseline ou seleção.

## Critérios falsificáveis fixados antes dos resultados

- H-1 (Convergência de trajeto):
  No braço `completo`, a razão entre o comprimento do trajeto na tentativa 5 e na tentativa 1
  é <= 0,80 (redução de pelo menos 20% no trajeto após aprendizado da rota), e o trajeto da
  tentativa 5 é significativamente menor do que o do melhor braço sem memória (`sem_memoria`
  ou `seguidor_parede`) com teste pareado de sinais por seed (p < 0,05, empates excluídos).
- H-2 (Teto de colisões):
  No braço `completo`, a média de colisões físicas por tentativa nas tentativas 2 a 5 é <= 0,50
  (queda substancial de colisões após mapeamento inicial), sendo significativamente inferior
  à do `seguidor_parede` e `sem_memoria`.
- H-3 (Replanejamento e adaptação em layout alterado):
  No Teste 3, após o fechamento da passagem conhecida, o braço `completo` detecta o bloqueio,
  replaneja e alcança o alimento através da nova passagem em até K=3 tentativas em pelo menos
  90% das seeds (>= 22/24 seeds no holdout).
- H-4 (Retenção após save/load):
  No Teste 4, o comprimento do trajeto após save/load v17 é <= 1,10 do trajeto da tentativa 5
  (retenção >= 90% do trajeto otimizado), sem erros de validação ou corrupção de estado.
- REGRA DE NÃO-DEMONSTRAÇÃO:
  Se o `seguidor_parede` sem memória empatar ou superar o braço `completo` em comprimento
  de trajeto em TODAS as tentativas em mais de 50% das seeds, o experimento será classificado
  como "aprendizado nao demonstrado".
- H-E (Integridade de engenharia e telepatia):
  CPU headless média do pet < 2,0 ms/tick; teste estático e dinâmico de telepatia 100% aprovado
  (garantindo que o planejador nunca consulta `world.obstacles`, `world.foods`, etc. diretamente);
  migração v1..v16 -> v17 idempotente; rejeição estrita de dados hostis (NaN, INF, fora dos limites).

Veredito global:
- PASS: H-1, H-2, H-3, H-4 e H-E cumpridas integralmente.
- PARTIAL: falha em algum critério comportamental com integridade e telepatia preservadas.
- FAIL: violação de telepatia, regressão de determinismo ou falha de integridade em save/load.
