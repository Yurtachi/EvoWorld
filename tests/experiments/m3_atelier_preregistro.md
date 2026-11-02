# M3 / X4 — protocolo pre-registrado de atelie e copia de formas antes do holdout

[FATO] Implementacao limpa e propria em GDScript (`scripts/atelier/atelier.gd`),
sem codigo externo, sem TensorFlow, sem dataset QuickDraw e sem LLM. Particoes
disjuntas de sementes: TRAIN 118101-118104 (4 seeds); DEV 118201-118206 (6 seeds);
HOLDOUT 118401-118424 (24 seeds ineditas, pareadas em todos os bracos e formas).
Nunca executar o holdout durante o desenvolvimento. O avaliador grava e sincroniza
`status="opened"` antes do primeiro ensaio e recusa reabertura se o arquivo existir.

[FATO] Representacao e acoes primitivas: todo desenho no quadro (`world.place_board`)
resulta exclusivamente de uma sequencia finita de acoes primitivas (`move_pen`,
`pen_down`, `pen_up`, `segment` com 16 direcoes discretas e 3 comprimentos discretos),
respeitando limites estritos de tracos, pontos e acoes. Curvas (como `circulo`)
sao formadas somente por segmentos retos discretos; nunca se usa imagem pronta
ou sorteada. Simbolos de escrita/letras nao sao implementados no E3.5 e ficam
restritos ao marco da biblioteca (M3b) com avaliacao propria.

[FATO] Metrica de erro e recompensa: o erro entre o traco desenhado pela criatura
e a forma de referencia demonstrada (`world.demonstrar_forma(board, forma)`) e a
distancia de Chamfer simetrica normalizada em [0, 1], invariante a translacao
(centralizacao pelo centroide) e a escala (normalizacao pelo raio RMS). Limiar
pre-fixado de sucesso por tentativa: `erro < 0.22`. A politica de tracos e
parametrizada e treinavel sobre direcao e comprimento discretos condicionados ao
erro residual (16 setores angulares e 3 faixas de magnitude), atualizada por
reducao medida do erro, sem conceder energia ou hidratacao.

[FATO] Bracos pareados por seed:
1. `random` (aleatorio / rabisco): escolhe direcoes e comprimentos discretos pelo
   RNG mental, sem usar tabela aprendida.
2. `naive` (nao treinado): politica inicial sem treino (`updates = 0`, tabelas
   zeradas, `learning = false`).
3. `trained_frozen` (treinado congelado): politica treinada por 12 tentativas por
   forma (`linha`, `circulo`, `quadrado`) na configuracao de treino (centro padrao
   32,32, escala 1.0, rotacao 0) e congelada (`learning = false`) antes do teste.
4. `trained_online` (treinado online): parte da mesma aquisicao e mantem
   `learning = true` durante as tentativas de avaliacao.

[FATO] Formas, posicoes e escalas HOLDOUT ineditas: no holdout, cada uma das tres
formas (`linha`, `circulo`, `quadrado`) e demonstrada em posicoes, escalas
continuas (0.65 a 1.42) e orientacoes angulares nao vistas em TRAIN nem em DEV.
Avaliam-se tambem a curva de melhoria ao longo das 12 tentativas de aquisicao,
a retencao imediata apos `save/load` (`World.from_dict(w.to_dict())`, v10) e a
retencao apos 2000 ticks ociosos no mundo fisico sem demonstracoes no quadro.

[HIPOTESE] H1 (competencia global vs controles): no holdout inedito, tanto
`trained_frozen` quanto `trained_online` atingem erro normalizado mediano < 0.18
e taxa de sucesso (`erro < 0.22`) >= 75%, reduzindo o erro mediano em pelo menos
0.20 frente a `random` e `naive`.
H2 (competencia honesta por forma): em CADA forma isolada (`linha`, `circulo`,
`quadrado`) sob posicoes/escalas/orientacoes holdout ineditas, `trained_frozen`
e `trained_online` atingem taxa de sucesso >= 70% e erro mediano < 0.20; se
qualquer forma falhar, o status cientifico global sera reportado como `PARTIAL`.
H3 (distinguibilidade sem treino): o braco `naive` apresenta erro mediano > 0.30
e taxa de sucesso < 25%, diferindo de `trained_frozen` em >= 50 pontos percentuais.
H4 (melhoria vs tentativas): durante o treinamento, o erro mediano nas tentativas
finais (10-12) cai em pelo menos 0.20 em relacao as tentativas iniciais (1-3).
H5 (retencao apos save/load): 100% dos round trips v10 preservam o estado exato,
e a avaliacao apos `save/load` mantem taxa de sucesso >= 75% e erro mediano < 0.18.
H6 (retencao apos 2000 ticks ociosos): apos 2000 ticks de simulacao sem treino
no quadro, a competencia retida mantem taxa de sucesso >= 75% e erro mediano < 0.18.

[FATO] Persistencia e CPU: save v10 com migracao idempotente v1-v9, preservacao
integral dos goldens M1/M2 em mundos sem quadro e rejeicao de entradas hostis
(NaN, tipos invalidos, strokes enormes). Medicao serial de CPU com quadro ativo
para 12/30/60/100 criaturas (mente desligada vs so no pet, 100 warmup + 400 ticks).

[LACUNA] O aprendizado avalia copia motor-vetorial condicionada a traco de
referencia visivel no quadro; nao constitui compreensao semantica, simbolismo
linguistico nem evidencia de consciencia.
