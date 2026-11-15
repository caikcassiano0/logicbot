class_name LBTutorial
extends RefCounted
## Roteiro do TUTORIAL OBRIGATÓRIO. Curto e prático: o aluno aprende fazendo.
##   1 arena e robô → 2 editor → 3 sequência (luta) → 4 SE/SENAO (luta) → 5 conclusão
## Cada passo de luta tem requisitos conferidos ANTES da luta (para não perder tempo)
## e uma explicação do resultado DEPOIS dela.

const STEPS := [
	{
		"id": "arena", "tipo": "info",
		"titulo": "Bem-vindo ao LogicBot!",
		"texto": "O robô [color=#22d3ee][b]azul[/b][/color] é o seu: o TITAN-A. Ele [b]não obedece a botões[/b] — ele segue o [b]programa[/b] que você escrever.\nNo alto ficam a [b]vida[/b] (barra grande) e a [b]energia[/b] (barra amarela, usada em golpes especiais).",
	},
	{
		"id": "editor", "tipo": "info",
		"titulo": "O editor de código",
		"texto": "Embaixo fica o [b]editor[/b]. Todo programa começa com [code]algoritmo[/code], e as instruções ficam entre [code]inicio[/code] e [code]fimalgoritmo[/code].\nÀ esquerda, a [b]Referência[/b] lista os comandos: clique para ler, duplo clique para inserir.",
	},
	{
		"id": "sequencia", "tipo": "luta",
		"titulo": "Passo 1 — Sequência",
		"texto": "Troque os [b]???[/b] por [color=#22d3ee]avancar()[/color] e [color=#22d3ee]jab()[/color] (o soco rápido). O programa roda de cima para baixo e, no fim, [b]recomeça[/b]. Depois clique em [b]PRONTO ▶[/b].",
		"fase": "f1_sequencia",
		"sucesso": "Isso! Seu robô repetiu [b]avancar()[/b] e [b]jab()[/b] até derrubar o saco. Uma lista de instruções executadas em ordem é uma [b]sequência[/b].",
	},
	{
		"id": "se", "tipo": "luta",
		"titulo": "Passo 2 — Decidindo com SE",
		"texto": "Agora o inimigo [b]revida[/b]! Socar de longe não acerta nada. Complete o código: [code]se inimigo_perto entao[/code] dê o jab, [code]senao[/code] avance.\nO sensor [color=#fbbf24]inimigo_perto[/color] é verdadeiro quando o soco alcança.",
		"fase": "f2_se_senao",
		"sucesso": "Perfeito! A cada volta o robô [b]testou a condição[/b]: perto → jab(), longe → avancar(). Isso é [b]tomada de decisão[/b] com SE/SENAO.",
	},
	{
		"id": "fim", "tipo": "fim",
		"titulo": "Tutorial concluído!",
		"texto": "Você usou [b]sequência[/b] e [b]SE/SENAO[/b] — a base de todo programa.\nA [b]Campanha[/b] e o [b]Treino livre[/b] foram liberados. Na campanha, cada fase ensina um conceito novo.",
	},
]


static func step(i: int) -> Dictionary:
	return STEPS[clampi(i, 0, STEPS.size() - 1)]


static func count() -> int:
	return STEPS.size()
