# M4a — terminal fictício E3.6, catálogo v1

[FATO] Base `evo3/integration` @ `73a9cc6`, branch local `Yurtachi/evo3-m4a`.
Implementação própria em GDScript, sem código externo ou GPL. O módulo é
`RefCounted`: não consulta criaturas, corpo, mundo físico, persistência mundial
ou UI. Os únicos arquivos modificados pertencem ao escopo do despacho.

## Linguagem e catálogo

[FATO] `terminal_catalogo.gd` define `VERSION = 1`; programa analisado, resultado
e estado serializado incluem `versao`. A versão do estado deve ser exatamente
1; versões futuras são recusadas, sem migração implícita.

```ebnf
programa = espacos, instrucao, { nova_linha, instrucao }, espacos ;
instrucao = "OLHAR" | "AJUDA"
          | "MARCAR", espaco, inteiro, espaco, inteiro
          | "MOVER", espaco, direcao, espaco, inteiro
          | "DESENHAR", espaco, forma
          | "LER", espaco, livro
          | "REPETIR", espaco, inteiro, espacos, "{", bloco, "}" ;
bloco = espacos, instrucao, { nova_linha, instrucao }, espacos ;
direcao = "NORTE" | "SUL" | "LESTE" | "OESTE" ;
forma = "LINHA" | "CIRCULO" | "QUADRADO" ;
livro = "livro_desenho" | "livro_repeticao" | "mapa" ;
inteiro = [ "-" ], digito, { digito } ;
```

[FATO] Espaço e tabulação separam tokens; LF separa instruções, CR é ignorado
como espaço para aceitar CRLF. Chaves também separam tokens. Linhas vazias e
espaços antes/depois são aceitos. Comandos são maiúsculos e sensíveis a caixa;
IDs de livro são minúsculos. Não há aspas, strings livres, comentários,
variáveis, expressões, caminhos, URLs ou escape. Apenas ASCII pode entrar no
tokenizador; as mensagens de resultado permanecem em pt-BR. O parser constrói
AST própria; a API de execução nunca recebe AST produzida pelo chamador.

| Comando | Aridade e domínio | Efeito virtual |
| --- | --- | --- |
| OLHAR | 0 | Consulta posição virtual, quando disponível. |
| MARCAR | 2 inteiros, cada um entre -64 e 64 | Marca coordenada. |
| MOVER | direção enumerada e inteiro 1–8 | Solicita deslocamento ao adaptador. |
| DESENHAR | 1 forma enumerada | Solicita forma. |
| REPETIR | inteiro 1–16 e bloco não vazio | Executa bloco limitado. |
| AJUDA | 0 | Descobre próximo comando da trilha de ajuda. |
| LER | 1 ID enumerado | Consulta objeto virtual; pode descobrir comando. |

[FATO] Limites globais: 4096 caracteres/bytes de entrada, 32 caracteres por
token, 512 tokens, 64 nós AST, quatro níveis de REPETIR, 128 passos expandidos
e 50000 microssegundos por execução. Cada nó executado custa um passo,
inclusive REPETIR. O custo é somado/multiplicado com saturação antes de executar;
nenhuma expansão de lista proporcional à repetição é alocada. Orçamentos menores
podem ser fornecidos pelo chamador; valores maiores são recusados. Prazo zero
serve para recusa determinística antes da primeira ação.

## Fronteira de segurança e execução

[FATO] `execute(source, adapter, state, tick, step_budget, time_budget_usec)`
aceita String ou PackedByteArray ASCII. Para bytes, tamanho, NUL e bytes acima
de 127 são verificados antes de decodificar. No Godot 4.7.2, construir String
com NUL já substitui esse caractere por U+FFFD e gera diagnóstico do motor;
os testes usam bytes com zero explícito e uma string com U+FFFD para cobrir
as duas fronteiras sem depender de um NUL que o motor não conserva.

[FATO] Sintaxe, tipos, custo total e todos os comandos conhecidos são
verificados antes de qualquer chamada virtual. Um prefixo válido seguido de
entrada hostil não produz ação. O primeiro erro de adaptador ou prazo encerra
a sequência, preservando os eventos já concluídos. Não há rollback de ações
virtuais já aceitas. Reentrada na mesma instância é recusada. Eventos retornam
comando, argumentos validados, resultado de catálogo, posição validada e
eventual comando descoberto; outros dados fornecidos pelo adaptador são
descartados. Falhas não reproduzem conteúdo hostil como mensagem de jogador.

[FATO] `terminal_mundo.gd` é a interface abstrata por implementação padrão
recusada: `olhar()->Dictionary`, `marcar(Vector2i)->Dictionary`,
`mover(String,int)->Dictionary`, `desenhar(String)->Dictionary`,
`ler(String)->Dictionary`. Cada retorno exige `ok` booleano. O adaptador falso
conta chamadas, mantém posição/marcas/desenhos em memória e permite recusar
ações. Os contadores de processos/arquivos/rede permanecem zero em todo o corpus.

[FATO] O teste varre recursivamente **todos** os `.gd` de `scripts/terminal`
e falha se encontrar `FileAccess`, `DirAccess`, `OS.`, `HTTPRequest`,
`HTTPClient`, `StreamPeer`, `PacketPeer`, `TCPServer`, `UDPServer`,
`Expression`, `JavaScriptBridge`, `Engine.`, `ClassDB`, `eval(`,
`get_tree(`, `callv(` ou `.call(`. O scanner, que precisa ler o código-fonte,
fica exclusivamente nos testes. O módulo usa recursos GDScript fixos via
preload/load e o relógio monotônico `Time` para orçamento; não recebe nomes
de recursos do programa.

[LACUNA] O adaptador é código confiável fornecido pelo integrador, não um
sandbox de código GDScript arbitrário. O prazo é cooperativo: é verificado
entre ações e após cada chamada; não interrompe uma função de adaptador que
bloqueie. M4b deve garantir ações pequenas, síncronas e sem acesso externo.
Os limites determinísticos de passos continuam ativos independentemente do
relógio. Os contadores mais a varredura demonstram o comportamento do módulo
e do falso nestes testes, sem constituir prova formal sobre qualquer plugin
ou adaptador futuro. Encerramento por tempo pode variar com carga da máquina.

## Conhecimento, tentativas e política

[FATO] Cada instância `terminal_estado.gd` começa apenas com OLHAR e AJUDA.
AJUDA descobre MARCAR, depois MOVER, depois LER, uma vez por chamada.
LER livro_desenho descobre DESENHAR; LER livro_repeticao descobre REPETIR,
somente após resposta virtual de sucesso. Três programas bem sucedidos,
inclusive ajuda, também permitem descobrir REPETIR pela prática. O programa
em curso só pode usar conhecimento existente antes da execução; uma sequência
com AJUDA e um comando ainda bloqueado é recusada antes de produzir efeitos.
`discover(command, source)` permite registrar eventos confiáveis de livro/ajuda
na integração; a validação exige que a fonte corresponda à trilha do comando.

[FATO] Há até sete conhecidos, 48 tentativas e 32 programas na tabela por
criatura. Cada tentativa registra `{comando, erro, resultado, tick}`. Comando
é dado opaco truncado em 256 caracteres, com controles fora de LF/CR/tab e
Unicode substituídos por `?`; também são registrados erros de sintaxe e
comandos desconhecidos. Mensagens são sempre obtidas de `terminal_textos.gd`.
Tick é inteiro 0–2147483647; contagens são inteiros 0–10000. Histórico descarta
a tentativa mais antiga. A tabela só recebe programas válidos de até 256
caracteres e oito passos; ao encher, remove a menor contagem, com desempate
lexicográfico. Assim ordenação de chaves por JSON não altera a continuação.

[FATO] `to_dict()` entrega cópia profunda. `valid(data)`/`from_dict(data)`
recusam schema/versão/tipos/limites/proveniência inválidos e NaN/INF; números
integrais vindos de JSON são normalizados. Não há leitura ou escrita de save
no módulo. `is_valid()` verifica o estado antes de execução sem duplicar
previamente coleções possivelmente adulteradas.

[FATO] `terminal_politica.gd` gera até 16 candidatos curtos: exemplos fixos
dos comandos conhecidos, programas lembrados permitidos e pares desses
programas. Cada candidato permanece em até oito passos. `score` usa média
suavizada `(sucessos+1)/(n+2)` e bônus exploratório `0.2/sqrt(n+1)`;
`choose` retorna o maior valor, com desempate estável. Tentativas bem sucedidas
aumentam a média; recusas a diminuem. A política usa apenas memória individual;
não executa ações nem altera corpo. Atualizações saturam em 10000 observações.

[HIPOTESE] A tabela permite que M4b favoreça sequências antes úteis. Isso
precisa de ensaio com objetivos, baselines e ablações antes de afirmar
aprendizagem de solução de problemas. Os exemplos fixos e a busca limitada
não inferem gramática, semântica geral nem planos novos arbitrários.

## Testes e evidência

[FATO] `tests/unit/test_terminal.gd` cobre os sete comandos, argumentos reais
recebidos pelo adaptador, retorno de OLHAR, bloqueio de conhecimento, ajuda,
livro, prática, isolamento entre estados, memória/tabela limitadas, preferência
por sucesso passado, retenção e continuação após JSON, tipos e NaN/INF no
schema, limites exatos de entrada/nós/profundidade/passos e recusa de efeitos
antes da validação completa.

[FATO] O corpus contém **1078 casos textuais**: 54 ataques explícitos,
512 mutações de bytes e 512 programas estruturados com limites válidos e
inválidos. Seeds determinísticas: **140101–140104**. Controles estruturados
válidos rodam em dois adaptadores independentes e devem produzir resultados
e contadores iguais. Rejeitados não chamam nenhuma ação virtual. Há ainda
entradas de tipos errados, bytes NUL/Unicode e controle positivo ASCII.
Inclui `; | & \\ > <`, barras duplas, aspas, crases, símbolos de substituição,
powershell, cmd /c, rm -rf, ../, C:\\, URLs, import os, OS.execute,
homoglifos/Unicode invisível, um milhão de caracteres, 100 níveis de blocos,
REPETIR 1000000000, NaN e comandos desconhecidos.

[FATO] Harness aberto, sem holdout: `godot --headless --path . -s
tests/experiments/terminal_hostile.gd`. A suíte integral descobre o teste
automaticamente, sem alterar `tests/run_tests.gd`. Nenhum `*_eval` fechado
foi executado; os JSON experimentais versionados devem permanecer idênticos.

[FATO] Validação final em Godot **4.7.2 stable**, executável console indicado
no despacho: harness hostil **PASS, exit 0**, e `godot --headless --path . -s
tests/run_tests.gd` com **22 suítes ok, exit 0, zero FAIL e zero SCRIPT ERROR**.
São as 21 suítes da base mais `test_terminal.gd`. `git diff --exit-code HEAD
-- 'reports/*.json'` terminou exit 0; nenhum JSON precisou de restauração.

## Contrato de integração M4b

[FATO] API mínima de uso, sem qualquer edição de mundo neste marco:

```gdscript
const Terminal = preload("res://scripts/terminal/terminal.gd")
const Estado = preload("res://scripts/terminal/terminal_estado.gd")
const Politica = preload("res://scripts/terminal/terminal_politica.gd")
var estado = Estado.new() # uma instância por criatura, sem herança automática
var terminal = Terminal.new()
var programa = Politica.choose(estado)
var resultado = terminal.execute(programa, adaptador_virtual, estado, tick)
var dados = estado.to_dict()
var restaurado = Estado.from_dict(dados) # null se inválido
```

[LACUNA] M4b deverá definir o dono do estado, migração opt-in do save, IDs e
objetivos virtuais, alcance/custos/cooldowns, orçamento de chamada por tick e
eventos observáveis. Se ações virtuais virarem intenções físicas, o executor
do mundo deve revalidar alcance/colisão/custo; este módulo não os concede.
Adaptador real, laboratório e textos de jogador em `scripts/core/textos.gd`
ficam para a integração. As mensagens internas deste módulo ficam no catálogo
próprio solicitado, sem dependência de Textos. Não há alegação de consciência.
