# Revisão dinâmica independente M3

[FATO] Revisão de 02/11/2026 sobre `evo3/integration` em `ac2e1ff`, executada na branch `Yurtachi/evo3-review-m3`. O revisor não escreveu o M3. Foram lidos `docs/EVOWORLD_3_SPEC.md`, `reports/M3_atelie.md` (inclusive a revisão do coordenador) e `reports/review_dinamico.md`.

[FATO] **Não identifiquei achado ALTO ou CRÍTICO.** Há três achados MÉDIOS de validação de saves e dois BAIXOS de texto. A suíte e a release passam, mas a validação de persistência não está completa: um checkpoint aceito provoca `SCRIPT ERROR` na continuação do desenho. A reclassificação científica do coordenador é sustentada: **X4 = PARTIAL**, como evidência de calibração guiada, sem demonstração de cópia de memória.

[FATO] Apenas este relatório integra o commit. Nenhum código de produção, teste, protocolo, captura ou JSON experimental foi alterado; nenhum avaliador fechado `*_eval.gd` foi executado. Sem push/merge e sem uso de código GPL.

## Ambiente e comandos executados

[FATO] PowerShell/Windows, Godot `4.7.2.stable.official.ed1daf0bf`. Nas transcrições abaixo:

```powershell
$G = 'C:\Users\Yurtachi\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe'
$T = 'C:\Users\Yurtachi\AppData\Local\Temp\evoworld-review-m3-3e7209bb952345c4b681217aec371e6f'
```

[FATO] Scripts de sondagem, saves hostis, gzip, logs e release ficaram em `$T`, fora do repositório. O fuzz usa `SaveStore.new($T)` e caminhos absolutos; não utiliza slots reais do jogador. As suítes existentes usam seus próprios slots de teste. Os arquivos `.gd.uid` não versionados gerados pelo importador foram removidos seletivamente ao concluir a revisão.

## RM3-01 — MÉDIA — sessão ativa validada pode ultrapassar a referência

[FATO] `Atelier.valid_active`, em `scripts/atelier/atelier.gd:753`, aceita `total_segments` até 16 e não relaciona `step_index` ao número de pontos da referência do quadro. `step_drawing`, na linha 449, indexa `ref_stroke[idx + 1]` com essa informação carregada. Um save válido foi modificado somente assim:

```gdscript
d.creatures[0].atelier.active.status = "active"
d.creatures[0].atelier.active.total_segments = 16
d.creatures[0].atelier.active.step_index = 8
```

[FATO] A base foi produzida com `tests/unit/test_sim_m3.gd:studio(20261102)`, um quadro a `(10, 0)` da criatura, demonstração de quadrado e quatro chamadas de desenho, incrementando o tick antes de cada chamada. O script escreveu um envelope com checksum correto por `SaveStore._encode/_write`, leu por `_read` e chamou `draw_on_board` no mundo restaurado.

```powershell
& $G --headless --path . -s "$T/active-corruption.gd" -- $T
```

Saída real, **exit 0 apesar do erro de script**:

```text
DISK_CHECKSUMMED_ACCEPTED=true
CORRUPTED_ACTIVE_ACCEPTED=true
CALL_DRAW
SCRIPT ERROR: Out of bounds get index '9' (on base: 'Array')
   at: step_drawing (res://scripts/atelier/atelier.gd:449)
   [1] draw_on_board (res://scripts/world/sim_world.gd:345)
AFTER_DRAW
```

[FATO] É uma entrada persistida aceita que interrompe a chamada de desenho, não um erro de parsing do harness. Não houve execução arbitrária nem encerramento do processo. [HIPOTESE] Validar conjuntamente sessão, quadro e referência, além de guardar o acesso em execução, elimina essa família de falhas. [LACUNA] Não foi corrigida neste despacho de revisão.

## RM3-02 — MÉDIA — IDs de artefato duplicados são aceitos

[FATO] Sobre o mesmo save v10 válido, três mutações independentes foram aceitas por `World.from_dict`:

```gdscript
bad.gallery.append(bad.gallery[0].duplicate(true))
bad.boards[0].artifacts.append(bad.boards[0].artifacts[0].duplicate(true))
bad.creatures[0].atelier.artifacts.append(
    bad.creatures[0].atelier.artifacts[0].duplicate(true))
```

```text
ACCEPTED v10 duplicate gallery ID
ACCEPTED v10 duplicate board artifact ID
ACCEPTED v10 duplicate competence artifact ID
```

[FATO] Em `scripts/world/sim_world.gd:1123`, os laços confrontam artefatos com `used_ids`, mas não registram ali os IDs de artefato nem exigem unicidade dentro de cada coleção. A repetição do mesmo artefato entre galeria, quadro e criatura é parte normal do formato; o defeito reproduzido é a duplicação **dentro da mesma coleção**. IDs duplicados de criatura/quadro e colisão de artefato com quadro foram rejeitados.

[HIPOTESE] Usar conjuntos locais por coleção e exigir consistência das réplicas compartilhadas preserva o formato e impede contagem/apresentação duplicada. [LACUNA] Não se provou exploração de recursos físicos; o impacto demonstrado é integridade de galeria e identidade.

## RM3-03 — MÉDIA — geometria da referência não corresponde necessariamente ao rótulo/parâmetros

[FATO] `Atelier.valid_board`, em `scripts/atelier/atelier.gd:695`, verifica limites e tipos da referência, mas não sua correspondência com `build_reference_strokes`. Foram aceitas, separadamente:

```gdscript
bad.boards[0].reference_strokes[0][1] = [3.0, 4.0]
bad.boards[0].reference_strokes = [[[3.0, 4.0], [4.0, 5.0]]]
bad.boards[0].reference_shape = "linha" # geometria original: quadrado
```

```text
ACCEPTED v10 corrupted reference geometry
ACCEPTED v10 reference only 2 points
ACCEPTED v10 mismatched shape label
```

[FATO] O carregamento aceita uma referência de dois pontos, enquanto `step_drawing:433` só considera referência com pelo menos nove pontos. Nesse caso o desenho passa ao caminho sem referência; em outro caso o rótulo mostrado pode divergir da geometria usada na avaliação. Isso enfraquece a proveniência da demonstração e da competência carregada.

[HIPOTESE] Recriar a referência a partir de forma/parâmetros e comparar, ou definir explicitamente um schema para referências livres, evita a divergência. [LACUNA] Não houve adulteração dos resultados X4 versionados; as mutações ficaram no diretório temporário.

## RM3-04 e RM3-05 — BAIXA — texto de jogador

[FATO] A leitura dos caminhos de rótulos, menus, dicas, galeria e laboratório em `scripts/ui` encontrou tradução por `Textos`. Não encontrei frases inteiras de UI em inglês. Há, porém, o termo inglês técnico **`naive`** visível em `M3-ablation.png`, vindo de `scripts/core/textos.gd:923,927`: `sem treino (naive descalibrado)` e a nota de ablação. RM3-04: substituir por expressão integralmente pt-BR, por exemplo `sem treino (mapeamento descalibrado)`. Comentários e mensagens inglesas de asserção em `verify_ui.gd` não são texto de jogador.

[FATO] RM3-05: `scripts/atelier/atelier.gd:496` contém os rótulos `Linha`, `Círculo`, `Quadrado`, `Rabisco` e o formato `%s #%d de %s`, usados como títulos visíveis da galeria. São pt-BR, mas estão fora de `scripts/core/textos.gd`, contrariando a centralização exigida. A revisão não os moveu.

## Fuzz independente v1–v10 e envelopes

```powershell
& $G --headless --path . -s "$T/fuzz.gd" -- $T
```

[FATO] Execução final **exit 0**, sem `SCRIPT ERROR` no fuzz de carregamento. As bases v1–v5 vieram das fixtures existentes; v6–v9 foram construídas sem estados cognitivos futuros e passaram no controle positivo antes das mutações; v10 contém quadro, desenho concluído e competência reais. A primeira montagem temporária de v8 foi corrigida para remover também os IDs de mentes desativadas; isso era um erro do harness, não um achado do produto.

```text
VERSION_DONE v1 cases=32
VERSION_DONE v2 cases=32
VERSION_DONE v3 cases=32
VERSION_DONE v4 cases=32
VERSION_DONE v5 cases=32
VERSION_DONE v6 cases=32
VERSION_DONE v7 cases=32
VERSION_DONE v8 cases=32
VERSION_DONE v9 cases=32
VERSION_DONE v10 cases=29
FUZZ_DONE checked=567 accepted=12 rejected=555
```

[FATO] O total inclui 250 mutações adicionais aninhadas de M3. Das 12 aceitações, **cinco são controles válidos**: listas vazias de artefatos/tentativas e dicionários vazios de último erro/sessão. As **sete aceitações inconsistentes** são exatamente os três IDs duplicados, as três corrupções de referência e a sessão de RM3-01. Portanto, 562 entradas deliberadamente inválidas: 555 rejeitadas e sete aceitas; não se reporta um PASS irrestrito do fuzz.

[FATO] Foram exercitados arrays de **100001** quadros, artefatos, ações, strokes, pontos, pesos e tentativas; tipos `null`, bool, string, Array e Dictionary; NaN/±INF em corpo, vetor, referência, pesos internos e ponto de stroke; IDs corporais/quadros duplicados; colisões de IDs; referências e competência futuras injetadas em schemas antigos. Os limites/tipos/números não finitos foram rejeitados. A suíte integral também executa o corpus legado (`693+`, `1204` e `280` casos anunciados pelo runner).

[FATO] Envelopes em disco v1 e gzip v2 tiveram checksums corretos recalculados para ações enormes. No v2 foi acrescentado padding ao envelope para passar pela guarda de expansão e alcançar a validação do mundo. O bomb contém 2 MiB de espaços mais um payload válido, gzip e checksums válidos:

```text
ENVELOPE v1 { "ok": false, "message": "World data failed schema validation." }
ENVELOPE v2 { "ok": false, "message": "World data failed schema validation." }
BOMB { "ok": false, "message": "Compressed checkpoint exceeds the 64:1 expansion limit." }
```

[LACUNA] É um corpus determinístico de mutações e limites, não prova exaustiva sobre todo arquivo possível. `exit 0` do harness registra término da investigação; as aceitações acima continuam sendo achados.

## X4: servo geométrico sem treino

```powershell
& $G --headless --path . -s "$T/servo.gd" -- $T
python "$T/audit.py" $T
```

[FATO] Foi implementado um controlador temporário independente, sem instanciar política treinada, carregar pesos, executar aquisição ou chamar feedback. Ele recebe os mesmos vértices que o motor recebe, calcula `erro = próximo_vértice - cursor`, arredonda o ângulo para 16 direções e seleciona o bucket de comprimento pelo erro relativo (`<0.75`, `<1.35`, restante). O cursor virtual avança pelo passo médio da referência e pela razão `LENGTHS[bucket]/3`. São executadas as mesmas primitivas reais por `Atelier.execute_actions`, com erro medido pela mesma Chamfer. Não usa `choose_action`, `residual_state` nem `shape_segment_dirs` para decidir a ação.

[FATO] Foram usados **todos os 24 seeds `118401–118424`**, as três formas e as três transformações X4 de holdout: centros `(29,38)`, `(40,31)`, `(29,40)`, escalas `0.82/1.23/1.41` e rotações `(seed+8/+12/+18)%16`. São **72 pares / 216 desenhos novos**, comparados apenas às linhas já gravadas de `reports/M3_atelie_eval.json`; nenhum avaliador fechado foi reaberto. A direção inicial de `move_pen` foi `seed%16`; ela só muda a translação inicial, removida pela métrica, e não usa experiência aprendida.

Saída real, **exit 0**:

```text
SERVO shape=linha n=24 median=0.000001 success=24 exact_trained=15 max_delta=0.000001
SERVO shape=circulo n=24 median=0.000002 success=24 exact_trained=14 max_delta=0.000002
SERVO shape=quadrado n=24 median=0.000002 success=24 exact_trained=10 max_delta=0.000003
SERVO_DONE n=72 transforms=216 training=0 feedback=0
```

| Forma | Mediana servo | Mediana trained_frozen | Mediana trained_online | Sucesso servo | Maior diferença pareada absoluta |
| --- | ---: | ---: | ---: | ---: | ---: |
| linha | 0.000001 | 0.000001 | 0.000001 | 24/24 | 0.000001 |
| circulo | 0.000002 | 0.000002 | 0.000002 | 24/24 | 0.000002 |
| quadrado | 0.000002 | 0.000002 | 0.000002 | 24/24 | 0.000003 |

[FATO] O recálculo Python independente confirmou essas medianas e deltas para **ambos** os braços treinados. **O servo iguala os treinados nas medianas e na taxa de sucesso**, sem igualdade bit a bit em todo par. Isso confirma o controle ausente apontado pelo coordenador: a métrica alcança o piso com direção do erro e nenhum aprendizado. O `naive` é explicitamente descalibrado em `atelier.gd:325`; portanto, vencê-lo não estabelece vantagem sobre um controlador geométrico simples.

[FATO] X4 sustenta produção por primitivas e calibração persistida de um mapeamento motor inicialmente errado. [LACUNA] Este controle não mede reprodução sem guia, novas famílias de formas, nem retenção do servo após 2000 ticks; também não invalida a aprendizagem de calibração que efetivamente ocorre. Nenhum número novo foi incorporado aos artefatos experimentais originais. [HIPOTESE] Cópia após retirar a guia, novos baselines e novas formas/seeds exigem outro pré-registro, como já propõe o coordenador.

## Pré-registro, motor e holdout

```powershell
& 'D:\Softwares\Git\bin\bash.exe' tests/experiments/verify_prereg.sh
git log --oneline --follow -- tests/experiments/m3_atelier_preregistro.md
git merge-base --is-ancestor c9a4e31 bf21e01
git merge-base --is-ancestor bf21e01 e276299
git merge-base --is-ancestor e276299 ac2e1ff
```

[FATO] Todos terminaram **exit 0**. Saída real relevante:

```text
M3 PASS prereg_commit=c9a4e31 ... evaluator_commit=bf21e0153fb0fbc0fee49af9bb163e5c60d7867e result_commit=e2762990eeb73edf7da2a9efc1a1add408bc324b
M3 PASS prereg=c9a4e31 evaluator=bf21e01 result=e276299 seeds=24 rows=288
c9a4e31 docs(m3): pre-registra protocolo X4 de atelie e copia de formas
```

[FATO] O gate também imprimiu PASS para E3, E4, M1 e M2. A auditoria Python comparou diretamente os blobs do protocolo em `c9a4e31`, `bf21e01`, `e276299` e `ac2e1ff`: todos têm SHA256 `717fab65bbe92c2689a648c7e40b956ea758651ba5d41ab0442c5ac6a59b6251`. O histórico do caminho mostra somente sua criação: **o pré-registro não foi alterado depois do holdout** no histórico auditado. O verificador M3 também conferiu os hashes congelados e as 288 linhas existentes.

[LACUNA] Ancestralidade e identidade de blobs não provam ausência de execuções locais não registradas. O PASS de integridade histórica não elimina a limitação científica demonstrada pelo servo.

## Corpo, determinismo e golden

```powershell
rg -n '(energy|hydration|\.pos)\s*[-+*/]?=' scripts/mind scripts/atelier
& $G --headless --path . -s "$T/det-body.gd" -- "$T/state-a.json"
& $G --headless --path . -s "$T/det-body.gd" -- "$T/state-b.json"
Get-FileHash "$T/state-a.json", "$T/state-b.json"
git log --oneline -- tests/experiments/m1_golden.json
```

[FATO] A busca não encontrou atribuições aos três campos nos módulos auditados. Nas seeds novas `20261102/20261103`, 100 rodadas de afeto, decaimento, observação, evidência e decisão mantiveram `[energy, hydration, pos]` exatamente iguais. Mesmo evidência sintética de energia/hidratação `1000` não aplicou recompensa corporal; ela foi descartada antes do teste de save, pois não é experiência válida. Quatro chamadas diretas de `Atelier.step_drawing`, com oito updates de calibração, também mantiveram o corpo igual.

[FATO] Mundos novos e válidos com quadro/círculo foram simulados por 300 ticks; depois do round trip, original e restaurado continuaram por mais 60 ticks, exatamente iguais. Dois processos independentes terminaram **exit 0** e produziram:

```text
GOLDEN_100_TICKS failures=[]
BODY_MIND seed=20261102 unchanged=true
BODY_ATELIER seed=20261102 unchanged=true updates=8
CONTINUATION seed=20261102 exact=true
DETERMINISM seed=20261102 sha=09e5867437788465fa4728f7c9d94d7f118d680410c79da49d6c5c3b9bf964f9
BODY_MIND seed=20261103 unchanged=true
BODY_ATELIER seed=20261103 unchanged=true updates=8
CONTINUATION seed=20261103 exact=true
DETERMINISM seed=20261103 sha=5c74e13789e4a33c8f75759bc8172596b8b0df216d9134bf5d1aabd97e38afac
PROBE_DONE failures=[]
```

[FATO] Ambos os arquivos de estados completos têm SHA256 `744028fe061e4e9b4090180382a7c7efee57b87a600bed76cb63f168950315c1`. O golden M1 passou nas duas execuções e seu histórico contém somente `c8e9e91`; não foi regenerado. A suíte integral passou também `test_perf_determinism.gd` e as continuações de M3.

[FATO] O executor físico `sim_world.gd:616` acrescenta `DRAW_ENERGY_COST` ao custo corporal quando a ação é `draw_stroke`. Isso é custo do mundo, não mutação pelo afeto/memória/ateliê. A mente escolhe ações e recebe evidência; não encontrei recompensa metabólica nem teleporte nesses módulos. [LACUNA] Testes finitos e leitura de código não constituem prova formal universal do termo “nunca”.

## Release exportada e UI real

```powershell
& $G --headless --path . --export-release 'Windows Desktop' "$T/EvoWorld.exe"
$p = Start-Process -FilePath "$T/EvoWorld.exe" -WindowStyle Hidden -ArgumentList @('--headless','--quit-after','20') -Wait -PassThru -RedirectStandardOutput "$T/release.log" -RedirectStandardError "$T/release.err"
$p.ExitCode
& $G --headless --path . -s scripts/ui/verify_ui.gd
$p = Start-Process -FilePath $G -WindowStyle Hidden -ArgumentList @('--path','.','-s','scripts/ui/verify_ui.gd') -Wait -PassThru -RedirectStandardOutput "$T/ui-graphic.log" -RedirectStandardError "$T/ui-graphic.err"
$p.ExitCode
```

[FATO] Exportação **exit 0**, release com `--quit-after 20` **exit 0**, somente cabeçalho Godot, stderr vazio e **zero `SCRIPT ERROR`**. Binário: `109791856` bytes, SHA256 `2743f3d7a08bf53853064d02a7746b73f7b91cb0b62726a8f73da38625f2e47b`.

[FATO] `verify_ui` passou em headless **e com renderização real**, ambos **exit 0**, `Integração da UI: ok`, sem erro de script. O segundo processo informou `OpenGL API 3.3.0 NVIDIA 610.62 - Compatibility - Using Device: NVIDIA - NVIDIA GeForce RTX 2050`. Foram exercitados controles da cena real, persistência e os testes M3 de quadro/demonstração/galeria/histórico/ablação.

[FATO] As oito capturas existentes `reports/M3-*.png` foram abertas e inspecionadas visualmente, sem alterá-las:

| Captura | Evidência observada |
| --- | --- |
| M3-scribble.png | Criatura junto ao quadro, desejo e ação de desenho; português e linguagem observacional. |
| M3-drawing.png | Miniatura e progresso `segmento 4/8`, quadro e controles cabem no painel. |
| M3-demo.png | Diálogo real com forma/escala/centro, prévia e confirmação; rótulo X quebra em duas linhas, legível. |
| M3-gallery.png | Miniaturas, dono, tick, quadro, referência e erro; lista com rolagem. |
| M3-lab-curve.png | Curva por forma, limiar e tentativas; aviso explícito de que não copia de memória. |
| M3-ablation.png | Treino desligado, política e aviso de persistência; contém o `naive` de RM3-04. |
| M3-tutorial.png | Roteiro explica guia visível e limite de calibração; conteúdo com rolagem. |
| M3-fps-12.png | 12 criaturas e painel legível, com indicador de quadros/s. |

[FATO] Não observei sobreposição que impedisse os controles M3 nessas imagens de `1100×680`. A criatura cobre parte do quadro no mundo, mas as miniaturas da demonstração/galeria tornam os traços inspecionáveis. [LACUNA] Capturas preexistentes não são novas medições de FPS nem prova de todo layout/tamanho. A release foi testada na inicialização headless; a renderização real foi validada no processo de desenvolvimento de `verify_ui`.

## Suíte integral e integridade da entrega

```powershell
& $G --headless --path . -s tests/run_tests.gd
git diff --exit-code HEAD -- 'reports/*.json'
```

[FATO] A suíte foi executada integralmente no início e novamente antes do commit: **20 suítes ok, exit 0, zero FAIL e zero `SCRIPT ERROR`** em ambas. Inclui:

```text
test_perf_determinism.gd: ok
E5 hostis: 693+ casos, versoes 1-7
M0 fuzz aninhado: 1204 casos deterministas, versoes 1-7
M0 TTL hostis: 280 casos, versoes 3-7 (v1/v2 nao tinham ordens)
test_save_robustez.gd: ok
test_sim_m1.gd: ok
test_sim_m1b.gd: ok
test_sim_m2.gd: ok
test_sim_m3.gd: ok
```

[FATO] A comparação dos JSON versionados terminou **exit 0**, sem mudanças a restaurar. O único erro de script reproduzido foi o caso adversarial RM3-01, que a suíte atual não cobre. [LACUNA] Permanecem RM3-01–03 para correção da validação e RM3-04–05 para ajuste de texto; aprovação da robustez de saves fica condicionada a essas correções, sem achados altos/críticos nesta revisão.
