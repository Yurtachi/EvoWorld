# Revisão dinâmica independente — M3c (X6) e M4a/M4b (X7)

Revisor: independente, dinâmico (executou código; não escreveu os patches). Repositório `D:\Docs\Git\EvoWorld`, branch `evo3/integration`, HEAD revisado `5f13150`. Godot 4.7.2 console. Scripts descartáveis em `C:\tmp\evo_review\` (fora do repo); nenhum save do jogador foi tocado (hash de `user://saves/autosave.json[.bak]` idêntico antes e depois; os fuzzers usam `C:\tmp\evo_review\store*`). Avaliadores de holdout fechados não foram executados.

## Veredito de severidade

**Não há achado ALTO nem CRÍTICO.** Nenhuma execução de processo/arquivo/rede a partir do terminal fictício, nenhum save hostil aceito com NaN/INF/tipo errado/ID duplicado entre registros, nenhum módulo cognitivo escreve corpo, nenhuma violação de ordem pré-registro→motor→holdout. Há 3 achados **médios** (validade científica das alegações X6/X7 e fraqueza de apresentação) e vários **baixos**.

| # | Sev. | Resumo |
|---|------|--------|
| F1 | média | X7: braço "sem memória" é um espantalho (sempre `OLHAR`, 0/576 por construção) |
| F2 | média | X7: as 24 verificações H-d/H-f são idênticas (n efetivo = 1), "24/24" não é evidência independente; H-e é confundido |
| F3 | média | X6: "ler livro" é uma regra direta (valor numérico do livro vira termo de utilidade); H-a 24/24 é consequência determinista |
| F4 | baixa | SCRIPT ERROR em validação de save com tipo errado (4 locais), save é recusado mas o log registra erro |
| F5 | baixa | Terminal sem texto pt-BR: ações/objetivo/razão caem em fallbacks enganosos; terminal não é alcançável pela UI |
| F6 | baixa | Chaves desconhecidas são aceitas e silenciosamente descartadas em dicionários do núcleo legado |
| F7 | baixa | 52 `.uid` não rastreados: qualquer execução do Godot suja a worktree |
| F8 | baixa | Veredito do relatório X7 ("FAIL global") difere do JSON ("PARTIAL"); H-a também falhou |
| F9 | info | Exceção documentada das 3 correções pós-holdout: considero **aceitável** (ver seção 4) |

---

## 1. Suíte completa e pré-registro

```
godot --headless --path . -s tests/run_tests.gd   -> 24 suítes "ok", exit=0, 0 SCRIPT ERROR (grep ERROR vazio)
bash tests/experiments/verify_prereg.sh            -> exit 0
  M3c PASS prereg_commit=4eb4050 ... evaluator_commit=6e0584f... result_commit=10fb22b...
  X6 INTEGRITY PASS scientific=PASS
  M4b PASS prereg_commit=d9b57a1 ... evaluator_commit=f8ec992... result_commit=5de92a7...
  M4b PASS historical prereg=d9b57a1 freeze=810cc85 result=5de92a7 seeds=24 rows=2880 scientific_verdict=PARTIAL
  X5 INTEGRITY PASS ... scientific=FAIL
```
Após as execuções, `git status` só mostrava `.uid` não rastreados (F7); nenhum `reports/*.json` foi regravado.

## 2. Fuzz de saves hostis (v1..v13) — scripts `build.gd`, `fuzz.gd`, `fuzz2.gd`

Mundos-base v13 construídos por mim (3 variantes: terminal+marcador+livro+quadro+objeto+glifo; pergunta pendente+fatos de cuidador/observado+2 glifos+sessão ativa; leitura em andamento). Comando: `godot --headless --path . -s C:/tmp/evo_review/fuzz.gd -- <0|1|2> leaf`.

* **Mutação folha por folha** (todas as 1185/234/341 trilhas × 14–17 mutações: NaN, ±INF, string, string de 5000, null, `[]`, `{}`, true, 1e300, int64 máx, -1, 0, delete, resize 100001, self-dup): 17200 + 3437 + 4979 = **25616 mutações**.
  * **NaN, ±INF, 1e300, int64 máx, string longa, resize 100001: 0 aceitações.**
  * Aceitas (1544) são todas semanticamente válidas: zero/negativo em campos assinados, listas esvaziadas, deleção de `conhecidos.REPETIR`, flags booleanas, `name`/`last_action`/`last_reason` com string curta. Cada aceitação foi seguida de 8 `step()` sem SCRIPT ERROR e sem IDs duplicados (`dupids=` vazio em todas).
* **IDs duplicados entre todos os registros** (`fuzz.gd -- N ids`): 17+14+9 campos de ID/referência (criaturas, genoma, comida, água, objetos, livros, quadros, terminais, marcadores, pergunta, leitura) permutados par a par = 454 colisões. Oráculo próprio (varredura dos registros do mundo carregado): **0 mundos com ID duplicado**. As únicas aceitações são referências (`mind.objects.target`, `knowledge.next_id`, `boards[].owner_id` = ID de criatura), legítimas.
* **Chaves longas / muitas chaves** (`fuzz2.gd -- keys`, 1750 casos: chave 100000 chars, 5000 chaves, chave vazia, unicode com U+202E/NUL, chave numérica gigante em todo dicionário): chave longa e 5000 chaves rejeitadas em todos; **aceitas e descartadas** chave vazia/unicode/numérica apenas em dicionários do núcleo legado (F6). Terminal, conhecimento, biblioteca e marcadores são estritos (contagem de chaves).
* **Histórico enorme**: `tentativas`, `outcomes`, `facts`, `terminals`, `terminal_markers`, `library.books` com 100001 itens: 0 aceitos.
* **Versões v1..v13** (`fuzz2.gd -- versions`): cada versão com todas as chaves de topo × {NaN, "x", null, delete, [], -1, int64} + injeção de campos futuros (`terminals`, `terminal_markers`, `library`, `boards`, `objects`, `mind.terminal`, `mind.knowledge`). v1–v11: `terminals`, `terminal_markers`, `library`, `boards`, `objects`, `mind.terminal`, `mind.knowledge` injetados = recusados; v12 recusa `terminals`, `terminal_markers`, `mind.terminal` e aceita (legitimamente) `library/boards/objects/knowledge`, que já existem em v12. 0 SCRIPT ERROR no modo versions. Observação: `gallery: []` (vazio) injetado em v1..v11 é aceito, inócuo.
* **Gzip bomb / envelope** (`fuzz2.gd -- bomb`, `SaveStore` em `C:\tmp\evo_review\store`): 8 MiB de zeros declarado correto (razão > 64:1) → "exceeds the 64:1 expansion limit" em 7 ms; 200 MiB reais declarados 8 MiB → "Invalid compressed checkpoint size or header" 32 ms; declarado 200 MiB / int64 máx / 1000 → recusados (7–10 ms); gzip corrompido, JSON aninhado 100k/20k, payload v1 > 8 MiB (124 ms), literal `NaN`, arquivo truncado, lixo após o JSON: todos recusados com mensagem correta, sem alocação grande.
* **Programa longo/aninhado via API**: `terminal_start` com programa válido de 124–250 caracteres inicia, faz round trip JSON e `SaveStore.save_world` ok (inclusive após 12 `terminal_step`).

### F4 (baixa) — SCRIPT ERROR com tipo errado, save recusado mas com erro no log
Comando: `godot --headless --path . -s C:/tmp/evo_review/fuzz.gd -- 0 leaf` (e `-- 1 leaf`). Saída real:
```
MUT|0|library/version|arr   SCRIPT ERROR: Invalid operands 'Array' and 'int' in operator '!='.  at: from_dict (res://scripts/world/sim_world.gd:1400)
   (idem dict, str, true)
MUT|0|creatures/0/mind/terminal/state/conhecidos/OLHAR|arr   ... 'Array' and 'String' ... at: valid (res://scripts/terminal/terminal_estado.gd:84)
   (idem para AJUDA; arr, dict, neg, true, zero)
MUT|0|creatures/0/mind/terminal/state/conhecidos/REPETIR|arr  ... at: valid (res://scripts/terminal/terminal_estado.gd:96)
   (idem dict, neg, true, zero; também MOVER/MARCAR/LER/DESENHAR seguem o mesmo ramo)
MUT|1|creatures/0/mind/knowledge/questions/0/goal|arr   ... at: valid (res://scripts/library/knowledge.gd:147)
   (idem para text_key; arr, dict, neg, true, zero)
```
Causa: comparação `!=` entre Variant de tipo errado e `String`/`int` antes de checar o tipo. Efeito: `from_dict` devolve `null` (save recusado; 0 aceitações), porém imprime SCRIPT ERROR (e para no depurador no editor). Contradiz a alegação "zero SCRIPT ERROR" para saves hostis (o corpus do repo não cobre esses tipos). Correção sugerida: `typeof(x) == TYPE_STRING and x == ...` antes da comparação (ou `is String`). Locais: `scripts/world/sim_world.gd:1400`, `scripts/terminal/terminal_estado.gd:84,96`, `scripts/library/knowledge.gd:147`.

### F6 (baixa) — chaves desconhecidas aceitas e descartadas no núcleo
`MUT|*|<raiz>|extra_key`/`emptykey`/`unicodekey`/`numkey` aceitos em: raiz do mundo, `rng_state`, `creatures/N`, `creatures/N/genome`, `genealogy/N/genome`, `config`, `foods/N`, `obstacles/N`. O mundo recarregado, ao salvar, não contém a chave (normaliza), então não há dado oculto persistindo; porém é inconsistente com a rigidez de terminal/conhecimento/biblioteca (que recusam). Sem impacto de segurança observado.

## 3. Ataque ao terminal fictício e ao adaptador do mundo — `attack.gd`

Comando: `godot --headless --path . -s C:/tmp/evo_review/attack.gd`. 306 programas hostis × `Terminal.execute` com `terminal_mundo_falso` (contadores) e estado com todos os 7 comandos conhecidos, mais 21 fontes de tipo estranho, mais o caminho real `SimWorld.terminal_start` com adaptador real.

Corpus: `; rm -rf /`, `&& rm -rf /`, `| cat /etc/passwd`, `` `whoami` ``, `$(whoami)`, redirecionamento `> canary.txt`, `powershell -c ...`, `cmd /c ...`, `del /f /s /q C:/*`, path traversal (`../../../etc/passwd`, `../../Windows/System32`), `file:///`, `http://`, `https://`, `import os; os.system`, `__import__`, `OS.execute/shell_open/create_process`, `FileAccess.open`, `DirAccess.remove_absolute`, `HTTPRequest`, `Expression`, `JavaScriptBridge`, `load/preload`, `${IFS}`, `%COMSPEC%`, `{{7*7}}`, `[url]`/`[b]` BBCode; cada um como programa isolado, sufixo após `OLHAR`, em nova linha, em argumento de `MARCAR`, dentro de `REPETIR { }`, e como argumento de `LER`. Mais: homóglifos (`ОLHAR` cirílico, `OLHАR`, `ＯＬＨＡＲ` largura plena, U+200B, U+202E, U+00A0, U+2028, dígitos árabe-índicos e largura plena em argumentos), maiúsculas/minúsculas, `MOVER NORTE 08`, `-0`, `1e1`, `0x10`, `REPETIR 999999999`, `REPETIR 16{16{16{16{}}}}` (custo), 5 níveis de REPETIR, comando de 1e6 caracteres (`OLHAR`×1e6, `A`×1e6, `OLHAR\n`×2e5, `REPETIR 2 { `×1e5, 1e6 espaços + OLHAR), limites 128/129 e 64/65 linhas, e `PackedByteArray` com NUL (`OLHAR\0; rm`, `[0]`, bytes > 127, vazio). NUL em `String` é truncado pelo próprio Godot (aviso "Unexpected NUL character") antes de chegar ao parser; NUL só chega por `PackedByteArray`, e é recusado em `terminal_parser.gd` (`byte == 0 or byte > 127`).

Resultado real:
```
ATK total=306 aceitos=5 rejeitados=301 violacoes=0 max_us=2024
CODES { simbolo:249, comando:7, sintaxe:11, argumento:19, "":5(ok), passos:2, limite:5, entrada:8 }
ODD ... (null,int,float,NaN,INF,bool,Array,Dictionary,StringName,PackedStringArray,Vector2,Callable,Object): ok=false calls=0
ODD PackedByteArray [79,76,72,65,82]  ok=true calls=1   (ASCII puro "OLHAR": aceito por desenho)
WORLD aceitos=0 corpo/marcadores/ids intactos=true
PROCS antes={powershell.exe:9, cmd.exe:1, bash.exe:2} depois={igual} iguais=true
DIRS iguais=true canary_existe=false
```
* Todos os 5 aceitos são exclusivamente do alfabeto `[A-Za-z0-9_- espaço \t \n \r { }]` (verificado programaticamente; nenhum aceito contém caractere fora dele) e todos rejeitados deram **0 chamadas** ao adaptador (`total_calls()==0`; `forbidden_calls` processos/arquivos/rede = 0).
* Pior tempo: 2,0 ms para entrada de 1e6 caracteres (o limite de 4096 caracteres é checado antes de varrer).
* Mundo real: após todos os 300 programas hostis ≤ 5000 chars, corpo (pos/energia/hidratação), `terminal_markers`, `terminals`, `next_id`, comidas, águas, objetos e quadros ficaram idênticos.
* Prova independente de não-efeito: contagem de processos `cmd/powershell/whoami/calc/notepad/curl/pwsh/bash` via `tasklist` antes/depois, hash de listagem de `res://scripts`, `res://tests`, `user://` e pasta temporária antes/depois, e arquivo-canário `C:/tmp/evo_review/canary.txt` (alvo de vários payloads de redirecionamento) inexistente.
* **Varredura estática de APIs proibidas** (`rg` sobre `scripts/`): `OS.execute|shell_open|create_process|create_instance|kill|get_environment`, `HTTPRequest|HTTPClient`, `TCPServer|StreamPeer|PacketPeer|UDPServer|WebSocket|ENet`, `Expression`, `JavaScriptBridge`, `ClassDB`, `set_script`, `GDScript.new`, `.call(`/`callv`, `Thread|Mutex`: **zero ocorrências em `scripts/terminal`, `scripts/library`, `scripts/mind`, `scripts/world`**. Fora do terminal, só `scripts/persistence/save_store.gd` (FileAccess/DirAccess em `user://saves`) e `scripts/ui/main.gd`/`verify_ui.gd` usam arquivos (esperado). Único `load()` em `scripts/terminal` é `terminal_estado.gd:129`, caminho literal para si mesmo.
* Nenhum campo de UI recebe programa do jogador: `grep -i terminal scripts/ui` e `scripts/communication` = vazio; as únicas fontes de string de programa são `TerminalLearning.candidates()` (interno) e dados de save (validados: `active.instructions` precisa coincidir com nova análise do programa). As cadeias aceitas em `tentativas.comando` são texto opaco (32–126), nunca executado; não há `RichTextLabel` com `bbcode_enabled` em `scripts/ui`.

## 4. Ordem pré-registro → motor → holdout (git log/show)

| Exp. | pré-registro | motor/avaliador | resultado (holdout) |
|---|---|---|---|
| X6 | `4eb4050` 06:10:01 (só `m3c_biblioteca_preregistro.md`, +24) | `6e0584f` 06:20:15 (motor + `m3c_biblioteca_eval.gd` + verify) | `10fb22b` 06:25:02 (só `reports/M3c_*`) |
| X7 | `d9b57a1` 06:31:19 (só `m4b_terminal_preregistro.md`, +52) | `f8ec992` 06:54:54 (motor + avaliador + `m4b_freeze.json`), congelamento corrigido em `810cc85` 06:57:43 (BOM) | `5de92a7` 07:03:11 (só `reports/M4b_terminal_{eval,cpu}.json`) |

* `git log --format=... -- <prereg/eval/verify/freeze/JSON>` mostra que **nenhum arquivo de pré-registro foi editado depois de criado** (`m3c_biblioteca_preregistro.md` e `m4b_terminal_preregistro.md` aparecem em um único commit cada) e que os avaliadores X6/X7 só mudaram **antes** do resultado (`6e0584f`; `f8ec992`, `810cc85`). Os JSON de resultado aparecem em um único commit (`10fb22b`, `5de92a7`) e não foram alterados depois. `m4b_freeze.json` lista 80 arquivos com `preregister_commit=d9b57a1`; `frozen_commit` gravado no JSON de resultado = `810cc856...` (o commit da correção de BOM, imediatamente anterior ao holdout).
* Ressalvas: (a) no X6 motor e avaliador entram no mesmo commit, então não há momento "avaliador congelado, motor ainda livre" (aceitável: ainda anterior ao resultado); (b) a guarda `verify_prereg.sh` prova hash do protocolo e ancestralidade, não prova ausência de execuções ocultas (o relatório reconhece em `[LACUNA]`); (c) em X7 a primeira invocação `--holdout` foi recusada pelo hash por causa de BOM, o que é consistente com o relato e com o diff de `810cc85` (`canonical_sha`).

### F9 — Exceção documentada: 3 correções de save após o holdout (`0046e5a`, 07:12:04)
Mudanças em `scripts/world/sim_world.gd`: (1) `terminal_start` descarta chaves de `tabela` > 128 chars de programas **recusados**; (2) marcador: reconstrução float32 `pos == dispositivo + Vector2(offset arredondado)` no lugar de `delta == floor(delta)`; (3) IDs de artefatos entram em `used_ids` antes de restaurar terminais. Todas atuam só em `from_dict`/ramo de erro; nenhuma toca `step()`, `terminal_move/draw/mark`, `TerminalLearning`, sensores, custo ou RNG.

Verificação dinâmica: extraí `810cc85` (motor congelado do holdout) com `git archive` para `C:\tmp\evo_review\old` e rodei `det.gd` (11 seeds incl. `154101,154102,154201-154206,154301,140201,140202`, mundo com terminal+livro+cápsula+quadro, 500 ticks, SHA-256 do `to_dict` a cada 100 ticks) nos dois códigos:
```
diff /tmp/det_old.txt /tmp/det_new.txt  -> idêntico (OLD==NEW)
diff det_new.txt det_new2.txt            -> idêntico (HEAD duas vezes, NEW==NEW2)
```
Conclusão: as correções não mudam política nem física de estados válidos (trajetórias idênticas bit a bit nos cenários testados) e relaxam a rejeição somente de marcadores fracionários realmente válidos, endurecendo a de colisão de IDs. A classificação do relatório (exceção explícita, motor final sem novo holdout, rebaixamento conservador) é honesta. Risco residual: o holdout não cobre os caminhos modificados; a equivalência foi mostrada por mim em 11 seeds, não exaustivamente.

## 5. Alegações dos relatórios contra os JSON brutos

### M3c (`reports/M3c_biblioteca_eval.json`, recomputado com python)
Todos os números conferem: 24 seeds `140401..140424` (distintas), 4 braços × 24.
* H-a: contatos==0 na 1ª prova — verdadeiro 24/24; sem_livro 0/24; enganoso 0/24; sem_memoria 0/24 (flag `avoided` consistente com `contacts`). ✔
* H-b: enganoso 24/24 contato real; confiança fato e fonte 0,80 → 0,35 (queda 0,45); 2ª cápsula evitada 24/24. ✔ Mas **sem_livro também evita 24/24 na 2ª prova** e investiga 24/24 na 1ª: a "convergência" é apenas efeito da experiência, não do livro.
* H-c: 24 perguntas em 1152 ticks (0,020833); `conhecido` e `sem_lacuna` = 0; controle aleatório: 4 perguntas em 3/24 seeds (0,003472). ✔
* H-d: aceito e retido 24/24, fonte `cuidador`, confiança 0,5135–0,6335. ✔
* H-e: sem_memoria 0/24 evitaram, `facts_after` vazio nas 24; diferença para sem_livro 0,00. ✔
* Leitura 16 ticks (verdadeiro) e 8 (enganoso); aproximação 7–10 ticks. ✔ Glifos: 48/48 acertos nos ensinados, 24/24 desconhecido rejeitado. ✔
* Seeds: TRAIN `140101-04`, DEV `140201-06`, holdout `140401-24`; testes unitários usam `140010-14`/`140050`; nenhum teste referencia seeds do holdout (grep só encontra os avaliadores/verificadores).

### F3 (média) — classificação honesta de "ler livro" no X6
É uma **regra direta**, não aprendizado de evitar categoria: `scripts/library/book_catalog.gd` fixa `guia_capsulas = [{"capsula": -1.0}, {"pedra": 0.0}]`; `reading.gd:page_tick` copia esse valor para um fato (`confianca 0.8`); `knowledge.gd:expectation` pondera por confiança e `object_memory.gd:34` o usa como termo de utilidade de investigação. Valor negativo para a categoria ⇒ o objetivo `investigar_objeto` perde para outras ações ⇒ "evita" (no JSON: 0 ticks `investigate_object` em verdadeiro; 24/24 em sem_livro). O resultado 24/24 vs 0/24 é consequência determinista dessa regra (sem variação entre seeds além de temperamento/distância), não evidência de compreensão de texto nem de generalização. "Evitar" significa não executar a interação aversiva (o relatório admite que não mede distância). O relatório já nega compreensão/linguagem, mas o rótulo "PASS" de H-a/H-e mede verificação de que um número do catálogo é lido; a parte genuinamente dinâmica é só a correção por experiência (H-b: fato e fonte caem 0,45) — e ela também é uma regra codificada (−0,45, piso 0,05). Glifos: busca em dicionário `glifo→categoria` com ID já discretizado; 48/48 é recuperação, não classificação.

### M4b (`reports/M4b_terminal_eval.json`)
Números conferem: 2880 linhas, 24 seeds `154401..154424`, taxas completo 504/576 (0,875), sem_ensino 456/576 (0,7917), aleatório 194/576 (0,3368), fixo/servo 576/576 (1,0), sem_memória 0/576; 1150 erros `objetivo` e 1730 `""`. H-a ganho 8,33 pp (aquisição 16,67 pp) < 20 pp: **falhou** ✔. H-b 24/24 novo alvo ✔ (mas `sem_ensino` e `fixo` também 144/144: não discrimina). H-c falha porque fixo ≥ completo ✔.

**Confirmado: o programa fixo/servo vence o completo** (576/576 contra 504/576; na aquisição 288/288 contra 216/288, 0 erros contra 72; nas fases de avaliação ambos 144/144). O "completo" é, por construção (`terminal_learning.gd:54-86`), o próprio gabarito geométrico (`MARCAR x y; MOVER dir n; MOVER dir n`) entre ~9 candidatos, mais exploração; o ganho de aprender é só descartar `OLHAR`/`AJUDA`/`MOVER` sozinhos nas 3 primeiras tentativas (sucesso por tentativa de aquisição `[0,0,0,24,24,...]`, idêntico em todas as seeds). O relatório afirma isso corretamente.

### F1 (média) — "sem memória" é espantalho
`m4b_terminal_eval.gd:117` apaga `table` antes de cada escolha; com `table = {}` todas as pontuações empatam e `choose()` (comparação `>` estrita) devolve o 1º candidato, `OLHAR`: `Counter(program)` no JSON = `OLHAR: 576` (100%), sucesso 0/576 garantido por construção. A comparação "completo supera sem memória por ≥0,10" em H-c é vácua; o relatório mostra o 0% na tabela sem alertar.

### F2 (média) — verificações H-d/H-f sem independência; H-e confundido
* `checks` tem 24 linhas, **1 valor distinto**: `score_before=0.8080880229039762`, `score_after=0.6154700538379252`, `choice_before="MARCAR 3 0\nMOVER LESTE 3"`, `choice_after="OLHAR"` em todas (o `scenario` não varia a geometria usada em `checks`, que sempre usa alvo (3,0)). "24/24" é n efetivo = 1. A "mudança" após o erro é para `OLHAR`, programa que nunca cumpre o objetivo; o relatório diz "sem repetição imediata" e "não demonstra planejamento".
* H-e (`m4b_terminal_eval.gd:206-211`): o par usa `studio(seed, 0.0)` (curiosidade 0). Com curiosidade < 0,15 e tédio < 0,5 `TerminalLearning.candidate` já devolve score −4 (`terminal_learning.gd:~28`), então o terminal seria ignorado mesmo sem `terminal_refuse`; o teste não isola a recusa.
* Em H-b/avaliação o protocolo pareia seeds, mas a variação entre seeds é só distância/posição (o relatório reconhece "não representa nova família").

### F8 (baixa) — rótulo de veredito
`summary.verdict = "PARTIAL"` no JSON e `hypotheses = {H-a:false, H-b:true, H-c:false, H-d:true, H-e:true, H-f:true}`. O pré-registro define PARTIAL como "desempenho restrito mas **H-c** falha"; aqui H-a **também** falha, o que o texto do protocolo não prevê. O relatório rebaixa para "FAIL global" por integridade de save; é conservador e documentado, mas difere do campo do JSON (que não foi reescrito). O commit `5f13150` diz "X7 FAIL global documentado".

### Seeds disjuntas e vazamento
Holdouts: X4 `118401-24`, X5 `129401-24`, X6 `140401-24`, X7 `154401-24` (todas distintas; `python` comparou todos os `reports/*_eval.json` par a par: **0 interseções**, inclusive E3, E4, M1, M1b, M2 e M0_social). TRAIN/DEV por experimento em faixas próprias (`X6 140101-04/140201-06`, `X7 154101-04/154201-06`). Nenhum teste/avaliador alheio referencia seeds `…401-424`. Observação: `checks` usa `seed+10000` para retenção (`164401…`), sem colisão. Sem vazamento treino/holdout observado; o ressalvado: seeds novas no mesmo gerador de cenário não são famílias novas.

## 6. Corpo intocado pelos módulos cognitivos e determinismo

* Estático: `rg "\.energy|\.hydration|\.pos\b|heading"` em `scripts/library`, `scripts/mind/terminal_learning.gd`, `scripts/terminal`, `scripts/mind/object_memory.gd`, `motivation.gd` → só leituras (`knowledge.gd:48` e `object_memory.gd:95` leem `evidence.energy/hydration`, evidência medida; `terminal_learning.gd:31` lê `pos`). As únicas escritas de corpo no terminal estão em `sim_world.gd:1034-1035` (`terminal_move`: posição varrida + custo), `:1045` (`terminal_draw`), `:1067` e `:1121` (custo fixo 0,004).
* Dinâmico (`body.gd`): 20 chamadas (`K.add/demonstrate/gap/maintain/outcome/expectation`, `Reading.page_tick/candidate`, `responder_pergunta`, `demonstrar_simbolo`, `L.feedback/choose/candidate`, `terminal_set_task/refuse/snapshot/observe/read/mark`, `Terminal.execute` com mundo falso): `[pos, energia, hidratação, heading, idade]` iguais antes/depois em **20/20**.
* Determinismo: mesma seed duas vezes, 400 ticks com livro+cápsula+terminal: SHA-256 do `to_dict` idêntico (`21eee3ba0dc7890c…`), seed diferente → hash diferente; 11 seeds × 500 ticks idênticos entre execuções (`det_new` = `det_new2`).

## 7. Exportação release

```
godot --headless --path . --export-release "Windows Desktop" C:/tmp/evo_review/exp/EvoWorld.exe   -> EvoWorld.exe 109 873 168 bytes, "[ DONE ] savepack"
cd C:/tmp/evo_review/exp && ./EvoWorld.exe --quit-after 300  -> exit=0; saída: 3 linhas (versão Godot, OpenGL 3.3 NVIDIA RTX 2050 Compatibility); 0 ocorrências de "ERROR"/"SCRIPT ERROR"
```
O jogo autossalva em `user://saves/autosave.json`; o arquivo pré-existente tinha hash `f48cd260…` e `.bak` `988056f9…`, idênticos após a execução. Obs.: `user://saves/ui_test_*` (deixados por `verify_ui.gd`) misturam resíduos de teste com a pasta de saves do jogador (baixo).

## 8. Texto em inglês visível ao jogador

`rg` por literais com palavras inglesas em `scripts/ui`, `scripts/render`, `scripts/main.gd` e `scenes/*.tscn`: nenhum literal visível em inglês (únicas ocorrências são lógica, `print` e `verify_ui.gd`). Mensagens do `SaveStore` em inglês passam por `Texto.mensagem()` (`main.gd:771,773,789`): chequei as 32 mensagens `_error(...)` — todas viram pt-BR (as sem mapeamento específico caem em "Não foi possível concluir a operação de salvamento ou carregamento.").

### F5 (baixa) — terminal sem textos de jogador e inalcançável pela UI
```
Texto.acao("use_terminal") / "seek_terminal" / "read_terminal_manual" -> "Ação não reconhecida"
Texto.mente_desejo("usar_terminal")                                    -> "O desejo aparece após iniciar a simulação."  (fallback m1_wait, enganoso)
Texto.mente_motivo("mind.iniciativa.terminal")                         -> "Razão não disponível nesta versão."
Texto.texto("library.question.unknown")                                -> "Texto indisponível."
```
(`scripts/core/textos.gd:275,810,474,892`; goal em `scripts/mind/motivation.gd:5`.) Não há inglês, mas o jogador veria rótulos genéricos/enganosos se uma criatura usasse um terminal. Hoje nada na UI chama `place_terminal` e não há campo de entrada de programa: o terminal só existe por API/testes/saves. O relatório M4b declara essa pendência. `library.question.unknown` (o `text_key` do evento) não existe em `Textos`, mas a UI de perguntas usa chaves próprias `m3c_question_*`/`m3c_answer_*` (`scripts/ui/main.gd:319-328`), então o jogador não é afetado.

### F7 (baixa) — `.uid` não rastreados
Após rodar testes/exportar, `git status` listou 52 `*.uid` novos (ex.: `scripts/library/knowledge.gd.uid`, `scripts/mind/terminal_learning.gd.uid`) enquanto 62 `.uid` estão rastreados. Removi só esses 52 arquivos gerados (nenhum `git clean`) para restaurar a worktree limpa. Recomenda-se commitar os `.uid` ou ignorá-los de forma consistente.

## 9. Resumo do que foi executado
`tests/run_tests.gd` (24 ok), `verify_prereg.sh` (PASS), fuzz 25616 mutações + 454 colisões de ID + 1750 chaves hostis + 13 versões + 12 cenários de envelope/gzip, 306+21 ataques ao terminal com contadores/tasklist/canário, varredura de APIs proibidas, equivalência 810cc85 × HEAD (11 seeds × 500 ticks), checagem de corpo em 20 chamadas, determinismo, export release + execução `--quit-after 300`, auditoria de textos. Limitação: o fuzz usa três mundos-base meus e mutações unitárias (não combinatórias); os avaliadores de holdout não foram reexecutados, então as alegações numéricas foram verificadas contra os JSON brutos e não por reprodução.
