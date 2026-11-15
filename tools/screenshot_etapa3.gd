extends Node
## FERRAMENTA: captura o menu da campanha e uma fase com o cartão de objetivo e a aba Variáveis.
var _is_runner := false
var _f := 0
var _step := 0
var out := "/tmp/lb_shots"

func _ready() -> void:
	if not _is_runner:
		var r := Node.new()
		r.set_script(get_script())
		r.set("_is_runner", true)
		get_tree().root.add_child.call_deferred(r)
		set_process(false)
		return
	DirAccess.make_dir_recursive_absolute(out)
	GameSettings.quality = 1
	Progress.reset_all()
	Progress.data.tutorial_concluido = true
	Progress.data.concluir_fase("f1_sequencia", 100)
	Progress.data.concluir_fase("f2_se_senao", 93)
	Progress.data.registrar_tentativa("f3_energia")
	Progress.data.registrar_erro("condicional")
	Progress.data.registrar_erro("condicional")
	Progress.data.registrar_erro("operador")
	Progress.data.dificuldade = 0
	get_tree().change_scene_to_file.call_deferred("res://scenes/main_menu/main_menu.tscn")

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("salvo ", name)

func _process(_d: float) -> void:
	_f += 1
	var sc = get_tree().current_scene
	match _step:
		0:
			if _f == 2 and OS.get_environment("LB_SKIP_MENU") != "":
				_f = 44
			if _f == 10:
				sc._refresh_campaign()
				sc._show_panel(sc._campaign)
			if _f == 40:
				_shot("campanha")
			if _f == 44:
				GameState.start_campaign("f3_energia")
				_step = 1
				_f = 0
		1:
			if _f == 6:
				sc.panel._right_tabs.current_tab = 1
				var vm := LBVM.new(LBCompiler.compile_source(sc.fase.solucao))
				sc.panel.update_watch(sc.sim._sensores(0), vm.vars, 6, "golpe_especial")
			if _f == 20:
				_shot("fase")
			if _f > 22:
				Progress.reset_all()
				get_tree().quit()
