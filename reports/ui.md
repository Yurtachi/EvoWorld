# Interface do EvoWorld

Relatório atualizado em 01/11/2026 após a migração para português brasileiro. A implementação inicial foi validada no ramo `Yurtachi/evo-ui2`; os ajustes de idioma estão no ramo `Yurtachi/evo-i18n`.

## Comportamento disponível

- A cena principal usa o `SimWorld` real. Criaturas, alimento e rochas vêm da simulação; tamanho e matiz dos genes determinam a aparência procedural. A decoração usa um gerador aleatório visual independente.
- Câmera com ampliação centrada no ponteiro, arraste com o botão do meio, WASD, F para enquadrar, Encontrar e Acompanhar.
- Interface nativa do Godot com tema verde e creme, indicadores de semente, passo, quadros por segundo e contagens. O diário de campo mostra nome, energia, idade, ação, razão e genes da criatura selecionada.
- Diálogo para nomear jardim e companheiro e escolher uma semente inteira. Um mundo novo começa pausado com 16 criaturas. Cancelar preserva o mundo anterior e seu estado de reprodução temporal.
- Iniciar/Pausar, Espaço e velocidades 1×, 2× e 5× avançam os passos fixos de 0,1 segundo. Cada quadro aceita até 0,25 segundo de recuperação temporal.
- Ferramentas Inspecionar, Alimento, Rocha e Criatura chamam os métodos reais de `SimWorld`. A interface limita a população adicionada a 150 criaturas.
- Salvar/Ctrl+S e Carregar/Ctrl+L usam um ponto local; carregar pausa e seleciona o companheiro salvo. Falhas de carregamento preservam o mundo aberto.
- O alcance de visão é geométrico; rochas podem ocultar objetos. As criaturas seguem regras fixas de busca de alimento, sem aprendizado, reprodução ou comunicação nesta versão. O companheiro pode morrer.

## Idioma e dimensões

Todos os textos de jogador são fornecidos por `scripts/core/textos.gd`. Ações e razões da simulação, nomes padrão antigos e mensagens de persistência são traduzidos na apresentação, preservando os dados salvos. Valores decimais usam vírgula. Nomes escolhidos pelo jogador permanecem intactos.

A barra inferior separa ferramentas e reprodução em duas linhas para acomodar o português. O diálogo tem largura mínima de 540 pixels. O diário de campo permite rolagem e quebra de linha; a janela suporta no mínimo 1100×680.

## Persistência

`scripts/persistence/save_store.gd` mantém o contrato `save_world(world, slot = "world", metadata = {})` e `load_world(slot = "world")`. Os retornos incluem `ok` e `message`; carregamentos bem-sucedidos também incluem mundo, metadados, caminho e indicação de recuperação.

O ponto padrão é `user://saves/world.json`, com cópia `.json.bak` e temporários no mesmo diretório. Um envelope versionado contém dados JSON e uma soma SHA-256. A leitura valida a estrutura do mundo; o limite é 32 MiB. A gravação valida o temporário, preserva um arquivo principal válido como cópia de segurança e substitui o principal por renomeação. Um arquivo corrompido não substitui uma cópia válida. A recuperação lê a cópia sem regravar o disco até o próximo salvamento.

## Validação e capturas atuais

Os testes de persistência cobrem restauração exata, continuação determinística, substituição, cópia anterior, temporários interrompidos, falha de soma de verificação, estrutura inválida, JSON malformado, caminhos inválidos e ausência de arquivos.

A integração `scripts/ui/verify_ui.gd` exercita a cena real, o formulário, os botões e ferramentas, a seleção, os campos traduzidos, a pausa, 5×, salvar/carregar, erro de JSON inválido, câmera e dimensões mínimas. Usa uma pasta isolada e não modifica o ponto de salvamento do jogador.

Os resultados atuais, códigos de saída e capturas gráficas novas estão em [reports/i18n.md](i18n.md). As imagens antigas `ui-world.png` e `ui-new-world.png` são evidências históricas da interface anterior, em inglês.

## Executar e capturar

```text
godot --path .
godot --headless --path . -s tests/run_tests.gd
godot --headless --path . -s scripts/ui/verify_ui.gd
godot --path . -- --capture=reports/i18n-inspecao.png
godot --path . -- --capture=reports/i18n-novo-mundo.png --show-new-world
godot --path . -- --capture=reports/i18n-invalid-load.png --capture-state=invalid-load
```

Os estados de captura disponíveis são `inspect`, `tools`, `creature`, `save`, `load`, `invalid-load` e `menu` (este último junto de `--show-new-world`). Use `--capture-minimum` para a janela de 1100×680. Capturas exigem execução gráfica e uma pasta de destino existente. Os cenários de persistência criam e removem arquivos próprios em uma pasta isolada; não usam o ponto do jogador. F12 captura a janela atual em `user://screenshots/`.

## Limites

Há um ponto de salvamento com sua revisão válida anterior; não há navegador de pontos, salvamento automático, desfazer ou exportação. O desenho das criaturas é procedural. Licenças, arquivos de terceiros e simulação não foram alterados na migração de idioma.
