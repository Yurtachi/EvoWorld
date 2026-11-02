# Revisão dinâmica independente — M0 + M1 + M1b + M2

[FATO] Revisão executada em 02/11/2026, Windows/PowerShell, Godot console
4.7.2 `ed1daf0bf`, na branch `Yurtachi/evo3-review-dyn`, criada sobre
`evo3/integration`, HEAD auditado `adce378f694e3c71fe1ecbd12c602e6ea9dadd97`.
O revisor não escreveu os patches examinados. Foram lidos
`docs/EVOWORLD_3_SPEC.md`, `reports/M1_mind.md`, `reports/M1b_afeto.md`,
`reports/M2_curiosidade.md`, pré-registros, validadores, executores e avaliadores.

[FATO] **Não foram encontrados achados de severidade ALTA ou CRÍTICA.**
A suíte integral e o executável release passaram. Há um defeito de severidade
MÉDIA na rejeição de saves hostis, uma divergência de contrato corporal que
precisa ser explicitada, uma falha MÉDIA na auditoria integrada de M1b e uma
lacuna BAIXA de apresentação M2. Os números científicos publicados conferem
com as linhas brutas; os limites PARTIAL de M1/X2b permanecem válidos.

[FATO] Só este relatório constitui alteração permanente no repositório.
Nenhum `*_eval.gd` foi executado, nenhum resultado foi reaberto, nenhum
`reports/*.json` foi modificado e nenhum save real do jogador foi usado.
Não houve push, merge, cópia de código externo ou operação Git destrutiva.
Os 20 arquivos `.gd.uid` gerados pela importação/exportação foram removidos
individualmente após verificar que eram arquivos novos dentro deste checkout.

## Comandos, isolamento e evidência local

[FATO] Nos comandos abaixo, as variáveis PowerShell correspondem exatamente a:

```powershell
$G = 'C:\Users\Yurtachi\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe'
$T = 'C:\Users\Yurtachi\AppData\Local\Temp\evoworld-review-dinamico-cb86f7df1d76448696c234841245c6b3'
```

[FATO] Os harnesses próprios, saves artificiais, exportação, estados comparados
e logs estão em `$T`, fora do repositório. `SaveStore` recebeu esse diretório
absoluto nos testes próprios, inclusive no teste com a cena real. A suíte
preexistente usa seus namespaces de teste, como `user://m1_unit_saves`,
`user://e5_migrations` e diretórios com PID; não foram usados slots pessoais.
Os arquivos temporários foram conservados para inspeção local, sem entrar no commit.

| Evidência local | Conteúdo |
| --- | --- |
| `suite_final.log`, `suite_final.exit` | Suíte integral e código de saída |
| `verify_prereg.log`, `prereg_history.patch` | Auditoria oficial e `git log -p` dos quatro protocolos |
| `fuzz.gd`, `fuzz_final.log` | 1616 mutações inválidas de saves v1–v9 e envelopes |
| `probe_observed.gd`, `probe_observed.log` | Oito sondagens de tipos em categoria observada |
| `ui_disk_probe.gd`, `ui_disk_probe.log` | Cena real e save gzip hostil com checksum válido |
| `audit_data.py`, `audit_data.log` | Recálculo independente de métricas, partições e proveniência |
| `determinism.gd`, `determinism_a.log`, `determinism_b.log` | Duas execuções e golden legado |
| `state_a.json`, `state_b.json` | Estados finais completos comparados |
| `export.log`, `EvoWorld.exe` | Exportação release |
| `release_plain.log/.err`, `release.log/.err`, `flags.log` | Execuções release e guarda de flags |

[FATO] SHA256 do harness final `fuzz.gd`:
`d89b135b6ddfc8475d82f432529c1cb56f8a39625cf5369d4bd4260c7b0ca3a2`.
SHA256 de `audit_data.py`:
`643a546fd62bb47a2be44ab03c95721978aa87085aaaf7627c73d98922d6b465`.

## Achados

### RD-01 — MÉDIA — tipo hostil causa SCRIPT ERROR no validador de objetos

[FATO] `scripts/mind/object_memory.gd:130` converte `k.value` e `k.confidence`
com `float(...)` antes de comprovar seus tipos com `Data.number()` nas linhas
seguintes. Quando `source == "observado"`, valores `[]`, `{}` ou `null`
alcançam a conversão e geram erro de execução. O leitor acaba rejeitando o
mundo; não foi observada aceitação do estado inválido, alteração do mundo
ativo nem encerramento do processo. O problema é a validação emitir erro de
script, inclusive ao carregar arquivo gzip válido, em vez de rejeitar
silenciosamente com o resultado de erro previsto.

```powershell
& $G --headless --path . -s "$T/probe_observed.gd"
& $G --headless --path . -s "$T/ui_disk_probe.gd" -- $T
```

Saída real, segundo comando, exit 0:

```text
OBSERVED_ENVELOPE_VERSION=2.0
SCRIPT ERROR: Invalid call. Nonexistent 'float' constructor.
   at: valid (res://scripts/mind/object_memory.gd:130)
   [1] from_dict (res://scripts/mind/creature_mind.gd:183)
   [2] from_dict (res://scripts/creature/sim_creature.gd:116)
   [3] from_dict (res://scripts/world/sim_world.gd:908)
   [4] _read (res://scripts/persistence/save_store.gd:129)
   [5] load_world (res://scripts/persistence/save_store.gd:52)
OBSERVED_DISK_REJECTION={ "ok": false, "message": "No valid checkpoint or backup. World data failed schema validation." }
```

[FATO] As oito sondagens diretas rejeitaram os mundos; seis produziram esse
erro (`value`/`confidence` × array/dicionário/null), duas com string rejeitaram
sem erro. Portanto exit 0 sozinho não detecta esta classe de falha.

[FATO] Reprodução mínima, em script temporário, sem escrever saves:

```gdscript
extends SceneTree
const Fixture = preload("res://tests/unit/test_sim_m2.gd")
const World = preload("res://scripts/world/sim_world.gd")
const Objects = preload("res://scripts/mind/object_memory.gd")
func _init() -> void:
    var w = Fixture.new().garden(20261102)
    var c = w.creatures[w.pet_id]
    w.place_object(c.pos + Vector2(24, 0))
    Objects.observe(c.mind, w.sense(c), w.tick)
    var bad: Dictionary = w.to_dict()
    bad.creatures[0].mind.objects.types.capsula.value = []
    print("rejeitado=", World.from_dict(bad) == null)
    quit(0)
```

[HIPOTESE] Validar todos os campos numéricos antes das condições semânticas
de `source` elimina o erro. Falta teste de regressão que também examine stderr;
não foi aplicado patch de produção neste despacho.

### RD-02 — MÉDIA contratual — o invariante absoluto de objetos não é verdadeiro

[FATO] O invariante de **módulos cognitivos** passou: afeto, decisão,
observação, codificação de episódios e memória de objetos não alteraram
energia, hidratação ou posição. A busca abaixo não encontrou atribuições
corporais em `scripts/mind`:

```powershell
rg -n -g '*.gd' -- '(energy|hydration|\.pos)\s*[-+*/]?=' scripts/mind
& $G --headless --path . -s "$T/fuzz.gd" -- $T
```

```text
COGNITIVE_BODY_UNCHANGED=true
OBJECT_PHYSICS before=[50.0, 50.0, (300.0, 300.0)] after=[54.0, 52.0, (300.0, 300.0)]
```

[FATO] A afirmação literal de que **objetos nunca alteram diretamente energia
ou hidratação**, incluindo seu executor físico, é falsa:
`SimWorld.interact_object()`, `scripts/world/sim_world.gd:280–281`, atribui
diretamente ambos os recursos conforme `ObjectCatalog.TYPES`. O teste acima
usa `capsula_agradavel` em contato corporal; não houve deslocamento.

[FATO] Isso está declarado em `M2_curiosidade.md` e exige alcance, linha de
visão, criatura viva e cooldown. A evidência aprendida é calculada depois dos
deltas físicos, e o valor aprendido não é reaplicado ao corpo. Não há evidência
de recompensa fictícia aplicada pela memória ou de teleporte.

[LACUNA] O requisito deste despacho usa “afeto/objetos/memória NUNCA”, enquanto
M2 prevê consequências físicas de cápsulas. A aprovação desse invariante
absoluto não pode ser assinada. É necessário explicitar a exceção do executor
físico ou modificar o catálogo, preservando a proibição de escrita corporal
pelos módulos cognitivos. Não classifico esse comportamento documentado como
exploit nem como achado alto/crítico.

### RD-03 — MÉDIA — auditoria M1b falha no HEAD integrado

```powershell
python tests/experiments/m2_affect_verify.py
```

Saída real, exit 1:

```text
  File "tests/experiments/m2_affect_verify.py", line 38, in main
    assert sha(git("show", f"HEAD:{path}")) == expected, path
AssertionError: scripts/mind/affect.gd
```

[FATO] O verificador exige que o motor atual ainda coincida com os hashes
congelados de M1b. M2 alterou legitimamente `affect.gd`, `creature_mind.gd` e
`motivation.gd`. A auditoria independente confirmou todos os hashes em
`300ffa4^`, antes do primeiro resultado M1b, e a imutabilidade do protocolo.
Logo, esta falha não demonstra edição retroativa do ensaio; demonstra que a
ferramenta não funciona como auditoria histórica depois de integrar M2.

[FATO] `verify_prereg.sh` passa E3/E4/M1/M2, mas não chama a auditoria M1b nem
audita o novo M0-B. Esses dois marcos foram conferidos separadamente aqui.

[HIPOTESE] Aceitar uma revisão explícita para auditoria histórica, separando
identidade no congelamento de identidade do HEAD atual, permitiria conservar
o gate de M1b após evoluções posteriores. Nenhum verificador foi alterado.

### RD-04 — BAIXA — apresentação M2 perde causas, motivos e ações

[FATO] A cena real foi instanciada com `SaveStore` temporário, pet em contato
com cápsula agradável e motivo `mind.iniciativa.novidade`. Os caminhos de
`scripts/ui/main.gd:1585` e `scripts/ui/laboratory.gd:264,280,285` consultam
`Textos`; faltam entradas correspondentes para `object_contact`, novos
motivos de iniciativa e ações `seek_object`/`investigate_object`.

```powershell
& $G --headless --path . -s "$T/ui_disk_probe.gd" -- $T
```

Saída real de controles da cena:

```text
UI_DESIRE=Parece querer investigar um objeto
UI_REASON=Texto indisponível.
UI_CAUSES=Passo 0 · Entusiasmo (0,168)
Texto indisponível.
UI_LOG=Passo 0 · Parece querer investigar um objeto
Razão não disponível nesta versão.
UI_ACTION_SEEK=Ação não reconhecida UI_ACTION_CONTACT=Ação não reconhecida
```

[FATO] Não foi encontrado texto bruto em inglês visível nesses caminhos:
eles usam fallbacks pt-BR. Leitura de atribuições de texto, menus, inspector,
chat e laboratório em `scripts/ui` confirmou uso de `Textos`/localizadores;
comentários e mensagens de asserção em inglês de `verify_ui.gd` são testes,
não texto de jogador. O desejo observado usa “Parece”; não houve emissão de
“sente”/“pensa” como alegação de estado subjetivo.

[LACUNA] Fallback traduzido não comprova apresentação completa de M2. Acrescentar
as entradas em `scripts/core/textos.gd` e testar os códigos novos é pendência
de integração visual. Não foi feita inspeção gráfica de todos os layouts.

## Suíte completa, saves hostis e envelope

```powershell
& $G --headless --path . -s tests/run_tests.gd
& 'D:\Softwares\Git\bin\bash.exe' tests/experiments/verify_prereg.sh
& $G --headless --path . -s "$T/fuzz.gd" -- $T
```

[FATO] A suíte integral foi concluída duas vezes; a execução final registrada
terminou **exit 0, 19 suítes ok, zero FAIL e zero SCRIPT ERROR**. Inclui:

```text
E5 hostis: 693+ casos, versoes 1-7
M0 fuzz aninhado: 1204 casos deterministas, versoes 1-7
M0 TTL hostis: 280 casos, versoes 3-7 (v1/v2 nao tinham ordens)
test_sim_m1.gd: ok
test_sim_m1b.gd: ok
test_sim_m2.gd: ok
test_perf_determinism.gd: ok
```

[FATO] O fuzz independente final terminou **exit 0, 1616 mutações inválidas
rejeitadas**, além dos envelopes e dos testes corporais. Cobriu campos
obrigatórios ausentes, tipos errados, NaN/±inf, IDs corporais/mentais/de objetos
duplicados ou inválidos, ordens com TTL nulo/fracionário/negativo/infinito,
acima do teto por intenção, afeto fora de [0,1], logs/episódios malformados,
memória de objetos, categorias, fontes e evidências corrompidas. As bases
v1–v7 vieram das fixtures de migração existentes; v8 e v9 foram construídas
com seed de revisão 20261102, sem executar avaliadores.

```text
VERSION_DONE v1 cases=89
VERSION_DONE v2 cases=175
VERSION_DONE v3 cases=313
VERSION_DONE v4 cases=454
VERSION_DONE v5 cases=595
VERSION_DONE v6 cases=736
VERSION_DONE v7 cases=877
VERSION_DONE v8 cases=1164
VERSION_DONE v9 cases=1616
FUZZ_DONE checked=1616 accepted=0
```

[FATO] Checksum correto foi recalculado para conteúdo hostil em envelope v1
e gzip v2. Ambos foram rejeitados com `World data failed schema validation`.
O gzip bomb com 2 MiB de espaços mais mundo válido, CRC/ISIZE e ambos os
checksums válidos, foi rejeitado por `64:1 expansion limit`. O gzip com tamanho
declarado maior que 8 MiB foi rejeitado por `Invalid compressed checkpoint header`.
A suíte também verifica que o bomb não chega a `_decompress`, limite de
32 MiB em disco, escrita com validação, reparo por backup e fallback v1 para
compressão excessiva. RD-01 registra separadamente o erro de script que esse
corpus principal não detectava.

[FATO] Sondagem exploratória adicional: `hydration="evil"`, `[]` ou `{}` em
saves v2/v3 é aceito e substituído por `Water.INITIAL` na migração
`sim_world.gd:1070`. Hidratação ainda não integrava esses schemas; NaN/inf são
rejeitados pelo filtro global. Arrays vazios de logs/episódios também são
válidos. Esses controles não foram contados como entradas inválidas no total
1616. [LACUNA] A validação não equivale a um schema universalmente fechado
para todos os campos de versões futuras adicionados a saves antigos.

## Release real e flags de captura

```powershell
& $G --headless --path . --export-release 'Windows Desktop' "$T/EvoWorld.exe"
$p = Start-Process -FilePath "$T/EvoWorld.exe" -WindowStyle Hidden -ArgumentList @('--headless','--quit-after','20') -Wait -PassThru -RedirectStandardOutput "$T/release_plain.log" -RedirectStandardError "$T/release_plain.err"
$p.ExitCode
$p = Start-Process -FilePath "$T/EvoWorld.exe" -WindowStyle Hidden -ArgumentList @('--headless','--quit-after','20','--',"--capture=$T/forbidden.png",'--fps-benchmark=30') -Wait -PassThru -RedirectStandardOutput "$T/release.log" -RedirectStandardError "$T/release.err"
$p.ExitCode
Test-Path -LiteralPath "$T/forbidden.png"
& $G --headless --path . -s "$T/flags.gd"
```

[FATO] Exportação **exit 0**. Execução release normal **exit 0**; execução
release com flags **exit 0**, `CAPTURE_EXISTS=False`. Ambas apresentaram
apenas o cabeçalho do Godot, sem `SCRIPT ERROR` ou stderr. A leitura de
`main.gd:114` confirma que a decisão usa `OS.is_debug_build()`; o teste direto
da guarda com `debug_build=false`, também coberto pela suíte, produziu:

```text
RELEASE_FLAG_GUARD { "path": "", "benchmark": false, "population": 12 }
```

[FATO] O binário exportado tem 109713328 bytes e SHA256
`6b4c7a3c88785ae7a97fc544f42049d60fc2e6c8d5c88b649fa19a7e49997f00`.
[LACUNA] São testes de inicialização headless e recusa de captura/benchmark;
não são validação gráfica sustentada nem medição de FPS do produto.

## Pré-registro, congelamento e resultado

[FATO] Foram executados `git merge-base --is-ancestor` entre cada etapa,
comparações de blobs nos quatro pontos e o comando exigido:

```powershell
git log -p -- tests/experiments/social_balanced_preregistro.md tests/experiments/m1_preregistro.md tests/experiments/m2_affect_preregistro.md tests/experiments/m2_curiosity_preregistro.md
python "$T/audit_data.py"
```

| Marco | Pré-registro → código congelado → primeiro resultado | Histórico do pré-registro até adce378 |
| --- | --- | --- |
| M0-B | `33bc81e` → `f7f90f4` → `0168096` | Só criação em `33bc81e` |
| M1 | `c8e9e91` → `99dd814` → `455deb9` | Só criação em `c8e9e91` |
| M1b | `52f7657` → `4d8a82a` → `300ffa4` | Só criação em `52f7657` |
| M2 | `f1a6349` → `ab5bc9f` → `49350ea` | Só criação em `f1a6349` |

[FATO] **Nenhum desses pré-registros foi editado depois dos resultados**;
`git log -p` mostra apenas suas adições iniciais. Os quatro blobs são iguais
no pré-registro, no congelamento, no resultado e no HEAD auditado.
`verify_prereg.sh` terminou exit 0, com `E3 PASS`, `E4 PASS`, `M1 PASS`,
`M2 PASS` e `M2 PASS prereg=f1a6349 evaluator=ab5bc9f result=49350ea seeds=24 rows=1008`.

[FATO] SHA256 dos protocolos canônicos UTF-8/LF, removendo BOM em M1b:

| Marco | SHA256 |
| --- | --- |
| M0-B | `5b7abeec4487671deffd7b8300d90a12c5916f478761861bc9f393e38574b106` |
| M1 | `4ccc451683f1e542131f1ad8aedd291e3e4b312cb51c88283cbc23556d9ccac3` |
| M1b | `375b6cdc194ec5eea5d65e422dd6799ba9b224ab62079852bc65a565917fbad7` |
| M2 | `f560da4498f9d35510f5d562e03b0c212546e42f9553559d42880089849ec19d` |

[FATO] Todos os hashes congelados de M1b conferem no pai do resultado;
todos os de M2 conferem no pai do resultado e no HEAD atual. Em M0-B,
runner/protocolo/fixture mantêm os blobs congelados até HEAD; os hashes
registrados usam bytes de arquivo, com CRLF para `social_fixture.gd` e LF
para os outros três. Essa diferença de fim de linha explica a diferença
entre hash bruto da fixture em Git/LF e o hash do checkpoint Windows.

[FATO] As guardas de abertura foram conferidas por leitura: marcador antes
dos ensaios e recusa quando o resultado já existe. Não foram invocadas para
reabrir holdout. [LACUNA] Git prova ordem/identidade de artefatos, não ausência
universal de execuções locais ocultas nem impossibilidade de apagar marcadores.

## Números dos relatórios e vazamento de partições

```powershell
python "$T/audit_data.py"
```

[FATO] Exit 0: `NUMERIC_AUDIT PASS; no experiment executed`. O cálculo usou
as linhas individuais de `x1`, `x2` e `rows`, sem chamar os `summarize()` dos
avaliadores. Recalculou médias, contrastes por seed, frequências, latências,
mudanças de contagens de ação e comparou agregados com tolerância de ponto
flutuante. Os valores abaixo reproduzem as tabelas dos relatórios.

| M1 X1, 200 ensaios | Contato A | Contato B | Diferença |
| --- | ---: | ---: | ---: |
| Completo | 80,708333% | 0,416667% | 80,291667 pp |
| Sem afeto | 100,000000% | 0,416667% | 99,583333 pp |
| Sem memória | 34,458333% | 4,937500% | 29,520833 pp |
| Aleatório | 16,916667% | 16,916667% | 0 pp |
| Fixo | 5,833333% | 5,833333% | 0 pp |

[FATO] M1 X2, 40 ensaios: pico de frustração completo 0,9724, liberação 0,
contribuição afetiva à valência −0,53482; maior mudança média de softmax
0,27214782 completo / 0,07662765 sem afeto. X1 sem afeto não remove o efeito;
X2 sem afeto não zera toda mudança de score. O relatório admite ambas as
limitações; não há discrepância numérica ou resgate oculto de resultado negativo.
Persistência exata e vizinho imóvel confirmados nas 200 linhas X1.

| M1b X1, 480 ensaios | Contraste afetivo | Contraste de memória |
| --- | ---: | ---: |
| Completo | 48,611111 pp | 48,611111 pp |
| Sem afeto | aproximadamente 0 pp | 97,222222 pp |
| Sem memória | 70,000000 pp | 0 pp |
| Sem ambos / aleatório / fixo | 0 pp | 0 pp |

[FATO] M1b X2, 160 ensaios: encurtamento 12 ticks em 20/20 pares completos
e sem memória; zero sem afeto/sem ambos. As contagens de ações diferem em
somente **4/20** pares completos, também 4/20 sem memória, zero nos demais
braços. Recuperação passa em 20/20 pares completos. Confirma-se a distinção
do relatório entre PASS de persistência e PARTIAL de estratégia física.
Persistência e vizinho imóvel confirmados nas 480 linhas X1b.

| M2, 24 seeds por célula, 1008 linhas | Novo | Habituado | Histórico neutro / aversivo | Entusiasmo / receio |
| --- | ---: | ---: | ---: | ---: |
| Completo | 24/24 | 0/24 | 24/24 / 0/24 | 24/24 / 0/24 |
| Sem memória | 24/24 | 24/24 | 24/24 / 24/24 | 24/24 / 24/24 |
| Sem afeto | 24/24 | 0/24 | 24/24 / 0/24 | 24/24 / 24/24 |
| Sem curiosidade | 0/24 | 0/24 | 0/24 / 0/24 | 0/24 / 0/24 |
| Aleatório | 7/24 | 7/24 | 7/24 / 7/24 | 7/24 / 7/24 |
| Sempre | 24/24 | 24/24 | 24/24 / 24/24 | 24/24 / 24/24 |
| Nunca | 0/24 | 0/24 | 0/24 / 0/24 | 0/24 / 0/24 |

[FATO] Latências censuradas: completo/novo 5; sem memória/receio 32,625;
aleatório 28,750 em todas as condições; ausências 36. H1–H6 passam com os
limiares publicados. Os 1008 round trips são verdadeiros nos registros;
os pares de histórico neutro/aversivo têm `initial_body` idêntico. O avaliador
M2 verifica igualdade imediata no load e prossegue pela cópia carregada;
não compara duas continuações paralelas em todos os 1008 ensaios. Continuação
pareada é coberta pela suíte; o teste independente abaixo verifica o
determinismo entre processos e o golden legado.

| Marco | TRAIN/DEV | HOLDOUT |
| --- | --- | --- |
| M0-B | 263101–263108 / 263201–263208 | 263901–263920 |
| M1 | 81001–81006, conjunto TRAIN/DEV compartilhado declarado | 82401–82420 |
| M1b | 93601–93604 / 93701–93706 | 94831–94850 |
| M2 | 106101–106104 / 106201–106206 | 107301–107324 |

[FATO] As 55 interseções entre esses 11 conjuntos são vazias. Seeds das
linhas brutas disponíveis conferem com as partições declaradas, incluindo
checkpoint TRAIN/DEV/HOLDOUT M0-B e TRAIN/DEV/HOLDOUT M1b/M2. O bruto DEV M1
é saída em `builds/` e não está versionado; seu intervalo foi conferido no
avaliador e no pré-registro. Mesmas seeds entre braços são pareamento deliberado.

[FATO] Leitura dos avaliadores mostra aquisição por seed, clones controlados,
ablação na avaliação e nenhum ajuste de produção pelo resultado carregado.
M0-B atualiza Q somente em TRAIN; `evaluate()` usa `learn=false` e verifica
checkpoint inalterado. Busca em `scripts/mind`, `scripts/world`,
`scripts/environment` não encontrou leitura de `reports/`, rótulos HOLDOUT
ou branches condicionados às seeds 82401–82420/94831–94850/107301–107324.
Objetos são percebidos por aparência/categoria, sem `tipo` oculto; a suíte
testa a indistinguibilidade antes do contato. Não foi identificado vazamento
train/holdout nesses caminhos.

[LACUNA] Desenvolvimento M1b/M2 conhece as limitações dos relatórios anteriores;
novos conjuntos disjuntos não apagam esse histórico de desenho experimental.
Seeds em geometria/traços fixos não são ecologias independentes. Os vetores
afetivos transplantados não isolam um único afeto; M1 varia temperamento e
experiência juntos. São limites declarados, não evidência de consciência ou
de generalização universal.

[FATO] Tabelas de CPU conferem com os JSON respectivos. Diferenças pet−off
recalculadas, em ms/tick, para 12/30/60[/100] criaturas:
M1 `+0,131812 / +0,251888 / +0,302992`;
M1b `+0,360310 / +0,181930 / −0,040497 / −1,583275`;
M2 `+0,146225 / +0,519235 / +0,689510 / −1,583165`.
Populações finais são iguais às iniciais; M2 registra 32 objetos.
[LACUNA] Os arquivos CPU conservam agregados, sem as 400 amostras individuais;
é possível conferir tabelas e diferenças, mas não recalcular os p95 do vetor
original. Não se executou benchmark novo nem se inferiu FPS gráfico.

## Determinismo e golden legado

```powershell
& $G --headless --path . -s "$T/determinism.gd" -- "$T/state_a.json"
& $G --headless --path . -s "$T/determinism.gd" -- "$T/state_b.json"
Get-FileHash "$T/state_a.json", "$T/state_b.json"
git log --oneline -- tests/experiments/m1_golden.json
```

[FATO] Dois processos independentes, exit 0, seeds de revisão 20261102 e
20261103, 12 criaturas, 300 ticks, objetos neutro/aversivo e dois escopos
(padrão só pet / todas as mentes) produziram estados completos iguais.
SHA256 dos dois arquivos concatenando os quatro estados:
`afab71895860b1ff56adb1f23306a7b8098bfa62bb982506033c2a19e6dc1b08`.

| Seed | Escopo | SHA256 do estado final |
| --- | --- | --- |
| 20261102 | Só pet | `9a16cabd85a7e60bdeb5952cecea5dbb0af6649e27377cdb616a5acb6864b388` |
| 20261102 | Todas | `e7430df70686e5aa5d643cc323eab4e3df92ddf7fdcedc4d3a44b3cb5ede8426` |
| 20261103 | Só pet | `2f2a68bb2a82c73759b8ed5c56a4a368b7dd16838316d1d4975c7f99069d4bf4` |
| 20261103 | Todas | `119df1c56a8b960d4c9fd22678ac9629770eb1eaba1ab37ac00e2964feea8081` |

[FATO] O harness também executou `_scope_and_golden()` de M1 nas duas
rodadas: `GOLDEN_100_TICKS failures=[]`. A fixture v7, com/sem E2, é comparada
por estado inteiro após 100 ticks. `m1_golden.json` tem só o commit de criação
`c8e9e91`; não foi regenerado. A suíte integral passou os hashes históricos
de `test_perf_determinism.gd`, `f271c2bd...e77b0` e `efcaad80...b9be9`, após
600 ticks, e a continuação pareada por 50 ticks. M1/M2 também passaram seus
round trips e continuação pareada próprios. Nenhum golden foi atualizado
para acomodar o resultado desta revisão.

## Integridade da entrega

```powershell
git diff --exit-code HEAD -- reports/*.json
```

[FATO] Exit 0. Uma segunda comparação de bytes de todos os JSON versionados
em `reports/` com `git show HEAD:<arquivo>`, normalizando apenas CRLF/LF,
também passou. Hashes dos resultados integrais LF conferidos com os relatórios:

| Resultado | SHA256 |
| --- | --- |
| M1 | `5f262cf19b85e0ff73a5158cb1ed8874af151595d53ef295516693592272f482` |
| M1b | `d639e7f3399489c8e1af213b986fcb7fa0d9cf32dfcc5917f4565d7b43a38ede` |
| M2 | `84c8c5b2ef61e9ae26f2cfc461565cd0117200125c56f2f29e83a3e1abde91c5` |

[LACUNA] Permanecem RD-01 a RD-04 para decisão/correção do coordenador;
não foram editados arquivos de produção, testes ou resultados neste despacho.
A revisão foi concluída com essas ressalvas, sem achados altos ou críticos.
