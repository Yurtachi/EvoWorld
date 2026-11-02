# M0-A — integridade

Data: 2026-11-02. Base recebida: `evo2/e1-base` @ `dc785ac`; trabalho local em `Yurtachi/evo3-m0a2`. Resultado: **PASS no escopo de integridade**. Não houve push, merge, execução de `ensino_eval`, `learn_eval` ou `social_eval`, nem alteração de `sim_world.gd`, fixtures ou resultados JSON existentes.

## Limites de checkpoints

- [FATO] `MAX_PAYLOAD_BYTES` caiu de 128 para **8 MiB**, aplicado tanto ao envelope sem compressão v1 quanto ao gzip v2 e à escrita. O arquivo em disco continua limitado a 32 MiB. A referência de E5 é um save de aproximadamente 0,8 MB: o novo teto permite cerca de dez vezes esse volume, reduzindo a alocação máxima pedida ao descompressor em dezesseis vezes.
- [FATO] O leitor rejeita `uncompressed_bytes > 64 * file_bytes` **antes de decodificar base64 ou descomprimir**. `file_bytes` é o tamanho real do envelope em disco, não uma informação fornecida pelo cabeçalho. SHA256, base64 canônico, cabeçalho gzip, ISIZE e tamanho efetivo continuam validados.
- [FATO] O teste gera uma gzip bomb com mais de 2 MiB de JSON válido, SHA256 do conteúdo e do base64 corretos e gzip produzido pelo próprio motor, incluindo CRC/ISIZE válidos. Um descompressor instrumentado confirma que a rejeição acontece sem chamar gzip.
- [FATO] O limiar automático de compressão passa a 1 MiB, abaixo do novo teto. Quando a compressão de um payload válido excede a razão permitida, o gravador usa envelope v1; não produz um save que seu próprio leitor rejeitaria. Há testes do limiar, fallback, UTF-8, teto v1/v2 e escrita interrompida/backup.
- [HIPOTESE] 8 MiB e razão 64 são margens adequadas ao produto atual; não são promessa de retenção ilimitada de genealogia. A razão admite compressão forte de JSON e bloqueia o caso altamente repetitivo testado.
- [LACUNA] Checkpoints antigos acima de 8 MiB decodificados, ou envelopes comprimidos acima da nova razão, serão recusados por política. Não foi feita varredura de todos os saves possíveis; fixtures do repositório e o autosave real disponível continuam carregando.

## TTL de ordens

- [FATO] `commands.order.remaining_ticks` persiste o saldo exato do TTL. É um campo opcional: ordens antigas com apenas `intent`/`target` mantêm o comportamento legado de receber o TTL original. O schema continua v7 e as migrações v1–v7 permanecem compatíveis; v1/v2 não tinham ordens persistidas.
- [FATO] O campo aceita somente inteiros de 1 até o máximo específico da ordem. Null, booleanos, strings, coleções, frações, negativos, zero, NaN/inf e valores acima do máximo são rejeitados; chaves extras continuam rejeitadas.
- [FATO] As quatro ordens (`chamar`, `brincar`, `parar`, `seguir`) são salvas com sete ticks restantes, inclusive após consumo de TTL durante suspensão por fome. Save/load real, segundo roundtrip e continuação pareada conservam o saldo e a expiração após sete ticks. A ausência do campo também é testada em cada ordem.

## Proveniência dos experimentos

- [FATO] A alternativa escolhida foi `tests/experiments/verify_prereg.sh`, auditoria somente de leitura, sem executar avaliações nem reescrever resultados. Uso: `bash tests/experiments/verify_prereg.sh [revisao]`, sendo `HEAD` o padrão; exige Git e utilitários padrão do Bash, disponíveis no Git Bash desta máquina.
- [FATO] O script fixa os commits históricos de pré-registro, verifica ancestralidade com o primeiro commit do avaliador e exige que ambos antecedam estritamente o primeiro artefato de resultados. Confere a identidade do blob do protocolo no pré-registro, avaliador, primeiro resultado e revisão auditada, além do SHA256 registrado no primeiro resultado e no resultado da revisão auditada. Não depende de timestamps nem do conteúdo do working tree.

| Gate | Commit de pré-registro | Blob do protocolo | Primeiro commit de resultados |
| --- | --- | --- | --- |
| E3 | `a66ea9c0084f2c3ced6e7c55c127a90266d006fd` | `2ad5405a65a166cb0605bdc6ed0cdb2b039745c1` | `6bb1e87965a0bcc43cd7ebefbf50b9bc46825ca1` |
| E4 | `ad63789bf26c64e5b829aba76f5c461f75e5a996` | `b301c78e0d69c038152ba28f79caacabfe3d7b51` | `c22cb053f070dc52a66e72414cb7837188ef2b8e` |

- [FATO] E3 incluiu protocolo e avaliador no mesmo commit; E4 introduziu o avaliador em `e1f43dbf65100d8eb1e2905169cca8ba4ff1241d`. A auditoria retorna PASS para ambos. Controles negativos rejeitaram uma revisão sem todos os artefatos e duas árvores temporárias com protocolo ou checksum adulterado, todas com exit 1; nenhum branch/ref foi alterado por esses controles.
- [LACUNA] Git prova a ordem dos commits e a ligação entre protocolo e artefatos registrados, não a data da primeira execução local. O histórico não prova que nunca houve rodadas de desenvolvimento com seeds de holdout social. Essa limitação científica permanece explícita e não é corrigida retroativamente por um hash.

## Flags de captura e benchmark

- [FATO] `--capture` e `--fps-benchmark` só são interpretados quando `OS.is_debug_build()` é verdadeiro. As entradas das rotinas de captura/benchmark também verificam a condição. Em release elas não alteram população, modo de captura ou fluxo de inicialização.
- [FATO] A captura exige arquivo PNG com caminho absoluto ou `user://`. Caminhos relativos, `res://`, esquemas externos, componentes `..`, controles e escapes de `user://` são recusados; separadores Windows são normalizados. Benchmark sem caminho explícito usa `user://E4-fps-N.png`. População precisa estar entre 1 e 100, com comprimento limitado antes da conversão numérica.
- [FATO] Os testes cobrem opções debug/release, caminhos válidos e hostis e populações malformadas. A entrada numérica gigantesca expôs erros de conversão no motor durante o desenvolvimento; o limite de comprimento corrige o problema e o log final não contém erros.
- [FATO] Exportação release Windows com Godot 4.7.2: exit 0. Duas execuções headless do binário com `--quit-after 5`, uma com captura válida/benchmark 100 e outra com caminho relativo/inteiro gigante/estado de captura, encerraram com exit 0, stderr vazio e sem criar a captura. O binário de verificação fica ignorado em `builds/M0-integridade.exe`.
- [LACUNA] Não foi refeita medição gráfica de FPS nem inspeção visual de screenshots; o trabalho verificou a restrição das flags e a ausência de crash em release.

## Fuzz, compatibilidade e validação

- [FATO] Comando obrigatório executado: `godot --headless --path . -s tests/run_tests.gd` usando o console Godot 4.7.2 indicado no despacho. Resultado final: **exit 0, 16 suítes ok**, sem `ERROR`, `FAIL` ou erro de Unicode no log. Log local ignorado: `builds/m0-tests.log`.
- [FATO] O corpus existente reporta 693+ entradas hostis v1–v7. Foram acrescentadas **1.204 mutações aninhadas deterministas** (seed 92026), incluindo tipos de corpo/genoma e inteiros textuais fora de faixa/não canônicos, e **280 TTLs hostis** v3–v7. Nenhum novo crash de save foi encontrado nesse corpus. O novo teto também foi aplicado ao envelope v1 para impedir que ele contornasse a política adotada para v2.
- [FATO] Fixtures reais, migrações, determinismo, backup/reparo e saves v1–v7 passam nas suítes. Leitura adicional, somente com `_read`, do autosave existente (**1.972.472 bytes**) e de `autosave.json.bak` retornou `ok=true`; SHA256 antes/depois confirmou que ambos permaneceram intactos.
- [FATO] `git diff --check` passou; os resultados científicos JSON permaneceram sem alterações. As mudanças respeitam a propriedade de caminhos do despacho; o coordenador autorizou adicionalmente uma regra específica em `.gitattributes` para preservar LF em `verify_prereg.sh` nos checkouts Windows, mantendo as regras anteriores.
- [LACUNA] Fuzz limitado e repetível não constitui prova de ausência de toda entrada hostil. Revisão independente por outro escritor e os demais itens científicos/UX de M0/E5 pertencem ao fluxo do coordenador.
