# Asset / dependency provenance

Registro auditado de proveniência de todas as dependências, ferramentas e pacotes de assets avaliados e incorporados ao projeto EvoWorld.

## Tabela de Proveniência de Pacotes e Dependências

| Item | URL | Licença | Tag / Commit | Data | SHA256 (Origem) | Arquivos Incorporados | Status / Observações |
|---|---|---|---|---|---|---|---|
| **Godot Engine** | https://godotengine.org/license/ | MIT | 4.7.2-stable (ed1daf0bf) | 2026-11-01 | Console bin winget | `(ferramenta externa, não incorporada)` | Base da simulação e renderizador 2D; boot headless e suíte de testes passando com código 0. |
| **godot_rl_agents** | https://github.com/edbeeching/godot_rl_agents | MIT | Tag `v0.8.2` (`f4b53921f0f6602d930b7b174a3ba7b8aed361aa`); main `207b6f476f5846f33d08b92c7a350147e7b78bf5` | Tag: 2025-01-22; Main: 2026-06-13 | N/A (não incorporado) | `Nenhum` | Verificado via Git remoto oficial. Nenhuma biblioteca Python de runtime incorporada (regra *No runtime libraries* e *No Python at runtime*). Candidato restrito a treinamento offline (Fase 6 Colab). |
| **godot_rl_agents_plugin** | https://github.com/edbeeching/godot_rl_agents_plugin | MIT | `[LACUNA: sem tags de release publicadas]`; main commit `998c357a0cd09b37f40a36d70c7867fc9f682338` | Main: 2026-06-13 | N/A (não incorporado) | `Nenhum` | Verificado via Git remoto oficial. Sem tags publicadas no repositório. Dispensado para runtime: exige comunicação por sockets TCP/WebSocket e acoplamento à árvore de nós do Godot, incompatível com o núcleo determinístico RefCounted da simulação. |
| **neat-python** | https://github.com/CodeReclaimers/neat-python | BSD-3-Clause | Tag `v2.0.1` (`043cddfcb83012d145095915d903790c556dda2a`); master `7d9acae0a1e5d7ed6199ffbd525dd15c5c87a86f` | Tag: 2026-03-14; Master: 2026-05-23 | N/A (não incorporado) | `Nenhum` | Verificado via Git remoto oficial. Nenhuma biblioteca Python de runtime incorporada. Forward pass neuroevolutivo para GDScript será implementado nativamente ou importado via JSON. |
| **Kenney Roguelike/RPG Pack** | https://kenney.nl/assets/roguelike-rpg-pack | CC0 1.0 Universal (Public Domain) | Release oficial Kenney | 2026-11-01 (audit) | Zip: `8E7D2378F8F794245645F6D7DC7AEEB246791410A7E512293C594B46A5A9524B` | `assets/external/kenney/roguelike-rpg-pack/` | Verificado CC0 direto do site oficial. Incorporado subset pequeno e útil: spritesheet transparente oficial (94 KB), arquivo de licença e tiles individuais fatiados (terreno, recursos/comida, obstáculos). |
| **Kenney Animal Pack Remastered** | https://kenney.nl/assets/animal-pack-remastered | CC0 1.0 Universal (Public Domain) | Release oficial Kenney | 2026-11-01 (audit) | Zip: `25C51AE89D0AF358D60B75CFCEBB76A72E9CB20E38453D90F0DFDDD29234069A` | `assets/external/kenney/animal-pack-remastered/` | Verificado CC0 direto do site oficial. Incorporado subset pequeno (8 sprites circulares de referência: bear, chicken, cow, dog, duck, frog, pig, rabbit) e arquivo de licença. Usado como referência visual morfológica para renderização procedural. |
| **Kenney Pixel Pack** | https://kenney.nl/assets/pixel-pack | CC0 1.0 Universal (Public Domain) | Release oficial Kenney (April Fools' 2019) | 2019-04-01 / 2026-11-01 (audit) | Zip: `8A147F84D25CD3D2192837D9418822C2A61F889FC4F3A05F03230E7E2046944E` | `assets/external/kenney/pixel-pack/` | Verificado CC0 direto do site oficial. Auditoria confirmou que este pacote é um release comemorativo de 1º de abril de 2019 contendo pixels 1x1 coloridos. Preservado com README explicativo e subset de 4 pixels de amostra + spritesheet. |
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
| `tiles/terrain/grass.png` | 177 | `1174970D325567226BD53199888F6E90AAA1C67D49393E2BB7927CAE807D1C7A` | Tile de grama primária (col=5, row=1) para fundo do mundo |
| `tiles/terrain/dirt.png` | 166 | `F893DB3799C7BD9D4FC098331356BFFC5007129310544DEE9E9F88CD72F7ED18` | Tile de terra/solo (col=3, row=1) |
| `tiles/terrain/sand.png` | 177 | `31FC5775B456D8E4002F9FD8BA871955CE1D530F65D1014FC7A9B9B88035BD38` | Tile de areia (col=6, row=0) |
| `tiles/terrain/water.png` | 166 | `F893DB3799C7BD9D4FC098331356BFFC5007129310544DEE9E9F88CD72F7ED18` | Tile de água (col=0, row=0) |
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
| `README.md` | 233 | `CF4F52179BD80CE617024AC2BC3C8AAAA47CE23CEE8CFEA61B64CEE1985B6502` | Documentação de contexto (pacote 1x1 April Fools' 2019) |
| `Spritesheet/pixelSpritesheet.png` | 87 | `BC08955973672AC9B906BF234516F2B45E58D96C763A7426CD225F8FD49BE21E` | Folha de 1x1 pixels para máscaras/cores sólidas |
| `black01.png` | 70 | `35C38E9C4FD4766F5CDD01074572F66A82C9257B0B27878E173FBEB56DC7786B` | Pixel 1x1 preto para sombras/tintura |
| `white01.png` | 68 | `260865134B6E69CA7BAFA9E8DDCD59FB6FFBF727F50A3D2DD186DE4BC8213697` | Pixel 1x1 branco para modulação de cor procedural |
| `white10.png` | 68 | `260865134B6E69CA7BAFA9E8DDCD59FB6FFBF727F50A3D2DD186DE4BC8213697` | Pixel 1x1 opacidade/tom |
| `white20.png` | 68 | `260865134B6E69CA7BAFA9E8DDCD59FB6FFBF727F50A3D2DD186DE4BC8213697` | Pixel 1x1 opacidade/tom |
