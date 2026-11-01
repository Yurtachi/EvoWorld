# Asset / dependency provenance

Registro auditado de proveniência de todas as dependências, ferramentas e pacotes de assets avaliados e incorporados ao projeto EvoWorld.

## Tabela de Proveniência de Pacotes e Dependências

| Item | URL | Licença | Tag / Commit | Data | SHA256 (Origem) | Arquivos Incorporados | Status / Observações |
|---|---|---|---|---|---|---|---|
| **Godot Engine** | https://godotengine.org/license/ | MIT | 4.7.2-stable (ed1daf0bf) | 2026-11-01 | Console bin winget | `(ferramenta externa, não incorporada)` | Base da simulação e renderizador 2D; boot headless e suíte de testes passando com código 0. |
| **godot_rl_agents** | https://github.com/edbeeching/godot_rl_agents | MIT | Tag `v0.8.2` (`f4b53921f0f6602d930b7b174a3ba7b8aed361aa`); main `207b6f476f5846f33d08b92c7a350147e7b78bf5` | Tag: 2025-01-22; Main: 2026-06-13 | N/A (não incorporado) | `Nenhum` | Verificado via Git remoto oficial. Nenhuma biblioteca Python de runtime incorporada (regra *No runtime libraries* e *No Python at runtime*). Candidato restrito a treinamento offline (Fase 6 Colab). |
| **godot_rl_agents_plugin** | https://github.com/edbeeching/godot_rl_agents_plugin | MIT | `[LACUNA: sem tags de release publicadas]`; main commit `998c357a0cd09b37f40a36d70c7867fc9f682338` | Main: 2026-06-13 | N/A (não incorporado) | `Nenhum` | Verificado via Git remoto oficial. Sem tags publicadas no repositório. Dispensado para runtime: exige comunicação por sockets TCP/WebSocket e acoplamento à árvore de nós do Godot, incompatível com o núcleo determinístico RefCounted da simulação. |
| **neat-python** | https://github.com/CodeReclaimers/neat-python | BSD-3-Clause | Tag `v2.0.1` (`043cddfcb83012d145095915d903790c556dda2a`); master `7d9acae0a1e5d7ed6199ffbd525dd15c5c87a86f` | Tag: 2026-03-14; Master: 2026-05-23 | N/A (não incorporado) | `Nenhum` | Verificado via Git remoto oficial. Nenhuma biblioteca Python de runtime incorporada. Forward pass neuroevolutivo para GDScript será implementado nativamente ou importado via JSON. |
| **Kenney Roguelike/RPG Pack** | https://kenney.nl/assets/roguelike-rpg-pack | CC0 1.0 Universal (Public Domain) | Release oficial Kenney | 2026-11-01 (audit/fix) | Zip: `8E7D2378F8F794245645F6D7DC7AEEB246791410A7E512293C594B46A5A9524B` | `assets/external/kenney/roguelike-rpg-pack/` | Verificado CC0 direto do site oficial. Atlas mestre oficial (94 KB), licença e tiles fatiados (terreno com correção de fatiamento dirt/water, recursos e obstáculos). |
| **Kenney Animal Pack Remastered** | https://kenney.nl/assets/animal-pack-remastered | CC0 1.0 Universal (Public Domain) | Release oficial Kenney | 2026-11-01 (audit) | Zip: `25C51AE89D0AF358D60B75CFCEBB76A72E9CB20E38453D90F0DFDDD29234069A` | `assets/external/kenney/animal-pack-remastered/` | Verificado CC0 direto do site oficial. Incorporado subset pequeno (8 sprites circulares de referência: bear, chicken, cow, dog, duck, frog, pig, rabbit) e arquivo de licença. Usado como referência visual morfológica para renderização procedural. |
| **Kenney Pixel Pack** | https://kenney.nl/assets/pixel-pack | CC0 1.0 Universal (Public Domain) | Release oficial Kenney (April Fools' 2019) | 2019-04-01 / 2026-11-01 (audit) | Zip: `8A147F84D25CD3D2192837D9418822C2A61F889FC4F3A05F03230E7E2046944E` | `assets/external/kenney/pixel-pack/` | Verificado CC0 direto do site oficial. Auditoria confirmou release comemorativo de 1x1 pixels idênticos para modulação (white01/10/20 idênticos na origem). |
| **Kenney Tiny Farm** | https://kenney.nl/assets/tiny-farm | CC0 1.0 Universal (Public Domain) | Release oficial Kenney (1.0) | 2026-07-01 / 2026-11-01 (audit) | Zip: `A06F75F312C27EFF15A2288475612E6F6699411BE7259D408323CD15A790DECC` | `assets/external/kenney/tiny-farm/` | Verificado CC0 oficial. Incorporado subset estritamente necessário para contratos E1 (frutas: morango/cenoura; sementes: trigo/plantada; folhas: repolho/broto) em 16x16. |
| **EvoWorld Original Assets** | N/A (autoria própria local) | CC0 1.0 Universal (Public Domain Dedication) | v1.0 local | 2026-11-01 | N/A (gerado no workspace) | `assets/original/` | Criado por Yurtachi: tile 16x16 de água com ondulação, spritesheet de lago/poça 48x48 e cogumelo 16x16 autoral com licença CC0 declarada. |
| **Brax** | https://github.com/google/brax | Apache-2.0 | Avaliado a partir do GDD | 2026-11-01 (audit) | N/A | `Nenhum` | Rejeitado para runtime. Dependência pesada de JAX/GPU; repositório oficial alerta que ambientes não têm manutenção ativa. Incompatível com execução local offline. |

---

## Detalhamento dos Arquivos Incorporados no Repositório

### 1. `assets/external/kenney/roguelike-rpg-pack/`
- **Licença:** CC0 1.0 Universal (arquivo `License.txt` incluído no diretório)
- **Origem:** Download assinado oficial de `https://kenney.nl/assets/roguelike-rpg-pack`

| Arquivo | Tamanho (bytes) | SHA256 | Função no EvoWorld |
|---|---|---|---|
| `License.txt` | 666 | `E3158109AD8580EF266DB5B00F97BBED853870A99C0721200EF23BB3A595462D` | Termos oficiais de licença CC0 |
| `Spritesheet/roguelikeSheet_transparent.png` | 94,579 | `808C8D734480BC949B284F3BCC252E87E1EE53B24178791A6838CFF1A5EC2C63` | Atlas mestre completo (1700 tiles em 16x16 com 1px de espaçamento) para TileMap/AtlasTexture |
| `Spritesheet/spritesheetInfo.txt` | 102 | `03D7FF281579D76D7A8462CF98514BBEE9DEFE6391D555B921287A13B826315F` | Metadados oficiais de dimensão e margens do spritesheet |
| `tiles/terrain/grass.png` | 177 | `1174970D325567226BD53199888F6E90AAA1C67D49393E2BB792752C1DE23061` | Tile de grama primária (col=5, row=1) para fundo do mundo |
| `tiles/terrain/dirt.png` | 197 | `4CAE6A68A2A1EA0F9FEFD5513A4895096B2C477929352A55BE950C2537CCFBB6` | Tile de terra/solo re-fatiado de (col=6, row=4: terra marrom autêntica; corrige bug de fatiamento anterior que amostrava água) |
| `tiles/terrain/sand.png` | 177 | `31FC5775B456D8E4002F9FD8BA871955CE1D530F65D1014FC7A9B5B1F99562D9` | Tile de areia (col=6, row=0) |
| `tiles/terrain/water.png` | 132 | `C14415D98715E4983EEC15AB99811B9FA21EFB1016749FC298528D5C5438F42E` | Tile de água pura re-fatiado de (col=0, row=0: água ciano 16x16; hash distinto de dirt.png) |
| `tiles/food/apple.png` | 189 | `155AFECC448068D1E77EDDF5C5A729A971CFFAFED7DAAD59C58B125B6C07FD98` | Ícone de maçã / fruta vermelha (col=52, row=28) para `place_food` |
| `tiles/food/berry.png` | 176 | `E2AA8DE3B026B89FAF1F25F368B0120FC8BF1A475CBC28947684FC0B796791DE` | Ícone de baga / fruta pequena (col=52, row=29) para recursos de arbusto |
| `tiles/food/seed.png` | 158 | `9BA671C348196C699B2CF6CB2030CAC689D2E2C9FAF5DCA8CBC42CF985F90B1E` | Ícone de semente / grão (col=35, row=9) |
| `tiles/food/meat.png` | 206 | `F0B7596CAD7176147AD2D4F73A443FAB8EF55616B0D429E8F711FA8E4CE3735F` | Ícone de carne / proteína (col=43, row=23) |
| `tiles/food/leaf.png` | 188 | `ECA94CE49D999258F1F0DAAA9D69FC8E5432BA73228071264033481488147774` | Ícone de folha / vegetal verde (col=50, row=28) |
| `tiles/obstacles/rock.png` | 214 | `0EEA7356D38D9EF2A63CC48117FED290B95822AB3BE728273ABE58485226EACD` | Obstáculo de pedra grande (col=9, row=7) para `place_obstacle` |
| `tiles/obstacles/rock_small.png` | 210 | `E6B5925DB8A81C6C49BC0FC844E25393F2A7C09DBF7FC20FED5862C72355F4D7` | Obstáculo de pedra pequena (col=9, row=8) |
| `tiles/obstacles/tree_top.png` | 206 | `58FD5865E7839A61DE6BBEE8C0BB152BE20E04C29E2DA07275C11E2DCDE9310A` | Copa de pinheiro (col=16, row=10) |
| `tiles/obstacles/tree_trunk.png` | 231 | `09FC08E40CC3C517A19134E7C2830641EBC2CBB0BEF997FF5A994FF213506CEE` | Tronco de árvore (col=16, row=11) |
| `tiles/obstacles/bush.png` | 203 | `744EC839A5E8F593FC2483ACB098EFE800F38CF9334D31FEA701ECBFBE9F5943` | Arbusto / obstáculo vegetal (col=8, row=16) |

> **Nota sobre o bug de fatiamento corrigido:** Anteriormente, `dirt.png` fora extraído incorretamente de (col=3, row=1), célula que no atlas do Kenney contém água ciano, resultando em hash idêntico a `water.png`. O arquivo `dirt.png` foi re-fatiado para a célula (col=6, row=4), onde reside solo marrom sólido autêntico (`#b98b5e` / `#a87e54`), eliminando a duplicação e restaurando a integridade visual da simulação.

---

### 2. `assets/external/kenney/animal-pack-remastered/`
- **Licença:** CC0 1.0 Universal (arquivo `License.txt` incluído no diretório)
- **Origem:** Download assinado oficial de `https://kenney.nl/assets/animal-pack-remastered`

| Arquivo | Tamanho (bytes) | SHA256 | Função no EvoWorld |
|---|---|---|---|
| `License.txt` | 515 | `A59A5DBC9F8B2DC600D63998EEB1D6078FED2EF4485E12AA415C97369528D01C` | Termos oficiais de licença CC0 |
| `bear.png` | 4,050 | `38BC0B488212AF64A3146373F4E5BAE731ACD97CB0F0DA1B06CE9F42EC7FFCE5` | Referência morfológica: urso (topo de cadeia / predador) |
| `chicken.png` | 3,489 | `28FF8DA3B83DDB5F56094FD6E860048F9DF7370222F3FE6D38C9DE0A1D39414F` | Referência morfológica: galinha (herbívoro pequeno / presa) |
| `cow.png` | 3,858 | `DA7BEB3985A01217A4B82BB51526079418316C2663E301A44184C0F7EF34F8C9` | Referência morfológica: vaca (herbívoro de grande porte) |
| `dog.png` | 3,886 | `2319095C34858FA9610D16DC2468DFC308CA9E061CC98B4276231EF3E18BAA05` | Referência morfológica: cão (animal companheiro / pet) |
| `duck.png` | 3,460 | `335A0DC95BAEECC7F3D6AB8EFAEE517FCD37D82F5999E46B0EDD588147E6BA2B` | Referência morfológica: pato (anfíbio / aquático) |
| `frog.png` | 2,908 | `DB0A75073C617F846F9F8E6C5E9186AC87A884F47E11EE77B3C01E9E0B256DF9` | Referência morfológica: sapo (organismo pequeno saltador) |
| `pig.png` | 3,669 | `2107AFFC9737E87B9AF0F88A5E8C45EB4825224FB347BCD3A55757755BE8A3FB` | Referência morfológica: porco (onívoro) |
| `rabbit.png` | 4,029 | `FA8AD3517B0B55C3893355E756982CE3114B21CA1BCDBC3CD56A0C22B487A462` | Referência morfológica: coelho (herbívoro veloz) |

---

### 3. `assets/external/kenney/pixel-pack/`
- **Licença:** CC0 1.0 Universal (arquivo `License.txt` incluído no diretório)
- **Origem:** Download assinado oficial de `https://kenney.nl/assets/pixel-pack`

| Arquivo | Tamanho (bytes) | SHA256 | Função no EvoWorld |
|---|---|---|---|
| `License.txt` | 610 | `6FF71FF5603BC364B324792E98EA51D190A9725774C7503B6839257C952FA267` | Termos oficiais de licença CC0 |
| `README.md` | 237 | `14197DF19E4A5FD0F25A0F218DA4C20465AF631EC72863925A12D2140A7B72BF` | Documentação de contexto (pacote 1x1 April Fools' 2019) |
| `Spritesheet/pixelSpritesheet.png` | 87 | `BC08955973672AC9B906BF234516F2B45E58D96C763A7426CD225F8FD49BE21E` | Folha de 1x1 pixels para máscaras/cores sólidas |
| `black01.png` | 70 | `35C38E9C4FD4766F5CDD01074572F66A82C9257B0B27878E173FBEB56DC7786B` | Pixel 1x1 preto para sombras/tintura |
| `white01.png` | 68 | `260865134B6E69CA7BAFA9E8DDCD59FB6FFBF727F50A3D2DD186DE4BC8213697` | Pixel 1x1 branco puro para modulação de cor procedural |
| `white10.png` | 68 | `260865134B6E69CA7BAFA9E8DDCD59FB6FFBF727F50A3D2DD186DE4BC8213697` | Pixel 1x1 branco (upstream idêntico na distribuição original de 2019) |
| `white20.png` | 68 | `260865134B6E69CA7BAFA9E8DDCD59FB6FFBF727F50A3D2DD186DE4BC8213697` | Pixel 1x1 branco (upstream idêntico na distribuição original de 2019) |

> **Nota de auditoria sobre os hashes duplicados de `white01/10/20`:** A revisão independente apontou hashes idênticos nestes 3 arquivos. A inspeção técnica dos bytes e do zip oficial da Kenney confirma que este pacote foi lançado no Dia da Mentira (1º de abril de 2019) como uma brincadeira de assets 1x1 pixels; os arquivos `white01.png`, `white10.png` e `white20.png` contêm exatamente 1 pixel RGBA `(255, 255, 255, 255)` de 68 bytes no pacote original upstream. A duplicação é, portanto, nativa do pacote do autor externo e não um erro de manipulação local.

---

### 4. `assets/original/` (Autoria Própria EvoWorld)
- **Autor:** Yurtachi (projeto EvoWorld)
- **Licença:** CC0 1.0 Universal (Public Domain Dedication, arquivo `LICENSE.txt` incluído no diretório)
- **Finalidade:** Fornecer tiles e spritesheets dedicados e originais de água, lago/poça e alimento cogumelo para o contrato E1.

| Arquivo | Tamanho (bytes) | SHA256 | Dimensões | Função no EvoWorld |
|---|---|---|---|---|
| `LICENSE.txt` | 528 | `EEF11384DB8B7FEB0CC199DC91B8C303C8B393D685D2F764AE8A5A16621A1A56` | Texto | Termos da declaração pública de domínio público CC0 1.0 Universal |
| `water_tile.png` | 143 | `4138DDD16478DBE4E8E2C9DA560696060ABB238B4CFCD2F93369283EF122BB98` | 16×16 | Tile original de água com ondulação, crista e reflexo especular |
| `water_lake_spritesheet.png` | 336 | `E5544FE7C222C4919CC9CC72A3DF70F8EDC1B1FF0840097B815D41006DACD44A` | 48×48 (3×3 tiles 16x16) | Spritesheet de corpo de água completo: margens, quinas, transição terra/areia e centro navegável |
| `mushroom.png` | 223 | `114A2EFF93B3CA46FDD2FA1864259775E5E6811F75098940BE25A3748C1BA867` | 16×16 | Sprite de cogumelo silvestre (chapéu vermelho com pintas brancas e haste clara) para `food_type = cogumelo` |

---

### 5. `assets/external/kenney/tiny-farm/`
- **Licença:** CC0 1.0 Universal (arquivo `License.txt` incluído no diretório)
- **Origem:** Download oficial de `https://kenney.nl/assets/tiny-farm` (Arquivo zip SHA256: `A06F75F312C27EFF15A2288475612E6F6699411BE7259D408323CD15A790DECC`)
- **Finalidade:** Sprites 16×16 oficiais de alta legibilidade para as categorias de alimento tipado da especificação E1.

| Arquivo | Tamanho (bytes) | SHA256 | Dimensões | Categoria E1 |
|---|---|---|---|---|
| `License.txt` | 566 | `9C4B5FC75E585A3495F6AA55B62172504780A51B7B4394066E1DC1A45403C548` | Texto | Termos oficiais de licença CC0 da Kenney |
| `fruit_strawberry.png` | 195 | `FEFA9A43564CCDBD1E3C2CA86C59E55A999BA1FC7C304ADB2EEC2430AD901AF2` | 16×16 | `food_type = fruta` (morango/fruta vermelha madura) |
| `fruit_carrot.png` | 208 | `028753AF7297BA20DACB5EAC6728CD65E884C5BAE8234888F6AD26A39AC2968A` | 16×16 | `food_type = fruta` (legume/raiz alaranjada) |
| `seed_wheat.png` | 185 | `13D8A53D72B4830866F3292DC303256486AC4A7271D8CFA80A8F07DD2950513B` | 16×16 | `food_type = semente` (grão de trigo / espiga) |
| `seed_planted.png` | 153 | `E0AD4D821516A6C913726850DE626245815C45523CC61CBC8C4E0985E66EE862` | 16×16 | `food_type = semente` (semente em solo arado) |
| `leaf_cabbage.png` | 194 | `4A96FB9E2BA26E01B3F4E3F4FC57D929184E580CC53B3F7D9AC5AAF6958C45FB` | 16×16 | `food_type = folha` (repolho/hortaliça verde) |
| `leaf_sprout.png` | 165 | `94453B8D448DCA05C466D48A5C0E1D37FF2ABE61C490010F1209DFAA49B476AD` | 16×16 | `food_type = folha` (broto vegetal com folhas tenras) |

---

## 6. Registro de Candidatos CC0 Pesquisados para a Fase E1

Pesquisa exaustiva de fontes públicas oficiais com licença CC0 dedicada a elementos de ecologia (frutas, sementes, folhas, cogumelos, terrenos hídricos e agrícolas):

| Pacote Candidato | Autor / Fonte | URL Oficial | Licença | Tamanho Grid | SHA256 do Pacote ZIP | Elementos Relevantes | Decisão / Uso |
|---|---|---|---|---|---|---|---|
| **Tiny Farm** | Kenney | https://kenney.nl/assets/tiny-farm | CC0 1.0 Universal | 16×16 | `A06F75F312C27EFF15A2288475612E6F6699411BE7259D408323CD15A790DECC` | Cultivos, legumes, sementes, folhas e brotos agrícolas | **INCORPORADO (subset)** em `assets/external/kenney/tiny-farm/` |
| **Platformer Art: Mushroom Land** | Kenney | https://opengameart.org/content/platformer-art-mushroom-land | CC0 1.0 Universal | Variável (vetor/PNG) | `BFACEC16B07158BCD494BBA3C365FDD9D053AC65FBD7A70B539945BF309B8218` | Cogumelos gigantes, chapéus vermelhos e marrons, vegetação | Candidato auditado para expansão de biomas de cogumelos |
| **Pixel Platformer Farm Expansion** | Kenney | https://kenney.nl/assets/pixel-platformer-farm-expansion | CC0 1.0 Universal | 18×18 (com padding) | `72C5EE0DDA3DFA1B95FF25C74A7FF6878E58851276A7766551218CBD55DA6D61` | Plantas, fardos de feno e estufas | Candidato CC0 auditado (requer corte para 16x16) |
| **Pixel Platformer Food Expansion** | Kenney | https://kenney.nl/assets/pixel-platformer-food-expansion | CC0 1.0 Universal | 18×18 (com padding) | `C80C6B26DADD3C57974E466545A88BF29461085BB47ABE5C28EE92DBE824FFA4` | Alimentos diversos (queijos, carnes, doces) | Candidato CC0 auditado |
| **Roguelike Caves & Dungeons** | Kenney | https://kenney.nl/assets/roguelike-caves-dungeons | CC0 1.0 Universal | 16×16 | `8EE0F7CE911E7BC0C425E98783058870D0A49572440AB0B89A5F44E68B74F0BF` | Terreno de cavernas, trilhos e estruturas subterrâneas | Candidato para expansão de mapas de subsolo |
| **1-Bit Pack** | Kenney | https://kenney.nl/assets/1-bit-pack | CC0 1.0 Universal | 16×16 | `129A0E74E1DC9091A769D5118BE5C88780484C7A3771EE33AC9EF0DF02583A9A` | 1078 tiles retrô monocromáticos e coloridos | Candidato para ícones minimalistas e glifos de status |
| **Tiny Dungeon** | Kenney | https://kenney.nl/assets/tiny-dungeon | CC0 1.0 Universal | 16×16 | `C109438AB06F65FD80F9B2686A4CF9C7C11DC64444B47333EC71D602F8BB5FC7` | Frascos, poções, tochas e pisos de pedra | Candidato para itens de laboratório e poções |
| **Tiny Town** | Kenney | https://kenney.nl/assets/tiny-town | CC0 1.0 Universal | 16×16 | `9768692DCCFF1D706408A5AEDD6CA4F6CD1409506CBC84CB2F862919764BE977` | Árvores, cercas, caminhos e construções rurais | Candidato para decoração de ambiente |
| **Tiny Mushrooms 16x Minecraft style** | bart / OGA | https://opengameart.org/content/tiny-mushrooms-16x-minecraft-style | CC0 1.0 Universal | 16×16 | N/A (inspecionado) | Cogumelos pequenos em estilo cúbico 16x16 | Candidato alternativo CC0 |
| **16x16 RPG Items (DB32)** | Henrique Lazarini / OGA | https://opengameart.org/content/16x16-rpg-items-db32 | CC0 1.0 Universal | 16×16 | N/A (inspecionado) | Vasta coleção de alimentos e cogumelos na paleta DB32 | Candidato alternativo CC0 |

---

## 7. Uso Visual Verificado — UI2 e Fase E1

O renderizador do EvoWorld consome os assets respeitando o desacoplamento de simulação:
1. **Terreno de Fundo:** `tiles/terrain/grass.png` (origem 5, 1) e `tiles/terrain/dirt.png` (origem 6, 4) formam a textura básica do substrato.
2. **Água Funcional:** Células hídricas utilizam `assets/original/water_tile.png` e `assets/original/water_lake_spritesheet.png` para visualização de corpos de água límpidos e navegáveis nas margens.
3. **Alimentos Tipados E1:**
   - `fruta`: `assets/external/kenney/tiny-farm/fruit_strawberry.png` e `fruit_carrot.png`.
   - `semente`: `assets/external/kenney/tiny-farm/seed_wheat.png` e `seed_planted.png`.
   - `folha`: `assets/external/kenney/tiny-farm/leaf_cabbage.png` e `leaf_sprout.png`.
   - `cogumelo`: `assets/original/mushroom.png`.
   - `legacy`: Mantém o ícone padrão histórico para compatibilidade com saves v1/v2/v3.
4. **Criaturas Procedurais:** As criaturas continuam sendo desenhadas parametricamente com base nos genes herdáveis (matiz, raio, velocidade), garantindo que as mutações visuais reflitam a genética real da simulação.
