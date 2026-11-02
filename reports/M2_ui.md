# M2 — objetos, iniciativa e memória na interface real

[FATO] Data: 02/11/2026. Base `evo3/integration` @ `adce378`, branch local
`Yurtachi/evo3-m2-ui`. Interface, regressão e captura gráfica: PASS.
Sem push/merge, código GPL, mudança no motor congelado ou execução de `*_eval`.

## Entrega e fronteira de conhecimento

[FATO] **Objeto** na barra inferior e **Apresentar objeto novo** na Convivência
abrem o catálogo. As quatro opções chamam `world.place_object` com
`capsula_neutra`, `capsula_agradavel`, `capsula_aversiva` ou `pedra`.
As cápsulas aparecem como lotes A/B/C, sem indicar consequências. Confirmar
seleciona a ferramenta; clicar no mapa coloca o objeto sem mover a criatura,
alterar seu corpo ou atribuir um objetivo. Fechar o catálogo mantém a ferramenta
anterior; atalhos de reprodução/câmera ficam suspensos enquanto ele está aberto.

[FATO] O desenho recebe exclusivamente `ObjectCatalog.appearance(row)`:
ID, posição, categoria e aparência públicas. Cápsulas têm os mesmos pixels,
cor clara, contorno escuro e costura central. A pedra investigável é angular
e distinta do obstáculo de **+ Rocha**. Os IDs são curtos para evitar a
sobreposição encontrada na primeira inspeção. Nenhum efeito oculto participa
do desenho ou da interpretação da reação.

[FATO] **Diante dos objetos** usa percepção atual e `mind_snapshot()` individual.
Mostra interesse, cautela, habituação ou ausência de percepção, em pt-BR.
**Ação física** traduz `seek_object` e `investigate_object`; a UI não executa
aproximação nem contato. O balão e o Laboratório traduzem
`mind.iniciativa.novidade`, `.lacuna`, `.evento` e a causa `object_contact`.
O motivo `.evento` continua reservado no motor; só sua tradução foi verificada.

[HIPOTESE] As frases são uma interpretação de apresentação, não um novo
estado mental: prioriza-se o alvo visível; sem alvo, o objeto visível de maior
novidade. Cautela aparece com risco aprendido >0,1 ou receio ativo >0,4;
habituação aparece com novidade <0,4. Interesse depende do objetivo real de
investigação. Receio global pode ter outra causa; a frase não prova que aquele
objeto causou o receio. A ação física é apresentada separadamente.

[FATO] A projeção de novidade é somente leitura, com a mesma equação do motor,
incluindo familiaridade da categoria, recuperação parcial e ablação de memória.
O verificador compara essa projeção à consulta real de `ObjectMemory.novelty`.
A percepção é atualizada por passo/seleção/quantidade de objetos ou obstáculos,
evitando reconstruí-la a cada quadro. Estilos de cápsula são reutilizados.

[FATO] O Laboratório mostra até seis instâncias recentes, com fonte
**observado/interagido**, confiança, validade da observação, novidade,
familiaridade, hipótese por categoria e evidência física separada. Contatos
mostram passo, Δenergia, Δhidratação, toxicidade e surpresa. O prazo da evidência
é separado da validade renovada pela visão. Categorias mostram fonte, valor
aprendido, confiança, contatos e familiaridade; observar não inventa evidência.

[FATO] **Memória M1 ativa** também controla a memória M2 da seleção.
**Curiosidade por objetos ativa** altera `objects.curiosity_enabled` pela
intervenção explícita. Um aviso explica aquisição/uso de memória, termo de
curiosidade, escolhas futuras, persistência e conservação dos registros e do
intervalo físico entre contatos. Registros ficam marcados como históricos
quando memória está desligada. As flags, objetos e memórias sobrevivem ao
save/load real v9; selecionar outra criatura não transfere conhecimento.

[FATO] A etapa 4/5 de **Primeiros 20 minutos** agora orienta: apresentar um
objeto novo no campo visual, iniciar em 1× e esperar sem comandar. Explica
hesitação, prioridade de fome/sede e ausência de investigação garantida.
Todos os textos novos de jogador estão em `scripts/core/textos.gd`.

## Verificação executada

[FATO] Godot console 4.7.2 indicado no despacho, GL Compatibility, Windows,
NVIDIA GeForce RTX 2050, driver 610.62. Comandos reais:

```text
godot --headless --path . -s tests/run_tests.gd
19 suítes: ok; exit 0; sem FAIL/SCRIPT ERROR
Log: reports/M2-ui-tests.txt

godot --headless --path . -s scripts/ui/verify_ui.gd
Integração da UI: ok; exit 0
Log: reports/M2-ui-verification.txt

godot --path . -s scripts/ui/verify_ui.gd
Integração da UI: ok; exit 0
Log: reports/M2-ui-graphics.txt
```

[FATO] O verificador mantém E1–E4/M1 e acrescenta os quatro lotes pelo
controle real, aparência pública indistinguível, preservação de corpo/mente
ao colocar, leitura imutável, bloqueio de atalhos no catálogo, aproximação e
contato sem ordem, fonte/confiança/validade/evidência, novidade, habituação por
contatos reais, cautela após histórico adverso, ablações, save/load v9, tradução
dos três motivos, roteiro, limpeza de seleção e largura mínima 1100×680.
Uma expectativa inicial de duas casas decimais foi corrigida para usar o
formatador da UI; a execução final passou nos dois modos.

## Capturas novas e inspeção visual

[FATO] Todas as imagens abaixo foram renderizadas pela cena real deste build;
nenhuma imagem antiga foi reutilizada ou editada. Capturas de inspeção usam
1100×680; o benchmark usa 1280×720. Reprodução com caminhos absolutos no README.

| Captura | Evidência observada |
| --- | --- |
| [M2-objeto-novo.png](M2-objeto-novo.png) | Passo 0; cápsula colocada, sem objetivo atribuído |
| [M2-aproximando.png](M2-aproximando.png) | Passo 1; `seek_object`, 3 unidades percorridas, iniciativa por novidade |
| [M2-investigando.png](M2-investigando.png) | Passo 5; `investigate_object`, 12 unidades percorridas, contato real |
| [M2-habituado.png](M2-habituado.png) | Passo 1449; explora, expressão de perda de interesse |
| [M2-historico-aversivo.png](M2-historico-aversivo.png) | Memória observada sem evidência e contato anterior com Δenergia −4,60/Δhidratação −2,00 |
| [M2-cauteloso.png](M2-cauteloso.png) | Mesmo histórico adverso na Convivência; cautela, repouso, sem deslocamento no passo observado |
| [M2-memoria.png](M2-memoria.png) | Fonte observado/interagido, confiança, validade, hipótese e evidência separadas |
| [M2-laboratorio.png](M2-laboratorio.png) | Objetivo e razão da iniciativa; controles da seleção |
| [M2-ablacoes.png](M2-ablacoes.png) | Memória/curiosidade desligadas e aviso explícito |
| [M2-catalogo.png](M2-catalogo.png) | Catálogo sem revelar efeitos ocultos |
| [M2-tutorial.png](M2-tutorial.png) | Roteiro de objeto novo e espera sem comandos |
| [M2-fps-12.png](M2-fps-12.png) | Cena gráfica com 12 criaturas, três objetos, mente só no pet e gráfico de FPS |

[FATO] As fixtures usam seed de UI 81102, um pet com curiosidade 0,9,
cautela 0,8, sociabilidade 0,2, impulsividade 0,3, visão 360°, velocidade 30 e
reservas iniciais altas. O objeto novo fica a 24 unidades. Não há ordens,
ensino, teleporte ou atribuição de objetivo. Movimento e contato vêm de
`world.step()`. Nas capturas de histórico, oito contatos físicos prévios
ocorrem com objeto a 13 unidades: avança-se somente o relógio em 181 passos
entre aquisições e restauram-se reservas antes/depois para isolar a apresentação
de urgências fisiológicas. Não se reescrevem afetos ou memórias.

[FATO] Inspeção visual: seis ferramentas cabem na janela mínima; catálogo e
tutorial cabem sem cortar conteúdo; os textos novos estão em pt-BR, sem chaves
internas ou inglês expostos. As linhas de interesse e ação permanecem visíveis.
Conteúdo longo usa rolagem vertical deliberada; não há corte horizontal nos
painéis de memória. Os rótulos longos dos objetos e o rodapé de FPS em duas
linhas foram corrigidos e recapturados. Nomes/indicadores podem se sobrepor a
um objeto no alcance de contato; os IDs de objeto continuam legíveis nas
capturas de histórico.

[FATO] Contraste calculado entre cores sólidas de texto/fundo: texto M2
`#c8d6c0` sobre `#213a30` = 8,08:1; aviso `#ffdda5` = 9,42:1; botões normais
`#ebeede` sobre `#354e42` = 7,68:1; botões ativos `#213a30` sobre `#d5deaa`
= 8,68:1. Cápsula clara sobre terreno = 4,12:1, além do contorno escuro.
Essas razões não medem todos os pixels com textura/antialiasing da imagem.

## FPS gráfico — 12 criaturas e três objetos

[FATO] Medição serial sem outro Godot deste worker, cena real, seed 7421,
1×, 2 s de aquecimento e 8,006698 s de coleta, 850 quadros. Resultado final
em [M2-fps-12.json](M2-fps-12.json):

| Condição | Resultado |
| --- | --- |
| População inicial/final | 12 / 12 |
| Objetos físicos | 3 |
| Mentes ativas / pet ativo | 1 / sim |
| Janela / renderer | 1280×720 / GL Compatibility |
| Média | 106,16 quadros/s |
| p95 de duração | 12,176 ms/quadro |
| Passo ao terminar | 101 |

[FATO] A coleta anterior foi 107,53 quadros/s, p95 12,251 ms. A segunda
substituiu o artefato depois da correção do rodapé cortado; o dado conservado
é o da imagem final, sem escolha pelo FPS mais alto. Nenhum `*_eval` foi rodado
e nenhum JSON científico anterior foi alterado.

[LACUNA] As capturas são fixtures de apresentação, não repetição do holdout
X3 nem demonstração de iniciativa em toda ecologia. O preparo de histórico
não é vida livre. Cautela/habituação são interpretações locais com limiares
de apresentação; uma categoria visual pode generalizar consequências.
O benchmark é curto, depende de hardware/carga e não estabelece margem para
5×, muitas mentes ou centenas de objetos. Revisão independente e integração
ficam com a coordenação; este worker não publicou nem integrou a branch.
