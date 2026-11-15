class_name LBRewards
extends RefCounted
## Experiência, níveis, conquistas e personalização.
##
## Regra de ouro: recompensar APRENDIZADO, não tempo de jogo.
##   * XP só vem de coisas novas: concluir uma fase pela 1ª vez, concluí-la numa
##     dificuldade maior, vencer um bot do treino pela 1ª vez, concluir o tutorial.
##   * Repetir a mesma luta não dá XP (não adianta "farmar").
##   * Conquistas celebram hábitos de quem programa bem: depurar, testar valores,
##     acertar de primeira, persistir depois de errar.
## Cores se desbloqueiam por nível. As MOEDAS (2.0, LBCoins) vêm da qualidade do
## algoritmo e compram só itens VISUAIS na loja (LBShop) — nunca força na luta.

const XP_TUTORIAL := 80
const XP_FASE := 100
const XP_DIFICULDADE := [1.0, 1.5, 2.0]
const XP_DE_PRIMEIRA := 50
const XP_SUBIU_DIFICULDADE := 50
const XP_BOT_TREINO := 40

## XP total necessário para ALCANÇAR cada nível (índice 0 = nível 1).
const NIVEIS := [0, 100, 250, 450, 700, 1000, 1400, 1900, 2500, 3200]

const CONQUISTAS := {
	"tutorial": {"nome": "Olá, Mundo Robótico", "desc": "Conclua o tutorial."},
	"primeira_vitoria": {"nome": "Primeira Vitória", "desc": "Vença sua primeira luta."},
	"de_primeira": {"nome": "De Primeira!", "desc": "Conclua uma fase da campanha na primeira tentativa."},
	"persistente": {"nome": "Persistente", "desc": "Conclua uma fase depois de 3 ou mais tentativas. Errar faz parte!"},
	"depurador": {"nome": "Detetive de Bugs", "desc": "Use o botão PASSO para analisar uma luta."},
	"escritor": {"nome": "Diário de Bordo", "desc": "Use escreval para acompanhar valores durante a luta."},
	"energia": {"nome": "Gestor de Energia", "desc": "Vença usando golpes especiais sem nenhuma falha por falta de energia."},
	"intocavel": {"nome": "Intocável", "desc": "Vença uma luta perdendo menos de 10 de vida."},
	"estrategista": {"nome": "Estrategista", "desc": "Conclua 4 fases da campanha."},
	"mestre": {"nome": "Mestre da Lógica", "desc": "Conclua toda a campanha."},
	"sem_rodinhas": {"nome": "Sem Rodinhas", "desc": "Conclua uma fase na dificuldade Difícil."},
	"sparring": {"nome": "Sparring", "desc": "Vença os 3 bots do treino livre."},
}

const CORES := [
	{"id": "azul", "nome": "Azul Titan", "pintura": "1e40af", "brilho": "22d3ee", "nivel": 1},
	{"id": "esmeralda", "nome": "Esmeralda", "pintura": "065f46", "brilho": "34d399", "nivel": 2},
	{"id": "ouro", "nome": "Ouro Solar", "pintura": "a16207", "brilho": "fde047", "nivel": 4},
	{"id": "nebulosa", "nome": "Nebulosa", "pintura": "5b21b6", "brilho": "c084fc", "nivel": 6},
	{"id": "polar", "nome": "Polar", "pintura": "94a3b8", "brilho": "e0f2fe", "nivel": 8},
]

const ARMADURAS := [
	{"id": "padrao", "nome": "TITAN-A", "desc": "Modelo padrão, equilibrado.", "nivel": 1},
	{"id": "vanguarda", "nome": "VANGUARDA", "desc": "Ombreiras e antebraços reforçados.", "nivel": 3},
	{"id": "espectro", "nome": "ESPECTRO", "desc": "Silhueta aerodinâmica com asas de energia.", "nivel": 5},
	{"id": "campeao", "nome": "CAMPEÃO", "desc": "Coroa de energia. Exclusiva de quem completa a campanha.", "conquista": "mestre"},
]


static func nivel(xp: int) -> int:
	var n := 1
	for i in NIVEIS.size():
		if xp >= NIVEIS[i]:
			n = i + 1
	return n


## [xp dentro do nível atual, xp necessário para o próximo] (no nível máximo, [0, 0]).
static func progresso_nivel(xp: int) -> Array:
	var n := nivel(xp)
	if n >= NIVEIS.size():
		return [0, 0]
	return [xp - NIVEIS[n - 1], NIVEIS[n] - NIVEIS[n - 1]]


static func cor_liberada(data: LBProgressData, c: Dictionary) -> bool:
	return nivel(data.xp) >= int(c.nivel)


static func armadura_liberada(data: LBProgressData, a: Dictionary) -> bool:
	if a.has("conquista"):
		return data.conquistas.has(a.conquista)
	return nivel(data.xp) >= int(a.nivel)


## Aparência escolhida (para LBRoboMixamo.build). Volta ao padrão se algo estiver bloqueado.
static func look_for(data: LBProgressData) -> Dictionary:
	var cor: Dictionary = CORES[0]
	for c in CORES:
		if c.id == data.cor and cor_liberada(data, c):
			cor = c
	var arm := "padrao"
	for a in ARMADURAS:
		if a.id == data.armadura and armadura_liberada(data, a):
			arm = a.id
	var eq := LBShop.equipados(data)
	return {"pintura": Color(cor.pintura), "brilho": Color(cor.brilho), "armadura": arm,
		"pecas": eq, "acabamento": eq.get("acabamento", "padrao"), "danca": eq.get("danca", "danca_hiphop_3")}


## Aplica as recompensas de um acontecimento e devolve o resumo.
## ctx: modo ("campanha"/"treino"/"tutorial"), venceu, fase_id, cumpriu_requisitos, vida,
##      dificuldade, tentativas, bot_id, usou_passo, usou_escreval, especiais, falhas_energia, dano_recebido
static func processar(data: LBProgressData, ctx: Dictionary) -> Dictionary:
	var xp := 0
	var novas: Array[String] = []
	var nivel_antes := nivel(data.xp)
	var venceu: bool = ctx.get("venceu", false)
	match ctx.get("modo", ""):
		"tutorial":
			if not data.tutorial_concluido:
				xp += XP_TUTORIAL
			data.tutorial_concluido = true
			_ganhar(data, "tutorial", novas)
		"campanha":
			var id: String = ctx.get("fase_id", "")
			if venceu and ctx.get("cumpriu_requisitos", false):
				var ja: bool = data.fase_concluida(id)
				var dif_antes: int = int(data.fases.get(id, {}).get("dificuldade", -1))
				var dif: int = ctx.get("dificuldade", 0)
				if not ja:
					xp += int(XP_FASE * XP_DIFICULDADE[dif])
					if int(ctx.get("tentativas", 0)) <= 1:
						xp += XP_DE_PRIMEIRA
						_ganhar(data, "de_primeira", novas)
				elif dif > dif_antes:
					xp += XP_SUBIU_DIFICULDADE
				if int(ctx.get("tentativas", 0)) >= 3:
					_ganhar(data, "persistente", novas)
				data.concluir_fase(id, int(ctx.get("vida", 0)))
				if dif == 2:
					_ganhar(data, "sem_rodinhas", novas)
				if data.fases_concluidas() >= 4:
					_ganhar(data, "estrategista", novas)
				if data.fases_concluidas() >= LBCampaign.count():
					_ganhar(data, "mestre", novas)
		"treino":
			var bot_id: String = ctx.get("bot_id", "")
			if venceu and not data.treino_vencidos.has(bot_id):
				data.treino_vencidos[bot_id] = true
				xp += XP_BOT_TREINO
			if data.treino_vencidos.size() >= LBBotLibrary.BOTS.size():
				_ganhar(data, "sparring", novas)

	if ctx.get("modo", "") != "tutorial":
		if venceu:
			_ganhar(data, "primeira_vitoria", novas)
			if int(ctx.get("especiais", 0)) >= 2 and int(ctx.get("falhas_energia", 0)) == 0:
				_ganhar(data, "energia", novas)
			if int(ctx.get("dano_recebido", 100)) < 10:
				_ganhar(data, "intocavel", novas)
		if ctx.get("usou_passo", false):
			_ganhar(data, "depurador", novas)
		if ctx.get("usou_escreval", false):
			_ganhar(data, "escritor", novas)

	data.xp += xp
	var nivel_depois := nivel(data.xp)
	var libs: Array[String] = []
	for c in CORES:
		if int(c.nivel) > nivel_antes and int(c.nivel) <= nivel_depois:
			libs.append("cor " + c.nome)
	return {"xp": xp, "conquistas": novas, "nivel_antes": nivel_antes, "nivel_depois": nivel_depois, "desbloqueios": libs}


static func _ganhar(data: LBProgressData, id: String, novas: Array[String]) -> void:
	if not data.conquistas.has(id):
		data.conquistas[id] = true
		novas.append(id)


## Texto curto do resumo (para a tela de resultado e o tutorial).
static func resumo_texto(r: Dictionary, data: LBProgressData) -> String:
	var partes: Array[String] = []
	if r.xp > 0:
		partes.append("+%d XP" % r.xp)
	var p := progresso_nivel(data.xp)
	partes.append("Nível %d%s" % [nivel(data.xp), (" (%d/%d)" % [p[0], p[1]]) if p[1] > 0 else " (máximo)"])
	if r.nivel_depois > r.nivel_antes:
		partes.append("SUBIU DE NÍVEL!")
	for c in r.conquistas:
		partes.append("★ " + CONQUISTAS[c].nome)
	if not r.desbloqueios.is_empty():
		partes.append("Desbloqueado: " + ", ".join(r.desbloqueios))
	return "  ·  ".join(partes)
