# A linguagem do LogicBot

Portugol inspirado no Visualg, com comandos próprios para o combate.
Maiúsculas e acentos são ignorados: `ENTÃO`, `Entao` e `entao` são a mesma palavra.

## Estrutura de um programa

```
algoritmo "MeuRobo"
var
   contador: inteiro
   alerta: logico
inicio
   // instruções do robô
fimalgoritmo
```

- `var` é opcional. Tipos: `inteiro`, `real`, `logico`, `caractere`.
- Valores iniciais: `0`, `0.0`, `falso`, `""`.
- Comentários: `//` até o fim da linha. Cada instrução em sua própria linha (sem `;`).

## Lacunas (`???`)

Na dificuldade Fácil o código pode vir com `???`. O programa só roda depois que todas as lacunas
forem trocadas pelo comando ou condição certa — o editor aponta a linha.

## Como o programa roda durante a luta

1. O programa executa de cima para baixo até encontrar um **comando de ação**.
2. O robô executa a ação (cada uma leva um tempo). Enquanto isso, o programa fica **pausado** naquela linha.
3. Quando a ação termina, o programa **continua de onde parou**.
4. Ao chegar em `fimalgoritmo`, ele **recomeça do início na hora** — é o "laço principal" do robô.
5. Suas variáveis **mantêm os valores** entre uma volta e outra (dá para fazer contadores).
6. Se uma volta inteira passar sem nenhuma ação, o robô espera 0,25 s (`aguardar`).

## Luta por turnos (2.0)

A luta dura até 60 s, dividida em **turnos de 5 s**. No fim de cada turno a luta **pausa**: o aluno pode
mudar o código e clicar em **CONTINUAR** (o código novo vale a partir do turno seguinte). Na pausa, a aba
**Inimigo** mostra o código que o inimigo usou no turno e o console mostra uma **prévia** do que o seu
programa faria na situação daquele momento. No Médio há 90 s para reprogramar; no Difícil, 45 s
(sem limite no Fácil e no tutorial). Se o tempo acabar, a luta continua (com erro, vale o código anterior).

## Comandos de boxe (2.0)

| Comando | Nº | Duração | Dano | Alcance | Altura / trajeto | Fôlego |
|---|---|---|---|---|---|---|
| `jab()` | 1 | 0,40 s | 4 | 1,8 m | cabeça / reto | 4 |
| `direto()` | 2 | 0,60 s | 9 | 1,9 m | cabeça / reto | 5 |
| `cruzado_frente()` | 3 | 0,55 s | 10 | 1,7 m | cabeça / curvo | 5 |
| `cruzado_tras()` | 4 | 0,70 s | 13 | 1,7 m | cabeça / curvo | 7 |
| `uppercut_frente()` | 5 | 0,60 s | 12 | 1,4 m | cabeça / sobe | 6 |
| `uppercut_tras()` | 6 | 0,75 s | 16 | 1,4 m | cabeça / sobe | 8 |
| `jab_corpo()` | — | 0,42 s | 4 | 1,7 m | corpo / reto | 4 |
| `direto_corpo()` | — | 0,62 s | 9 | 1,8 m | corpo / reto | 5 |
| `gancho_figado()` | — | 0,65 s | 11 | 1,7 m | corpo / curvo | 6 |
| `overhand()` | — | 0,85 s | 17 | 1,9 m | cabeça / curvo (custa 20 de energia) | 9 |

| Defesa | Duração | Efeito |
|---|---|---|
| `bloqueio_alto()` | 0,55 s | segura 75% dos golpes na cabeça (só 25% do uppercut, que sobe pelo meio) |
| `bloqueio_baixo()` | 0,55 s | segura 75% dos golpes no corpo |
| `esquivar_esquerda()` / `esquivar_direita()` | 0,45 s | desvia de golpes **retos** na cabeça (custa 6 de energia) |
| `abaixar()` | 0,50 s | desvia de golpes retos e curvos na cabeça; o **uppercut** pega com +30% (custa 6) |
| `recuar_tronco()` | 0,55 s | desvia de golpes na cabeça de alcance até 1,7 m (ganchos, uppercuts) |
| `passo_lado()` | 0,50 s | sai da linha dos golpes **retos** (cabeça e corpo) |

Regras do boxe:
- **Golpe forte** (dano ≥ 10) interrompe o alvo e o deixa atordoado; **golpe leve** não — os dois socos entram.
- Um golpe leve no rosto, **com fôlego**, corta o golpe forte que o adversário ainda estava preparando.
- **Fôlego** (0–100): golpes gastam; volta 5/s (12/s bloqueando, esquivando, recuando ou aguardando).
  Abaixo de 25 o robô fica 20% mais lento; em 0, um golpe forte na cabeça **derruba** (nocaute).
- **Partes do corpo** (0–100): cabeça avariada (< 40) = atordoamento 60% maior; corpo avariado = fôlego volta
  pela metade; braços avariados (de tanto bloquear) = socos com 80% do dano e guarda segurando só 60%.
- Golpes liberados pela campanha: cruzados e `abaixar` (fase 2), uppercuts e `recuar_tronco` (fase 4),
  golpes no corpo e `passo_lado` (fase 5), `overhand` (fase 8).

## Comandos clássicos

| Comando | Duração | Efeito | Energia |
|---|---|---|---|
| `atacar()` | 0,42 s | soco: 7 de dano se a distância for ≤ 1,7 m | +10 ao acertar |
| `defender()` | 0,55 s | reduz 75% do dano de socos e 50% do especial | +5 ao bloquear |
| `avancar()` | 0,30 s | anda ~1,2 m em direção ao inimigo | — |
| `recuar()` | 0,30 s | anda ~1 m para trás | — |
| `esquivar()` | 0,45 s | fica intocável quase todo o tempo e recua um pouco | custa 8 |
| `pular()` | 0,60 s | no ar, socos não acertam (o especial acerta) | custa 10 |
| `golpe_especial()` | 0,85 s | plasma: 20 de dano, alcance 2,8 m | custa 50 |
| `aguardar()` | 0,25 s | não faz nada | — |

- Golpe **em cheio** interrompe o alvo (0,3 s atordoado).
- Golpe **bloqueado** deixa o atacante desequilibrado (+0,25 s para se recuperar).
- Sem energia suficiente, a ação **falha** e o robô perde 0,35 s.
- Energia: começa em 20, recarrega 6 por segundo, máximo 100.

Os comandos `atacar()`, `defender()`, `esquivar()` e `pular()` são da versão 1.x: continuam funcionando
(códigos antigos não quebram), mas não aparecem mais na Referência.

## Sensores (somente leitura)

| Sensor | Tipo | Significado |
|---|---|---|
| `vida` | inteiro | sua vida (0–200) |
| `energia` | inteiro | sua energia (0–100) |
| `vida_inimigo` | inteiro | vida do inimigo |
| `energia_inimigo` | inteiro | energia do inimigo |
| `distancia_inimigo` | real | distância em metros |
| `inimigo_perto` | logico | distância ≤ 1,7 m (alcance do soco) |
| `inimigo_atacando` | logico | o inimigo está **preparando** um golpe agora |
| `inimigo_defendendo` | logico | o inimigo está com a guarda erguida |
| `defesa_ativa` | logico | sua última ação foi `defender()` |
| `tempo_restante` | inteiro | segundos até o fim (luta de 60 s) |
| `inimigo_atacando_alto` / `inimigo_atacando_baixo` | logico | o golpe que ele prepara vai na cabeça / no corpo |
| `inimigo_bloqueando_alto` / `inimigo_bloqueando_baixo` | logico | a guarda dele protege a cabeça / o corpo agora |
| `folego` / `folego_inimigo` | inteiro | fôlego (0–100) |
| `cabeca`, `corpo`, `bracos` | inteiro | integridade das suas partes (0–100) |
| `cabeca_inimigo`, `corpo_inimigo`, `bracos_inimigo` | inteiro | integridade das partes do inimigo |

## Instruções

```
x <- 10                       // atribuição (também aceita :=)

se condição entao             // condicional
   ...
senao se outra entao          // quantos SENAO SE quiser
   ...
senao
   ...
fimse

enquanto condição faca        // repete enquanto verdadeira
   ...
fimenquanto

repita                        // repete até a condição ficar verdadeira
   ...
ate condição

para i de 1 ate 3 faca        // i precisa ser inteiro declarado em VAR
   ...                        // PASSO opcional: para i de 3 ate 1 passo -1 faca
fimpara

escreval("vida: ", vida)      // escreve no console (escreva também funciona)
```

## Procedimentos

Dão um nome a um grupo de comandos. São declarados **depois do VAR e antes do INICIO**:

```
algoritmo "Organizado"
var
   golpes: inteiro
procedimento contra_ataque()
inicio
   defender()
   atacar()
   golpes <- golpes + 1
fimprocedimento

inicio
   se inimigo_atacando entao
      contra_ataque()
   senao
      avancar()
   fimse
fimalgoritmo
```

- O `inicio` dentro do procedimento é opcional.
- Procedimentos podem usar e alterar as variáveis do algoritmo e chamar outros procedimentos.
- Ainda não recebem parâmetros nem têm variáveis próprias.
- Máximo de 16 chamadas aninhadas (protege contra recursão sem fim).

## Operadores (da menor para a maior precedência)

| Grupo | Operadores |
|---|---|
| lógicos | `ou`, `e`, `nao` |
| comparação | `=`, `<>`, `<`, `>`, `<=`, `>=` |
| soma | `+`, `-` (o `+` também junta textos) |
| multiplicação | `*`, `/` (sempre real), `div` (divisão inteira), `mod` (resto) |

Comparações têm prioridade sobre `e`/`ou`, então `se vida < 30 e energia >= 50 entao` funciona sem parênteses.
Não é permitido encadear comparações (`10 < vida < 30`) — use `vida > 10 e vida < 30`.

## Limites de segurança

| Limite | Valor | O que acontece |
|---|---|---|
| instruções seguidas sem ação | 500 | o programa para com uma explicação (provável laço infinito) |
| tempo por decisão | 8 ms | idem |
| tamanho de texto | 200 caracteres | erro de execução |
| variáveis | 40 | erro de compilação |
| tamanho do programa | 20.000 caracteres | erro de compilação |
| estruturas aninhadas | 12 níveis | erro de compilação |

Quando o programa para por erro, a luta continua (o robô fica parado) e o erro aparece no console
e na tela de resultado. O código do aluno **nunca** acessa nada do jogo além dos comandos e sensores acima.
