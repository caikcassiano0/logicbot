extends RefCounted
## Testes de progressão, tutorial e campanha.


func _sim(a: String, b: String) -> LBCombatSim:
	var s := LBCombatSim.new()
	s.setup(LBVM.new(LBCompiler.compile_source(a)), LBVM.new(LBCompiler.compile_source(b)))
	s.run_to_end()
	return s


## Mesma regra da tela de batalha: venceu + cumpriu requisitos + vida mínima.
func _completa(fase: Dictionary, codigo: String) -> bool:
	var r := LBCompiler.compile_source(codigo)
	if not r.ok:
		return false
	var s := LBBotLibrary.nova_luta(LBVM.new(r), LBCampaign.bot_of(fase), 1)
	s.turnos = true
	s.run_to_end()
	var vida_min := int(fase.get("requisitos", {}).get("vida_minima", 0))
	return s.vencedor == 0 and LBCampaign.missing_requirements(fase, r.program).is_empty() and s.lutadores[0].vida >= vida_min


func run(t: LBTestContext) -> void:
	t.suite("Progressão: tutorial obrigatório e desbloqueios")
	var d := LBProgressData.new()
	t.check("sem tutorial, a campanha fica bloqueada", not d.fase_desbloqueada(0))
	t.check("sem tutorial, o treino livre fica bloqueado", not d.treino_livre_liberado())
	d.tutorial_concluido = true
	t.check("com tutorial, a fase 1 libera", d.fase_desbloqueada(0))
	t.check("com tutorial, o treino livre libera", d.treino_livre_liberado())
	t.check("fase 2 continua bloqueada até concluir a 1", not d.fase_desbloqueada(1))
	d.registrar_tentativa(LBCampaign.FASES[0].id)
	t.check("tentativa sem vitória não libera a próxima", not d.fase_desbloqueada(1))
	d.concluir_fase(LBCampaign.FASES[0].id, 80)
	t.check("concluir a fase 1 libera a fase 2", d.fase_desbloqueada(1))
	t.check("fase 3 ainda bloqueada", not d.fase_desbloqueada(2))
	t.equal("conta fases concluídas", d.fases_concluidas(), 1)
	d.registrar_erro("condicional")
	d.registrar_erro("condicional")
	d.registrar_erro("laco")
	t.equal("erro mais comum é identificado", d.erros_mais_comuns(1)[0][0], "condicional")
	var d2 := LBProgressData.new()
	d2.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	t.check("salvar e carregar mantém o progresso", d2.tutorial_concluido and d2.fase_concluida(LBCampaign.FASES[0].id) and int(d2.fases[LBCampaign.FASES[0].id].tentativas) == 1)

	t.suite("Tutorial: passos")
	var lutas := 0
	for i in LBTutorial.count():
		var st := LBTutorial.step(i)
		if st.tipo != "luta":
			continue
		lutas += 1
		var fase := LBCampaign.get_fase(st.fase)
		t.check("passo '%s' aponta para uma fase existente" % st.id, not fase.is_empty())
		var inicio := LBCompiler.compile_source(fase.inicio[0])
		t.check("passo '%s': código inicial tem lacunas ??? explicadas" % st.id, not inicio.ok and inicio.first_error().message.contains("lacuna"))
		t.check("passo '%s': a solução esperada vence e cumpre os requisitos" % st.id, _completa(fase, fase.solucao))
	t.check("tutorial tem pelo menos 2 lutas (sequência e SE)", lutas >= 2)
	t.equal("último passo é a conclusão", LBTutorial.step(LBTutorial.count() - 1).tipo, "fim")

	t.suite("Campanha: cada fase tem solução")
	t.check("campanha tem 10 fases", LBCampaign.count() == 10)
	for i in LBCampaign.count():
		var fase: Dictionary = LBCampaign.FASES[i]
		var n := "fase %d (%s)" % [i + 1, fase.titulo]
		var bot := LBCompiler.compile_source(LBCampaign.bot_of(fase).codigo)
		t.check(n + ": código do inimigo compila", bot.ok, "" if bot.ok else bot.first_error().to_text())
		t.check(n + ": solução de referência vence e cumpre os requisitos", _completa(fase, fase.solucao))
		var facil := LBCompiler.compile_source(fase.inicio[0])
		var tem_lacuna: bool = String(fase.inicio[0]).contains("???")
		t.check(n + ": Fácil traz lacunas (???) ou orientação", tem_lacuna and not facil.ok or not tem_lacuna and facil.ok)
		t.check(n + ": Médio e Difícil começam com código válido", LBCompiler.compile_source(fase.inicio[1]).ok and LBCompiler.compile_source(fase.inicio[2]).ok)
		t.check(n + ": tem 3 dicas", fase.dicas.size() == 3)
		var com_codigo := ""
		for dica in fase.dicas:
			var re := RegEx.create_from_string("[a-z_]+\\(\\)|<-| entao\\b|fim(se|para|enquanto|procedimento)")
			if re.search(String(dica)) != null:
				com_codigo = dica
		t.check(n + ": nenhuma dica entrega código pronto", com_codigo == "", com_codigo)
		if i >= 2:
			t.check(n + ": o código inicial do treino NÃO conclui a fase", not _completa(fase, LBBotLibrary.TEMPLATE))

	t.suite("Referência: exemplo pronto só no Fácil")
	var ok_snip := true
	for sn in LBProgrammingPanel.SNIPPETS:
		var vazio: String = sn[3]
		if sn.size() != 4 or not vazio.contains("???") or RegEx.create_from_string("[a-z_]+\\(\\)").search(vazio.replace("???()", "")) != null:
			ok_snip = false
	t.check("toda estrutura tem versão vazia (com ???) e sem comandos prontos", ok_snip)
	var pp := LBProgrammingPanel.new()
	pp.snippets_filled = false
	var meta := {"insert": "se inimigo_perto entao\n   atacar()\nfimse", "skeleton": "se ??? entao\n   ???\nfimse"}
	t.check("Médio/Difícil: insere a estrutura vazia", pp._snippet_of(meta) == meta.skeleton)
	pp.snippets_filled = true
	t.check("Fácil: insere o exemplo preenchido", pp._snippet_of(meta) == meta.insert)
	t.check("comandos simples continuam inserindo o comando", pp._snippet_of({"insert": "atacar()"}) == "atacar()")
	pp.free()

	t.suite("Campanha: conferência de requisitos")
	var r := LBCompiler.compile_source("algoritmo \"x\"\nvar\n i: inteiro\ninicio\nse inimigo_perto e energia >= 50 entao\ngolpe_especial()\nsenao se nao inimigo_perto entao\npara i de 1 ate 2 faca\navancar()\nfimpara\nsenao\natacar()\nfimse\nfimalgoritmo")
	var f := LBProgramInspector.features(r.program)
	t.check("detecta SE, SENAO e SENAO SE", f.se and f.senao and f.senao_se)
	t.check("detecta E e NAO", f.e and f.nao and not f.ou)
	t.check("detecta PARA e variável", f.para and f.variavel)
	t.check("detecta sensores usados em condições", f.sensores_em_condicao.has("energia") and f.sensores_em_condicao.has("inimigo_perto"))
	t.check("detecta ações usadas", f.acoes.has("golpe_especial") and f.acoes.has("avancar") and not f.acoes.has("defender"))
	var falta := LBCampaign.missing_requirements(LBCampaign.get_fase("f4_senao_se"), LBCompiler.compile_source(LBBotLibrary.TEMPLATE).program)
	t.check("aponta o que falta (SENAO SE e os sensores de altura) no código que não usa",
		falta.size() == 3 and falta[0].contains("SENAO SE") and ", ".join(falta).contains("inimigo_atacando_alto"))

	t.suite("Progressão: experiência, níveis e conquistas")
	t.equal("nível 1 com 0 XP", LBRewards.nivel(0), 1)
	t.equal("nível 2 com 100 XP", LBRewards.nivel(100), 2)
	t.equal("nível 3 com 300 XP", LBRewards.nivel(300), 3)
	t.equal("progresso dentro do nível (300 XP: 50 de 200)", LBRewards.progresso_nivel(300), [50, 200])
	var p := LBProgressData.new()
	var r0 := LBRewards.processar(p, {"modo": "tutorial"})
	t.check("tutorial dá XP e conquista", r0.xp == LBRewards.XP_TUTORIAL and r0.conquistas.has("tutorial") and p.tutorial_concluido)
	t.equal("refazer o tutorial não dá XP de novo", LBRewards.processar(p, {"modo": "tutorial"}).xp, 0)
	var f1: String = LBCampaign.FASES[0].id
	p.registrar_tentativa(f1)
	var r1 := LBRewards.processar(p, {"modo": "campanha", "fase_id": f1, "venceu": true, "cumpriu_requisitos": true, "dificuldade": 0, "tentativas": 1, "vida": 90, "dano_recebido": 10})
	t.equal("concluir fase inédita de primeira (Fácil): 100 + 50 XP", r1.xp, 150)
	t.check("ganha 'De Primeira!' e 'Primeira Vitória'", r1.conquistas.has("de_primeira") and r1.conquistas.has("primeira_vitoria"))
	t.check("fase fica concluída", p.fase_concluida(f1))
	var r2 := LBRewards.processar(p, {"modo": "campanha", "fase_id": f1, "venceu": true, "cumpriu_requisitos": true, "dificuldade": 0, "tentativas": 2, "vida": 90})
	t.equal("repetir a mesma fase NÃO dá XP (sem 'farmar')", r2.xp, 0)
	var r3 := LBRewards.processar(p, {"modo": "campanha", "fase_id": f1, "venceu": true, "cumpriu_requisitos": true, "dificuldade": 2, "tentativas": 3, "vida": 90})
	t.check("refazer em dificuldade maior dá bônus", r3.xp == LBRewards.XP_SUBIU_DIFICULDADE)
	t.check("concluir no Difícil dá 'Sem Rodinhas'; 3+ tentativas dá 'Persistente'", r3.conquistas.has("sem_rodinhas") and r3.conquistas.has("persistente"))
	var f2: String = LBCampaign.FASES[1].id
	var r4 := LBRewards.processar(p, {"modo": "campanha", "fase_id": f2, "venceu": true, "cumpriu_requisitos": false, "dificuldade": 1, "tentativas": 1})
	t.check("vitória sem cumprir requisitos não dá XP nem conclui", r4.xp == 0 and not p.fase_concluida(f2))
	var r5 := LBRewards.processar(p, {"modo": "treino", "bot_id": "treino", "venceu": true})
	t.equal("1ª vitória contra um bot do treino dá XP", r5.xp, LBRewards.XP_BOT_TREINO)
	t.equal("vencer o mesmo bot de novo não dá XP", LBRewards.processar(p, {"modo": "treino", "bot_id": "treino", "venceu": true}).xp, 0)
	t.check("derrota não dá XP", LBRewards.processar(p, {"modo": "treino", "bot_id": "vortex", "venceu": false}).xp == 0)
	var r6 := LBRewards.processar(p, {"modo": "treino", "bot_id": "sentinela", "venceu": false, "usou_passo": true, "usou_escreval": true})
	t.check("depurar com PASSO e usar escreval rendem conquistas (mesmo perdendo)", r6.conquistas.has("depurador") and r6.conquistas.has("escritor"))

	t.suite("Progressão: personalização")
	var q := LBProgressData.new()
	t.check("começa só com a cor e a armadura padrão", LBRewards.cor_liberada(q, LBRewards.CORES[0]) and not LBRewards.cor_liberada(q, LBRewards.CORES[1]) and not LBRewards.armadura_liberada(q, LBRewards.ARMADURAS[1]))
	q.cor = "ouro"
	t.equal("item bloqueado escolhido volta para o padrão", LBRewards.look_for(q).armadura, "padrao")
	t.equal("...inclusive a cor", LBRewards.look_for(q).brilho, Color(LBRewards.CORES[0].brilho))
	q.xp = 1000
	q.armadura = "espectro"
	t.check("com nível suficiente, cor e armadura liberam", LBRewards.look_for(q).armadura == "espectro" and LBRewards.look_for(q).brilho == Color("fde047"))
	q.armadura = "campeao"
	t.equal("armadura CAMPEÃO exige a conquista, não só nível", LBRewards.look_for(q).armadura, "padrao")
	q.conquistas["mestre"] = true
	t.equal("com a conquista 'Mestre da Lógica', CAMPEÃO libera", LBRewards.look_for(q).armadura, "campeao")
	var pr := LBProgressData.new()
	var rr := LBRewards.processar(pr, {"modo": "tutorial"})
	rr = LBRewards.processar(pr, {"modo": "campanha", "fase_id": f1, "venceu": true, "cumpriu_requisitos": true, "dificuldade": 0, "tentativas": 1, "vida": 80})
	t.check("subir de nível informa o que foi desbloqueado", rr.nivel_depois > rr.nivel_antes and rr.desbloqueios.size() > 0, str(rr))
	var dd := LBProgressData.new()
	dd.from_dict(JSON.parse_string(JSON.stringify(pr.to_dict())))
	t.check("XP e conquistas são salvos e carregados", dd.xp == pr.xp and dd.conquistas.size() == pr.conquistas.size())
	var sim_p := LBProgressData.new()
	LBRewards.processar(sim_p, {"modo": "tutorial"})
	for fz in LBCampaign.FASES:
		LBRewards.processar(sim_p, {"modo": "campanha", "fase_id": fz.id, "venceu": true, "cumpriu_requisitos": true, "dificuldade": 1, "tentativas": 2, "vida": 50})
	t.check("concluir toda a campanha dá 'Mestre da Lógica' e libera a CAMPEÃO", sim_p.conquistas.has("mestre") and LBRewards.armadura_liberada(sim_p, LBRewards.ARMADURAS[3]))
	t.check("campanha inteira no Médio chega a um nível alto (≥ 6)", LBRewards.nivel(sim_p.xp) >= 6, "nível %d, %d XP" % [LBRewards.nivel(sim_p.xp), sim_p.xp])

	t.suite("Moedas e loja (2.0)")
	var fase8 := LBCampaign.get_fase("f8_omega")
	var comp := LBCompiler.compile_source(fase8.solucao)
	var luta := LBBotLibrary.nova_luta(LBVM.new(comp), LBCampaign.bot_of(fase8), 1)
	luta.turnos = true
	luta.run_to_end()
	var nt := LBCoins.nota(luta, comp.program, true)
	t.check("nota vai de 0 a 100 e soma algoritmo + vida (%d = %d + %d)" % [nt.total, nt.algoritmo, nt.vida],
		nt.total == nt.algoritmo + nt.vida and nt.total <= 100 and nt.algoritmo <= LBCoins.MAX_ALGORITMO)
	t.check("a solução que lê a altura ganha pontos de leitura do adversário", int(nt.itens[2][1]) >= 10, str(nt.itens[2]))
	var ruim := LBCompiler.compile_source(LBBotLibrary.TEMPLATE)
	var luta2 := LBBotLibrary.nova_luta(LBVM.new(ruim), LBCampaign.bot_of(fase8), 1)
	luta2.turnos = true
	luta2.run_to_end()
	var nt2 := LBCoins.nota(luta2, ruim.program, false)
	t.check("perdendo, a vida não conta (só o algoritmo)", luta2.vencedor != 0 and nt2.vida == 0 and nt2.total == nt2.algoritmo)
	t.check("código melhor tira nota maior (%d > %d)" % [nt.total, nt2.total], nt.total > nt2.total)
	var md := LBProgressData.new()
	var g1 := LBCoins.receber(md, "fase:x", 60)
	var g2 := LBCoins.receber(md, "fase:x", 60)
	var g3 := LBCoins.receber(md, "fase:x", 75)
	t.check("repetir a mesma luta não dá moedas de novo (sem farm)", g1.ganho == 60 and g2.ganho == 0)
	t.check("melhorar o recorde paga só a diferença", g3.ganho == 15 and md.moedas == 75 and md.recordes["fase:x"] == 75)
	t.check("sem moedas suficientes, não compra", not LBShop.comprar(md, "ombro_escudo") and md.moedas == 75)
	md.moedas = 300
	t.check("comprar desconta o preço", LBShop.comprar(md, "ombro_escudo") and md.moedas == 80)
	t.check("não compra duas vezes o mesmo item", not LBShop.comprar(md, "ombro_escudo") and md.moedas == 80)
	t.check("item que não é seu não pode ser equipado", not LBShop.equipar(md, "nucleo_reator"))
	LBShop.equipar(md, "ombro_escudo")
	t.equal("dança grátis (Hip Hop 3) vem equipada", LBShop.equipados(md).danca, "danca_hiphop_3")
	var md2 := LBProgressData.new()
	md2.from_dict(JSON.parse_string(JSON.stringify(md.to_dict())))
	t.check("moedas, compras e peças equipadas são salvas", md2.moedas == 80 and md2.compradas.has("ombro_escudo") and LBRewards.look_for(md2).pecas.get("ombreiras", "") == "ombro_escudo")

	t.suite("Botão EXEMPLO (Fácil)")
	var f3 := LBCampaign.get_fase("f3_energia")
	var ex: String = load("res://scripts/interface/lb_battle.gd").example_text(f3, f3.inicio[0])
	t.check("Fácil mostra a linha que entra no lugar dos ??? (fôlego)", ex.contains("Linha 3:") and ex.contains("se folego") and ex.contains("30 entao"), ex)
	var todas_ok := true
	for fz in LBCampaign.FASES:
		var e2: String = load("res://scripts/interface/lb_battle.gd").example_text(fz, fz.inicio[0])
		if e2.contains("???") and not e2.contains("No lugar dos"):
			todas_ok = false
	t.check("toda fase tem exemplo (linhas ou programa completo)", todas_ok)

	t.suite("Campanha: só repetir golpes não vence (2.0.3)")
	var so_direto := "algoritmo \"x\"\ninicio\nse inimigo_perto entao\ndireto()\nsenao\navancar()\nfimse\nfimalgoritmo"
	for fid in ["f3_energia", "f4_senao_se", "f6_logicos", "f7_para", "f7a_enquanto"]:
		var fz := LBCampaign.get_fase(fid)
		var sz := LBBotLibrary.nova_luta(LBVM.new(LBCompiler.compile_source(so_direto)), LBCampaign.bot_of(fz), 1)
		sz.turnos = true
		sz.run_to_end()
		t.check("%s: só socar com direto() não vence" % fz.titulo, sz.vencedor != 0)
