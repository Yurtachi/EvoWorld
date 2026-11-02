# M3b — cópia de formas por observação e memória (X5)

[FATO] **Classificação científica: FAIL.** A arquitetura agora observa uma demonstração limitada, reproduz de memória sem receber vértices durante os segmentos e ajusta parâmetros por erro escalar. Isso produziu melhora restrita em algumas trajetórias, mas não satisfez a aquisição, o desempenho nas formas de treino, a generalização nem o nível absoluto exigido de retenção. H1/H2/H3/H5 falharam; H4/H6/H7 passaram. Não houve ajuste depois da abertura do holdout.

## Protocolo, congelamento e abertura única

[FATO] Pré-registro imutável: `9460b1e`, arquivo `tests/experiments/m3b_copia_preregistro.md`, SHA256 UTF-8/LF `befbcf988ee7d24459b5e1fc716992eebd3e11b78431a40ba0f7d2aabef47266`. A divergência histórica de redação do pré-registro (que chama a revisão X4 de FAIL) não foi corrigida: a classificação efetiva do coordenador em `reports/M3_atelie.md` é PARTIAL. O protocolo foi preservado literalmente.

[FATO] A integração solicitada pelo coordenador, incluindo `reports/review_m3.md`, entrou por merge local `1430067`. O defeito de save ganhou fix separado `45c1bc7`; o motor e as correções RM3-01–05 estão em `fa6f2e0`. Motor, avaliador, recálculo e auditor congelados em **`88c726a3dc6395f63f318c366950c39b510c7e7a`**, commit anterior ao primeiro resultado. Os hashes dos 20 arquivos congelados estão no próprio JSON.

[FATO] O comando `--holdout` foi invocado uma única vez, com worktree limpa, e terminou exit 0. Antes de qualquer ensaio, o avaliador gravou e descarregou em disco o marcador `status = opened` no caminho definitivo; a guarda recusa abertura com marcador existente ou worktree suja. Ao terminar, esse mesmo artefato passou a `status = complete`. Não se testou a recusa reabrindo o holdout. O resultado contém 24 seeds inéditas `129401–129424`, seis braços e 144 trajetórias. Cada trajetória foi repetida dentro dessa abertura para verificar determinismo, conforme H7, sem retreino do código entre repetições.

[FATO] TRAIN utilizou `129101–129104`; DEV, `129201–129206`. As formas novas não aparecem nas 24 tentativas de aquisição de cada criatura: são apresentadas apenas depois do treino em linha, círculo e quadrado. DEV executou o mesmo protocolo de avaliação em suas próprias seeds. Dois processos independentes de DEV, com a versão final do avaliador, produziram arquivos idênticos, SHA256 `71f5b1c7cf254073a746d59b8ae4698d16c2835c9546c0787a0b41328e9d679d` (arquivo local em `builds/`, não versionado).

[LACUNA] As famílias geométricas já estavam enumeradas no pré-registro e foram avaliadas no DEV; são inéditas para a aquisição da criatura, não para o experimentador. Git e marcadores documentam esta execução e a identidade dos arquivos, sem provar ausência universal de execuções ocultas. Nenhum avaliador fechado anterior foi executado.

## O que mudou no motor

[FATO] `SimWorld.observe_board` verifica visão real, alcance visual e oclusão, inclusive quando o quadro já era conhecido. O observador recebe a demonstração apenas nessa fase. A memória por criatura contém até seis formas, cada uma com até oito deslocamentos observados normalizados, direção inicial discretizada, curvas relativas e comprimentos relativos. Há ruído perceptual e consolidação em observações repetidas durante o treino. Não se guardam coordenadas absolutas da referência.

[FATO] `propose_actions(shape, rng)` e o planejador de reprodução consultam apenas essa memória. Nas políticas que decodificam memória, a sequência de segmentos é planejada antes da execução e fica sujeita à mesma deriva, complacência angular e dinâmica de ruído motor; o oráculo zera o ruído para estabelecer o teto. O antigo rastreamento do próximo vértice foi retirado. O reprodutor não chama o gerador de geometria pelo nome da forma. Sem observação anterior, as políticas de memória recusam reproduzir a forma; o controle sem observação recebe erro 1 no avaliador.

[FATO] Ao concluir o traço, a avaliação externa calcula Chamfer simétrico com amostragem por segmento, remoção do centróide e escala RMS; a média bidirecional é dividida por 1,12 e limitada a [0,1]. O aprendiz recebe o erro escalar e seu histórico, sem gradiente ou recompensa por segmento. Os campos históricos `s_dir`/`r_step` não orientam o aprendizado; `r_step` permanece zero. O argumento de redução de erro mantido por compatibilidade é ignorado pela busca.

[FATO] A busca local propõe uma alteração em um dos três parâmetros persistidos, compara o erro final com o melhor anterior e aceita ou rejeita a proposta. Uma falha inverte a direção e reduz o passo; não há acesso à solução física ideal no critério de aceitação. A contagem de atualizações do X5 corresponde às tentativas com feedback. As tabelas antigas de pesos permanecem como campos de compatibilidade e resumo; não dirigem a reprodução.

[FATO] Baselines: `random` emite primitivas aleatórias; `naive` / memória sem treino parte dos mesmos parâmetros iniciais pré-registrados dos treinados `[0.62, -0.44, 0]`; `servo_geometrico` usa o mapeamento nominal `[0,0,0]` da memória perceptual, sem aprender; `oraculo` recebe percepção e execução sem ruído e a compensação exata `[0.26, 0.5625, 1]`, como teto. Todos produzem ações primitivas executadas pelo mesmo executor de traços. Não existe um viés adicional aplicado somente ao braço sem treino, nem a permutação artificial de comprimentos presente no trabalho parcial recebido.

[LACUNA] A inicialização descalibrada é uma escolha explícita do pré-registro, compartilhada por memória sem treino e treinados. Vencer esse braço isoladamente não estabelece aprendizado útil; por isso o servo nominal é o controle decisivo. O oráculo é privilegiado e não constitui política aprendida. O ambiente motor é sintético, e a métrica de Chamfer ignora a ordem de visita dos pontos e não valida escrita, símbolos ou linguagem.

## Resultado nas 24 seeds

[FATO] Cada braço tem 216 avaliações de formas de treino transformadas e 216 de formas novas (72 por forma). Sucesso exige erro **estritamente menor que 0,22**. As medianas/IQR abaixo são recalculadas a partir das tentativas individuais, sem médias de sucessos por seed.

| Braço | Erro treino (mediana; IQR) | Sucesso treino | Erro formas novas (mediana; IQR) | Sucesso formas novas |
| --- | --- | --- | --- | --- |
| `random` | 0,333849; 0,109951 | 7,41% | 0,320032; 0,087392 | 6,02% |
| `naive` | 0,383389; 0,101108 | 3,24% | 0,335794; 0,125480 | 1,85% |
| `servo_geometrico` | 0,316182; 0,087256 | 9,72% | 0,259925; 0,087599 | 30,09% |
| `trained_frozen` | 0,186338; 0,139834 | 64,35% | 0,240346; 0,146888 | 43,98% |
| `trained_online` | 0,188447; 0,137782 | 59,26% | 0,249194; 0,142916 | 42,59% |
| `oraculo` | 0,000001; 0,000001 | 100,00% | 0,000002; 0,000002 | 100,00% |

[FATO] Aquisição: o erro inicial é a média da primeira tentativa de cada forma; o final, a média das duas últimas tentativas de cada forma. A redução é calculada por trajetória antes de tomar a mediana.

| Treinado | Erro inicial mediano | Erro final mediano | Redução mediana |
| --- | --- | --- | --- |
| `trained_frozen` | 0,339455 | 0,200118 | 0,110282 |
| `trained_online` | 0,339455 | 0,200118 | 0,110282 |

[FATO] Formas não apresentadas durante a aquisição:

| Braço | Triângulo (erro; sucesso) | Cruz (erro; sucesso) | Zigue-zague (erro; sucesso) |
| --- | --- | --- | --- |
| `random` | 0,318623; 6,94% | 0,339604; 0,00% | 0,287210; 11,11% |
| `naive` | 0,278833; 4,17% | 0,340289; 0,00% | 0,434031; 1,39% |
| `servo_geometrico` | 0,259374; 6,94% | 0,310443; 0,00% | 0,173746; 83,33% |
| `trained_frozen` | 0,197367; 62,50% | 0,304040; 16,67% | 0,217695; 52,78% |
| `trained_online` | 0,193209; 68,06% | 0,307450; 12,50% | 0,241768; 47,22% |
| `oraculo` | 0,000002; 100,00% | 0,000002; 100,00% | 0,000002; 100,00% |

[FATO] Margens agregadas sobre o servo nas formas novas: congelado `0,019578` e online `0,010730`, abaixo de 0,08. Em zigue-zague, o servo nominal foi melhor que ambos os treinados. Nenhum treinado alcançou 50% de sucesso agregado nas novas formas, além das falhas H1/H2/H5; não cabe PARTIAL pelo protocolo.

## Retenção, observação e corpo

[FATO] A retenção utiliza as seis formas, uma reprodução por forma em cada seed/fase (144 por braço). As demonstrações da lousa são limpas; as referências ficam exclusivamente no avaliador e não são reconstruídas internamente pelo nome da forma. Não há novo feedback escalar nessa fase. O estado completo do mundo passa por `World.from_dict(JSON.parse_string(snapshot))`, e os 144 roundtrips foram exatos na representação canônica de seis casas decimais.

| Braço | Memória imediata | Após save/load | Após 2000 ticks | Degradação absoluta mediana pareada (máxima das duas fases) |
| --- | --- | --- | --- | --- |
| `random` | 0,321063 | 0,321063 | 0,325123 | 0,041931 |
| `naive` | 0,350465 | 0,350465 | 0,348975 | 0,028792 |
| `servo_geometrico` | 0,273832 | 0,273832 | 0,293710 | 0,029979 |
| `trained_frozen` | 0,219309 | 0,219309 | 0,210977 | 0,022201 |
| `trained_online` | 0,201415 | 0,201415 | 0,195329 | 0,030030 |
| `oraculo` | 0,000001 | 0,000001 | 0,000002 | 0,000001 |

[FATO] O congelado preservou parâmetros e memória, mas seus erros após save/load `0,219309` e após 2000 ticks `0,210977` não ficaram abaixo de 0,20. Sua degradação mediana absoluta pareada `0,022201` ficou dentro de 0,05; **estabilidade não implica habilidade suficiente**, portanto H5 falha. Durante os ticks ociosos, o harness retirou os quadros e saciou o corpo a cada tick para impedir prática e morte; essas reposições são do teste, não da mente.

[FATO] H6 passou: nos dois treinados, apagar a memória e desabilitar a observação resultou em `has_observed = false`, nenhuma reprodução e erro mediano 1. H7 passou: delta máximo de energia/hidratação nas chamadas diretas de observação/reprodução/feedback foi `0.0`, e todas as 144 comparações pareadas de determinismo foram exatas. Nenhuma atualização do ateliê adiciona reservas corporais. O custo físico de desenho continua aplicado pelo executor em `SimWorld.step`, além do metabolismo normal; esse custo não é uma recompensa cognitiva.

## Decisão por hipótese

| Hipótese | Resultado | Evidência decisiva |
| --- | --- | --- |
| H1 | FAIL | Redução mediana 0,110282 < 0,14 nos dois treinados. |
| H2 | FAIL | Medianas 0,186338/0,188447 >= 0,18 e sucessos 64,35%/59,26% < 75%. |
| H3 | FAIL | Medianas >= 0,20, sucessos < 70% e margens sobre servo < 0,08. |
| H4 | PASS | Servo combinado 0,284308 >= 0,22 e < memória sem treino 0,363588; oráculo próximo de zero, 100% de sucesso. |
| H5 | FAIL | Retenção estável, mas erro absoluto do congelado >= 0,20 nas duas fases. |
| H6 | PASS | Sem observação não há reprodução das formas. |
| H7 | PASS | Delta cognitivo zero e repetição determinística. |

[HIPOTESE] A busca com poucas tentativas e comparação a um mínimo ruidoso pode aceitar acertos ocasionais e transferir mal a compensação para reversões de 180 graus e esquinas agudas. A memória perceptual discretizada também pode acumular erro angular. São explicações candidatas; os ensaios não isolam suas contribuições e não justificam escolher parâmetros novos a partir deste holdout.

## Persistência e correções da revisão M3

[FATO] Save mundial v11 e `Atelier.VERSION = 2`. As migrações v1–v9 continuam a preservar os estados legados sem ativar experiência nova; v10 migra explicitamente o ateliê v1. A migração é idempotente, preserva artefatos e histórico e inicia memória X5 vazia e parâmetros motores iniciais. Não concede a compensação do oráculo a criaturas antigas. Sessões X4 ativas são encerradas porque o plano servo antigo não é um plano de memória X5. A competência não é herdada por descendentes.

[FATO] **O M3 integrado podia rejeitar o próprio save após desenho**: episódios de personalidade guardavam `seek_board`/`draw_stroke`, ausentes no vocabulário aceito pelo leitor. O fix separado adiciona os dois códigos, com regressão que produz episódio real, salva em disco e recarrega o mundo inteiro por `SaveStore`.

[FATO] RM3-01: sessão exige oito segmentos e coerência entre estado, contador e ações; a mutação `status = active`, `total_segments = 16`, `step_index = 8` é rejeitada. RM3-02: IDs repetidos dentro de galeria, quadro ou ateliê são rejeitados; réplicas entre coleções devem concordar. RM3-03: geometria da referência deve coincidir com rótulo/parâmetros; ponto alterado, referência de dois pontos e troca de rótulo são rejeitados. A demonstração limpa possui representação explícita com parâmetros e traços vazios.

[FATO] RM3-04/05: rótulos e formato do título vêm de `scripts/core/textos.gd`, em pt-BR; foi removido o termo técnico inglês visível na política. Avisos da UI descrevem observação/memória como experiência restrita, sem transformar uma tentativa bem-sucedida em alegação de domínio geral. O verificador da UI foi atualizado para exigir esse contrato.

## Verificação e integridade

[FATO] `godot --headless --path . -s tests/run_tests.gd` passou antes de cada commit: 20 suítes legadas preservadas e a nova `test_sim_m3b.gd`, total 21 suítes na versão final, exit 0 e sem erros de script. O último ciclo foi executado depois do congelamento, antes do commit de resultados. Cobertura nova: saves após desenho, mutações exatas RM3, observação desabilitada/distante/fora do campo/ocluída, reprodução após limpar referência, feedback escalar, migração idempotente e números/tipos hostis.

[FATO] `godot --headless --path . -s scripts/ui/verify_ui.gd` passou (exit 0). Os goldens existentes não foram regenerados; testes de determinismo/performance e golden M1 continuam passando. Os `.uid` rastreados acidentalmente removidos pelo worker anterior foram restaurados antes dos commits. JSON de experimentos anteriores e o pré-registro X5 permaneceram intactos. O único JSON experimental novo deste trabalho é `reports/M3b_copia_eval.json`, SHA256 UTF-8/LF `dd929367170daf6eb3d1c7e8fd4721e6deebc2f66e6ff091d3b0b23c62f0d257`.

[FATO] O recálculo é somente leitura: `python tests/experiments/m3b_copia_metrics.py reports/M3b_copia_eval.json`. O gate `tests/experiments/verify_prereg.sh` inclui X5 e chama `m3b_copia_verify.py`, que verifica ancestralidade, hashes, protocolo imutável, cobertura de seeds/braços/fases, roundtrips, invariantes e classificação científica a partir do bruto. **PASS de integridade histórica não é PASS científico**.

[LACUNA] Não foi realizado benchmark novo de CPU/FPS, exportação release ou inspeção gráfica desta versão. A evidência de UI aqui é headless. O resultado não estabelece generalização ampla, aprendizagem de escrita nem desempenho em ecologias independentes. O trabalho foi commitado localmente com identidade Yurtachi, sem push, sem código GPL e sem alterações do motor após a abertura.
