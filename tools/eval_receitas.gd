extends SceneTree
## FERRAMENTA: receitas simples de aluno (sem ler o inimigo) contra os bots táticos.
## Ideia: receitas "burras" devem PERDER do BRUTUS/MAESTRO/ÔMEGA; as soluções devem vencer.
##   godot --headless --path . --script res://tools/eval_receitas.gd
const P := {
	"jab": "se inimigo_perto entao\njab()\nsenao\navancar()\nfimse",
	"1-2": "se inimigo_perto entao\njab()\ndireto()\nsenao\navancar()\nfimse",
	"so direto": "se inimigo_perto entao\ndireto()\nsenao\navancar()\nfimse",
	"ganchos": "se inimigo_perto entao\ncruzado_frente()\ncruzado_tras()\nsenao\navancar()\nfimse",
	"uppercuts": "se inimigo_perto entao\nuppercut_frente()\nuppercut_tras()\nsenao\navancar()\nfimse",
	"corpo": "se inimigo_perto entao\njab_corpo()\ngancho_figado()\nsenao\navancar()\nfimse",
	"guarda alta+direto": "se inimigo_atacando entao\nbloqueio_alto()\nsenao se inimigo_perto entao\ndireto()\nsenao\navancar()\nfimse",
	"so bloqueia": "se inimigo_atacando entao\nbloqueio_alto()\nsenao\naguardar()\nfimse",
	"le altura+direto": "se inimigo_atacando_alto entao\nbloqueio_alto()\nsenao se inimigo_atacando_baixo entao\nbloqueio_baixo()\nsenao se inimigo_perto entao\ndireto()\nsenao\navancar()\nfimse",
	"SOL f8": "",
	"le tudo": "se inimigo_atacando_alto entao\nabaixar()\nsenao se inimigo_atacando_baixo entao\nbloqueio_baixo()\nsenao se folego < 30 entao\nrecuar()\nsenao se inimigo_perto e inimigo_bloqueando_alto entao\ngancho_figado()\nsenao se inimigo_perto e inimigo_bloqueando_baixo entao\ncruzado_frente()\nsenao se inimigo_perto entao\njab()\ndireto()\nsenao\navancar()\nfimse",
}

func _init():
	var bots := {"brutus": LBBotLibrary.get_bot("brutus"), "maestro": LBBotLibrary.get_bot("maestro"),
		"omega": LBCampaign.bot_of(LBCampaign.get_fase("f8_omega"))}
	var linha := "%-20s" % ""
	for b in bots: linha += "%-10s" % b
	print(linha)
	for pn in P:
		var src: String = LBCampaign.get_fase("f8_omega").solucao if pn == "SOL f8" else "algoritmo \"x\"\ninicio\n" + P[pn] + "\nfimalgoritmo"
		linha = "%-20s" % pn
		for b in bots:
			var w := 0
			var vd := 0.0
			for seed in range(1, 9):
				var s := LBBotLibrary.nova_luta(LBVM.new(LBCompiler.compile_source(src)), bots[b], seed)
				s.turnos = true
				s.run_to_end()
				if s.vencedor == 0: w += 1
				vd += s.lutadores[0].vida - s.lutadores[1].vida
			linha += "%d/8 %+4d " % [w, int(vd / 8)]
		print(linha)
	quit()
