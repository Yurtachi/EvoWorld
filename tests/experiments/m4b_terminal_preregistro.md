# X7 — terminal no mundo real (pré-registro)

[FATO] Protocolo anterior ao código avaliador e à abertura do holdout. Nenhum
avaliador fechado anterior será executado. Implementação própria, sem LLM.

TRAIN: 154101–154104. DEV: 154201–154206. HOLDOUT inédito: 154401–154424,
24 seeds pareadas. Somente TRAIN/DEV podem orientar implementação. O holdout
terá uma abertura, com árvore limpa, marcador persistido antes da primeira
trajetória, protocolo e arquivos do motor congelados por hashes Git/LF.

Cada seed cria uma criatura saciada, terminal físico e espaço livre. Objetivo
operacional: marcar uma coordenada e deslocar o corpo até ela (tolerância 1,5
unidades), com custo e colisão reais. Coordenadas são relativas ao terminal,
sem revelar recursos fora dos sensores. Uma instrução por criatura por tick,
até oito instruções por programa; sem executar shell ou arquivos externos.
Manual/demonstração oferece comandos, nunca força o objetivo da criatura.

Aquisição: 12 tentativas, limite de 40 ticks cada, alvo horizontal próximo
(2–6 unidades), feedback de sucesso físico por programa e objetivo. Avaliação:
seis tentativas, mesmo limite, depois alvo NOVO vertical e outra posição do
terminal, sem nova demonstração. Variam seed, direção, distância e posição;
isso não representa nova família de problemas. O controlador que parametriza
comandos pelo alvo é uma heurística explícita, a ser comparada com um servo.

Braços: completo com manual; sem ensino (OLHAR/AJUDA iniciais, pode descobrir);
programas aleatórios com o mesmo manual; programa fixo/servo geométrico com o
mesmo alvo e comandos; sem memória (mesmos comandos do completo, tabela por
objetivo apagada antes de cada escolha). Reportar tentativas, erros, sucesso,
ticks, deslocamento e energia, sem excluir criaturas que recusam.

- H-a: completo supera sem ensino em pelo menos 0,20 na proporção de
  tentativas bem sucedidas; relatar também erros e aquisição de comandos.
- H-b: sucesso completo no alvo novo em pelo menos 18/24 seeds.
- H-c: completo supera aleatório e sem memória em 0,10; se fixo/servo iguala
  ou supera o completo, NÃO concluir aprendizado de solução de problemas.
- H-d: após erro de colisão induzido no DEV e no ensaio pareado de holdout,
  erro fica no histórico e a pontuação da mesma sequência diminui em 24/24;
  medir repetição efetiva, sem confundir score com estratégia nova.
- H-e: perfil sem curiosidade/ocioso, com recusa explícita, pode ignorar o
  terminal por 200 ticks; sobrevivência e estado corporal iguais ao controle
  sem terminal em pelo menos 24/24 pares. Necessidades críticas prevalecem.
- H-f: round trip JSON/save v13 conserva comandos, erros e tabela; escolhas
  e continuação física iguais por 20 ticks em 24/24 pares.

PASS global exige todas as hipóteses, incluindo vantagem sobre o fixo.
PARTIAL se há integração/retensão e desempenho restrito mas H-c falha;
FAIL se segurança, integridade de save ou execução física falharem. Não ajustar
motor, limiares ou protocolo depois de abrir holdout. Falhas serão publicadas.

CPU separado: populações 12/30/60/100, 40 ticks de aquecimento e 200 medidos,
com terminal e todas as mentes versus sem terminal, mesmas seeds. Guardar
amostras, média e p95; não converter tempo headless em FPS gráfico.
