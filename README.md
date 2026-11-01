# EvoWorld

Jardim de vida artificial em **Godot 4.7.2** e GDScript, executado localmente, sem rede ou Python durante o jogo. Adote um companheiro, ofereça alimento, introduza organismos e examine reprodução, herança, decisões e sinais registrados. A interface está em português brasileiro.

## Instalar e abrir no Windows

1. Instale **Godot 4.7.2 Standard**, com GDScript. Não é necessária a edição .NET. O projeto usa **GL Compatibility**.
2. Pelo Gerenciador de Pacotes do Windows: `winget install -e --id GodotEngine.GodotEngine --version 4.7.2`. Também é possível extrair a distribuição oficial dessa versão e executar seu arquivo de console.
3. No gerenciador de projetos do Godot, escolha **Importar**, selecione `project.godot`, abra e aguarde a importação dos recursos. Pressione **F5** para executar o projeto.
4. Pelo terminal, entre nesta pasta e execute:

```powershell
godot --version
godot --editor --path .
godot --path .
```

O primeiro comando deve indicar 4.7.2. Se `godot` não estiver no PATH, substitua-o pelo caminho do executável entre aspas, precedido por `&` no PowerShell. O executável validado neste ambiente é:

```powershell
& 'C:\Users\Yurtachi\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe' --path .
```

## Criar e cuidar de um jardim

Ao abrir, escolha os nomes do jardim e do companheiro, uma semente inteira de 0 a 2147483647 e a população inicial de 1 a 100. O padrão é **Jardim de Musgo**, **Pip** e **12 organismos, com três regiões de água**. Essa criação usa `SimWorld.new_world`; o seletor explícito continua prevalecendo e carregar saves mantém a população gravada. A semente recria condições iniciais; as intervenções do jogador mudam a trajetória. Criar um jardim substitui o mundo não salvo; **Continuar explorando** mantém o mundo aberto.

O jardim começa pausado. Use **Iniciar/Pausar** e **1×, 2× ou 5×**. **Inspecionar** seleciona uma criatura e mostra energia, hidratação, sede, idade, ação e último evento no **Cuidador**. A lista do painel e os nomes desenhados no terreno também selecionam criaturas; genes e parentesco ficam no **Laboratório**. Acima de 30 criaturas, o enquadramento geral mostra nomes só da seleção e do companheiro; aproximar a câmera revela os demais, e a lista continua disponível. Rótulos que colidiriam são omitidos, priorizando a seleção; os corpos continuam visíveis. **Encontrar** volta ao companheiro; **Acompanhar** segue a seleção; **Mostrar alcance da visão** desenha o campo geométrico, sujeito à oclusão por rochas.

Escolha **Fruta**, **Semente**, **Folha** ou **Cogumelo** e clique no terreno para plantar. Os quatro têm cores e formas próprias. **+ Água** chama `place_water` para colocar uma região circular de raio 30; beber exige alcançar a margem. Uma gota, um anel azul e “Bebeu +…” aparecem por dois segundos de simulação após um evento físico com ganho positivo. **+ Rocha** e **+ Criatura** continuam disponíveis. Comida precisa ser percebida, alcançada e consumida; colocá-la não aumenta a energia diretamente. O teto padrão é 150 organismos vivos, contando descendentes. Os corpos são procedurais: tamanho, matiz e velocidade dos genes afetam a aparência. Terreno e rochas usam sprites Kenney CC0; água, alimentos e corpos são desenhos procedurais próprios. O arquivo `water.png` não é usado. A palatabilidade é a do catálogo por alimento; esta etapa não registra preferência individual. Cogumelo tem toxicidade 8 e pode causar perda líquida de energia (valores fictícios da simulação).

**Oferecer alimento à seleção** chama `oferecer_alimento` com o tipo escolhido e registra seu ID, sem alterar reservas nem posição. Os recibos acompanham aproximação medida, ingestão pelo destinatário com ganho positivo e bebida confirmada pelo simulador. Desaparecimento sem evento de ganho positivo não conta como refeição; colocar não garante aceitação. O painel mostra os quatro recibos mais recentes; o histórico temporário é limitado a 32 e reinicia ao criar/carregar.

**Expandir terreno** abre confirmação com borda direita/inferior, quantidade, tamanho resultante, área, custo **zero** (não há moeda no contrato E1) e limite de **100.000 por eixo**. Confirmar chama `world.expand` e reenquadra a câmera. Não acrescenta recursos automaticamente. Coordenadas, IDs e RNG permanecem preservados. O desenho do terreno percorre apenas os ladrilhos visíveis, inclusive em áreas grandes.

Em **Ajustes**, configure velocidade, população do próximo jardim, proteção e salvamento automático. A proteção é uma **pausa preventiva**: impede o próximo passo quando o companheiro está com 15% de energia ou menos, ou a um passo do limite de idade. Não repõe energia nem rejuvenesce. Para avançar nessas condições, desligue a proteção assumindo o risco indicado; colocar alimento não remove o bloqueio enquanto o companheiro ainda não comeu. A pausa interrompe todo o ecossistema e influencia sua observação.

**No modo sobrevivência, o companheiro pode morrer de fome ou idade. A morte é permanente naquele mundo.** Só carregar um ponto anterior permite voltar. Introduzir outra criatura não a transforma automaticamente no companheiro perdido.

| Controle | Ação |
|---|---|
| Roda do mouse | Ampliar/reduzir ao redor do ponteiro |
| Botão do meio arrastado ou WASD | Mover a câmera |
| Botão direito no terreno | Marcar o alvo dos pedidos de diálogo |
| F | Enquadrar o jardim |
| Espaço | Iniciar/pausar |
| Esc | Voltar a Inspecionar |
| Ctrl+S / Ctrl+L | Salvar/carregar o ponto manual |
| F12 | Capturar a tela |

Atalhos de câmera/reprodução ficam suspensos enquanto os painéis de texto estão abertos. **Ajuda** oferece um tutorial dentro do jogo.

## Conversar com o companheiro

No **Cuidador**, abra **Conversar com o companheiro**, digite e pressione **Enviar** ou Enter. Exemplos: **como você está?**, **oferecer comida**, **chamar**, **seguir**, **parar**, **brincar** e **proteger**. Chamar/seguir usam o marcador azul escolhido com o botão direito no jardim; ele permanece naquele ponto até você marcar outro.

A interface chama `Dialogo.interpretar/responder` e usa a instância persistente `world.comandos`. A tela separa resposta, recibo e evidências: passo, energia, fome, idade, ação/razão, alimentos percebidos e evento próprio recente quando houver. A consulta descreve o instante indicado; não é uma leitura de consciência. Entradas fora da gramática não recebem evidências inventadas.

Oferecer comida coloca alimento real sem prometer ingestão. Pedidos de movimento passam pela física, colisões e custos normais; o recibo de registro não significa que o alvo já foi alcançado. **Proteger** ativa a pausa preventiva da interface. O save v4 guarda ordens e alvo; o alvo de seguir é restaurado pela UI. Se a mesma UI for usada com uma base sem executor de comandos, ela indica explicitamente os pedidos pendentes.

## Investigar no Laboratório

O toggle **Laboratório** troca o painel lateral sem interromper o jardim. Ele apresenta:

- Genoma, geração, nascimento e os seis genes da seleção.
- Mutações de nascimento, ancestrais e descendentes pelas APIs reais de evolução, incluindo mortos. As listas mostram até 12 registros e informam quando há mais.
- População viva, geração máxima e totais de nascimentos/mortes do registro genealógico permanente.
- Variância por gene e curvas observadas a cada 50 passos, limitadas a 180 amostras. Cada curva tem sua escala. A diversidade normalizada é a média das variâncias divididas pela amplitude de cada gene ao quadrado; população vazia/única produz zero.
- Eventos recentes de nascimento, morte, introdução e alimentação. O buffer geral guarda até 256 eventos; os totais genealógicos não dependem dele.
- Canal de sinais, símbolo e **Emitir pela seleção**, como intervenção explícita com custo de energia. O canal começa desligado. A heurística padrão não emite sozinha.
- Log de até 20 emissões recentes: símbolo, emissor, contexto, receptores e primeiras ações registradas após recepção. O log do mundo guarda até 256 emissões. Uma mudança temporal de ação não demonstra que o sinal a causou; nenhum símbolo significa automaticamente comida ou perigo.

As curvas começam ao criar/carregar e não são persistidas. Os dados genealógicos e de sinais são persistentes. Variação, sobrevivência e gerações isoladas não comprovam adaptação. O jardim padrão usa a heurística quando `brain == null`; o resultado de aprendizado em [reports/learn.md](reports/learn.md) não significa que cada organismo novo já tenha sido treinado. A hipótese de benefício do canal no experimento G4 **não passou**, conforme [reports/sinais.md](reports/sinais.md).

## Salvar e recuperar

**Salvar** grava `user://saves/world.json`; **Carregar** restaura o ponto manual e pausa. O automático, ativado por padrão, grava a cada 60 segundos de sessão quando o mundo mudou, inclusive por ferramentas com o jardim pausado. Usa `user://saves/autosave.json` e preserva o manual. **Ajustes → Recuperar automático** restaura esse ponto e pausa.

Cada ponto tem sua revisão válida anterior em `.json.bak`. `SaveStore` escreve um temporário, valida dados e soma SHA-256, preserva a cópia e substitui o principal por renomeação. Ao carregar um principal inválido, tenta a cópia; se ambos falharem, mantém o mundo aberto e mostra o erro em português. O limite por arquivo é 32 MiB. Alterações posteriores à última gravação podem se perder em uma interrupção.

No Windows, `user://` normalmente corresponde a `%APPDATA%/Godot/app_userdata/EvoWorld/`. Preferências da interface ficam em `ui-settings.cfg`; capturas F12 ficam em `screenshots/`. Esta entrega usa **save v4**, com migração das versões anteriores fornecida pelo simulador. A migração preserva população e fisiologia histórica: em saves antigos a sede permanece desativada, mesmo se o jogador colocar água. Nenhum campo da simulação foi acrescentado ou renomeado pela UI.

## Testes e capturas

```powershell
godot --headless --path . -s tests/run_tests.gd
godot --headless --path . -s scripts/ui/verify_ui.gd
```

Ambos devem retornar **código de saída 0**, sem `SCRIPT ERROR`. A suíte cobre simulação, percepção, aprendizado, evolução, diálogo, sinais, persistência e textos. O teste de UI instancia a cena real, percorre formulário/ferramentas, conversa com evidências, oferta de comida, genealogia/mutações, curvas, proteção, configurações e salvamento manual/automático. Também verifica a janela mínima de 1100×680. Seus arquivos são isolados e não alteram pontos ou preferências pessoais.

Para reproduzir capturas do build atual:

```powershell
godot --path . -- --capture=reports/ui2-cuidador.png
godot --path . -- --capture=reports/ui2-dialogo.png --capture-state=dialogue
godot --path . -- --capture=reports/ui2-laboratorio.png --capture-state=laboratory
godot --path . -- --capture=reports/ui2-linhagem.png --capture-state=lineage --capture-minimum
godot --path . -- --capture=reports/ui2-sinais.png --capture-state=signals --capture-minimum
godot --path . -- --capture=reports/ui2-ajustes.png --capture-state=settings --capture-minimum
godot --path . -- --capture=reports/ui2-ajuda.png --capture-state=help --capture-minimum
godot --path . -- --capture=reports/ui2-novo-mundo.png --show-new-world --capture-minimum
```

As capturas usam a cena real, desativam autosave e não escrevem preferências pessoais. O laboratório avança naturalmente até o passo 1200 para mostrar descendência, sem forçar genomas ou nascimentos. O cenário de sinais faz uma emissão manual pelo mesmo botão disponível ao jogador e avança um passo. Resultados e limites em [reports/ui2.md](reports/ui2.md).

## E1: capturas e mini gráfico de quadros/s

A barra inferior contém um gráfico das últimas 120 durações de quadro (exibidas como quadros/s). Para medir a cena real, renderizada e em execução a 1×, com dois segundos de aquecimento e oito segundos de coleta:

```powershell
godot --path . -- --fps-benchmark=12
godot --path . -- --fps-benchmark=30
```

Esses comandos usam seed 7421, janela de 1280×720 e escrevem `reports/E1-fps-12.json`/`.png` e `reports/E1-fps-30.json`/`.png`, com média de quadros/s, p95 de duração, população final e adaptador. Exigem modo gráfico; não use `--headless`. Não acessam saves nem preferências pessoais. Valores dependem de hardware, carga e sincronização da janela; não constituem um gate de eficácia do aprendizado.

```powershell
godot --path . -- --capture=reports/E1-12-criaturas-agua.png --capture-state=e1-garden
godot --path . -- --capture=reports/E1-4-alimentos.png --capture-state=e1-foods --capture-minimum
godot --path . -- --capture=reports/E1-expandir-antes.png --capture-state=e1-expand-before
godot --path . -- --capture=reports/E1-expandir-depois.png --capture-state=e1-expand-after
godot --path . -- --capture=reports/E1-oferecer-alimento.png --capture-state=e1-offer
godot --path . -- --capture=reports/E1-inspector.png --capture-state=e1-inspector
godot --path . -- --capture=reports/E1-agua-bebendo.png --capture-state=e1-water
godot --path . -- --capture=reports/E1-novo-mundo.png --show-new-world --capture-minimum
godot --path . -- --capture=reports/E1-ajuda.png --capture-state=help --capture-minimum
godot --path . -- --capture=reports/E1-laboratorio.png --capture-state=laboratory
```

As capturas E1 usam a mesma cena e os mesmos controles. Os cenários `e1-offer`, `e1-inspector` e `e1-water` são fixtures explícitas: reduzem reservas para observar bebida/ingestão sem esperar muitos minutos; os dois primeiros removem comida concorrente e colocam água perto da seleção. Não deslocam criaturas nem simulam sucesso: os eventos, ganhos e movimento são executados por `world.step`. O inspector rebaixa hidratação depois para exibir o aviso de sede. A captura de expansão posterior confirma +300 à direita e +200 na borda inferior. Evidências e limites em [reports/E1_ui.md](reports/E1_ui.md).

## Estrutura e licenças

| Caminho | Responsabilidade |
|---|---|
| `project.godot`, `scenes/main.tscn` | Configuração e cena inicial |
| `scripts/core/` | RNG, IDs, validação, grade espacial e catálogo `Textos` |
| `scripts/world/`, `scripts/creature/` | Ecossistema e organismos |
| `scripts/behavior/` | Observações, ações e cérebros substituíveis |
| `scripts/evolution/` | Herança, mutações e genealogia |
| `scripts/communication/` | Intenções, respostas, comandos e sinais |
| `scripts/persistence/` | Pontos validados e cópias de segurança |
| `scripts/ui/`, `scripts/render/` | Controles, laboratório, curvas e desenho |
| `assets/external/` | Recursos de terceiros com licenças preservadas |
| `tests/unit/`, `tests/experiments/` | Verificações e experimentos |
| `docs/`, `reports/` | Contratos, missão, resultados e capturas |

Textos de jogador novos ficam em `scripts/core/textos.gd`; o narrador de diálogo tem catálogo em `scripts/communication/dialogo_textos.gd`. Identificadores, chaves JSON e nomes personalizados são preservados. A tradução não reescreve saves.

Consulte [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/ASSET_PROVENANCE.md](docs/ASSET_PROVENANCE.md) e [docs/REUSE_MATRIX.md](docs/REUSE_MATRIX.md). O Godot usa MIT; os sprites Kenney incorporados são CC0. Não há código de terceiros de treinamento rodando no jogo.
