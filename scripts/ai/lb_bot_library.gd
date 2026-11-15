class_name LBBotLibrary
extends RefCounted
## Os oponentes do jogo.
##
## Decisão de projeto: os inimigos são programados NA MESMA LINGUAGEM do aluno
## e rodam na mesma máquina virtual, com os mesmos sensores e regras.
## Vantagens: a IA é justa (sem trapaça invisível) e o aluno pode LER o código
## do inimigo depois da luta para entender por que perdeu.

const BOTS := [
	{
		"id": "treino",
		"nome": "TREINO-01",
		"titulo": "Bot de Treinamento",
		"nivel": "Iniciante",
		"cor": "#22d3ee",
		"descricao": "Avança e solta o jab. Depois de cada soco ele para um instante para respirar. Nunca se defende.",
		"codigo": """algoritmo "Treino01"
// Estratégia simples: chegar perto e soltar o jab.
inicio
   se inimigo_perto entao
      jab()
      aguardar()
      aguardar()
   senao
      avancar()
   fimse
fimalgoritmo
""",
	},
	{
		"id": "sentinela",
		"nome": "SENTINELA",
		"titulo": "Guardiã Defensiva",
		"nivel": "Intermediário",
		"cor": "#ffc94a",
		"descricao": "Nunca sai do lugar. Lê a altura dos seus golpes e bloqueia; quem chega perto leva direto e cruzado. De longe, dispara o especial.",
		"codigo": """algoritmo "Sentinela"
// Nunca anda: lê a altura dos golpes, bloqueia e responde pesado.
inicio
   se inimigo_atacando_alto entao
      bloqueio_alto()
   senao se inimigo_atacando_baixo entao
      bloqueio_baixo()
   senao se inimigo_perto entao
      direto()
      cruzado_tras()
   senao se energia >= 50 e distancia_inimigo <= 2.8 entao
      golpe_especial()
   senao
      aguardar()
   fimse
fimalgoritmo
""",
	},
	{
		"id": "vortex",
		"nome": "VÓRTEX",
		"titulo": "Duelista Agressivo",
		"nivel": "Avançado",
		"cor": "#ff3b4e",
		"descricao": "Ataca em rajadas (jab, jab, direto) e fecha a guarda alta quando você ataca. Bater na guarda dele não adianta.",
		"codigo": """algoritmo "Vortex"
// Ataca em rajadas (jab, jab, direto) e fecha a guarda quando você ataca.
var
   i: inteiro
inicio
   se inimigo_atacando entao
      bloqueio_alto()
   senao se inimigo_perto entao
      para i de 1 ate 2 faca
         jab()
      fimpara
      direto()
      aguardar()
   senao
      avancar()
   fimse
fimalgoritmo
""",
	},
	{
		"id": "brutus",
		"nome": "BRUTUS",
		"titulo": "Pugilista de Rua",
		"nivel": "Intermediário",
		"cor": "#f59e0b",
		"descricao": "Boxeador com 5 táticas. Troca de tática a cada turno — às vezes reage ao que você fez, às vezes só muda para não ser previsível.",
		"taticas": ["pressao", "ganchos", "trabalho_corpo", "esquiva_tronco", "contra_ataque", "recuperar"],
		"leitura": 0.5,
		"codigo": LBTactics.TATICAS.pressao.codigo,
	},
	{
		"id": "maestro",
		"nome": "MAESTRO",
		"titulo": "Mestre do Ringue",
		"nivel": "Avançado",
		"cor": "#a855f7",
		"descricao": "Lê o seu jogo: se você repete um padrão, ele escolhe a tática que vence esse padrão. Tem 8 táticas.",
		"taticas": ["pressao", "ganchos", "trabalho_corpo", "cabeca", "esquiva_tronco", "pendulo", "contra_ataque", "finalizador", "recuperar"],
		"leitura": 1.0,
		"codigo": LBTactics.TATICAS.pressao.codigo,
	}
]


static func get_bot(id: String) -> Dictionary:
	for b in BOTS:
		if b.id == id:
			return b
	return BOTS[0]


## Programa inicial que o jogador recebe.
const TEMPLATE := """algoritmo "MeuRobo"
var
   // declare suas variáveis aqui. Ex:  contador: inteiro
inicio
   se inimigo_perto entao
      jab()
   senao
      avancar()
   fimse
fimalgoritmo
"""



## Cria a simulação contra um bot (com cérebro, se o bot tiver táticas).
static func nova_luta(vm_jogador: LBVM, bot: Dictionary, semente := 1, nome_jogador := "TITAN-A") -> LBCombatSim:
	var s := LBCombatSim.new()
	var saved := LBRobotAPI.bloqueados
	LBRobotAPI.bloqueados = {}
	var vm_bot := LBVM.new(LBCompiler.compile_source(bot.codigo))
	LBRobotAPI.bloqueados = saved
	s.setup(vm_jogador, vm_bot, nome_jogador, bot.nome)
	if bot.has("taticas"):
		s.usar_cerebro(LBEnemyBrain.new(bot.taticas, float(bot.get("leitura", 0.5)), semente))
	return s
