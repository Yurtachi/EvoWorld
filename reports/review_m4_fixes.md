# Correção dos achados F4 (SCRIPT ERROR com tipos hostis em saves)

## Contexto
O relatório de revisão dinâmica independente (`reports/review_m4.md`, achado **F4**) identificou que mutações com tipos incompatíveis (`Array`, `Dictionary`, `String`, `bool`, `int`) em campos de validação de saves eram rejeitadas com retorno `null`, mas geravam `SCRIPT ERROR` no log do Godot devido ao operador `!=` entre tipos incompatíveis antes da checagem de tipo.

## Modificações realizadas

### 1. `scripts/world/sim_world.gd` (`from_dict`, validação de `library`)
- **Problema**: `lib.get("version") != Books.VERSION` era avaliado antes de `Data.integer(lib.get("version"), 1)`. Quando `version` era `Array`, `Dictionary`, `String` ou `bool`, o Godot emitia:
  `SCRIPT ERROR: Invalid operands '<Tipo>' and 'int' in operator '!='.`
- **Correção**: A checagem `not Data.integer(lib.get("version"), 1)` foi movida para ser avaliada antes de comparar com `Books.VERSION`. Com isso, tipos não-inteiros são rejeitados de forma segura pelo `Data.integer` via curto-circuito, sem disparar erro de operador no motor.

### 2. `scripts/terminal/terminal_estado.gd` (`valid`, validação de `conhecidos`)
- **Problema**:
  - Na linha 84, `data.conhecidos.get("OLHAR") != "inicial"` e `data.conhecidos.get("AJUDA") != "inicial"` eram avaliados diretamente. Valores com tipo `Array`, `Dictionary`, `int` ou `bool` disparavam `Invalid operands '<Tipo>' and 'String' in operator '!='`.
  - Na linha 89-96, para comandos conhecidos como `REPETIR`, `MOVER`, `DESENHAR`, `source` era comparado diretamente com `"livro"`, `"inicial"`, etc., disparando o mesmo erro se `source` não fosse string.
- **Correção**:
  - Adicionada verificação `typeof(...) != TYPE_STRING` antes de comparar `OLHAR` e `AJUDA` com `"inicial"`.
  - Adicionadas verificações `typeof(command) != TYPE_STRING` e `typeof(source) != TYPE_STRING` no loop de comandos de `conhecidos`, rejeitando precocemente qualquer valor não-string sem chegar a comparações de string.

### 3. `scripts/library/knowledge.gd` (`valid`, validação de `questions`)
- **Problema**: Na linha 147, `q.get("goal") != "investigar_objeto"` e `q.get("text_key") != "library.question.unknown"` eram avaliados diretamente sem validar se eram `String`. Mutações com `Array`, `Dictionary`, `int`, etc., disparavam `SCRIPT ERROR`.
- **Correção**: Adicionadas guardas `not q.get("category") is String`, `not q.get("goal") is String` e `not q.get("text_key") is String` antes das comparações de igualdade e pertinência.

### 4. `tests/unit/test_save_robustez.gd` (`_hostile_types_regression`)
- Adicionada a suíte `_hostile_types_regression(failures)` com 87 casos de teste cobrindo todas as permutações de tipos hostis (`[]`, `{}`, `String`, `bool`, `negativo`, `zero`, `float`, `NAN`, `INF`, chave numérica):
  - `library.version` hostil (10 casos)
  - `conhecidos` em terminal com comandos `OLHAR`, `AJUDA`, `REPETIR`, `MOVER`, `DESENHAR` e chave inteira (46 casos)
  - `questions` em knowledge com `goal`, `text_key` e `category` (30 casos)
- Todos os casos são rejeitados pelo carregador (`World.from_dict(...) == null`) com zero ocorrências de `SCRIPT ERROR` no log.

## Verificação e Determinismo
- Suíte completa de testes executada em modo headless:
  `Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/run_tests.gd`
  - **Resultado**: 24 suítes "ok", exit 0, **zero SCRIPT ERROR**.
  - `test_perf_determinism.gd: ok` (golden digests idênticos; nenhuma alteração de comportamento físico ou de política).
  - Nenhum formato de save nem estado válido foi alterado; nenhuma biblioteca experimental ou pré-registro foi tocado.
