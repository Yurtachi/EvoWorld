# E4-UI — vínculos, conversa com evidências e sinais experimentais

[FATO] **PASS no escopo UI/render.** Data: 01/11/2026. Branch local
`Yurtachi/evo2-e4-ui`, recebida sobre `evo2/e1-base` em
`6b70cdd5614764dc779d2c3e2110fabba6ea67b0`. Identidade Git local Yurtachi,
commit seletivo, sem push e sem trailers de IA. Lidos a especificação
`docs/EVOWORLD_2_SPEC.md` e os relatórios disponíveis E1–E4 SIM/UI/reúso.
Não foram editados caminhos de simulação ou `scripts/persistence`; não houve
cópia de código, textos, pesos ou assets do Pestinha.

## Integração entregue

[FATO] O Cuidador mantém cinco abas; **Social** reúne vínculos e encontros da
seleção. A consulta `world.social_observar` fornece por parceiro ID/nome,
familiaridade, afinidade, aversão, contagem e último passo. O contato com o
cuidador continua separado. Afinidade/aversão são componentes da valência dos
encontros; não se apresentam como emoções medidas. Leitura ou seleção não
criam encontros. Legados sem personalidade recebem a explicação existente;
retirar a seleção apaga os dados anteriores.

[FATO] O histórico mostra até oito episódios de encontro, do mais recente ao
mais antigo, filtrados dos registros limitados do corpo. Contato sem disputa e
disputa por alimento têm descrições em português, ação e variações físicas.
Todos os formatadores agora reconhecem o catálogo e as razões sociais E4;
ações como seguir, evitar, ceder e disputar não aparecem como desconhecidas.

[LACUNA] O episódio social não guarda o ID do parceiro. A tela informa que não
é possível associar cada episódio a um vínculo específico; não se inferem
parceiros por proximidade temporal. O histórico é o que permaneceu na memória,
não um registro ilimitado de toda a vida. Ceder acesso não confirma ingestão
pelo outro corpo, e aproximação não confirma contato.

[FATO] **Conversar com o companheiro** fica acessível acima das abas, com três
atalhos reais: **Do que você gosta?**, **O que aprendeu?**, **Onde está a água?**.
O destino continua sendo o pet, independentemente da seleção no mapa. Resposta,
recibo de leitura e fontes internas são separados. Os rótulos traduzem a fonte,
mantendo o identificador técnico entre parênteses para rastreio; não despejam
dicionários internos em inglês. Fontes vazias aparecem explicitamente.

| Consulta | Evidência apresentada |
|---|---|
| Gostos | `personality.preferences`, alimento e valor aprendido entre −1 e +1; resposta positiva exige valor >0,05. |
| Aprendizado | `ensino.statistics`, sucessos/amostra autônoma e selo real; `personality.episodes`, quantidade retida e limite de inferência. |
| Água | `sense.waters`, ID, margem percebida e passo; `creature.memory`, ausência ou quantidade com ressalva sobre coordenadas. |

[FATO] Sem suporte, aparece **“Não sei; não tenho evidência suficiente nos meus
registros.”** Consultas preservam o snapshot do mundo, não geram ordens nem
marcam o mundo como alterado para autosave. O critério de aprendizado permanece
o real de E3: cinco tentativas autônomas recentes e taxa de pelo menos 70%.
Água vem da percepção atual; retirar água percebida devolve “Não sei”.

[FATO] O Laboratório apresenta **SINAIS · EXPERIMENTAL** e
**LOG · EXPERIMENTAL**, emissor, receptores, contexto observado e decisão após
recepção. Uma mudança mostra ação anterior → posterior; ação igual aparece
como **ação mantida**. Sem receptores ou sem decisão registrada, a ausência é
explícita. Símbolos continuam neutros, e emitir continua sendo intervenção
manual com custo real. O aviso explica que uma sequência temporal não comprova
causalidade no jardim.

[FATO] O painel reproduz honestamente o resultado já publicado em
[E4-SIM](E4_sim.md): bebida em **18/20** episódios com canal ativo, **8/20**
desligado e **10/20** embaralhado, no protocolo pré-registrado. A própria UI
limita a conclusão: **utilidade restrita, encoder fixo, receptor aprendido e
visão experimental; não é linguagem**. O receptor experimental não é instalado
nos pets. Não foi executado novo experimento de eficácia, nem foram alterados
os artefatos de avaliação do coordenador; o resultado anterior G4 conserva seu
escopo original.

[FATO] No mapa, somente o corpo selecionado recebe indicadores sociais:
dois pontos claros com contorno escuro após encontro registrado nos últimos
20 passos; seta pequena na direção corporal durante aproximação/seguimento.
Os indicadores usam vínculos/ação reais, não consomem RNG nem alteram estado.
Não ligam todos os corpos por linhas, não indicam um parceiro presumido e são
omitidos quando o zoom fica abaixo de 0,15. A legenda fica na aba Social.

## Capturas novas e inspeção

[FATO] Todas as imagens abaixo foram geradas nesta entrega a partir da cena
real, sem reutilizar PNGs E1–E3. As dez capturas funcionais usam a janela mínima
**1100×680**, e o benchmark usa **1280×720**.

| Artefato | Inspeção |
|---|---|
| [E4-social.png](E4-social.png) | Nome do parceiro, familiaridade 4%, afinidade 5%, aversão 0%; indicador de encontro na seleção. |
| [E4-aversao.png](E4-aversao.png) | Encontro com disputa produz aversão real de 10%, sem afinidade positiva. |
| [E4-encontros.png](E4-encontros.png) | Histórico, falta de ID do parceiro e legenda, acessíveis pela rolagem. |
| [E4-aproximacao.png](E4-aproximacao.png) | Seta corporal durante aproximação real, antes de existir vínculo. |
| [E4-nao-sei.png](E4-nao-sei.png) | “Não sei” e fonte alimentar vazia. |
| [E4-gostos.png](E4-gostos.png) | Preferência positiva após ingestão física e valor na fonte. |
| [E4-aprendizado.png](E4-aprendizado.png) | Cinco conclusões autônomas, selo e fontes de estatística/episódios. |
| [E4-agua.png](E4-agua.png) | Margem percebida, passo e fontes hídrica/memória. |
| [E4-sinais.png](E4-sinais.png) | Selo EXPERIMENTAL, resultado pré-registrado, escopo e controles. |
| [E4-sinais-log.png](E4-sinais-log.png) | Aviso causal, emissor/receptor, contexto e ação mantida em português. |
| [E4-fps-12.png](E4-fps-12.png) | Jardim com 12 criaturas, mini gráfico e resultado da medição. |

[FATO] Inspeção visual abriu as capturas e conferiu largura, rolagem, contraste
e idioma. Respostas/fontes cabem na conversa mínima. Social e Laboratório usam
rolagem para conteúdo longo; foram capturados tanto o início quanto os trechos
relevantes abaixo. Não há texto funcional em inglês acidental: identificadores
das fontes são rastreabilidade solicitada, “encoder” pertence à ressalva
experimental e EVO WORLD é a marca existente. A captura do log foi ajustada
para não começar com um fragmento da linha anterior.

[FATO] Razões de contraste calculadas a partir das cores sRGB do tema:
texto de evidência `#c8d6c0` sobre `#213a30`: **8,08:1**; ressalva experimental
`#ffdda5` sobre `#213a30`: **9,42:1**; texto das abas `#eeeede` sobre
`#193329`: **11,58:1**; marcador claro `#ffe7ac` contra contorno `#17372b`:
**10,68:1**. Isso verifica essas combinações, não constitui auditoria completa
de acessibilidade, antialiasing ou todos os estados de foco.

[FATO] Os cenários funcionais são fixtures de inspeção, explicitadas no rodapé:
seed 51001, dois corpos próximos, sem obstáculos/reposição/reprodução, visão
completa e perda de pacote zero para reprodutibilidade. O cenário de aproximação
começa com os corpos mais distantes e necessidade de contato elevada. O cenário
de disputa começa com fome e alimento próximo. Encontros, disputa e movimento
são resolvidos por `world.step`; os valores sociais não são escritos pela UI.
Gostos usam alimento ao alcance e ingestão real; o cenário de aprendizado usa
cinco alvos no próprio local e conclusão física pelo ensino. Esses cenários
verificam apresentação e integração, não generalização ou eficácia. Os mundos
normais e carregados não passam por esse preparo. O benchmark usa o jardim
padrão de 12 criaturas, sem a fixture de dois corpos.

## Validação e desempenho

[FATO] Executável Godot 4.7.2 console fornecido no despacho, Windows, render
GL Compatibility, NVIDIA GeForce RTX 2050. Comandos na raiz, substituindo
`godot` pelo caminho desse executável:

| Comando | Resultado |
|---|---|
| `godot --headless --path . -s tests/run_tests.gd` | **exit 0**, 14 arquivos verdes; [log](E4_ui_regression.txt). |
| `godot --headless --path . -s scripts/ui/verify_ui.gd` | **exit 0**, integração completa; [log](E4_ui_tests.txt). |
| `godot --path . -s scripts/ui/verify_ui.gd` | **exit 0**, integração com janela renderizada; [log](E4_ui_graphics_tests.txt). |
| `godot --path . -- --capture=reports/E4-fps-12.png --fps-benchmark=12` | **exit 0**, 12 iniciais e 12 finais; [JSON](E4-fps-12.json). |
| `git diff --check` e `git diff --cached --check` | **exit 0**. |

[FATO] O verificador E4 percorre os botões de perguntas, ausência de evidência,
preferência após ingestão, cinco conclusões autônomas, percepção hídrica e
retirada da água, preservação do snapshot e da marca de autosave, ações/razões
sociais traduzidas, fonte/histórico de encontros, aversão por disputa física,
indicadores, log experimental, save v7 e limpeza de seleção. Confere largura
e tamanho da conversa na janela mínima, além das regressões E1–E3. A execução
gráfica identificou que o verificador lia preferências pessoais antes de usar
seu diretório isolado; agora o caminho de ajustes já é isolado antes do `_ready`.

[FATO] Benchmark gráfico: aquecimento de dois segundos, amostra de **8,005 s**,
**830 quadros**, média **103,68 quadros/s**, **p95 12,652 ms/quadro**, velocidade
1× e passo final 101. O jardim manteve 12 criaturas. Não é benchmark headless;
a imagem e os metadados do adaptador acompanham o JSON. O teste ocorreu sem
outra instância Godot da tarefa em execução.

[HIPOTESE] A medição sugere viabilidade do jardim padrão nesta máquina, sem
garantir desempenho em outro hardware, em populações maiores ou sessões longas.
Não há gate de FPS pré-registrado para este trabalho.

[LACUNA] Permanecem os limites da simulação E4: encoder fixo e cenário sensorial
restrito no experimento, ausência de linguagem emergente demonstrada e ausência
de inferência sobre água oculta. Não houve estudo de usabilidade, revisão visual
independente ou validação em outros monitores; integração/revisão do commit
pertencem ao coordenador. Nenhum dos scripts `ensino_eval.gd`, `learn_eval.gd`
ou `social_eval.gd` foi executado por este worker.

[FATO] Continuação: o worker anterior parou por limite de uso com o trabalho
acima não commitado. Esta retomada revisou o diff completo e as capturas,
corrigiu a concordância “1 encontros” → “1 encontro” na aba Social (com
verificação nova em `verify_ui.gd`), regenerou `E4-social.png`,
`E4-aversao.png` e `E4-encontros.png` e reexecutou testes, verificador headless
e verificador gráfico, todos com exit 0. As demais capturas e o benchmark são
os da execução anterior e foram reinspecionados sem alteração.

[LACUNA] Na captura `E4-sinais-log.png` resta um resíduo de poucos pixels no
topo da área rolável; não corta texto legível. O título “ÚLTIMOS ENCONTROS” usa
o mesmo estilo do corpo de texto, sem destaque visual próprio.

## Reproduzir as capturas

[FATO] Exemplo de captura mínima:

```powershell
godot --path . -- --capture=reports/E4-social.png --capture-state=e4-social --capture-minimum
```

[FATO] Estados disponíveis: `e4-social`, `e4-aversao`, `e4-encontros`,
`e4-approach`, `e4-nao-sei`, `e4-gostos`, `e4-aprendizado`, `e4-agua`,
`e4-sinais` e `e4-sinais-log`. Informe um `--capture=reports/E4-*.png`
correspondente. A rotina usa o mesmo painel, APIs e render do aplicativo,
encerra após a captura e não grava saves do jogador.
