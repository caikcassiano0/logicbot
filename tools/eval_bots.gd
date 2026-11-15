extends SceneTree
## FERRAMENTA: simula programas de aluno contra os bots táticos com várias sementes.
##   godot --headless --path . --script res://tools/eval_bots.gd
const PROGS := {
	"modelo (antigo)": "algoritmo \"m\"\ninicio\nse inimigo_perto entao\natacar()\nsenao\navancar()\nfimse\nfimalgoritmo",
	"so jab-direto": "algoritmo \"a\"\ninicio\nse inimigo_perto entao\njab()\ndireto()\nsenao\navancar()\nfimse\nfimalgoritmo",
	"guarda + 1-2": "algoritmo \"b\"\ninicio\nse inimigo_atacando_alto entao\nbloqueio_alto()\nsenao se inimigo_atacando_baixo entao\nbloqueio_baixo()\nsenao se inimigo_perto e folego > 30 entao\njab()\ndireto()\nsenao se inimigo_perto entao\nrecuar()\nsenao\navancar()\nfimse\nfimalgoritmo",
	"le altura + varia": "algoritmo \"c\"\ninicio\nse inimigo_atacando_alto entao\nabaixar()\nsenao se inimigo_atacando_baixo entao\nbloqueio_baixo()\nsenao se inimigo_perto e inimigo_bloqueando_alto entao\ngancho_figado()\nsenao se inimigo_perto e inimigo_bloqueando_baixo entao\ncruzado_frente()\nsenao se inimigo_perto e folego > 30 entao\njab()\ncruzado_frente()\nsenao se inimigo_perto entao\nrecuar()\nsenao\navancar()\nfimse\nfimalgoritmo",
}

func _init():
	for bid in ["treino", "sentinela", "vortex", "brutus", "maestro"]:
		var bot := LBBotLibrary.get_bot(bid)
		for pn in PROGS:
			var w := 0
			var hist := ""
			for seed in range(1, 9):
				var s := LBBotLibrary.nova_luta(LBVM.new(LBCompiler.compile_source(PROGS[pn])), bot, seed)
				s.turnos = true
				s.run_to_end()
				if s.vencedor == 0:
					w += 1
				if seed == 1 and s.cerebro:
					hist = ",".join(s.cerebro.historico)
			print("%-10s x %-18s venceu %d/8  %s" % [bid, pn, w, hist])
	quit()
