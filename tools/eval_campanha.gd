extends SceneTree
## FERRAMENTA: confere cada fase da campanha com várias sementes (luta por turnos).
##   godot --headless --path . --script res://tools/eval_campanha.gd
func _luta(codigo: String, bot: Dictionary, sem: int) -> LBCombatSim:
	var s := LBBotLibrary.nova_luta(LBVM.new(LBCompiler.compile_source(codigo)), bot, sem)
	s.turnos = true
	s.run_to_end()
	return s

func _init():
	for i in LBCampaign.count():
		var f: Dictionary = LBCampaign.FASES[i]
		var bot := LBCampaign.bot_of(f)
		var r := LBCompiler.compile_source(f.solucao)
		var vs := 0
		var vida := []
		for sem in range(1, 5):
			var s := _luta(f.solucao, bot, sem)
			if s.vencedor == 0:
				vs += 1
			vida.append(s.lutadores[0].vida)
		var tpl := 0
		var med := 0
		for sem in range(1, 5):
			if _luta(LBBotLibrary.TEMPLATE, bot, sem).vencedor == 0:
				tpl += 1
			if LBCompiler.compile_source(f.inicio[1]).ok and _luta(f.inicio[1], bot, sem).vencedor == 0:
				med += 1
		var falta := LBCampaign.missing_requirements(f, r.program) if r.ok else ["NAO COMPILA: " + r.first_error().to_text()]
		print("F%d %-18s solucao %d/4 vidas %s | modelo vence %d/4 | inicio-medio vence %d/4 | falta %s" % [i + 1, f.titulo, vs, str(vida), tpl, med, str(falta)])
	for bid in ["treino", "sentinela", "vortex"]:
		print("BOT %s: vencedor com o modelo = %d" % [bid, _luta(LBBotLibrary.TEMPLATE, LBBotLibrary.get_bot(bid), 1).vencedor])
	quit()
