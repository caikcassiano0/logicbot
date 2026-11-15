class_name LBCampaign
extends RefCounted
## A CAMPANHA: fases progressivas, cada uma ensinando um conceito.
##
## Cada fase tem:
##   bot        — o inimigo (programa Portugol, igual aos outros bots)
##   requisitos — o que o programa do aluno PRECISA usar para a vitória contar:
##                "acoes": comandos obrigatórios; "usa": estruturas (veja LBProgramInspector);
##                "sensores": sensores que precisam aparecer em alguma condição;
##                "vida_minima": vencer com pelo menos essa vida.
##   inicio     — código inicial por dificuldade (facil tem lacunas ???)
##   dicas      — da mais vaga para a mais concreta (nunca a solução inteira)
##   solucao    — solução de referência; os testes garantem que ela vence e cumpre os requisitos.

const DIFICULDADES := ["Fácil", "Médio", "Difícil"]
const DIFICULDADE_DESC := [
	"Aprendiz: o código vem com lacunas (???) para completar e as dicas aparecem sozinhas.",
	"Estrategista: você recebe só o esqueleto e pode pedir uma dica por fase.",
	"Mestre da Lógica: editor livre, sem dicas. Só as ferramentas de depuração.",
]

const USA_NOMES := {
	"se": "SE", "senao": "SENAO", "senao_se": "SENAO SE", "enquanto": "ENQUANTO",
	"repita": "REPITA", "para": "PARA", "e": "E", "ou": "OU", "nao": "NAO",
	"variavel": "uma variável declarada em VAR", "e_ou": "E ou OU", "procedimento": "um PROCEDIMENTO (criado e chamado)",
}

const FASES := [
	{
		"id": "f1_sequencia",
		"titulo": "Primeiros Passos",
		"conceito": "Sequência de instruções",
		"objetivo": "Derrube o saco de pancadas: ande até ele e solte o jab.",
		"bot": {"nome": "SACO-01", "titulo": "Saco de Pancadas", "nivel": "Fase 1", "cor": "#7f93b0",
			"descricao": "Não se mexe e não revida.", "codigo": "algoritmo \"Saco\"\ninicio\n   aguardar()\nfimalgoritmo\n"},
		"requisitos": {"acoes": ["avancar", "jab"]},
		"dicas": [
			"O programa roda de cima para baixo, uma linha de cada vez — e depois recomeça.",
			"Você precisa de dois comandos: um para andar e outro para socar. Procure-os na aba Comandos da Referência.",
			"Pense na ordem: primeiro o robô precisa chegar perto; só depois o soco alcança.",
		],
		"inicio": [
			"algoritmo \"PrimeirosPassos\"\ninicio\n   // 1) ande em direção ao inimigo\n   ???\n   // 2) solte o jab\n   ???\nfimalgoritmo\n",
			"algoritmo \"PrimeirosPassos\"\ninicio\n   // Aproxime-se do saco de pancadas e golpeie.\n\nfimalgoritmo\n",
			"algoritmo \"PrimeirosPassos\"\ninicio\n\nfimalgoritmo\n",
		],
		"solucao": "algoritmo \"PrimeirosPassos\"\ninicio\n   avancar()\n   jab()\nfimalgoritmo\n",
	},
	{
		"id": "f2_se_senao",
		"titulo": "Decisões",
		"conceito": "SE / SENAO",
		"objetivo": "Vença o TREINO-01 decidindo entre golpear e avançar com SE/SENAO.",
		"bot_id": "treino",
		"requisitos": {"usa": ["senao"], "sensores": ["inimigo_perto"]},
		"dicas": [
			"Golpear de longe não acerta nada. O robô precisa DECIDIR o que fazer.",
			"O sensor inimigo_perto fica verdadeiro quando o soco alcança.",
			"Pense em duas situações: quando o inimigo está perto, o que faz sentido? E quando ele ainda está longe?",
		],
		"inicio": [
			"algoritmo \"Decisoes\"\ninicio\n   se ??? entao\n      jab()\n   senao\n      ???\n   fimse\nfimalgoritmo\n",
			"algoritmo \"Decisoes\"\ninicio\n   // Use SE ... SENAO com o sensor inimigo_perto.\n\nfimalgoritmo\n",
			"algoritmo \"Decisoes\"\ninicio\n\nfimalgoritmo\n",
		],
		"solucao": "algoritmo \"Decisoes\"\ninicio\n   se inimigo_perto entao\n      jab()\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n",
	},
	{
		"id": "f3_energia",
		"titulo": "Fôlego",
		"conceito": "Comparação (>=, <)",
		"objetivo": "O TOURO espera você cansar para dar o golpe pesado. Compare o seu fôlego e respire na hora certa.",
		"bot": {"nome": "TOURO", "titulo": "Peso Pesado", "nivel": "Fase 3", "cor": "#ef4444",
			"descricao": "Troca jab e direto e respira quando cansa. Quando VOCÊ fica sem fôlego, ele solta o uppercut pesado — e sem fôlego, um golpe forte derruba.",
			"codigo": "algoritmo \"Touro\"\ninicio\n   se folego < 30 entao\n      recuar()\n   senao se inimigo_perto e folego_inimigo < 30 entao\n      uppercut_tras()\n   senao se inimigo_perto entao\n      jab()\n      direto()\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n"},
		"requisitos": {"usa": ["se"], "sensores": ["folego"]},
		"dicas": [
			"Cada soco gasta fôlego. Sem fôlego, você fica lento — e um golpe forte na cabeça derruba.",
			"O fôlego volta mais rápido quando o robô se defende, recua ou espera. Qual operador compara 'menor que'?",
			"Antes de socar, pergunte: meu fôlego ainda está acima de um limite seguro? Se não estiver, feche a guarda para respirar.",
		],
		"inicio": [
			"algoritmo \"Folego\"\ninicio\n   se folego ??? 30 entao\n      bloqueio_alto()\n   senao se inimigo_perto entao\n      jab()\n      direto()\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n",
			"algoritmo \"Folego\"\ninicio\n   se inimigo_perto entao\n      jab()\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n",
			"algoritmo \"Folego\"\ninicio\n\nfimalgoritmo\n",
		],
		"solucao": "algoritmo \"Folego\"\ninicio\n   se folego < 30 entao\n      bloqueio_alto()\n   senao se inimigo_perto entao\n      jab()\n      direto()\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n",
	},
	{
		"id": "f4_senao_se",
		"titulo": "Muitos Caminhos",
		"conceito": "SENAO SE",
		"objetivo": "A SERPENTE ataca a cabeça e o corpo. Leia a altura do golpe e escolha a guarda certa com SENAO SE.",
		"bot": {"nome": "SERPENTE", "titulo": "Golpes Alternados", "nivel": "Fase 4", "cor": "#22c55e",
			"descricao": "Alterna golpes no corpo e na cabeça. Uma guarda só não segura os dois.",
			"codigo": "algoritmo \"Serpente\"\ninicio\n   se inimigo_perto entao\n      gancho_figado()\n      cruzado_frente()\n      aguardar()\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n"},
		"requisitos": {"usa": ["senao_se"], "sensores": ["inimigo_atacando_alto", "inimigo_atacando_baixo"]},
		"dicas": [
			"Bloqueio alto protege só a cabeça; bloqueio baixo, só o corpo.",
			"Os sensores inimigo_atacando_alto e inimigo_atacando_baixo dizem para onde vai o golpe dela.",
			"Ordene as perguntas: o golpe vem na cabeça? No corpo? Ela está perto? Ainda está longe?",
		],
		"inicio": [
			"algoritmo \"MuitosCaminhos\"\ninicio\n   se inimigo_atacando_alto entao\n      ???\n   senao se ??? entao\n      bloqueio_baixo()\n   senao se inimigo_perto entao\n      jab()\n      direto()\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n",
			"algoritmo \"MuitosCaminhos\"\ninicio\n   se inimigo_perto entao\n      jab()\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n",
			"algoritmo \"MuitosCaminhos\"\ninicio\n\nfimalgoritmo\n",
		],
		"solucao": "algoritmo \"MuitosCaminhos\"\ninicio\n   se inimigo_atacando_alto entao\n      bloqueio_alto()\n   senao se inimigo_atacando_baixo entao\n      bloqueio_baixo()\n   senao se inimigo_perto entao\n      jab()\n      direto()\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n",
	},
	{
		"id": "f5_variaveis",
		"titulo": "Contando Golpes",
		"conceito": "Variáveis",
		"objetivo": "O RELÓGIO pune quem nunca para. Conte seus golpes numa variável e respire a cada 3.",
		"bot": {"nome": "RELÓGIO", "titulo": "Ritmo Constante", "nivel": "Fase 5", "cor": "#eab308",
			"descricao": "Troca jab e direto no mesmo ritmo e respira quando cansa. Se VOCÊ cansar, ele vem com direto e cruzado.",
			"codigo": "algoritmo \"Relogio\"\ninicio\n   se folego < 30 entao\n      recuar()\n   senao se inimigo_perto e folego_inimigo < 35 entao\n      direto()\n      cruzado_tras()\n   senao se inimigo_perto entao\n      jab()\n      direto()\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n"},
		"requisitos": {"usa": ["variavel"]},
		"dicas": [
			"Uma variável guarda um valor entre uma volta e outra do programa — como um placar.",
			"Declare a variável na seção VAR como um número inteiro. A cada soco, o novo valor dela deve ser o valor antigo mais um.",
			"O operador mod dá o resto da divisão. Quando o resto da divisão por 3 for zero, é hora de recuar e respirar.",
		],
		"inicio": [
			"algoritmo \"ContandoGolpes\"\nvar\n   golpes: inteiro\ninicio\n   se inimigo_perto entao\n      direto()\n      golpes <- ???\n      se golpes mod 3 = 0 entao\n         recuar()\n         recuar()\n      fimse\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n",
			"algoritmo \"ContandoGolpes\"\nvar\n   golpes: inteiro\ninicio\n   se inimigo_perto entao\n      direto()\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n",
			"algoritmo \"ContandoGolpes\"\ninicio\n\nfimalgoritmo\n",
		],
		"solucao": "algoritmo \"ContandoGolpes\"\nvar\n   golpes: inteiro\ninicio\n   se inimigo_perto entao\n      direto()\n      golpes <- golpes + 1\n      se golpes mod 3 = 0 entao\n         recuar()\n         recuar()\n      fimse\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n",
	},
	{
		"id": "f6_logicos",
		"titulo": "Leitura",
		"conceito": "Operadores lógicos (E, NAO)",
		"objetivo": "A MURALHA fecha a cabeça quase o tempo todo. Bata no corpo quando ela proteger a cabeça — e na cabeça quando NÃO proteger.",
		"bot": {"nome": "MURALHA", "titulo": "Guarda Alta", "nivel": "Fase 6", "cor": "#3b82f6",
			"descricao": "Vive de guarda alta: bloqueia e responde com o cruzado. Golpes na cabeça quase não entram.",
			"codigo": "algoritmo \"Muralha\"\ninicio\n   se inimigo_atacando_alto entao\n      bloqueio_alto()\n      cruzado_tras()\n   senao se inimigo_perto entao\n      bloqueio_alto()\n      jab()\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n"},
		"requisitos": {"usa": ["e", "nao"], "sensores": ["inimigo_bloqueando_alto"]},
		"dicas": [
			"Bloqueio alto não protege o corpo. Os golpes no corpo foram liberados na fase anterior.",
			"Para atacar o corpo, duas coisas precisam ser verdadeiras ao mesmo tempo: ela está perto e ela está bloqueando a cabeça.",
			"E quando ela está perto e NÃO está bloqueando a cabeça? Aí a cabeça está aberta. Qual operador inverte uma condição?",
		],
		"inicio": [
			"algoritmo \"Leitura\"\ninicio\n   se inimigo_perto ??? inimigo_bloqueando_alto entao\n      jab_corpo()\n   senao se inimigo_perto e ??? inimigo_bloqueando_alto entao\n      direto()\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n",
			"algoritmo \"Leitura\"\ninicio\n   se inimigo_perto entao\n      direto()\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n",
			"algoritmo \"Leitura\"\ninicio\n\nfimalgoritmo\n",
		],
		"solucao": "algoritmo \"Leitura\"\ninicio\n   se inimigo_perto e inimigo_bloqueando_alto entao\n      gancho_figado()\n   senao se inimigo_perto e nao inimigo_bloqueando_alto entao\n      direto()\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n",
	},
	{
		"id": "f7_para",
		"titulo": "Rajada",
		"conceito": "Laço PARA",
		"objetivo": "O ESQUIVO desvia de todo golpe reto e responde. Golpes curvos pegam quem esquiva para o lado: solte uma rajada de cruzados com PARA.",
		"bot": {"nome": "ESQUIVO", "titulo": "Pernas Rápidas", "nivel": "Fase 7", "cor": "#06b6d4",
			"descricao": "Esquiva para o lado dos seus golpes na cabeça e devolve com o cruzado. Golpes retos na cabeça passam no vazio.",
			"codigo": "algoritmo \"Esquivo\"\ninicio\n   se inimigo_atacando_alto entao\n      esquivar_direita()\n      cruzado_tras()\n   senao se inimigo_perto entao\n      jab()\n      direto()\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n"},
		"requisitos": {"usa": ["para"]},
		"dicas": [
			"Esquiva lateral não escapa de golpe que vem de lado. Quais golpes são curvos?",
			"PARA repete um bloco um número fixo de vezes e usa uma variável contadora, do tipo inteiro, declarada em VAR.",
			"Quantos cruzados seguidos bastam para pressioná-lo? Coloque o golpe curvo dentro do PARA quando estiver perto.",
		],
		"inicio": [
			"algoritmo \"Rajada\"\nvar\n   i: inteiro\ninicio\n   se inimigo_perto entao\n      para i de 1 ate ??? faca\n         ???\n      fimpara\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n",
			"algoritmo \"Rajada\"\nvar\n   i: inteiro\ninicio\n   se inimigo_perto entao\n      jab()\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n",
			"algoritmo \"Rajada\"\ninicio\n\nfimalgoritmo\n",
		],
		"solucao": "algoritmo \"Rajada\"\nvar\n   i: inteiro\ninicio\n   se inimigo_perto entao\n      para i de 1 ate 2 faca\n         cruzado_frente()\n      fimpara\n      recuar()\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n",
	},
	{
		"id": "f7a_enquanto",
		"titulo": "Paciência",
		"conceito": "Laço ENQUANTO",
		"objetivo": "Chegar perto da TORRE é perigoso. Enquanto a energia não encher, fique longe; depois, dispare o golpe especial.",
		"bot": {"nome": "TORRE", "titulo": "Fortaleza", "nivel": "Fase 8", "cor": "#f97316",
			"descricao": "Nunca sai do lugar. Quem chega perto leva direto e cruzado.",
			"codigo": "algoritmo \"Torre\"\ninicio\n   se inimigo_perto entao\n      direto()\n      cruzado_tras()\n   senao\n      aguardar()\n   fimse\nfimalgoritmo\n"},
		"requisitos": {"usa": ["enquanto"], "acoes": ["golpe_especial"]},
		"dicas": [
			"Chegar perto da TORRE é perigoso. O golpe especial alcança 2,8 m — mais longe que os socos dela.",
			"ENQUANTO repete um bloco enquanto a condição for verdadeira. Que condição significa 'ainda não tenho energia para o especial'?",
			"Dentro do laço, mantenha distância da TORRE. Quando o laço terminar, a energia já está cheia: o que fazer agora?",
		],
		"inicio": [
			"algoritmo \"Paciencia\"\ninicio\n   enquanto energia < ??? faca\n      se inimigo_perto entao\n         recuar()\n      senao\n         aguardar()\n      fimse\n   fimenquanto\n   se distancia_inimigo <= 2.8 entao\n      golpe_especial()\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n",
			"algoritmo \"Paciencia\"\ninicio\n   se inimigo_perto entao\n      jab()\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n",
			"algoritmo \"Paciencia\"\ninicio\n\nfimalgoritmo\n",
		],
		"solucao": "algoritmo \"Paciencia\"\ninicio\n   enquanto energia < 50 faca\n      se inimigo_perto entao\n         recuar()\n      senao\n         aguardar()\n      fimse\n   fimenquanto\n   se distancia_inimigo <= 2.8 entao\n      golpe_especial()\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n",
	},
	{
		"id": "f7b_procedimentos",
		"titulo": "Meu Combo",
		"conceito": "Procedimentos",
		"objetivo": "Crie o seu próprio combo como um PROCEDIMENTO e use-o contra o VÓRTEX.",
		"bot_id": "vortex",
		"requisitos": {"usa": ["procedimento"]},
		"dicas": [
			"Um procedimento dá um NOME a um grupo de comandos. O código principal fica mais curto e fácil de ler.",
			"O procedimento é declarado antes do INICIO principal, com um nome que explique o que ele faz. Para usá-lo, basta escrever o nome dele onde precisar.",
			"Que sequência de golpes você usaria sempre que ele baixar a guarda? Esse é o seu combo.",
		],
		"inicio": [
			"algoritmo \"MeuCombo\"\nprocedimento meu_combo()\ninicio\n   jab()\n   ???\nfimprocedimento\n\ninicio\n   se inimigo_atacando_alto entao\n      bloqueio_alto()\n   senao se inimigo_atacando_baixo entao\n      bloqueio_baixo()\n   senao se inimigo_perto entao\n      ???\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n",
			"algoritmo \"MeuCombo\"\ninicio\n   se inimigo_perto entao\n      jab()\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n",
			"algoritmo \"MeuCombo\"\ninicio\n\nfimalgoritmo\n",
		],
		"solucao": "algoritmo \"MeuCombo\"\nprocedimento meu_combo()\ninicio\n   jab()\n   gancho_figado()\nfimprocedimento\n\ninicio\n   se inimigo_atacando_alto entao\n      bloqueio_alto()\n   senao se inimigo_atacando_baixo entao\n      bloqueio_baixo()\n   senao se inimigo_perto entao\n      meu_combo()\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n",
	},
	{
		"id": "f8_omega",
		"titulo": "Ômega",
		"conceito": "Tudo junto",
		"objetivo": "O ÔMEGA tem várias táticas e lê o seu jogo a cada turno. Use tudo o que aprendeu — e ajuste o código nas pausas.",
		"bot": {"nome": "ÔMEGA", "titulo": "Campeão", "nivel": "Fase final", "cor": "#a855f7",
			"descricao": "Troca de tática a cada turno, conforme o que você fez: guarda alta, guarda baixa, esquivas ou cansaço.",
			"taticas": ["pressao", "ganchos", "trabalho_corpo", "cabeca", "esquiva_tronco", "pendulo", "contra_ataque", "finalizador", "recuperar"],
			"leitura": 1.0,
			"codigo": ""},
		"requisitos": {"usa": ["senao_se"]},
		"dicas": [
			"Leia o código dos inimigos anteriores: o ÔMEGA junta o melhor de cada um.",
			"Nas pausas, olhe a aba Inimigo: a tática dele muda conforme o que você faz.",
			"Proteja a altura certa, não fique sem fôlego e varie entre cabeça e corpo.",
		],
		"inicio": [
			"algoritmo \"Final\"\ninicio\n   // Use tudo o que aprendeu. Dica: comece pela sua solução da fase 4.\n   ???\nfimalgoritmo\n",
			"algoritmo \"Final\"\ninicio\n   se inimigo_perto entao\n      jab()\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n",
			"algoritmo \"Final\"\ninicio\n\nfimalgoritmo\n",
		],
		"solucao": "algoritmo \"Final\"\ninicio\n   se inimigo_atacando_alto entao\n      bloqueio_alto()\n   senao se inimigo_atacando_baixo entao\n      bloqueio_baixo()\n   senao se folego < 30 entao\n      recuar()\n   senao se inimigo_perto entao\n      direto()\n   senao\n      avancar()\n   fimse\nfimalgoritmo\n",
	},
]


static func count() -> int:
	return FASES.size()


static func index_of(id: String) -> int:
	for i in FASES.size():
		if FASES[i].id == id:
			return i
	return -1


static func get_fase(id: String) -> Dictionary:
	var i := index_of(id)
	return FASES[i] if i >= 0 else {}


## Dicionário do inimigo da fase (mesmo formato de LBBotLibrary.BOTS).
static func bot_of(fase: Dictionary) -> Dictionary:
	if fase.has("bot"):
		var b: Dictionary = fase.bot.duplicate()
		b["id"] = fase.id
		if b.has("taticas") and String(b.codigo) == "":
			b["codigo"] = LBTactics.get_tatica(b.taticas[0]).codigo
		return b
	return LBBotLibrary.get_bot(fase.bot_id)


## Confere os requisitos de estrutura. Retorna a lista do que FALTA (vazia = ok).
static func missing_requirements(fase: Dictionary, program: Dictionary) -> Array[String]:
	var falta: Array[String] = []
	var req: Dictionary = fase.get("requisitos", {})
	var f := LBProgramInspector.features(program)
	for a in req.get("acoes", []):
		if not f.acoes.has(a):
			falta.append("usar o comando %s()" % a)
	for u in req.get("usa", []):
		var ok: bool = (f.e or f.ou) if u == "e_ou" else f.get(u, false)
		if not ok:
			falta.append("usar %s" % USA_NOMES.get(u, u))
	for s in req.get("sensores", []):
		if not f.sensores_em_condicao.has(s):
			falta.append("usar o sensor %s em uma condição" % s)
	return falta


## Texto curto dos requisitos (para mostrar ao aluno).
static func requirements_text(fase: Dictionary) -> String:
	var req: Dictionary = fase.get("requisitos", {})
	var parts: Array[String] = []
	for a in req.get("acoes", []):
		parts.append("%s()" % a)
	for u in req.get("usa", []):
		parts.append(USA_NOMES.get(u, u))
	for s in req.get("sensores", []):
		parts.append("sensor %s" % s)
	if req.has("vida_minima"):
		parts.append("terminar com vida ≥ %d" % req.vida_minima)
	return "Obrigatório: " + ", ".join(parts) if not parts.is_empty() else ""
