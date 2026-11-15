# Arquitetura

```
 Editor (texto) ──► LBCompiler ──► LBVM ◄── sensores ── LBCombatSim ──► eventos ──► LBArena / HUD
                    lexer            (máquina           (regras, 60 Hz,           (somente
                    parser            virtual)           determinístico)            apresentação)
                    checker
```

## Princípios

1. **Lógica separada da apresentação.** `scripts/programming` e `scripts/combat` não usam
   nada gráfico — por isso são testados sozinhos (`tests/`). A arena só *lê* o estado.
2. **Justiça.** Os inimigos são programas Portugol (`scripts/ai/lb_bot_library.gd`) rodando na
   mesma VM, com os mesmos sensores. Não há bônus escondidos.
3. **Determinismo.** Sem números aleatórios: mesmos programas → mesma luta. Os dois robôs leem
   os sensores e têm os golpes resolvidos no mesmo instante (ninguém ganha por ser "o primeiro").
4. **Segurança.** O código do aluno é compilado para operações simples e executado por uma VM
   com limites. Nunca é transformado em GDScript.

## Módulos

| Arquivo | Responsabilidade |
|---|---|
| `programming/lb_lexer.gd` | texto → tokens; normaliza acentos/maiúsculas |
| `programming/lb_parser.gd` | tokens → árvore (AST); erros de sintaxe |
| `programming/lb_checker.gd` | tipos, variáveis, sensores somente leitura, sugestões |
| `programming/lb_compiler.gd` | AST → lista de operações com saltos; fachada `compile_source()` |
| `programming/lb_vm.gd` | executa até a próxima ação; limites; estatísticas |
| `programming/lb_robot_api.gd` | contrato: comandos e sensores permitidos |
| `combat/lb_combat_rules.gd` | **todos os números do balanceamento** |
| `combat/lb_combat_sim.gd` | o passo de simulação e os eventos |
| `combat/lb_fight_analyzer.gd` | feedback educativo pós-luta |
| `arena/lb_arena.gd` | cena 3D, luz, câmera, qualidade gráfica, efeitos por evento |
| `robots/lb_robo_mixamo.gd` | **2.0** robô TRELLIS + animações Mixamo, tipos de corpo, peças da loja |
| `robots/lb_robot_visual.gd` | robô clássico da 1.x (não é mais usado na luta; fica como referência) |
| `ai/lb_tactics.gd` / `ai/lb_enemy_brain.gd` | **2.0** táticas dos inimigos e o "cérebro" que troca de tática por turno |
| `progression/lb_coins.gd` | **2.0** nota do algoritmo (0–100) e moedas (só o que passar do recorde) |
| `progression/lb_shop.gd` | **2.0** loja: ombreiras, luvas, capacete, núcleo, acabamento e danças (tudo visual) |
| `interface/lb_battle.gd` | controlador da tela de batalha (máquina de estados) |

## Balanceamento

Altere apenas `lb_combat_rules.gd` (e os textos de `lb_robot_api.gd`). Depois rode os testes:
a seção **"equilíbrio pedagógico"** garante que o código inicial só vence o bot de treino e que
cada bot continua tendo uma solução diferente. Se um teste desses falhar, a mudança quebrou a
progressão de aprendizado.

## Robô e animações (2.0)

O robô vem de `assets/robo/` (gerado por uma ferramenta a partir dos .fbx do Mixamo):
`robo.scn` (malha + esqueleto de 33 ossos), `animacoes.res` (biblioteca com ~45 animações já
tratadas) e `animacoes.json` (instante do impacto, mão e alcance de cada golpe).
`LBRoboMixamo.MAPA` liga cada ação da simulação a uma animação; nos golpes, a animação é
"esticada" para o soco encostar exatamente no instante `hit_at` da simulação. A esquiva para a
esquerda é a da direita espelhada. Para trocar o modelo: refaça o rig no Mixamo, baixe as mesmas
animações e gere de novo os três arquivos (o script de extração está em `tools/mixamo_extrair.gd.txt`).

Câmeras (Configurações ou F7 na luta): Real Steel (padrão), Lateral, TV e Dinâmica.
O ringue fica a 0,5 m do chão (`LBArena.RING_Y`); colados, os robôs são afastados só no visual
(`DIST_VISUAL_MIN`) — a simulação não muda.

## Adicionar um comando novo

1. Regras em `lb_combat_rules.gd` (`ACOES`).
2. Comportamento em `lb_combat_sim.gd` (se precisar de algo além de mover/golpear).
3. Contrato em `lb_robot_api.gd` (nome + descrição).
4. Animação em `LBRoboMixamo.MAPA` e efeito em `lb_arena.gd`.
5. Testes em `tests/test_combat.gd`.

## Progressão e áudio

| Arquivo | Responsabilidade |
|---|---|
| `progression/lb_progress_data.gd` | dados do aluno (puros, testáveis) |
| `progression/lb_rewards.gd` | XP, níveis, conquistas, cores e armaduras — **regras de recompensa** |
| `progression/lb_tutorial.gd` | roteiro do tutorial obrigatório |
| `ai/lb_campaign.gd` | as 8 fases (inimigo, requisitos, código inicial por dificuldade, dicas, solução) |
| `core/progress.gd` | autoload que salva/carrega `user://progresso.json` |
| `core/audio.gd` | autoload `Sfx`: efeitos, música em loop, volumes, som automático em botões |
| `tools/gen_audio.py` | gera todos os .wav por síntese (numpy/scipy) |

Para criar uma fase nova: adicione um item em `LBCampaign.FASES` com uma `solucao`. Os testes
recusam a fase se a solução não vencer o inimigo e cumprir os requisitos.
