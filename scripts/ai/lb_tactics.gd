class_name LBTactics
extends RefCounted
## TÁTICAS DOS INIMIGOS (2.0) — cada tática é um programa Portugol comum, escrito
## com os MESMOS comandos e sensores do aluno. O "cérebro" (LBEnemyBrain) escolhe
## uma tática por turno; o aluno pode ler o código da tática que foi usada.
##
## "contra" diz quando a tática é a resposta certa (ver LBEnemyBrain.sinais()).
## Os pares foram medidos (tools/eval_bots.gd): cada tática listada VENCE o estilo.

const TATICAS := {
	"pressao": {
		"nome": "Pressão",
		"resumo": "Chega perto e solta jab + direto sem parar.",
		"contra": ["distancia"],
		"codigo": """algoritmo "Pressao"
// Encurta a distância e solta a combinação 1-2.
inicio
   se inimigo_atacando_alto entao
      bloqueio_alto()
   senao se inimigo_perto entao
      jab()
      direto()
   senao
      avancar()
   fimse
fimalgoritmo
""",
	},
	"contra_ataque": {
		"nome": "Contra-ataque",
		"resumo": "Espera o seu golpe na cabeça, esquiva para o lado e responde com o gancho.",
		"contra": ["retos_altos"],
		"codigo": """algoritmo "ContraAtaque"
// Deixa você atacar primeiro: esquiva do golpe alto e responde.
inicio
   se inimigo_atacando_alto entao
      esquivar_esquerda()
      cruzado_frente()
   senao se inimigo_atacando_baixo entao
      bloqueio_baixo()
   senao se inimigo_perto e folego > 40 entao
      jab()
   senao se distancia_inimigo > 2.2 entao
      avancar()
   senao
      aguardar()
   fimse
fimalgoritmo
""",
	},
	"pendulo": {
		"nome": "Pêndulo",
		"resumo": "Abaixa por baixo dos seus golpes na cabeça e sobe com o uppercut.",
		"contra": [],
		"codigo": """algoritmo "Pendulo"
// Golpe na cabeça? Abaixe e suba com o uppercut.
inicio
   se inimigo_atacando_alto entao
      abaixar()
      uppercut_frente()
   senao se inimigo_atacando_baixo entao
      bloqueio_baixo()
   senao se inimigo_perto e folego > 40 entao
      jab()
      direto()
   senao se inimigo_perto entao
      recuar()
   senao
      avancar()
   fimse
fimalgoritmo
""",
	},
	"trabalho_corpo": {
		"nome": "Trabalho de corpo",
		"resumo": "Bate no corpo, por baixo da sua guarda alta.",
		"contra": "guarda_alta",
		"codigo": """algoritmo "TrabalhoDeCorpo"
// Sua guarda está alta? Então o corpo está aberto.
inicio
   se inimigo_atacando entao
      bloqueio_alto()
   senao se inimigo_perto entao
      jab_corpo()
      gancho_figado()
   senao
      avancar()
   fimse
fimalgoritmo
""",
	},
	"cabeca": {
		"nome": "Caça à cabeça",
		"resumo": "Mira a cabeça quando você protege o corpo.",
		"contra": ["guarda_baixa", "golpes_corpo"],
		"codigo": """algoritmo "CacaACabeca"
// Guarda baixa deixa a cabeça livre.
inicio
   se inimigo_atacando_alto entao
      abaixar()
   senao se inimigo_atacando_baixo entao
      bloqueio_baixo()
   senao se inimigo_perto entao
      jab()
      cruzado_frente()
   senao
      avancar()
   fimse
fimalgoritmo
""",
	},
	"ganchos": {
		"nome": "Ganchos",
		"resumo": "Golpes curvos: pegam quem esquiva para os lados.",
		"contra": ["esquivas"],
		"codigo": """algoritmo "Ganchos"
// Esquiva lateral não escapa de golpe que vem de lado.
inicio
   se inimigo_atacando entao
      bloqueio_alto()
   senao se inimigo_perto entao
      cruzado_frente()
      cruzado_tras()
   senao
      avancar()
   fimse
fimalgoritmo
""",
	},
	"esquiva_tronco": {
		"nome": "Esquiva de tronco",
		"resumo": "Joga o tronco para trás dos seus ganchos e uppercuts e responde com o direto.",
		"contra": ["ganchos_altos", "uppercuts"],
		"codigo": """algoritmo "EsquivaDeTronco"
// Gancho e uppercut são curtos: um passo de tronco para trás e eles passam no vazio.
inicio
   se inimigo_atacando_alto entao
      recuar_tronco()
      direto()
   senao se inimigo_atacando_baixo entao
      bloqueio_baixo()
   senao se inimigo_perto e folego > 40 entao
      jab()
   senao se distancia_inimigo > 1.8 entao
      avancar()
   senao
      aguardar()
   fimse
fimalgoritmo
""",
	},
	"finalizador": {
		"nome": "Finalizador",
		"resumo": "Você está cansado: ele vai com golpes pesados.",
		"contra": "jogador_cansado",
		"codigo": """algoritmo "Finalizador"
// Sem fôlego, um golpe forte na cabeça derruba.
inicio
   se inimigo_perto entao
      se folego_inimigo < 25 entao
         uppercut_tras()
      senao
         direto()
         cruzado_tras()
      fimse
   senao
      avancar()
   fimse
fimalgoritmo
""",
	},
	"recuperar": {
		"nome": "Recuperar o fôlego",
		"resumo": "Cansado ou perdendo, ele se fecha e recua para respirar.",
		"contra": "inimigo_em_apuros",
		"codigo": """algoritmo "Recuperar"
// Guarda fechada e distância até o fôlego voltar.
inicio
   se inimigo_atacando_alto entao
      bloqueio_alto()
   senao se inimigo_atacando_baixo entao
      bloqueio_baixo()
   senao se inimigo_perto e folego > 60 entao
      jab()
   senao se inimigo_perto entao
      recuar()
   senao
      aguardar()
   fimse
fimalgoritmo
""",
	},
}


static func get_tatica(id: String) -> Dictionary:
	return TATICAS.get(id, {})
