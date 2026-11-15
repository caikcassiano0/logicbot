class_name LBEnemyBrain
extends RefCounted
## CÉREBRO DO INIMIGO (2.0) — a cada turno escolhe UMA tática (LBTactics) para o
## robô inimigo. Nada de trapaça: ele só olha o que qualquer um veria na luta
## (o que o jogador FEZ no turno anterior, vida e fôlego) e troca o programa.
##
##   leitura  0 a 1 — quanto ele "lê" o jogador (0 = só varia; 1 = sempre responde)
##   semente  inteiro — variedade reproduzível: a mesma semente sempre gera as
##            mesmas escolhas (os testes conseguem provar que cada fase tem solução).

var taticas: Array = []          ## ids de LBTactics, na ordem de preferência
var leitura := 0.5
var semente := 1
var atual := ""                  ## id da tática em uso
var historico: Array[String] = []  ## tática escolhida em cada turno
var _compiladas := {}


func _init(p_taticas: Array = [], p_leitura := 0.5, p_semente := 1) -> void:
	taticas = p_taticas
	leitura = p_leitura
	semente = p_semente


## O que o jogador mostrou no turno que acabou (contagens das ações dele).
static func sinais(sim: LBCombatSim) -> Dictionary:
	var j := sim.lutadores[0]
	var e := sim.lutadores[1]
	var c: Dictionary = j.acoes_turno
	var retos := 0       # jab, direto (e o soco antigo atacar)
	var curvos := 0      # cruzados, overhand
	var sobe := 0        # uppercuts
	var baixos := 0
	for nome in c:
		var d: Dictionary = LBCombatRules.ACOES.get(nome, {})
		if nome == "atacar" or (d.get("altura", "") == "alto" and d.get("trajeto", "") == "reto"):
			retos += int(c[nome])
		elif d.get("altura", "") == "alto":
			curvos += int(c[nome])
		elif d.get("altura", "") == "baixo":
			baixos += int(c[nome])
	var esquivas := 0
	for nome in ["esquivar", "esquivar_esquerda", "esquivar_direita", "passo_lado"]:
		esquivas += int(c.get(nome, 0))
	return {
		"retos_altos": retos >= 3 and retos >= curvos + sobe and retos > baixos,
		"uppercuts": sobe >= 2 and sobe >= curvos,
		"golpes_corpo": baixos >= 3 and baixos > retos + curvos + sobe,
		"ganchos_altos": curvos >= 2 and curvos > retos,
		"guarda_alta": int(c.get("bloqueio_alto", 0)) + int(c.get("defender", 0)) >= 2,
		"guarda_baixa": int(c.get("bloqueio_baixo", 0)) >= 2,
		"esquivas": esquivas >= 2,
		"distancia": int(c.get("recuar", 0)) >= 2 or sim.distancia() > 2.5,
		"jogador_cansado": j.folego < 35.0 or j.vida < 60,
		"inimigo_em_apuros": e.folego < 30.0,
	}


## Escolhe a tática do próximo turno. Determinístico para a mesma semente.
func escolher(sim: LBCombatSim) -> String:
	if taticas.is_empty():
		return ""
	var s := sinais(sim)
	var melhor := ""
	var melhor_pontos := -INF
	for k in taticas.size():
		var id: String = taticas[k]
		var tat := LBTactics.get_tatica(id)
		var pontos := 1.0 - 0.05 * k                       # ordem de preferência do bot
		var contra = tat.get("contra", [])
		for sinal in (contra if contra is Array else [contra]):
			if s.get(sinal, false):
				pontos += 3.0 * leitura                    # responde ao que o jogador fez
				break
		if historico.size() >= 1 and historico[-1] == id:
			pontos -= 0.8                                  # evita repetir...
		if historico.size() >= 2 and historico[-2] == id:
			pontos -= 0.6                                  # ...e ficar previsível
		pontos += _ruido(sim.turno, k) * (1.6 - leitura)   # variedade (menos em bots que leem mais)
		if pontos > melhor_pontos:
			melhor_pontos = pontos
			melhor = id
	return melhor


## Número entre 0 e 1 "embaralhado", mas sempre igual para a mesma semente.
func _ruido(turno: int, k: int) -> float:
	var h := hash([semente, turno, k])
	return float(posmod(h, 1000)) / 1000.0


## Primeira tática (turno 1): a preferida do bot.
func primeira() -> String:
	return "" if taticas.is_empty() else String(taticas[0])


## Programa compilado da tática (o inimigo nunca é travado pelos bloqueios do aluno).
func vm_de(id: String) -> LBVM:
	if not _compiladas.has(id):
		var saved := LBRobotAPI.bloqueados
		LBRobotAPI.bloqueados = {}
		_compiladas[id] = LBCompiler.compile_source(LBTactics.get_tatica(id).codigo)
		LBRobotAPI.bloqueados = saved
	return LBVM.new(_compiladas[id])
