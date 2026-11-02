# P1 — memória espacial (pré-registro, 02/11/2026)

[HIPOTESE] Experiência em locais sorteados melhora busca alimentar sem percepção
atual do recurso, supera o melhor controle sem memória e persiste após save/load.
Política fixa de recuperação de evidência não implica aprender uma estratégia nova.

## Separação e amostra

DEV: 271101–271106. HOLDOUT: 271401–271424, 24 seeds inéditas, uma abertura.
Inventário histórico consultado: E3/E4 91501–91520, M0 93xxx,
M1 82401–82420/94831–94850/106xxx, M2 107301–107324,
M3 118401–118424, M3b 129401–129424, M3c 140401–140424,
M4b 154401–154424 (retenção 164401–164424), M5 151401–151424,
P0 160001–160003 e 7421, revisão 20261102–20261103.
Antes da abertura, verificar também todas as folhas chamadas seed/world_seed/seeds
dos JSON históricos; colisão invalida a abertura, sem escolher novas seeds em segredo.

## Protocolo congelado

Arena vazia 900 × 600, uma criatura, sem reposição, reprodução ou água;
visão 70, FOV 1,5π, velocidade 55, tamanho 8, metabolismo 0,5.
L é amostrado uniformemente no interior [100,800] × [100,500] por seed;
L2 também sorteado, distância de L >= 250. Nenhuma coordenada de L entra na política.
Treino: N=8 episódios de ingestão física de fruta em L, partindo a 25–60
unidades, direções variadas. Ressurgimento e reposicionamento são do protocolo;
nenhum comando, crédito corporal ou memória sintética no controlador.

A: três partidas inéditas, aleatórias, distância de L >= 180, sem comida
visível inicialmente, fome 0,65; T=180 ticks por partida. Uma fruta física em L.
Medir sucesso por ingestão, latência censurada T+1, caminho/reta, buscas de
memória e falhas; gravar posições por tick e lugares de treino em JSON.
B: desligar reposição/remover comida; provocar até K=5 visitas a L iniciadas
fora da visão, horizonte 180 cada, preservando aprendizado; registrar falhas,
expectativa e retornos autônomos em mais 180 ticks. Reposicionamento entre
tentativas apenas para medir revisão, nunca inserir resultado na memória.
C: serializar/deserializar o estado treinado real e repetir exatamente A.
D: experiência física adicional em L2 com alimento mais energético (legacy,
8 episódios); comparar valor recuperado de L e L2 a partir do ponto médio.
Reportar mudança de preferência e ganhos experimentados, mesmo se falhar.

Braços pareados, mesmos genoma, seeds, partidas, recursos e sensores disponíveis:
treinado, memória desligada (mesmo motor e exploração), não treinado,
explorador sistemático (varredura em faixas com espaçamento <= alcance visual,
sem lembrança entre episódios), oráculo (L conhecido, teto separado).
As trajetórias podem produzir observações diferentes; "mesmas observações"
significa mesmo canal e mesmas regras, sem alimentar controles com verdade oculta.
Validar separadamente cobertura geométrica >=90% da arena pelo explorador
em até 2000 ticks, com custo físico e FOV reais; falha invalida comparação PASS.

## Critérios falsificáveis, sem ajuste posterior

H-A: sucesso médio treinado >= melhor baseline sem memória +0,20 e latência
média censurada <=0,75 da melhor latência baseline. Teste pareado por seed:
sign test exato unilateral nas latências médias, empates removidos, p<0,05.
H-B: expectativa <0,25 em <=5 falhas reais em >=90% das seeds;
reportar retornos após revisão, sem ocultar fracassos de navegação.
H-C: sucesso pós-save >=95% do sucesso pré-save e latência <=110% da pré-save.
H-D: preferência por L2 mais rico em >=75% das seeds.
H-E: isolamento sensorial estático/dinâmico, save hostil e CPU pet <2 ms/tick.
PASS somente se todos passarem; PARTIAL se mecanismo funciona mas algum H
falha; FAIL se integridade/sensor/save falhar. Empate com sistemático implica
"aprendizado não demonstrado", mesmo se recuperação mecânica funcionar.

Pré-registro em commit separado antes do congelamento. O avaliador recusa
reabertura do holdout por marcador exclusivo e resultado existente; hashes do
pré-registro, motor e avaliador acompanham os resultados. Após abertura não
alterar motor, cenário, métricas ou limiares; somente relatório e auditoria.
