# EvoWorld 2.0 — especificação (continuação do repositório existente)

Base: `main` @ `9c7ba62`. Branch de continuação: `evo2/*`. Sem push sem autorização expressa. Godot 4.7.2, GDScript, offline, pt-BR.

## Origem das ideias e licença (Pestinha)
- Fonte de estudo: https://github.com/mille-okws/pestinha (GPL-3.0-or-later; imagens/textos com direitos não confirmados). Referência de **ideias** apenas: homeostase, habituação, memória episódica, condicionamento (Rescorla–Wagner), reforço, tendências neurais restritas pela física, perfil individual persistente.
- **Nada** do código, dos pesos, dos textos ou dos assets do Pestinha entra neste repositório. Implementação própria em GDScript, guiada por requisitos. Registro em `docs/ASSET_PROVENANCE.md`.
- Arquitetura de comportamento escolhida: **A+B** (motivação + memória episódica sobre o `brain` atual, Q-learning estendido a água/alimentos). Opção C (rede pulsada) só como pesquisa isolada se A+B falharem.

## Invariantes
1. `SimWorld` continua `RefCounted`, tick fixo 0,1 s, RNG semeado único, determinismo por seed.
2. Saves antigos (v1/v2/v3) carregam; nova versão só se o schema mudar, com migração idempotente, backup e rejeição de NaN/inf.
3. Reforço/recompensa **nunca** adiciona energia, sede ou posição. Só ações físicas (comer, beber, andar) alteram estados fisiológicos.
4. Fome/sede acima do limiar suspendem ordens do jogador (bugfix de `Comandos` preservado).
5. Texto ao jogador só via `scripts/core/textos.gd`, em pt-BR; identificadores e chaves JSON permanecem em inglês estável.
6. Expressão visual deriva de estado real; nada de “sente/entende”. Usar “aparenta”.
7. População: 12 iniciais **só em novos mundos** (padrão); seletor existente e saves antigos mantêm seus valores. Teto configurável validado.

## E1 — contratos
- `food_type` ∈ {`legacy`, `fruta`, `semente`, `folha`, `cogumelo`}; parâmetros (nutrição, hidratação, palatabilidade, toxicidade) em tabela única e documentada (valores fictícios da simulação). Comida antiga migra para `legacy` com a semântica de energia anterior.
- Água: células/regiões de água reais (não colisão sólida para beber na margem), `hydration` por criatura, sede, ação `beber` com alcance, perda de hidratação por metabolismo, eventos `drink`. Água visível distinta de terra.
- Expandir terreno: `world.expand(side, amount)` por borda direita/inferior (e esquerda/superior só com deslocamento migrado explicitamente); coordenadas, IDs, RNG, genealogia preservados; nunca encolhe sobre criaturas.
- Oferecer alimento: efeito somente após criatura aproximar, avaliar e ingerir; ingestão de ganho zero não conta como refeição.

## Ownership
- SIM (scripts/world, creature, behavior, environment, evolution, core exceto textos): um escritor por vez.
- UI (scripts/ui, scripts/render, textos.gd, README): um escritor por vez.
- Integração sequencial no branch `evo2/*`, testes completos a cada merge.

## Gates e relatórios
E1 ecologia · E2 personalidade · E3 ensino · E4 social · E5 produto. Relatório por gate em `reports/E*.md`; consolidado em `reports/EVOWORLD_2_STATUS.md` com `[FATO]/[HIPÓTESE]/[LACUNA]` e `PASS/PARTIAL/BLOCKED`.
