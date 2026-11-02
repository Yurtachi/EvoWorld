# EvoWorld 3.0 — especificação (indivíduos digitais autônomos)

Base: branch local `evo2/e1-base` @ `7c6ea98` (2.0, não publicada). Sem push/merge sem autorização. Offline, pt-BR. Godot 4.7.2.
Estudo das referências e licenças: `docs/EVOWORLD_3_REUSE.md` (GPL: Dosidicus 2.0-only, Pestinha 3.0+ → só ideias, nenhuma cópia).

## Princípio
A métrica de produto é **mudança comportamental persistente causada por experiência** e **iniciativa não comandada**, não volume de sistemas. Emoções = *estados afetivos computacionais simulados*, sem alegação de consciência. Toda frase “aprendeu/sentiu/pensou” na UX precisa de estado + evento + teste que a sustente; o Laboratório mostra a prova.

## Status das capacidades (`confirmado | previsto | experimental`)
| Capacidade | Estado |
|---|---|
| Física, genética, reprodução, água, alimentos, expansão, saves v1–v7 | confirmado (2.0) |
| Drives, temperamento, memória episódica, vínculos, expressão valência/ativação | confirmado (2.0) |
| Ensino `ir_ate_local`/`buscar_agua` (reproduz heurística; não a supera) | confirmado, restrito |
| Canal de sinais (utilidade restrita; viés de lados em revisão M0) | experimental |
| Afetos específicos, motivação endógena, privacidade/solidão, iniciativa, objetos novos | previsto M1–M2 |
| Perguntas por lacuna, quadro, biblioteca, mini terminal DSL, LLM opcional | previsto M3–M6 |

## Arquitetura cognitiva (módulos por criatura; `SimWorld.step()` continua sem LLM)
```
sensores + eventos verdadeiros + necessidades
  -> Afetos (estados com causa, decaimento, memória)
  -> Memória (episódios, fatos com fonte/confiança, objetos conhecidos, relações)
  -> Motivação (candidatos de objetivo pontuados; compromisso; justificativa)
  -> Planejador leve (poucos passos, falha e replanejamento)
  -> Execução física segura (ações do catálogo, sujeitas à física/custos)
  -> Consequências observadas -> atualização de memória/política com proveniência
```
Pastas: `scripts/mind/` (affect, motivation, objects, mind_log), reutilizando `scripts/behavior/personality.gd`, `scripts/social/`, `scripts/interaction/`. Um escritor por caminho. Integração sequencial em `evo3/*`.

## Contratos do M1 (indivíduo crível)
1. **Afetos** (`creature.mind.affect`, [0,1], todos com `cause_log` curto): `frustracao`, `tranquilidade`, `entusiasmo`, `receio`, `solidao`, `satisfacao`, `saturacao_social`. Cada atualização registra `{tick, estado, delta, causa}`; ganhos/decaimentos dependem do temperamento (cautela, sociabilidade, impulsividade, curiosidade); nenhum afeto altera energia/hidratação/posição diretamente — só a escolha de ações e a expressão. Flag de ablação `affect_enabled` (padrão true em mundos novos; saves antigos desativam).
2. **Motivação endógena**: candidatos {comer, beber, descansar, explorar, buscar_companhia, buscar_privacidade, brincar, investigar_objeto}. Pontuação = urgência fisiológica + modulação afetiva + viés de memória (recência + relevância + importância, padrão de agentes generativos, implementação própria) + temperamento + ruído semeado. Objetivo ativo tem **compromisso mínimo** (anti-oscilação) e **tempo máximo** (anti-loop); fome/sede críticas sempre prevalecem. Cada troca grava `mind_log {tick, objetivo, pontuacoes, motivo}`.
3. **Sociabilidade individual**: busca de contato e saturação social independentes; familiaridade/confiança/conflito por criatura (reusa `bonds` E2/E4), de modo que a mesma presença agrade a A e estresse B. Ninguém é obrigatoriamente amigo/agressivo.
4. **Persistência**: afetos, objetivo atual, `mind_log` limitado e memória de objetos entram no save com versão nova **somente** se o schema mudar; migração idempotente, limites, rejeição de NaN/tipos; backup/rollback do `SaveStore`.
5. **UX**: modo `Convivência` mostra desejo atual e emoção legíveis em pt-BR (“parece buscar companhia”, nunca “sente”), ícones/postura proporcionais; `Laboratório` mostra causas, pontuações, log, ablação. Texto só via `Textos`.
6. **Criatura principal**: autonomia observável priorizada para o pet; demais ganham o mesmo motor depois (custo CPU medido a 12/30/60/100).

## Experimentos obrigatórios (pré-registro **antes** do holdout; falsificáveis; ablações)
- **X1 Isolamento vs companhia**: dois perfis/experiências distintos, recursos e ameaças fixos, companhia oferecida; medir proporção de tempo em contato; persiste após save/load; ablação de afeto/memória remove o efeito.
- **X2 Frustração**: obstáculos objetivos repetidos aumentam `frustracao`, mudam probabilidades de ação/expressão; cai ao mudar a circunstância; ablação elimina.
- **X3 Curiosidade (M2)**: objeto novo, sem comandos; investigação por iniciativa em ensaios apropriados; habituação reduz novidade; hipóteses que falharem são reportadas.
- Seeds de treino e holdout disjuntas; mesmas seeds pareadas entre braços; baselines simples (aleatório, heurística, sem memória, sem afeto); relatório em `reports/EVOWORLD_3_EXPERIMENTS.md`.

## Segurança
Sem shell, rede, `eval`, arquivos reais ou LLM no ciclo biológico. Mini terminal (M4) = DSL fictícia com parser/AST e catálogo versionado, testes com entradas hostis. LLM só opcional, por evento, sem criar fatos/ações; desligado por padrão.

## Ownership e Git
Workers em worktrees próprias; um revisor que não escreveu o patch; revisão dinâmica executa os testes. Commits locais seletivos, sem trailers de IA, sem reset/clean/force.
