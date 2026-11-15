extends Node
## FERRAMENTA: visita todas as telas, tira foto e procura coisas CORTADAS:
## controle visível que passa da borda da tela e não está dentro de uma área que rola.
##   LB_DEVICE=celular xvfb-run godot --path . --resolution 540x1080 res://tools/auditoria_telas.tscn
var _runner := false
var _f := 0
var _i := 0
var _probs := 0
var _out := "/tmp/lb_audit"
const ETAPAS := ["menu", "oponentes", "campanha", "config", "garagem", "fase_edicao", "fase_exemplo", "fase_luta", "fase_planejamento", "resultado", "tutorial"]

func _ready():
	if not _runner:
		var r := Node.new(); r.set_script(get_script()); r.set("_runner", true)
		get_tree().root.add_child.call_deferred(r); set_process(false); return
	if OS.get_environment("LB_OUT") != "": _out = OS.get_environment("LB_OUT")
	DirAccess.make_dir_recursive_absolute(_out)
	GameSettings.quality = 0
	Progress.reset_all()
	var d := Progress.data
	d.tutorial_concluido = true
	d.xp = 600
	d.moedas = 300
	for f in LBCampaign.FASES.slice(0, 3): d.concluir_fase(f.id, 100)
	get_tree().change_scene_to_file.call_deferred("res://scenes/main_menu/main_menu.tscn")

func _foto(nome: String):
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, nome])
	_checar(nome)

func _dentro_de_rolagem(c: Control) -> bool:
	var p := c.get_parent()
	while p:
		if p is ScrollContainer: return true
		p = p.get_parent()
	return false

func _checar(nome: String):
	var tela := get_viewport().get_visible_rect().grow(1.0)
	var vistos := {}
	for c in get_tree().root.find_children("*", "Control", true, false):
		var ct := c as Control
		if not ct.is_visible_in_tree() or ct.get_global_rect().size.x < 2: continue
		if ct is ScrollBar or ct.get_parent() is ScrollBar: continue
		if ct.get_viewport() != get_viewport(): continue
		var r := ct.get_global_rect()
		if tela.encloses(r) or _dentro_de_rolagem(ct): continue
		if ct.get_parent() is Control and not tela.encloses((ct.get_parent() as Control).get_global_rect()) and not (ct.get_parent() is CanvasLayer): continue
		var desc := "%s(%s)" % [ct.get_class(), (ct.text.substr(0, 24) if "text" in ct and ct.text is String else ct.name)]
		if vistos.has(desc): continue
		vistos[desc] = true
		_probs += 1
		print("  CORTADO [%s] %s %s" % [nome, desc, r])
		if OS.get_environment("LB_AUDIT_DET") != "":
			for k in ct.find_children("*", "Control", true, false):
				if (k as Control).is_visible_in_tree() and (k as Control).size.y > 300: print("      ", k.get_class(), " ", k.name, " ", (k as Control).get_global_rect(), " min=", (k as Control).get_combined_minimum_size())

func _process(_d):
	_f += 1
	var sc := get_tree().current_scene
	if sc == null: return
	var et: String = ETAPAS[_i] if _i < ETAPAS.size() else ""
	match et:
		"menu":
			if _f == 40: await _foto("01_menu"); _prox()
		"oponentes":
			if _f == 5: sc._show_panel(sc._opponents)
			if _f == 25: await _foto("02_oponentes"); _prox()
		"campanha":
			if _f == 5: sc._refresh_campaign(); sc._show_panel(sc._campaign)
			if _f == 25: await _foto("03_campanha"); _prox()
		"config":
			if _f == 5: sc._load_settings_ui(); sc._show_panel(sc._settings)
			if _f == 25: await _foto("04_config"); _prox()
		"garagem":
			if _f == 5: sc._refresh_garage(); sc._show_panel(sc._garage)
			if _f == 40: await _foto("05_garagem"); _prox(); GameState.start_campaign("f3_energia")
		"fase_edicao":
			if sc.name != "Battle": _f = 0; return
			if _f == 30: await _foto("06_fase_edicao"); _prox()
		"fase_exemplo":
			if _f == 5: sc._on_example_pressed()
			if _f == 20: await _foto("07_fase_exemplo"); _prox()
		"fase_luta":
			if _f == 2:
				sc.guide.hide_card()
				sc.panel.editor.text = LBCampaign.get_fase("f3_energia").solucao
				sc._start_fight()
			if _f == 120: await _foto("08_fase_luta"); _prox()
		"fase_planejamento":
			if _f == 2:
				var n := 0
				while not sc.sim.aguardando_turno and n < 2000:
					sc._sim_step(); n += 1
			if _f == 20: await _foto("09_planejamento"); _prox()
		"resultado":
			if _f == 2:
				sc.state = sc.State.FIGHTING
				var n := 0
				while not sc.sim.terminou and n < 20000:
					if sc.sim.aguardando_turno: sc.sim.proximo_turno()
					sc._sim_step(); n += 1
			if _f == 300: await _foto("10_resultado"); _prox(); GameState.start_tutorial()
		"tutorial":
			if sc.name != "Battle" or GameState.mode != "tutorial": _f = 0; return
			if _f == 40: await _foto("11_tutorial"); _prox()
		_:
			print("AUDITORIA: %d problema(s)" % _probs)
			Progress.reset_all()
			get_tree().quit()

func _prox():
	_i += 1
	_f = 0
