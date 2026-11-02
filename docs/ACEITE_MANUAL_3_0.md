# Roteiro de aceite manual — EvoWorld 3.0 (≈20 minutos)

Pré-requisito: Godot 4.7.2 (`winget install -e --id GodotEngine.GodotEngine`) e o projeto em `D:\Docs\Git\EvoWorld` (branch `evo3/integration`). Abrir: `godot --path .` ou executar `builds/EvoWorld.exe` (exportado com `--export-release "Windows Desktop"`). Tudo offline. Tudo em português. Nada é executado no seu computador: o terminal é fictício.

1. **Adotar (2 min).** Novo mundo → nomear o companheiro. Confirme 12 criaturas, 3 águas, alimentos de 4 tipos. O companheiro aparece em *Convivência* com desejo e emoção em pt-BR.
2. **Cuidar (3 min).** Ofereça fruta ao companheiro (ferramenta *Oferecer alimento*). Veja o recibo físico (aproximou/comeu/bebeu). Observe fome/sede nas barras.
3. **Presença e privacidade (3 min).** Coloque outra criatura perto. Observe o texto “parece buscar companhia / parece querer ficar sozinho”. Abra *Laboratório* e veja as causas (afetos, pontuações, log).
4. **Iniciativa (3 min).** Ferramenta *Objeto*: coloque uma cápsula nova e **não comande nada**. Veja se o companheiro investiga sozinho; recoloque o mesmo tipo e veja a habituação. No *Laboratório*, abra a memória de objetos.
5. **Ateliê (3 min).** Coloque um *Quadro*. Veja traços reais da criatura e a *Galeria*. Use *Demonstrar* (linha/círculo/quadrado). **Note** o texto honesto: “demonstrado/praticado/aprendeu” — o sistema ainda não copia formas de memória.
6. **Biblioteca e perguntas (3 min).** Coloque um *Livro* e acompanhe a leitura. Abra *Conhecimento*: fonte, confiança, “o cuidador disse…”. Se aparecer uma pergunta por lacuna, responda por opção (ou “não sei”).
7. **Terminal fictício (2 min).** Coloque um *Terminal*; ofereça o manual; veja comandos conhecidos e tentativas. Abra o console opcional (OLHAR/MARCAR/MOVER…): confirme o aviso “não executa comandos do computador”. Recuse/adie o terminal para a criatura e veja que ela segue normal.
8. **Salvar e reabrir (1 min).** Salvar → Carregar. Confirme nome, memórias, desenhos, conhecimento e histórico do terminal preservados.

## Verificações técnicas (opcionais)
- `godot --headless --path . -s tests/run_tests.gd` → exit 0 (24 suítes).
- `bash tests/experiments/verify_prereg.sh` → ordem pré-registro→motor→holdout.
- Nenhum botão leva a rede, processos ou arquivos reais.
