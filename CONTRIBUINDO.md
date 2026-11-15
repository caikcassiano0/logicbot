# Como contribuir com o LogicBot

Obrigado por querer ajudar! Qualquer contribuição é bem-vinda: código, fases novas, ideias, correções de texto e relatos de bugs.

## Só quero dar uma ideia ou avisar de um bug

Abra uma **Issue** (aba *Issues* → *New issue*) e escolha "Bug" ou "Ideia". Não precisa saber programar.

## Quero alterar o jogo

1. Clique em **Fork** (canto de cima, à direita) para criar uma cópia do projeto na sua conta.
2. Baixe a sua cópia e abra na **Godot 4.7.2** (`Importar` → `project.godot`).
3. Faça a sua alteração.
4. Rode os testes e confira se todos passam:
   ```
   godot --headless --path . -s res://tests/run_tests.gd
   ```
5. Envie para a sua cópia no GitHub e clique em **Contribute → Open pull request**.
6. Explique no pull request **o que mudou e por quê**. Prints ou um GIF ajudam muito.

O autor vai revisar e, se estiver tudo certo, juntar a sua mudança ao jogo.

## Boas primeiras contribuições

- **Nova fase da campanha:** as fases ficam em `scripts/ai/lb_campaign.gd`. Cada fase tem título, conceito, robô inimigo, objetivo e um exemplo de resposta.
- **Novo comando ou sensor:** veja `scripts/programming/lb_robot_api.gd` e a documentação em `documentation/LINGUAGEM.md`.
- **Novo cenário:** `scripts/arena/lb_cenarios.gd`.
- **Itens da Garagem:** `scripts/progression/lb_shop.gd`.
- **Textos e mensagens de erro** mais claras para alunos iniciantes.

## Combinados

- O jogo é **educativo**: as mensagens devem ser simples e em português.
- Uma mudança por pull request (fica mais fácil de revisar).
- Novos testes para coisas novas, quando der (pasta `tests/`).
- Use só sons, imagens e modelos que você tem direito de usar, e coloque o crédito em `documentation/CREDITOS.md`.
- Ao contribuir, você concorda que a sua contribuição fica sob a mesma licença do projeto (CC BY-NC 4.0).
