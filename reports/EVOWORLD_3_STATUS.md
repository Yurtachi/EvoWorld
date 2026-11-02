# EvoWorld 3.0 — status final desta rodada

Data: 2026-11-02. Branch: `evo3/integration` (a partir de `evo2/e1-base` @ `7c6ea98`). `main` preservada em `9c7ba62`. **Nenhum push, merge em `main`, force ou reset foi feito por esta rodada.** Sem Colab, sem LLM, sem API externa: o jogo roda 100% local.

**Status geral: PARTIAL.** M0–M4 e M5 implementados, integrados, testados e revisados de forma independente. **O 3.0 não está concluído** porque vários marcos científicos obrigatórios terminaram em PARTIAL ou FAIL (abaixo) e a aprendizagem cultural, a seleção e o aceite visual manual completo ficaram pendentes.

## Fatos verificados pelo coordenador
- Testes: `godot --headless --path . -s tests/run_tests.gd` → **exit 0, 25 suítes ok, sem SCRIPT ERROR**. `bash tests/experiments/verify_prereg.sh` → exit 0 (ordem pré-registro → motor → holdout para E3, E4, M0-B, M1, M1b, M2, M3, M3b, M3c, M4b, M5).
- Save: **v14**; v1–v14 carregam (fixtures reais e fuzz de ≥30 mil mutações hostis nas revisões, 0 aceitações indevidas relevantes). Limite de descompressão com razão máxima; backup/rollback do `SaveStore`.
- Build Windows: `godot --headless --path . --export-release "Windows Desktop" builds/EvoWorld.exe` → exit 0 (≈110 MB); executa e fecha com `--quit-after` sem erro; flags de captura recusadas em release.
- FPS real (RTX 2050, 1280×720, 1×, mente no pet): **12 criaturas ≈101; 30 ≈74; 60 ≈47; 100 ≈32**. Meta de 60 FPS a 12 criaturas atingida; 60 e 100 ficam abaixo (custo cresce com população; a mente fica só no pet por padrão).
- Revisões independentes **dinâmicas** (executam suíte, fuzz, ataques, release): M0–M2, M3, M3c+M4, M5. Nenhuma com achado alto ou crítico; todos os médios de integridade foram corrigidos; os médios científicos viraram reclassificações abaixo.
- Segurança: terminal fictício sem shell/PowerShell/CMD/arquivo/rede/processo; varredura de APIs proibidas limpa; 1078 casos hostis do módulo + 306 ataques de revisor externa → zero chamadas indevidas.

## Marcos
| Marco | Implementado | Integrado | Testado | Aprovação científica |
|---|---|---|---|---|
| M0 integridade + estudo das referências | sim | sim | sim | PASS (saves, TTL, descompressão, auditoria de pré-registro); social balanceado PASS restrito |
| M1 afetos, motivação, memória | sim | sim | sim | PARTIAL (X1/X2); X1b PASS restrito; X2b PARTIAL |
| M2 curiosidade e objetos | sim | sim | sim | PASS restrito (X3, cenário controlado) |
| M3 ateliê (quadro, traços reais, galeria) | sim | sim | sim | X4 PARTIAL; **X5 FAIL** (não copia formas novas) |
| M3c biblioteca, conhecimento, perguntas | sim | sim | sim | PASS restrito (X6; regra direta) |
| M4 terminal fictício seguro | sim | sim | sim | **X7 FAIL global** (programa fixo vence; 3 falhas de save achadas pós-holdout, corrigidas) |
| M5 convivência, herança, reprodução voluntária | sim | sim | sim | **X8 PARTIAL** (aleatório supera completo; sem_afeto = completo) |
| M6 LLM/Colab | — | — | — | **NOT_IMPLEMENTED por decisão** (nenhum experimento exige GPU/LLM) |

Detalhe numérico: `reports/EVOWORLD_3_EXPERIMENTS.md`. Roteiro manual: `docs/ACEITE_MANUAL_3_0.md`. Referências/licenças: `docs/EVOWORLD_3_REUSE.md`, `docs/PESTINHA_LICENCAS.md`. Spec: `docs/EVOWORLD_3_SPEC.md`.

## Experiências de aceite do Goal (F1–F8) — estado real
1. **Isolamento vs companhia:** PARTIAL. Perfis/experiências divergem e persistem após save; o efeito do afeto só foi isolado no X1b.
2. **Frustração real:** PARTIAL. Afeto causal e recupera; mudança de ação física em 4/20.
3. **Curiosidade autoiniciada:** PASS restrito (X3).
4. **Pergunta por lacuna:** PASS restrito (X6 H-c); sem LLM; “o cuidador disse” é fato atribuído.
5. **Quadro verdadeiro:** traços reais, persistência e galeria: sim. **Cópia por observação: não demonstrada (FAIL).**
6. **Biblioteca e terminal de brinquedo:** ler e praticar comandos na DSL: sim; segurança testada com entradas hostis: sim; **aprender além de uma solução roteirizada: não demonstrado.**
7. **Vínculo e convivência:** parcialmente; regra direta sobre o vínculo; sem demonstração de aprendizado de estratégia social.
8. **Resiliência:** tudo jogável offline sem LLM; UI rotula estados como “parece/aparenta” e estados computacionais simulados.

## [HIPÓTESE] / [LACUNA]
- [HIPÓTESE] Com tarefa que exija coordenação real (informação assimétrica ecológica) ou formas mais complexas, a cópia e o terminal poderiam se beneficiar de aprendizado; não demonstrado.
- [LACUNA] Aprendizagem cultural por observação de outro organismo (E3.7): prevista, não implementada. Experimento de **seleção** (adaptação) não feito. Braços aleatório e sem_afeto do X8 com avaliação efetiva. Aceite visual manual completo de 20 minutos por usuário real não executado.
- [LACUNA] Custo de CPU alto com mente em muitas criaturas (51 ms/tick a 100 criaturas com mente em todas, M1b).

## Pendências por gravidade
- **Média:** (1) X8: reescrever o desenho com controles que não zerem por construção, incluindo `sem_afeto` distinto e braço aleatório inferior ao completo; (2) X5/X7: novo protocolo com tarefa que exija aprendizado (hoje um servo/programa fixo resolve); (3) performance a 60–100 criaturas (otimizar `Personality.advance`, sensores de objetos/livros); (4) aprendizagem cultural e seleção.
- **Baixa:** `.uid` novos precisam ser versionados a cada rodada; alguns textos de relatórios de workers citam valores desatualizados (mutation_scale 0,05 vs 0,025); tolerância do H-e no X8 (0,35 vs 3σ).

## Commits e rollback
Histórico em `evo3/integration` (merges `--no-ff` por worker, commits de pré-registro separados dos de motor e de resultado). Rollback: `git checkout main` (1.0) ou `git checkout evo2/e1-base` (2.0). Saves v1–v13 migram; o `.bak` do `SaveStore` é mantido.

## Próximas recomendações (por prioridade)
1. Fechar o aceite manual de 20 minutos com você jogando e ajustar a UX (texto, ritmo, legibilidade).
2. Redesenhar X8 e um novo X9 de aprendizagem social ecológica (informação assimétrica real).
3. Tarefa de cópia de forma com demonstração por imitação onde servo geométrico não resolva (ex.: formas arbitrárias vistas uma vez).
4. Otimização de CPU antes de ativar mente em todas as criaturas.
5. Só então avaliar LLM local opcional (Ollama) como camada expressiva, desligado por padrão.
