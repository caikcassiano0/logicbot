# LogicBot

Jogo educativo de luta de robôs: você **programa o seu robô em Portugol** e ele luta seguindo o seu código.
Feito em **Godot 4.7.2** para ajudar alunos a aprender algoritmo.

**Jogue grátis:** https://logic-bot.netlify.app/ · **Downloads (Windows, Linux, Mac, Android):** https://logicbot.itch.io/logicbot

## 🤝 O código é aberto: ajude a melhorar o jogo!

Qualquer pessoa pode **estudar, alterar e adicionar coisas** no LogicBot: novas fases, robôs, golpes, cenários, traduções, correções...
Veja o passo a passo em **[CONTRIBUINDO.md](CONTRIBUINDO.md)**.

Achou um bug ou tem uma ideia? Abra uma [Issue](../../issues/new/choose).

## Como abrir o projeto

1. Baixe a **Godot 4.7.2** (versão padrão, não a .NET): https://godotengine.org/download
2. Baixe este código: botão verde **Code → Download ZIP** (ou `git clone`).
3. Abra a Godot, clique em **Importar** e escolha o arquivo `project.godot`.
4. Aperte **F5** para jogar.

Rodar os testes automáticos (330 testes):

```
godot --headless --path . -s res://tests/run_tests.gd
```

## Como o código está organizado

| Pasta | O que tem |
|---|---|
| `scripts/programming/` | A linguagem Portugol: lexer, parser, verificador e a máquina virtual que roda o código do aluno |
| `scripts/combat/` | Regras da luta (turnos, dano, fôlego) |
| `scripts/ai/` | Campanha (as 10 fases) e os robôs inimigos |
| `scripts/interface/` | Menus, editor de código, HUD, tela de resultado |
| `scripts/arena/` | Ringue, cenários e efeitos |
| `scripts/robots/` | Robô 3D e animações |
| `scripts/progression/` | Moedas, loja da Garagem e progresso |
| `tests/` | Testes automáticos |
| `tools/` | Ferramentas (builds, pôsteres, documentação) |
| `documentation/` | [Arquitetura](documentation/ARQUITETURA.md), [Linguagem](documentation/LINGUAGEM.md), [Guia de desenvolvimento](documentation/GUIA_DESENVOLVIMENTO.md), [Créditos](documentation/CREDITOS.md) |

## Licença

O LogicBot é liberado sob a licença **[CC BY-NC 4.0](LICENSE)**:

- ✅ Pode usar, estudar, alterar e compartilhar, inclusive versões modificadas.
- ✅ Tem que dar o crédito ao autor original (Caik / LogicBot).
- ❌ **Não pode usar para fins comerciais** (vender o jogo ou versões dele).

Sons e animações de terceiros seguem as licenças deles — veja [CREDITOS.md](documentation/CREDITOS.md).
