# EvoWorld 2.0 — status por gate

Data: 2026-11-01. Branch de continuação: `evo2/e1-base` (base `main` @ `9c7ba62`). **Nenhum push foi feito**; tudo está em commits locais.
Status geral: **PARTIAL** — E1, E2, E3 e E4 implementados e testados; E5 parcial (robustez, build e FPS medidos; falta tutorial de primeira experiência testado com usuário real e revisão independente por segundo agente de código). Nenhum achado crítico/alto da revisão independente permanece aberto.

## Fatos de verificação (reproduzidos pelo coordenador)
- Testes: `godot --headless --path . -s tests/run_tests.gd` → **exit 0, 16 suítes ok**. Saves v1–v7 carregam (fixtures reais em `tests/fixtures`).
- Holdout E3 reexecutado por mim: números idênticos aos do worker (exit 0). Holdout E4 idem.
- Build Windows: `godot --headless --path . --export-release "Windows Desktop" builds/EvoWorld.exe` → exit 0 (≈110 MB). `builds/EvoWorld.exe --quit-after 400` → exit 0, 0 erros. Modo de captura com caminho absoluto no exe de release → exit 0, 12 criaturas, 111 FPS (`reports/E5-build.png`).
- FPS gráfico real (RTX 2050, 1280×720, 1×): **12 criaturas 111,7 FPS (p95 11,5 ms); 30: 82,5; 60: 68,2; 100: 45,6 (p95 36 ms)**. Meta de 60 FPS a 12 criaturas: atingida. 100 criaturas fica abaixo de 60 FPS.
- CPU (5000 ticks, E1–E4 ativos, `reports/E5_perf*.json`): ≈16 ms/tick médio (p95 ≈ 23 ms), memória estável (~35–56 MB), save de ≈0,8 MB. A 1× há folga (100 ms/tick); a 5× o p95 fica no limite (20 ms).

## E1 — Ecologia: PASS
12 criaturas em mundo novo (`SimWorld.new_world`); `new` e saves antigos mantêm a população anterior. 4 alimentos tipados + legado (fruta, semente, folha, cogumelo; nutrição/hidratação/palatabilidade/toxicidade parametrizados), água real (hidratação, sede, ação beber, evento `drink`), expansão de terreno preservando IDs/posições/RNG, oferta de alimento sem ganho imediato (zero-ganho não conta refeição). Água distinta de terra (bug do tile duplicado corrigido; hash único). Evidências: `reports/E1_sim.md`, `E1_ui.md`, `E1-*.png`.

## E2 — Personalidade: PASS
Drives (fome, sede, fadiga, estímulo, contato), temperamento herdável (curiosidade, cautela, sociabilidade, impulsividade), memória episódica limitada (32), habituação, condicionamento Rescorla–Wagner próprio (preferência por consequência de ingestão), vínculos por encontros, expressão valência/ativação. Memória adquirida **não** é herdada. Testes: mesmos genes + experiências distintas → preferências distintas; 12 perfis em 4 seeds; save/load determinista. UI: abas Corpo/Traços/Memória/Comida/Vínculos, carinho validado por contato, nomes brasileiros. Evidências: `E2_sim.md`, `E2_ui.md`, `E2-*.png`.

## E3 — Ensino: PASS restrito
Habilidades `ir_ate_local` e `buscar_agua`; mostrar/observar/recompensar/reiniciar; recompensa só após conclusão física e nunca altera energia/hidratação/posição. Experimento **pré-registrado em commit anterior** à implementação (18:51 < 18:57 < 19:00), 20 seeds de HOLDOUT inéditas, 5 braços.
HOLDOUT (40 pares): trained_frozen **40/40**, heurística 40/40, naive 0/40, aleatório 1/40, trained_online 31/40 (local 11/20). Frozen vs naive: p≈1,8e-12.
**Ressalvas honestas ([FATO] da revisão independente):** (a) o braço `naive` é degenerado (tabela zero → sempre “frente”), então o ganho de 100 pp é contra “andar sempre em frente”, e o congelado só **reproduz a heurística geométrica** (empate exato), não a supera; (b) o online piora no local (exploração). Não há evidência de que o ensino produza mais que a heurística; há evidência de que a política aprendida substitui um professor determinístico em cenário aberto de 140 passos. Um baseline aleatório não degenerado (uniforme sobre as ações permitidas) já existe no experimento (1/40).
Bug achado e corrigido: ensinar com política `q` anexava um QBrain permanente a criaturas sem cérebro, mudando o comportamento autônomo → agora marcado `teaching_only` e ignorado na decisão autônoma (teste de regressão + persistência).

## E4 — Social e comunicação: PASS restrito (experimental)
[FATO] Familiaridade/afinidade/aversão por encontros, diálogo ancorado (“do que você gosta?”, “o que aprendeu?”, “onde está a água?” com fontes internas e “Não sei”), canal de sinais com selo EXPERIMENTAL. E4 original preservado: **18/20 ativo vs 8/20 desligado vs 10/20 embaralhado**, com 8E/12D e prior “sempre esquerda”; esse resultado não é o teste novo.

[FATO] **Novo M0-B contrabalanceado (02/11/2026): PASS restrito.** Pré-registro separado `33bc81e` e fontes/checkpoint congelados `f7f90f4` antes da abertura única do HOLDOUT. TRAIN/DEV separados; 20 seeds inéditas 263901–263920, cada uma com esquerda e direita (40 episódios por braço). Bebida: **ativo 38/40 vs desligado 20/40 vs embaralhado 20/40 vs uniforme 20/40 vs decoder sem sinal com prior aprendido 20/40**. Ativo por lado: **18/20 esquerda, 20/20 direita**; ganho +45 pp e 18 vitórias/0 derrotas/2 empates POR SEED contra cada controle. Todos os critérios novos passaram; o ganho agregado persistiu após corrigir frequência dos lados e adicionar controles. Detalhes, custos por lado e auditoria: [`M0_social.md`](M0_social.md).

[LACUNA] Emissor com codificador fixo de dois símbolos, decoder aprendido e navegador heurístico em cenário binário com intervenção sensorial. O desligado novo ainda escolhe sempre um lado (direita), mas o teste também supera uniforme e prior TRAIN com desempate uniforme. Não há ganho sobre desligado no lado direito, onde este já acerta 20/20. **Não** se afirma linguagem emergente, significado dos símbolos nem utilidade no ecossistema autônomo.

## E5 — Produto: PARTIAL
Feito: robustez de saves (hostis v1–v7, envelope gzip v2 com limites, reparo por backup, escrita atômica), benchmark CPU/FPS, build exportado, 3+ gerações em mundo novo, tutorial/ajuda pt-BR, UI cuidador/ensinar/laboratório. Pendente: teste de primeira experiência com usuário real; performance a 100 criaturas < 60 FPS; revisão por segundo agente de código (cota dos agentes Codex/AGY esgotada durante parte da execução; a revisão independente foi feita por um subagente Claude sem acesso a execução de Godot — os testes foram rodados por mim).

## Revisão independente (subagente Claude, somente leitura) — achados e destino
Corrigidos neste ciclo: QBrain permanente por ensino (alto), estatística contando política heurística como “aprendeu”, texto pt-BR corrompido (`pr?ximo`), laço base64 caractere a caractere (substituído por regex nativa), `fps-benchmark` gravando em caminho não gravável no exe (agora aviso em vez de crash).
Abertos (médios/baixos): teto de descompressão de 128 MiB sem razão de compressão; TTL de ordens reinicia ao carregar; `preregister_sha256` aponta o arquivo do working tree (não prova ordem de commit — a ordem foi verificada no `git log`); proveniência do holdout social (rodadas dev) não verificável via git; flags de captura de desenvolvimento não restritas a build de debug; baseline social contrabalanceado (resolvido pelo novo M0-B acima); confirmação de implementação “clean-room” do Rescorla–Wagner/habituação (nenhum código do Pestinha foi copiado; implementação própria a partir de fórmulas públicas).

## Orquestração (fatos)
Orca 1.4.245, Run `run_70673bbe1d7a`. Workers: Codex (E1-SIM, E1-UI, E2-SIM, E2-UI, E3-SIM, E3-UI, E4-SIM), Antigravity (REUSE2 com Gemini 3.8 Flash; E4-UI continuação com Claude Opus 5.5; E5 continuação com Claude Sonnet 5.5, interrompido por cota), coordenador Sonnet integrando em `evo2/e1-base`, com conflitos de `textos.gd` resolvidos manualmente (seções aditivas por gate). Codex e AGY esgotaram cotas em momentos distintos; trabalhos parciais foram preservados e reatribuídos.

## Licenças
Pestinha (GPL-3.0-or-later; assets com direitos não confirmados): somente ideias estudadas; ver `docs/PESTINHA_LICENCAS.md`. Assets: Kenney CC0 (Roguelike, Animal, Pixel, Tiny Farm) + originais CC0 em `assets/original/`; registro em `docs/ASSET_PROVENANCE.md`.

## [HIPÓTESE] não demonstradas
Linguagem emergente; superioridade do aprendizado sobre a heurística; adaptação evolutiva medida em 2.0; benefício de rede pulsada (G6 não executado).

## Rollback
Tudo em `evo2/e1-base` (commits locais). `main` permanece em `9c7ba62`. Para voltar: `git checkout main`. Saves v1–v6 continuam carregando; v7 é o formato novo (backup `.bak` mantido pelo `SaveStore`).
