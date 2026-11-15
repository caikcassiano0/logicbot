# LogicBot

Jogo educacional de batalha de robôs. O jogador **programa a lógica do robô em Portugol**
(inspirado no Visualg), clica em **PRONTO** e assiste ao robô executar o código contra um
inimigo — que também é um programa, escrito na mesma linguagem.

> **Versão 1.0** — as 5 etapas do plano original estão implementadas. Os robôs ainda são modelos procedurais (feitos por código); veja "Limitações".

---

## 1. Requisitos

| Item | Versão | Observação |
|---|---|---|
| Godot Engine | **4.7.x** (padrão, não a versão .NET) | <https://godotengine.org/download> |
| VS Code | qualquer recente | |
| Extensão *godot-tools* | 2.x | o VS Code sugere ao abrir a pasta |

Placa de vídeo com suporte a **Vulkan** (renderizador Forward+). Em PCs modestos use a
qualidade **Baixa** no menu Configurações.

## 2. Primeira vez (passo a passo)

1. Baixe a Godot 4.7.x e descompacte em uma pasta fixa (ex.: `C:\Godot\`).
2. Abra a pasta do projeto no VS Code (**Arquivo → Abrir Pasta**).
3. Aceite instalar as extensões recomendadas.
4. Edite `.vscode/settings.json` e coloque o caminho do executável da Godot em
   `godotTools.editorPath.godot4`.
5. **Terminal → Executar Tarefa → "LogicBot: abrir no editor da Godot"**.
   Na primeira abertura a Godot importa fontes e recursos (leva alguns segundos).
6. Na Godot: **Editor → Configurações do Editor → Texto → Editor Externo**:
   marque *Usar editor externo* e aponte para o VS Code (`code`), com os parâmetros
   `{project} --goto {file}:{line}:{col}`. Assim, clicar em um script abre no VS Code.

## 3. Rodar

- **Jogo:** F5 no VS Code (configuração "LogicBot: rodar o jogo", usa a extensão godot-tools).
  Se o F5 não funcionar na sua versão da extensão, use a tarefa **"LogicBot: rodar o jogo"**
  ou aperte F5 dentro do editor da Godot.
- **Testes:** tarefa **"LogicBot: rodar testes"** (Ctrl+Shift+P → *Run Test Task*).
- **Teste de fumaça da interface:** tarefa **"LogicBot: teste de fumaça da interface"**.

Pela linha de comando (na pasta do projeto):

```bash
godot --headless --path . --script res://tests/run_tests.gd        # testes
godot --headless --path . --fixed-fps 60 res://tools/smoke_test.tscn # interface
godot --path .                                                      # jogar
```

## 3.1 Gerar o executável (.exe)

1. Na Godot: **Editor → Gerenciar Modelos de Exportação → Baixar e Instalar** (uma vez só, ~1 GB).
2. **Projeto → Exportar…** → escolha **Windows Desktop** (já configurado em `export_presets.cfg`)
   → **Exportar Projeto** → salve em `build/windows/LogicBot.exe`.
3. O .exe já contém tudo (um arquivo só). As pastas `tools/` e `tests/` ficam de fora.

Pela linha de comando: `godot --headless --path . --export-release "Windows Desktop" build/windows/LogicBot.exe`

O ícone (`icon.ico`) é embutido automaticamente pela própria Godot.

## 4. Como jogar

1. Na primeira vez, o menu só libera o **TUTORIAL** (obrigatório, poucos minutos): apresenta a arena
   e o editor e pede duas lutas curtas — uma com **sequência** e outra com **SE/SENAO**.
2. Depois do tutorial, libera a **CAMPANHA** (10 fases, uma por conceito) e o **TREINO LIVRE**.
3. Escolha a **dificuldade** no painel da campanha:
   - **Fácil (Aprendiz):** o código vem com lacunas `???` para completar; dicas aparecem sozinhas.
   - **Médio (Estrategista):** só o esqueleto; até 2 dicas por fase.
   - **Difícil (Mestre da Lógica):** editor livre, sem dicas — só as ferramentas de depuração.
   A dificuldade muda a **ajuda**, não a vida ou o dano do inimigo.
4. Cada fase tem **requisitos** (ex.: "usar SENAO SE"). A vitória só conta se o programa usar o que a fase ensina.
5. **Atalhos:** F5 lutar · Ctrl+Enter validar · Esc pausar · F6 passo · F1 dica · Ctrl+ / Ctrl- tamanho da fonte.
   Durante a luta: a linha executada fica destacada; **⏸** pausa; **PASSO** avança uma ação do seu robô;
   a aba **Variáveis** mostra sensores e suas variáveis ao vivo; **1x** muda a velocidade.
6. No fim: estatísticas, sugestões, o código do inimigo e a saída do programa.

7. **Progressão:** XP só vem de aprender algo novo (fase inédita, dificuldade maior, bot novo) —
   repetir a mesma luta não rende nada. Níveis liberam **cores** e **armaduras** na **GARAGEM**;
   12 **conquistas** celebram bons hábitos (depurar, usar escreval, acertar de primeira, persistir).
   Não existe nenhuma compra.

O progresso fica em `user://progresso.json` (só no computador do aluno). O menu da campanha mostra
quais tipos de erro foram mais frequentes, como sugestão do que praticar.

A linguagem completa está em [documentation/LINGUAGEM.md](LINGUAGEM.md).
O gabarito das fases não fica no repositório: gere com `godot --headless --path . -s res://tools/gen_docs.gd` (cria `documentation/SOLUCOES_PROFESSOR.md`).

## 5. O que já funciona

- Linguagem educacional completa, com **procedimentos** (léxico, sintaxe, semântica, compilação, máquina virtual segura),
  com mensagens para iniciantes e lacunas `???` para exercícios de completar.
- Combate lateral determinístico; 8 comandos, 10 sensores; inimigos escritos na própria linguagem.
- **Tutorial obrigatório**, **campanha de 10 fases** (incluindo ENQUANTO e procedimentos), **3 dificuldades**, dicas graduais,
  requisitos por fase, **depuração** (pausa, passo a passo, variáveis ao vivo) e registro local de erros.
- Arena 3D, robôs animados com 4 armaduras e 5 cores, efeitos, HUD, menu, configurações e tela de resultado.
- **Experiência, 10 níveis, 12 conquistas e Garagem** de personalização.
- **Sons e músicas originais** gerados por síntese (`tools/gen_audio.py`), volumes separados, transições com fade.
- Ícone próprio embutido no .exe.
- **231 testes automatizados** + **teste de fumaça** da interface (37 verificações), também validado no jogo exportado.

## 6. Limitações conhecidas (honestas)

- **Robôs e arena são provisórios**, construídos por código. Ver `documentation/ARQUITETURA.md`.
- **Sons sintetizados**: funcionais e originais, mas simples. Para regerar/ajustar: `python3 tools/gen_audio.py`.
- **Ainda não testado em vários PCs reais** — confirmar desempenho em máquinas modestas.
- Multiplayer e batalhas em equipe ficaram para o futuro, como previsto no plano.
- O teste de fumaça **apaga o progresso salvo** (ele começa do zero de propósito).

## 7. Estrutura

```
scenes/          cenas (menu, batalha)
scripts/
  programming/   a LINGUAGEM: lexer, parser, checker, compiler, vm, API do robô
  combat/        regras e simulação do combate (sem gráficos)
  ai/            bots e campanha (código Portugol dos inimigos, fases)
  progression/   progresso do aluno e roteiro do tutorial
  robots/        robô 3D provisório (visual)
  arena/         arena 3D e efeitos
  interface/     tema, HUD, editor de código, painéis e telas
  core/          autoloads: GameSettings, GameState
tests/           testes automatizados
tools/           ferramentas de desenvolvimento (capturas, teste de fumaça)
documentation/   linguagem, arquitetura, soluções para o professor
assets/          fontes (OFL), shaders; pastas reservadas para modelos, sons etc.
```

## 8. Licenças de terceiros

Fontes Orbitron, Rajdhani e JetBrains Mono — SIL Open Font License 1.1
(arquivos em `assets/fonts/licencas/`).
