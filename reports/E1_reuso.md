# Relatório de Execução: REUSE2 (Fase E1 — Ecologia e Reúso)

**Data:** 01 de novembro de 2026  
**Worker / Responsável:** REUSE2 (Yurtachi)  
**Branch de Trabalho:** `Yurtachi/evo2-reuse`  
**Escopo Autorizado:** `assets/`, `docs/ASSET_PROVENANCE.md`, `docs/PESTINHA_LICENCAS.md`, `reports/E1_reuso.md` (com proibição estrita de edições em `scripts/`).  
**Status do Gate:** **PASS**

---

## 1. Resumo Executivo

O worker REUSE2 concluiu integralmente os três objetivos estabelecidos para a prontidão de assets, proveniência e auditoria jurídica na transição para o marco E1 do EvoWorld 2.0:

1. **Estudo de Licenças e Arquitetura do Pestinha (`docs/PESTINHA_LICENCAS.md`):** Realizada análise somente-leitura e elaborado parecer detalhado comprovando que o código-fonte está sob GPL-3.0-or-later e que os assets possuem direitos incertos/não confirmados, vedando qualquer cópia literal. Foi redigida síntese conceitual original dos mecanismos de homeostase, habituação, condicionamento Rescorla-Wagner, memória episódica, plasticidade por 3 fatores e separação entre invariantes físicas fixas e comportamento plástico aprendido, delimitando a fronteira de reimplementação limpa em GDScript.
2. **Correção do Tile de Água e Terra (`dirt.png` / `water.png`):** Identificado e solucionado o bug de fatiamento no atlas Kenney Roguelike. O tile `dirt.png` (que estava amostrando água ciano em col=3, row=1) foi re-fatiado para a célula de solo marrom (col=6, row=4), e `water.png` mantido em água pura (col=0, row=0), eliminando a duplicidade de hashes. Em complemento, foi criada a pasta `assets/original/` com tile de água original 16×16, spritesheet de lago/poça 48×48 e cogumelo silvestre 16×16, todos com licença CC0 1.0 Universal declarada formalmente. A aparente duplicação de `white01/10/20` no Pixel Pack foi tecnicamente esclarecida como característica de 1x1 pixels idênticos no lançamento comemorativo upstream da Kenney de 2019.
3. **Fontes Oficiais CC0 para Contratos de Alimento E1 (`assets/external/kenney/tiny-farm/`):** Pesquisadas fontes públicas CC0 para suprir as categorias de alimentos do contrato E1 (`fruta`, `semente`, `folha`, `cogumelo`). Foram catalogados 10 pacotes candidatos com URLs, licenças e hashes criptográficos SHA256. Foi baixado em nova pasta (`assets/external/kenney/tiny-farm/`) um subset estritamente necessário de 6 sprites 16×16 do pacote oficial *Kenney Tiny Farm* (CC0), provendo morangos, cenouras, sementes de trigo, sementes plantadas, folhas de repolho e brotos vegetais.

---

## 2. Detalhamento dos Resultados por Pilar

### Pilar 1: Auditoria Jurídica e Conceitual do Pestinha
- **Documento Produzido:** `docs/PESTINHA_LICENCAS.md` (redigido integralmente em português pt-BR).
- **Licença do Código:** GPL-3.0-or-later. Identificado o risco crítico de contaminação por copyleft forte sobre a distribuição do EvoWorld caso trechos de código fossem copiados.
- **Direitos dos Assets:** O próprio autor do Pestinha declara em `README.md` e `assets/LEIA-ME.txt` que os arquivos de mídia não possuem direitos confirmados para redistribuição pública segura.
- **Síntese dos Mecanismos:** Descrição técnica elaborada do zero (sem trechos de código) cobrindo:
  - *Homeostase:* Regulação contínua de energia, estimulação e contato social por interocepção que envia sinais moduladores à rede;
  - *Habituação:* Depressão na transmissão dos canais de entrada a cada pulso sensorial, recuperando-se assintoticamente no repouso;
  - *Condicionamento Rescorla-Wagner:* Aprendizado associativo clássico entre pistas antecedentes (*cues*) e desfechos, com extinção na ausência do reforço e canal antecipatório para decisões evasivas ou de alerta;
  - *Memória Episódica:* Registro de episódios (contexto, ação, resultado, valência) associado a um bandit contextual com exploração $\epsilon$-greedy, consolidação durante o sono e atribuição retroativa de culpa caso haja punição imediata;
  - *Plasticidade com Recompensa:* Regra de plasticidade de três fatores associando atividade pré-sináptica elegível temporariamente, sinal pós-sináptico e neuromodulador global escalar de reforço/afeto;
  - *Fixo vs. Aprendido:* Demarcação rígida entre física, colisões, limiares vitais basais e supressão de comandos por sobrevivência (invariantes fixas inegociáveis) versus expectativas e valências de ação (plásticas e dependentes de experiência).
- **Fronteira de Reimplementação:** Estabelecida a permissão de reimplementação *clean-room* dos modelos matemáticos abertos em GDScript nativo para o simulador `SimWorld`, proibindo taxativamente qualquer transferência de código, pesos pré-treinados, diálogos, memes ou imagens.

### Pilar 2: Correção de Fatiamento e Criação de Assets Originais
- **Bug de Fatiamento Corrigido:**
  - `assets/external/kenney/roguelike-rpg-pack/tiles/terrain/dirt.png`: Re-fatiado para col=6, row=4 (coordenadas x=102, y=68 no atlas `roguelikeSheet_transparent.png`). Novo tamanho: 197 bytes. Novo SHA256: `4CAE6A68A2A1EA0F9FEFD5513A4895096B2C477929352A55BE950C2537CCFBB6`.
  - `assets/external/kenney/roguelike-rpg-pack/tiles/terrain/water.png`: Re-fatiado para col=0, row=0 (x=0, y=0 no atlas). Novo tamanho: 132 bytes. Novo SHA256: `C14415D98715E4983EEC15AB99811B9FA21EFB1016749FC298528D5C5438F42E`.
  - Hashes agora completamente distintos e conformes com a física visual (terra marrom vs. água ciano).
- **Criação de `assets/original/`:**
  - `LICENSE.txt`: Declaração formal de dedicação pública CC0 1.0 Universal assinada por Yurtachi (SHA256: `EEF11384DB8B7FEB0CC199DC91B8C303C8B393D685D2F764AE8A5A16621A1A56`).
  - `water_tile.png`: Tile 16×16 de água com cristas e reflexo especular procedurais (SHA256: `4138DDD16478DBE4E8E2C9DA560696060ABB238B4CFCD2F93369283EF122BB98`).
  - `water_lake_spritesheet.png`: Spritesheet 48×48 (grid 3×3 de células 16×16) contendo bordas de areia/terra e lago navegável ao centro (SHA256: `E5544FE7C222C4919CC9CC72A3DF70F8EDC1B1FF0840097B815D41006DACD44A`).
  - `mushroom.png`: Sprite 16×16 de cogumelo silvestre (chapéu vermelho com pintas brancas e haste texturizada) para uso imediato no contrato `food_type = cogumelo` (SHA256: `114A2EFF93B3CA46FDD2FA1864259775E5E6811F75098940BE25A3748C1BA867`).
- **Esclarecimento do Achado de Revisão sobre `white01/10/20`:**
  - Auditados os 3 arquivos do *Kenney Pixel Pack* (April Fools' 2019). Confirmado que a origem upstream fornece pixels 1x1 brancos idênticos de 68 bytes para slots de opacidade/tintura. O registro foi devidamente anotado em `docs/ASSET_PROVENANCE.md` para evitar apontamentos redundantes em futuras revisões.

### Pilar 3: Pesquisa e Curadoria de Alimentos Tipados (E1)
- **Pacote Incorporado:** *Kenney Tiny Farm (1.0)*
  - URL Oficial: `https://kenney.nl/assets/tiny-farm`
  - Licença: CC0 1.0 Universal
  - Hash do Arquivo ZIP: `A06F75F312C27EFF15A2288475612E6F6699411BE7259D408323CD15A790DECC`
  - Destino Local: `assets/external/kenney/tiny-farm/`
  - Subset Curado Estritamente Necessário:
    - `fruit_strawberry.png` (16×16, morango vermelho maduro) — `FEFA9A43564CCDBD1E3C2CA86C59E55A999BA1FC7C304ADB2EEC2430AD901AF2`
    - `fruit_carrot.png` (16×16, cenoura/raiz colhida) — `028753AF7297BA20DACB5EAC6728CD65E884C5BAE8234888F6AD26A39AC2968A`
    - `seed_wheat.png` (16×16, grãos/espiga de trigo) — `13D8A53D72B4830866F3292DC303256486AC4A7271D8CFA80A8F07DD2950513B`
    - `seed_planted.png` (16×16, semente no sulco de plantio) — `E0AD4D821516A6C913726850DE626245815C45523CC61CBC8C4E0985E66EE862`
    - `leaf_cabbage.png` (16×16, folha de hortaliça verde) — `4A96FB9E2BA26E01B3F4E3F4FC57D929184E580CC53B3F7D9AC5AAF6958C45FB`
    - `leaf_sprout.png` (16×16, broto tenro de folhas jovens) — `94453B8D448DCA05C466D48A5C0E1D37FF2ABE61C490010F1209DFAA49B476AD`
    - `License.txt` (termos oficiais CC0 da Kenney) — `9C4B5FC75E585A3495F6AA55B62172504780A51B7B4394066E1DC1A45403C548`
- **Registro de Pacotes Candidatos CC0 Auditados:**
  - Documentados em tabela no `docs/ASSET_PROVENANCE.md` os seguintes pacotes CC0 com SHA256: *Tiny Farm* (`A06F...`), *Platformer Art: Mushroom Land* (`BFAC...`), *Pixel Platformer Farm Expansion* (`72C5...`), *Pixel Platformer Food Expansion* (`C80C...`), *Roguelike Caves & Dungeons* (`8EE0...`), *1-Bit Pack* (`129A...`), *Tiny Dungeon* (`C109...`), *Tiny Town* (`9768...`), *Tiny Mushrooms 16x* e *16x16 RPG Items DB32*.

---

## 3. Verificação e Conformidade com os Contratos

### A. Execução dos Testes Headless
Comando executado:
```powershell
& "C:\Users\Yurtachi\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s tests/run_tests.gd
```
- **Resultado:** Código de saída **0** (Zero falhas).
- **Cobertura de Testes Verificada:**
  - `test_behavior_learn.gd`: ok
  - `test_comandos_sobrevivencia.gd`: ok
  - `test_dialogo.gd`: ok
  - `test_evolution.gd`: ok
  - `test_save_store.gd`: ok
  - `test_signal_channel.gd`: ok
  - `test_sim_review.gd`: ok
  - `test_sim_world.gd`: ok
  - `test_smoke.gd`: ok
  - `test_textos.gd`: ok

### B. Invariantes de Governança
- **Scripts Intocados:** Nenhum arquivo sob `scripts/` ou `scenes/` foi criado ou modificado.
- **Identidade Git:** Mantida a identidade local configurada `Yurtachi <diegorodriguesny@gmail.com>`.
- **Commits e Branches:** Branch `Yurtachi/evo2-reuse`; nenhum comando `git push` executado; nenhum trailer ou menção a IA inserida nas mensagens ou arquivos de commit.
