class_name LBCoins
extends RefCounted
## MOEDAS (2.0) — pagam pela QUALIDADE do algoritmo, não pelo tempo de jogo.
##
##   Nota da luta (0 a 100) = algoritmo (até 60) + vida que sobrou (até 40, só vencendo)
##   Perdeu? Conta só a parte do algoritmo.
##
## Para não virar "farm": em cada fase/bot você ganha só o quanto SUPERAR o seu
## próprio recorde. Repetir a mesma luta igual não dá moedas; melhorar o código, dá.

const LEITURA := ["inimigo_atacando", "inimigo_atacando_alto", "inimigo_atacando_baixo",
	"inimigo_defendendo", "inimigo_bloqueando_alto", "inimigo_bloqueando_baixo",
	"folego_inimigo", "vida_inimigo", "energia_inimigo", "cabeca_inimigo", "corpo_inimigo", "bracos_inimigo"]
const MAX_ALGORITMO := 60
const MAX_VIDA_PONTOS := 40


## Nota de uma luta já terminada. program = resultado da compilação do código do aluno.
## requisitos_ok: na campanha, se cumpriu o que a fase pede (no treino, true).
static func nota(sim: LBCombatSim, program: Dictionary, requisitos_ok: bool) -> Dictionary:
	var eu := sim.lutadores[0]
	var ele := sim.lutadores[1]
	var itens: Array = []
	var alg := 0

	var sem_erro := int(eu.stats.get("erros_programa", 0)) == 0 and eu.erro_programa == null
	var p_erro := 10 if sem_erro else 0
	itens.append(["Programa rodou sem erros", p_erro, 10])
	alg += p_erro

	var p_req := 10 if requisitos_ok else 0
	itens.append(["Usou o que a fase pede", p_req, 10])
	alg += p_req

	var lidos := 0
	if not program.is_empty():
		var f := LBProgramInspector.features(program)
		for s in LEITURA:
			if f.sensores_em_condicao.has(s):
				lidos += 1
	var p_leitura := mini(15, lidos * 5)
	itens.append(["Lê o adversário (%d sensor%s)" % [lidos, "" if lidos == 1 else "es"], p_leitura, 15])
	alg += p_leitura

	var st: Dictionary = eu.stats
	var lancados := int(st.acertos) + int(st.golpes_no_vazio) + int(st.golpes_bloqueados_pelo_inimigo) + int(ele.stats.esquivas_ok)
	var prec := float(st.acertos) / float(lancados) if lancados > 0 else 0.0
	var p_prec := int(round(prec * 15.0))
	itens.append(["Precisão dos golpes (%d%%)" % int(round(prec * 100.0)), p_prec, 15])
	alg += p_prec

	var defendidos := int(st.defesas_ok) + int(st.esquivas_ok)
	var vieram := defendidos + int(st.golpes_recebidos_em_cheio)
	var dfs := float(defendidos) / float(vieram) if vieram > 0 else 0.0
	var p_def := int(round(dfs * 10.0))
	itens.append(["Defesa (%d%% dos golpes dele)" % int(round(dfs * 100.0)), p_def, 10])
	alg += p_def

	var venceu := sim.vencedor == 0
	var p_vida := int(round(float(eu.vida) / float(LBCombatRules.MAX_VIDA) * MAX_VIDA_PONTOS)) if venceu else 0
	itens.append(["Vida que sobrou" + ("" if venceu else " (só conta vencendo)"), p_vida, MAX_VIDA_PONTOS])
	return {"algoritmo": alg, "vida": p_vida, "total": alg + p_vida, "itens": itens, "venceu": venceu}


## Chave do recorde: cada fase e cada bot do treino têm o seu.
static func chave(modo: String, fase_id: String, bot_id: String) -> String:
	return ("fase:" + fase_id) if modo == "campanha" else ("treino:" + bot_id)


## Aplica a nota: ganha só o que passar do recorde. Devolve {ganho, recorde_antes, total}.
static func receber(data: LBProgressData, k: String, total: int) -> Dictionary:
	var antes := int(data.recordes.get(k, 0))
	var ganho := maxi(0, total - antes)
	if total > antes:
		data.recordes[k] = total
	data.moedas += ganho
	return {"ganho": ganho, "recorde_antes": antes, "total": total}
