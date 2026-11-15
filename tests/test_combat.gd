extends RefCounted
## Testes do sistema de combate (lógica pura, sem gráficos).

const R = preload("res://scripts/combat/lb_combat_rules.gd")


func _vm(body: String) -> LBVM:
	var src := "algoritmo \"t\"\ninicio\n" + body + "\nfimalgoritmo"
	var r := LBCompiler.compile_source(src)
	if not r.ok:
		push_error(r.first_error().to_text())
		return null
	return LBVM.new(r)


func _vm_src(src: String) -> LBVM:
	return LBVM.new(LBCompiler.compile_source(src))


func _sim(a: String, b: String, perto := false) -> LBCombatSim:
	var s := LBCombatSim.new()
	s.setup(_vm(a), _vm(b), "A", "B")
	if perto:
		s.lutadores[0].x = -0.5
		s.lutadores[1].x = 0.5
	return s


## Avança até aparecer um evento do tipo pedido (ou o limite de passos).
func _until(s: LBCombatSim, tipo: String, limit := 600) -> Dictionary:
	for i in limit:
		for e in s.step():
			if e.tipo == tipo:
				return e
	return {}


## Resultado do primeiro golpe do robô A contra o robô B (os dois começam colados).
func _golpe(ataque: String, defesa: String) -> Dictionary:
	var s := _sim(ataque, defesa, true)
	for i in 120:
		for e in s.step():
			if e.get("atacante", -1) == 0 and e.tipo in ["acerto", "bloqueio", "esquiva", "errou"]:
				return e
	return {}


func run(t: LBTestContext) -> void:
	t.suite("Combate: efeitos dos comandos")
	var s := _sim("atacar()", "aguardar()", true)
	var e := _until(s, "acerto")
	t.check("atacar() de perto acerta", not e.is_empty())
	t.equal("atacar() causa 7 de dano", s.lutadores[1].vida, R.MAX_VIDA - 7)
	t.check("acerto em cheio atordoa o alvo", s.lutadores[1].atordoado > 0.0)

	s = _sim("atacar()", "aguardar()")
	e = _until(s, "errou")
	t.check("atacar() de longe erra (golpe no vazio)", not e.is_empty() and s.lutadores[1].vida == R.MAX_VIDA)
	t.equal("golpe no vazio é contabilizado", s.lutadores[0].stats.golpes_no_vazio, 1)

	s = _sim("atacar()", "defender()", true)
	e = _until(s, "bloqueio")
	t.check("defender() bloqueia", not e.is_empty())
	t.equal("defesa reduz 75% (7 -> 2)", s.lutadores[1].vida, R.MAX_VIDA - 2)
	t.equal("defesa bem-sucedida é contabilizada", s.lutadores[1].stats.defesas_ok, 1)

	s = _sim("atacar()", "esquivar()", true)
	e = _until(s, "esquiva")
	t.check("esquivar() evita o golpe", not e.is_empty() and s.lutadores[1].vida == R.MAX_VIDA)
	t.equal("esquivar() custa 8 de energia", s.lutadores[1].stats.energia_gasta, 8)

	s = _sim("atacar()", "pular()", true)
	e = _until(s, "esquiva")
	t.check("pular() evita o soco", not e.is_empty() and s.lutadores[1].vida == R.MAX_VIDA)

	s = _sim("avancar()", "aguardar()")
	var x0 := s.lutadores[0].x
	_until(s, "fim_acao")
	t.check("avancar() aproxima do inimigo", s.lutadores[0].x > x0 + 1.0, "x %.2f -> %.2f" % [x0, s.lutadores[0].x])
	s = _sim("recuar()", "aguardar()")
	x0 = s.lutadores[0].x
	_until(s, "fim_acao")
	t.check("recuar() afasta do inimigo", s.lutadores[0].x < x0 - 0.8)

	s = _sim("avancar()", "avancar()")
	for i in 600:
		s.step()
	t.check("robôs não se atravessam", s.distancia() >= R.DISTANCIA_MINIMA - 0.001, "distância %.2f" % s.distancia())

	t.suite("Combate: energia")
	s = _sim("golpe_especial()", "aguardar()", true)
	s.step()
	t.check("golpe especial sem energia falha", s.lutadores[0].acao == "falha" and s.lutadores[0].stats.falhas_sem_energia == 1)
	t.check("falha não gasta energia", s.lutadores[0].stats.energia_gasta == 0)

	s = _sim("golpe_especial()", "aguardar()", true)
	s.lutadores[0].energia = 60.0
	s.step()
	t.equal("golpe especial consome 50 de energia", s.lutadores[0].energia, 60.0 + R.ENERGIA_REGEN_POR_SEG * R.DT - 50.0)
	_until(s, "acerto")
	t.equal("golpe especial causa 20 de dano", s.lutadores[1].vida, R.MAX_VIDA - 20)

	s = _sim("aguardar()", "aguardar()")
	for i in 60 * 30:
		s.step()
	t.equal("energia recarrega até o máximo de 100", s.lutadores[0].energia, 100.0)

	t.suite("Combate: fim de luta")
	s = _sim("atacar()", "aguardar()", true)
	s.run_to_end()
	t.check("luta termina por nocaute", s.terminou and s.motivo_fim == "nocaute")
	t.equal("vitória do jogador detectada", s.vencedor, 0)
	t.equal("vida do perdedor termina em 0", s.lutadores[1].vida, 0)
	t.check("perdedor fica nocauteado", s.lutadores[1].nocauteado)

	s = _sim("aguardar()", "atacar()", true)
	s.run_to_end()
	t.equal("derrota do jogador detectada", s.vencedor, 1)

	s = _sim("aguardar()", "aguardar()")
	s.run_to_end()
	t.check("luta termina por tempo", s.terminou and s.motivo_fim == "tempo" and s.tempo_restante == 0.0)
	t.equal("empate por tempo com vidas iguais", s.vencedor, 2)
	t.check("duração do round ~60 s", absi(s.passos - int(R.ROUND_TIME * R.TICK_RATE)) <= 1, "%d passos" % s.passos)
	t.check("passos depois do fim não mudam nada", s.step().is_empty())

	t.suite("Combate: invariantes e justiça")
	var programas := {"modelo": LBBotLibrary.TEMPLATE}
	for b in LBBotLibrary.BOTS:
		programas[b.nome] = b.codigo
	var vida_ok := true
	var energia_ok := true
	var todas_terminaram := true
	var detalhe := ""
	var resultados := []
	for na in programas:
		for nb in programas:
			var sim := LBCombatSim.new()
			sim.setup(_vm_src(programas[na]), _vm_src(programas[nb]), na, nb)
			while not sim.terminou:
				sim.step()
				for f in sim.lutadores:
					if f.vida < 0 or f.vida > R.MAX_VIDA:
						vida_ok = false
						detalhe = "%s x %s: vida %d" % [na, nb, f.vida]
					if f.energia < -0.0001 or f.energia > R.MAX_ENERGIA + 0.0001:
						energia_ok = false
				if sim.passos > 4000:
					todas_terminaram = false
					break
			resultados.append("%s x %s -> %s (%s) vidas %d/%d" % [na, nb, ["A", "B", "empate"][sim.vencedor], sim.motivo_fim, sim.lutadores[0].vida, sim.lutadores[1].vida])
	t.check("vida sempre entre 0 e 100 (todas as combinações de bots)", vida_ok, detalhe)
	t.check("energia sempre entre 0 e 100", energia_ok)
	t.check("todas as lutas terminam", todas_terminaram)
	for linha in resultados:
		print("     (info) ", linha)

	var s1 := LBCombatSim.new()
	s1.setup(_vm_src(LBBotLibrary.TEMPLATE), _vm_src(LBBotLibrary.get_bot("vortex").codigo))
	s1.run_to_end()
	var s2 := LBCombatSim.new()
	s2.setup(_vm_src(LBBotLibrary.TEMPLATE), _vm_src(LBBotLibrary.get_bot("vortex").codigo))
	s2.run_to_end()
	t.check("determinismo: mesma luta, mesmo resultado", s1.passos == s2.passos and s1.lutadores[0].vida == s2.lutadores[0].vida and s1.lutadores[1].vida == s2.lutadores[1].vida)

	var sm := LBCombatSim.new()
	sm.setup(_vm_src(LBBotLibrary.TEMPLATE), _vm_src(LBBotLibrary.TEMPLATE))
	sm.run_to_end()
	t.check("justiça: programas iguais terminam empatados", sm.vencedor == 2 and sm.lutadores[0].vida == sm.lutadores[1].vida,
		"vidas %d / %d" % [sm.lutadores[0].vida, sm.lutadores[1].vida])

	var ruim := LBCombatSim.new()
	ruim.setup(_vm_src("algoritmo \"r\"\nvar\n x: inteiro\ninicio\nenquanto verdadeiro faca\nx <- x + 1\nfimenquanto\nfimalgoritmo"), _vm("atacar()"))
	var ev := _until(ruim, "erro_programa", 10)
	t.check("programa que trava não derruba o combate", not ev.is_empty() and ruim.lutadores[0].programa_travado)
	ruim.run_to_end()
	t.check("luta continua e termina mesmo com programa travado", ruim.terminou)

	t.suite("Combate: luta por turnos de 5 s")
	var bl := LBBotLibrary.BOTS
	var ta := LBCombatSim.new()
	ta.setup(_vm_src(bl[1].codigo), _vm_src(bl[2].codigo), "A", "B")
	ta.turnos = true
	var evt := _until(ta, "fim_turno", 2000)
	t.check("o turno termina sozinho depois de 5 s", not evt.is_empty() and evt.turno == 1 and absf(ta.passos * R.DT - R.TURNO_DURACAO) < R.DT * 1.5,
		"passos=%d" % ta.passos)
	var parado := ta.passos
	for k in 30:
		ta.step()
	t.check("enquanto espera o próximo turno, a luta não anda", ta.passos == parado and ta.aguardando_turno)
	ta.proximo_turno()
	t.check("proximo_turno() continua a luta no turno 2", ta.turno == 2 and not ta.aguardando_turno)
	ta.step()
	t.check("...e a simulação volta a andar", ta.passos == parado + 1)
	t.check("a luta tem no máximo 12 turnos (60 s / 5 s)", ta.total_turnos() == 12)
	# pausar não muda nada: sem trocar o código, turnos = luta contínua
	var iguais := true
	for par_ in [[0, 1], [1, 2], [2, 0], [1, 1]]:
		var cont := LBCombatSim.new()
		cont.setup(_vm_src(bl[par_[0]].codigo), _vm_src(bl[par_[1]].codigo), "A", "B")
		cont.run_to_end()
		var turn := LBCombatSim.new()
		turn.setup(_vm_src(bl[par_[0]].codigo), _vm_src(bl[par_[1]].codigo), "A", "B")
		turn.turnos = true
		turn.run_to_end()
		if cont.vencedor != turn.vencedor or cont.passos != turn.passos or cont.lutadores[0].vida != turn.lutadores[0].vida or cont.lutadores[1].vida != turn.lutadores[1].vida:
			iguais = false
	t.check("sem mudar o código, a luta por turnos termina igual à contínua", iguais)
	# trocar o programa entre turnos muda o comportamento do robô
	var tc := _sim("aguardar()", "aguardar()")
	tc.turnos = true
	_until(tc, "fim_turno", 2000)
	var x_antes: float = tc.lutadores[0].x
	tc.proximo_turno(_vm("avancar()"))
	_until(tc, "fim_turno", 2000)
	t.check("código novo no turno 2: o robô passa a obedecer o programa novo", tc.lutadores[0].x > x_antes + 0.5,
		"x %.2f -> %.2f" % [x_antes, tc.lutadores[0].x])

	t.suite("Combate: golpes de boxe (2.0)")
	var g_r := _golpe("jab()", "aguardar()")
	t.check("jab acerta a cabeça com 4 de dano", g_r.tipo == "acerto" and g_r.dano == 4, str(g_r))
	g_r = _golpe("direto()", "aguardar()")
	t.check("direto (mão de trás) acerta com 9", g_r.tipo == "acerto" and g_r.dano == 9, str(g_r))
	g_r = _golpe("jab()", "bloqueio_alto()")
	t.check("bloqueio alto segura o jab (75%)", g_r.tipo == "bloqueio" and g_r.dano == 1, str(g_r))
	g_r = _golpe("jab_corpo()", "bloqueio_alto()")
	t.check("bloqueio alto NÃO protege o corpo: jab no corpo entra", g_r.tipo == "acerto" and g_r.dano == 4, str(g_r))
	g_r = _golpe("gancho_figado()", "bloqueio_baixo()")
	t.check("bloqueio baixo segura o gancho no fígado", g_r.tipo == "bloqueio", str(g_r))
	g_r = _golpe("cruzado_frente()", "bloqueio_baixo()")
	t.check("bloqueio baixo NÃO protege a cabeça: cruzado entra", g_r.tipo == "acerto" and g_r.dano == 10, str(g_r))
	g_r = _golpe("direto()", "esquivar_esquerda()")
	t.check("esquiva lateral desvia do direto (golpe reto)", g_r.tipo == "esquiva", str(g_r))
	g_r = _golpe("cruzado_frente()", "esquivar_direita()")
	t.check("esquiva lateral NÃO desvia do cruzado (vem de lado)", g_r.tipo == "acerto", str(g_r))
	g_r = _golpe("cruzado_tras()", "abaixar()")
	t.check("abaixar desvia do cruzado", g_r.tipo == "esquiva", str(g_r))
	g_r = _golpe("uppercut_frente()", "abaixar()")
	t.check("uppercut pega quem se abaixa com +30% (12 -> 16)", g_r.tipo == "acerto" and g_r.dano == 16, str(g_r))
	g_r = _golpe("uppercut_tras()", "recuar_tronco()")
	t.check("recuar o tronco desvia do uppercut (golpe curto)", g_r.tipo == "esquiva", str(g_r))
	g_r = _golpe("jab()", "recuar_tronco()")
	t.check("recuar o tronco NÃO escapa do jab (alcance longo)", g_r.tipo == "acerto", str(g_r))
	g_r = _golpe("jab_corpo()", "passo_lado()")
	t.check("passo lateral sai da linha do jab no corpo", g_r.tipo == "esquiva", str(g_r))
	var s_esp := _sim("golpe_especial()", "abaixar()", true)
	s_esp.lutadores[0].energia = 100.0
	s_esp.lutadores[1].energia = 100.0
	var r_esp := {}
	for k in 120:
		for ev_esp in s_esp.step():
			if r_esp.is_empty() and ev_esp.get("atacante", -1) == 0 and ev_esp.tipo in ["acerto", "bloqueio", "esquiva", "errou"]:
				r_esp = ev_esp
	t.check("esquivas de boxe não desviam do golpe especial (plasma)", r_esp.get("tipo", "") == "acerto", str(r_esp))
	var s_ov := _sim("overhand()", "aguardar()", true)
	s_ov.lutadores[0].energia = 5.0
	var ev_s := _until(s_ov, "sem_energia", 60)
	t.check("overhand custa 20 de energia: sem energia, falha", not ev_s.is_empty() and ev_s.acao == "overhand")
	var s_atk := _sim("aguardar()", "gancho_figado()", true)
	s_atk.step()
	var sens_v := s_atk._sensores(0)
	t.check("sensor inimigo_atacando_baixo vê o gancho no fígado", sens_v.inimigo_atacando_baixo and not sens_v.inimigo_atacando_alto)
	var s_blq := _sim("aguardar()", "bloqueio_alto()", true)
	s_blq.step()
	sens_v = s_blq._sensores(0)
	t.check("sensor inimigo_bloqueando_alto (e não o baixo)", sens_v.inimigo_bloqueando_alto and not sens_v.inimigo_bloqueando_baixo)

	t.suite("Combate: golpe leve x golpe forte (2.0)")
	var tr := _sim("jab()", "cruzado_tras()", true)
	var ev_tr := _until(tr, "cortou", 120)
	t.check("jab (com fôlego) acerta o rosto e CORTA o gancho que ainda estava sendo preparado", not ev_tr.is_empty())
	var tc2 := _sim("jab()", "cruzado_tras()", true)
	tc2.lutadores[0].folego = 5.0
	t.check("jab cansado NÃO corta o gancho", _until(tc2, "cortou", 120).is_empty())
	var nl := _sim("jab()", "direto()", true)
	var dano_b := 0
	var dano_a := 0
	for k in 60:
		for ev_nl in nl.step():
			if ev_nl.tipo == "acerto":
				if ev_nl.atacante == 0: dano_a += ev_nl.dano
				else: dano_b += ev_nl.dano
	t.check("jab não interrompe o direto: os dois socos entram (troca de golpes)", dano_a > 0 and dano_b > 0, "%d x %d" % [dano_a, dano_b])
	var fz := _sim("cruzado_tras()", "aguardar()", true)
	_until(fz, "acerto", 120)
	t.check("golpe forte (dano ≥ 10) atordoa quem leva", fz.lutadores[1].atordoado > 0.0)
	var fl := _sim("jab()", "aguardar()", true)
	_until(fl, "acerto", 120)
	t.check("golpe leve (jab) não atordoa", fl.lutadores[1].atordoado == 0.0)

	t.suite("Combate: fôlego e partes do corpo (2.0)")
	var sf := _sim("jab()", "aguardar()")
	sf.step()
	t.check("dar um soco de boxe gasta fôlego (jab: -4)", absf(sf.lutadores[0].folego - (R.FOLEGO_MAX - 4.0)) < 0.2, "%.2f" % sf.lutadores[0].folego)
	var sl := _sim("atacar()", "aguardar()")
	sl.step()
	t.check("comandos antigos não gastam fôlego (campanha atual intacta)", sl.lutadores[0].folego >= R.FOLEGO_MAX - 0.01)
	var hc := _sim("jab()", "aguardar()", true)
	_until(hc, "acerto")
	var hb := _sim("jab_corpo()", "aguardar()", true)
	_until(hb, "acerto")
	t.check("golpe no corpo tira mais fôlego que na cabeça (mesmo dano)", hb.lutadores[1].folego < hc.lutadores[1].folego,
		"corpo %.1f x cabeça %.1f" % [hb.lutadores[1].folego, hc.lutadores[1].folego])
	t.check("golpe na cabeça avaria a cabeça; no corpo, o corpo", hc.lutadores[1].cabeca < 100.0 and hc.lutadores[1].corpo == 100.0 and hb.lutadores[1].corpo < 100.0 and hb.lutadores[1].cabeca == 100.0)
	var bq := _sim("direto()", "bloqueio_alto()", true)
	_until(bq, "bloqueio")
	t.check("bloquear gasta os braços", bq.lutadores[1].bracos < 100.0, "%.1f" % bq.lutadores[1].bracos)
	var fr := _sim("direto()", "aguardar()", true)
	fr.lutadores[0].bracos = 10.0
	var ev_fr := _until(fr, "acerto")
	t.check("braços avariados: o soco perde força (9 -> 7)", ev_fr.get("dano", -1) == 7, str(ev_fr))
	var gf := _sim("direto()", "bloqueio_alto()", true)
	gf.lutadores[1].bracos = 10.0
	var ev_gf := _until(gf, "bloqueio")
	t.check("braços avariados: a guarda segura menos (dano 2 -> 4)", ev_gf.get("dano", -1) == 4, str(ev_gf))
	var cs := _sim("jab()", "aguardar()")
	cs.lutadores[0].folego = 10.0
	cs.step()
	t.check("cansado (fôlego < 25): o golpe fica 20% mais lento", absf(cs.lutadores[0].acao_dur - 0.40 * R.LENTIDAO_CANSADO) < 0.001)
	var rc := _sim("aguardar()", "aguardar()")
	rc.lutadores[0].folego = 50.0
	for k in 60:
		rc.step()
	t.check("parado, o fôlego volta (≈ 12 por segundo)", rc.lutadores[0].folego > 60.0, "%.1f" % rc.lutadores[0].folego)
	var ko := _sim("cruzado_tras()", "aguardar()", true)
	ko.lutadores[1].folego = 0.0
	ko.run_to_end(200)
	t.check("sem fôlego, um golpe forte na cabeça derruba (nocaute com vida sobrando)",
		ko.terminou and ko.vencedor == 0 and ko.motivo_fim == "nocaute" and ko.lutadores[1].vida > 0, "vida %d" % ko.lutadores[1].vida)
	var nk := _sim("jab()", "aguardar()", true)
	nk.lutadores[1].folego = 0.0
	_until(nk, "acerto")
	t.check("...mas um jab (golpe leve) não derruba", not nk.lutadores[1].nocaute_folego)

	t.suite("Inimigos com táticas (2.0)")
	var compila_tudo := true
	LBRobotAPI.bloqueados = LBRobotAPI.bloqueios_para(func(_f): return false)
	for tid in LBTactics.TATICAS:
		var cb := LBEnemyBrain.new([tid])
		cb.vm_de(tid)
		if not cb._compiladas[tid].ok:
			compila_tudo = false
	LBRobotAPI.bloqueados = {}
	t.check("as 7 táticas compilam (mesmo com os golpes do aluno bloqueados)", compila_tudo)
	var brutus := LBBotLibrary.get_bot("brutus")
	var maestro := LBBotLibrary.get_bot("maestro")
	var bom := "algoritmo \"b\"\ninicio\nse inimigo_atacando_alto entao\nbloqueio_alto()\nsenao se inimigo_atacando_baixo entao\nbloqueio_baixo()\nsenao se folego < 30 entao\nrecuar()\nsenao se inimigo_perto entao\ndireto()\nsenao\navancar()\nfimse\nfimalgoritmo"
	var l1 := _luta_tatica(bom, brutus, 3)
	var l2 := _luta_tatica(bom, brutus, 3)
	t.check("mesma semente = mesma luta (táticas e resultado iguais)", l1.cerebro.historico == l2.cerebro.historico and l1.vencedor == l2.vencedor and l1.passos == l2.passos)
	var variou := false
	for sem in range(1, 9):
		if _luta_tatica(bom, brutus, sem).cerebro.historico != l1.cerebro.historico:
			variou = true
	t.check("sementes diferentes geram lutas diferentes (não é previsível)", variou)
	t.check("MAESTRO lê guarda alta repetida e responde com trabalho de corpo", _tatica_turno2("bloqueio_alto()", maestro) == "trabalho_corpo")
	t.check("MAESTRO lê guarda baixa repetida e responde mirando a cabeça", _tatica_turno2("bloqueio_baixo()", maestro) == "cabeca")
	t.check("MAESTRO lê esquivas laterais e responde com ganchos", _tatica_turno2("esquivar_esquerda()", maestro) == "ganchos")
	var passivo := _luta_tatica("algoritmo \"p\"\ninicio\naguardar()\nfimalgoritmo", maestro, 1)
	var distintas := {}
	for h in passivo.cerebro.historico:
		distintas[h] = true
	t.check("contra um jogador parado, o MAESTRO ainda varia de tática (%d táticas usadas)" % distintas.size(), distintas.size() >= 2)
	var perde_b := 0
	var perde_m := 0
	var vence_b := 0
	for sem in range(1, 5):
		if _luta_tatica(LBBotLibrary.TEMPLATE, brutus, sem).vencedor == 1:
			perde_b += 1
		if _luta_tatica(LBBotLibrary.TEMPLATE, maestro, sem).vencedor == 1:
			perde_m += 1
		if _luta_tatica(bom, brutus, sem).vencedor == 0:
			vence_b += 1
	t.check("código inicial perde para o BRUTUS (%d/4 sementes)" % perde_b, perde_b == 4)
	t.check("código inicial perde para o MAESTRO (%d/4 sementes)" % perde_m, perde_m == 4)
	t.check("BRUTUS tem solução: guarda pela altura + fôlego + direto vence (%d/4 sementes)" % vence_b, vence_b >= 3)
	# receitas que só repetem golpes (sem ler o adversário) não podem vencer o chefe que lê o jogo
	var receitas := {
		"so ganchos": "se inimigo_perto entao\ncruzado_frente()\ncruzado_tras()\nsenao\navancar()\nfimse",
		"so uppercuts": "se inimigo_perto entao\nuppercut_frente()\nuppercut_tras()\nsenao\navancar()\nfimse",
		"so direto": "se inimigo_perto entao\ndireto()\nsenao\navancar()\nfimse",
		"so no corpo": "se inimigo_perto entao\njab_corpo()\ngancho_figado()\nsenao\navancar()\nfimse",
	}
	for rn in receitas:
		var vit := 0
		for sem in range(1, 5):
			if _luta_tatica("algoritmo \"r\"\ninicio\n" + receitas[rn] + "\nfimalgoritmo", maestro, sem).vencedor == 0:
				vit += 1
		t.check("receita '%s' (sem ler o adversário) não vence o MAESTRO (%d/4)" % [rn, vit], vit == 0)
	var errou := _sim("uppercut_tras()", "recuar_tronco()", true)
	var dur_apos := 0.0
	for k in 90:
		for ev_e in errou.step():
			if ev_e.tipo == "esquiva" and dur_apos == 0.0:
				dur_apos = errou.lutadores[0].acao_dur
	t.check("uppercut esquivado com recuar_tronco desequilibra quem bateu (duração %.2f s)" % dur_apos,
		is_equal_approx(dur_apos, float(R.ACOES.uppercut_tras.dur) + R.DESEQUILIBRIO_ESQUIVA))

	t.suite("Prévia do programa na pausa (2.0)")
	var prog := "algoritmo \"p\"\ninicio\nse inimigo_perto entao\njab()\ndireto()\nsenao\navancar()\nfimse\nfimalgoritmo"
	var sp := _sim("aguardar()", "aguardar()", true)
	var pv: Array = load("res://scripts/interface/lb_battle.gd").preview_actions(prog, sp._sensores(0))
	t.check("perto do inimigo, a prévia mostra jab() → direto() → jab()", pv == ["jab()", "direto()", "jab()"], str(pv))
	var sp2 := _sim("aguardar()", "aguardar()")
	var pv2: Array = load("res://scripts/interface/lb_battle.gd").preview_actions(prog, sp2._sensores(0))
	t.check("longe do inimigo, a prévia mostra avancar()", pv2.size() > 0 and pv2[0] == "avancar()", str(pv2))
	t.check("código com erro: sem prévia (e sem travar)", load("res://scripts/interface/lb_battle.gd").preview_actions("algoritmo", {}).is_empty())

	t.suite("Combate: golpes liberados pela campanha")
	var bl_todos := LBRobotAPI.bloqueios_para(func(_f): return false)
	t.check("no começo, jab/direto/bloqueios/esquivas laterais estão liberados",
		not bl_todos.has("jab") and not bl_todos.has("direto") and not bl_todos.has("bloqueio_alto") and not bl_todos.has("esquivar_esquerda"))
	t.check("no começo, cruzados, uppercuts e overhand estão bloqueados",
		bl_todos.has("cruzado_frente") and bl_todos.has("uppercut_tras") and bl_todos.has("overhand"))
	t.check("concluir todas as fases libera tudo", LBRobotAPI.bloqueios_para(func(_f): return true).is_empty())
	var so_f2 := LBRobotAPI.bloqueios_para(func(f): return f == "f2_se_senao")
	t.check("concluir a fase 2 libera os cruzados e o abaixar", not so_f2.has("cruzado_frente") and not so_f2.has("abaixar") and so_f2.has("uppercut_frente"))
	LBRobotAPI.bloqueados = bl_todos
	var rb := LBCompiler.compile_source("algoritmo \"x\"\ninicio\n   uppercut_tras()\nfimalgoritmo")
	var rl := LBCompiler.compile_source("algoritmo \"x\"\ninicio\n   jab()\nfimalgoritmo")
	LBRobotAPI.bloqueados = {}
	t.check("golpe bloqueado não compila e explica como liberar", not rb.ok and rb.first_error().hint.contains("Conclua a fase"))
	t.check("golpe liberado compila normalmente", rl.ok)

	t.suite("Combate: análise pós-luta")
	var sa := _sim("golpe_especial()", "atacar()", true)
	sa.run_to_end()
	var sug := LBFightAnalyzer.analisar(sa)
	t.check("análise detecta golpe especial sem energia", sug.any(func(x): return x.titulo.contains("energia")))
	var sb := _sim("atacar()", "aguardar()")
	sb.run_to_end()
	sug = LBFightAnalyzer.analisar(sb)
	t.check("análise detecta ataques no vazio", sug.any(func(x): return x.titulo.contains("vazio")))

	t.suite("Combate: equilíbrio pedagógico")
	# Garante que a progressão de dificuldade continue fazendo sentido se as regras mudarem:
	# o código inicial só vence o bot de treino, e cada bot tem uma solução aprendível.
	var modelo := LBBotLibrary.TEMPLATE
	var le_altura := "algoritmo \"LeAltura\"\ninicio\nse inimigo_atacando_alto entao\nbloqueio_alto()\nsenao se inimigo_atacando_baixo entao\nbloqueio_baixo()\nsenao se folego < 30 entao\nrecuar()\nsenao se inimigo_perto entao\ndireto()\nsenao\navancar()\nfimse\nfimalgoritmo"
	var so_direto := "algoritmo \"SoDireto\"\ninicio\nse inimigo_perto entao\ndireto()\nsenao\navancar()\nfimse\nfimalgoritmo"
	t.equal("código inicial vence o TREINO-01", _vencedor(modelo, "treino"), 0)
	t.equal("código inicial NÃO vence a SENTINELA", _vencedor(modelo, "sentinela"), 1)
	t.equal("código inicial NÃO vence o VÓRTEX", _vencedor(modelo, "vortex"), 1)
	t.equal("SENTINELA tem solução: ler a altura dos golpes e cuidar do fôlego", _vencedor(le_altura, "sentinela"), 0)
	t.equal("VÓRTEX tem solução: golpes que não deixam ele respirar", _vencedor(so_direto, "vortex"), 0)
	t.equal("não há receita única: a solução do VÓRTEX perde para a SENTINELA", _vencedor(so_direto, "sentinela"), 1)
	t.equal("ficar longe esperando o especial não vence a SENTINELA", _vencedor("algoritmo \"d\"\ninicio\nse energia >= 50 e distancia_inimigo <= 2.8 e nao inimigo_perto entao\ngolpe_especial()\nsenao se inimigo_perto entao\nrecuar()\nsenao se distancia_inimigo > 2.6 entao\navancar()\nsenao\naguardar()\nfimse\nfimalgoritmo", "sentinela"), 1)

func _luta_tatica(codigo: String, bot: Dictionary, semente: int) -> LBCombatSim:
	var s := LBBotLibrary.nova_luta(_vm_src(codigo), bot, semente)
	s.turnos = true
	s.run_to_end()
	return s


## Tática que o bot escolhe no turno 2 depois de um turno 1 com o jogador repetindo uma ação.
func _tatica_turno2(acao: String, bot: Dictionary) -> String:
	var s := LBBotLibrary.nova_luta(_vm(acao), bot, 1)
	s.turnos = true
	s.lutadores[0].x = -0.6
	s.lutadores[1].x = 0.6
	for i in 2000:
		s.step()
		if s.aguardando_turno:
			break
	s.proximo_turno()
	return s.cerebro.atual


func _vencedor(codigo: String, bot_id: String) -> int:
	var s := LBBotLibrary.nova_luta(_vm_src(codigo), LBBotLibrary.get_bot(bot_id), 1)
	s.turnos = true
	s.run_to_end()
	return s.vencedor
