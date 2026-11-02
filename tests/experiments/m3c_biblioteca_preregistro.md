# X6 — biblioteca, fontes e perguntas por lacuna (pré-registro)

[FATO] Protocolo registrado antes do motor/avaliador final e antes da abertura única do holdout. Não executar avaliadores fechados anteriores. Código próprio; nenhum dado da internet.

## Partições e congelamento
Treino: 140101–140104. Desenvolvimento: 140201–140206. Holdout inédito: 140401–140424 (24 seeds pareadas). Cenários construídos por seed, temperamentos e distância inicial variáveis; mesmos parâmetros entre braços. O avaliador e motor serão commitados após este protocolo e antes de abrir holdout. Guardar hashes dos arquivos congelados, commit HEAD e SHA256 deste protocolo no resultado. Exigir worktree limpa e gravar marcador `opened` antes dos ensaios; nunca reabrir arquivo existente. Alterações após resultados exigem novo experimento.

## Cenário e medidas
Cada mundo contém uma criatura com mente, sem reprodução/regeneração, sem comandos, necessidades não críticas e cápsula aversiva cuja aparência não revela efeitos. Livro verdadeiro avisa que cápsulas podem causar dano (conselho conservador por categoria); livro enganoso recomenda aproximação segura. A categoria não distingue variantes de cápsula, portanto não se afirma discriminação do tipo oculto. Leitura exige aproximação e oito ticks distintos por página. Registrar páginas, ticks, contatos e escolhas físicas reais, sem considerar texto armazenado como compreensão.

H-a: após leitura autônoma de livro verdadeiro, pelo menos 75% dos seeds evitam contato aversivo durante 48 ticks de prova, com vantagem pareada de pelo menos 0,5 na fração de seeds sobre sem livro. O braço sem livro recebe mesmo período de preparação sem objeto. Prova apresenta objeto novo a 8–12 unidades, sem instrução de investigação. Não realimentar metabolismo durante a prova.

H-b: livro enganoso provoca contato real em pelo menos 75% dos seeds; a confiança na fonte e no fato cai pelo menos 0,25 após dano. Em prova posterior com outra cápsula da mesma categoria, pelo menos 75% evitam novo contato, convergindo ao braço verdadeiro. Registrar antes/depois e evidência medida; não fabricar experiência.

H-c: lacuna observável associada a objetivo não resolvido gera pergunta em pelo menos 75% dos seeds; controle com categoria já conhecida e controle sem objeto/lacuna têm taxa zero, com uma pergunta máxima por contexto e cooldown de 180 ticks. Controle aleatório independente tenta perguntar a cada tick com probabilidade 1/180, por 48 ticks; relatar taxa por condição e falsos positivos, sem usar esse controle como prova de causalidade.

H-d: responder pergunta existente com opção conservadora registra fonte `cuidador`, confiança estritamente entre 0 e 1 dependente de temperamento/histórico; pelo menos 75% das respostas são aceitas e persistem no save/load. Recusa/silêncio permitidos e contados; nunca converter fonte em observado/interagido. Experiência contraditória reduz confiança (teste separado quando resposta aceitar afirmação segura).

H-e: ablação de memória desliga codificação/consulta do conhecimento e elimina vantagem do livro: diferença absoluta na taxa de evitar entre livro verdadeiro sem memória e sem livro <=0,1. Nenhum módulo cognitivo altera energia/hidratação/posição. Verificar retenção por roundtrip e continuação determinista em unitários.

## Símbolos e critérios globais
Pequeno conjunto de três glifos discretos (`anel`, `barra`, `onda`) associado a categorias (`capsula`, `pedra`, `quadro`) por demonstração com feedback correto/incorreto. Ensinar duas associações em cada criatura; terceira associação é holdout e deve retornar desconhecida, sem generalização inventada. Avaliar associação em novas instâncias/contextos dos glifos ensinados e glifo não demonstrado; reportar precisão, cobertura e rejeição do desconhecido. Isso não constitui escrita, leitura livre nem linguagem geral.

PASS exige H-a até H-e; PARTIAL se ao menos três passarem; FAIL caso contrário. Símbolos são medida secundária, não resgate das hipóteses. Relatar denominadores e resultados por seed, inclusive falhas, sem ajustar limiares. CPU: medir step por 240 ticks em 12/30/60/100 criaturas com mente, livros e objetos; mediana/p95 em ms por tick, sem confundir com FPS gráfico.
