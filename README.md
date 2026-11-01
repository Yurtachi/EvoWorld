# EvoWorld

Ambiente 2D de vida artificial em Godot 4.7.2 e GDScript. A interface e a documentação para jogadores estão em português brasileiro. Veja `docs/mission/` para a visão e as metas do projeto.

## Executar

```text
godot --path .
godot --headless --path . -s tests/run_tests.gd
godot --headless --path . -s scripts/ui/verify_ui.gd
```

Os dois comandos de verificação retornam código de saída 0 quando passam.

Godot 4.7.2: `winget install -e --id GodotEngine.GodotEngine`.

## Criar e observar um jardim

Ao abrir o jogo, escolha o nome do jardim, o nome do seu companheiro e uma semente inteira entre 0 e 2147483647. A semente reproduz o estado inicial do ecossistema. O padrão é **Jardim de Musgo**, com o companheiro **Pip**. Criar um jardim substitui o mundo atual não salvo; **Continuar explorando** fecha o diálogo e mantém o mundo atual.

O jardim começa pausado. Use **Iniciar/Pausar** e as velocidades **1×, 2× e 5×**. Clique em uma criatura com **Inspecionar** para consultar energia, idade, ação, razão e genes no diário de campo. **Encontrar** seleciona e centraliza seu companheiro; **Acompanhar** move a câmera com a criatura selecionada. **Mostrar alcance da visão** exibe o campo geométrico de visão; rochas podem ocultar objetos dentro dele.

As ferramentas **+ Alimento**, **+ Rocha** e **+ Criatura** atuam ao clicar dentro do jardim. Há um limite de 150 criaturas adicionadas pela interface. As criaturas seguem regras fixas de busca de alimento; não aprendem nem se reproduzem nesta versão. A energia pode acabar e seu companheiro pode morrer.

| Controle | Ação |
|---|---|
| Roda do mouse | Ampliar ou reduzir ao redor do ponteiro |
| Arraste com o botão do meio ou WASD | Mover a câmera |
| F | Enquadrar o jardim |
| Espaço | Iniciar ou pausar |
| Esc | Voltar a Inspecionar |
| Ctrl+S / Ctrl+L | Salvar / carregar |
| F12 | Capturar a tela |

## Salvar e recuperar

**Salvar** grava um ponto local com o mundo, os nomes e o estado aleatório. **Carregar** substitui o mundo atual pelo ponto salvo e pausa a simulação. Existe um único ponto de salvamento, com uma cópia da revisão válida anterior. Se o arquivo principal estiver inválido, o jogo tenta recuperar essa cópia; se ambos falharem, apresenta um erro em português e preserva o mundo aberto.

Os arquivos ficam em `user://saves/world.json` e `world.json.bak`. No Windows, `user://` normalmente corresponde a `%APPDATA%/Godot/app_userdata/EvoWorld/`. As capturas feitas com F12 ficam na subpasta `screenshots/`.

## Textos e compatibilidade

Os textos para jogadores ficam no catálogo `scripts/core/textos.gd` (`Textos`). Ações, razões e mensagens internas em inglês são traduzidas somente na apresentação; identificadores, chaves JSON, dados da simulação e formatos de salvamento permanecem compatíveis. Nomes personalizados são preservados; nomes padrão antigos são apresentados em português. Razões ou erros desconhecidos recebem uma mensagem segura em português.

Veja `reports/i18n.md` para os testes e as capturas atuais da interface.

## Estado
Veja `reports/` (um relatório por etapa de validação) e `docs/CHANGELOG.md`.
