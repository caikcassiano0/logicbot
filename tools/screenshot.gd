extends Node
## FERRAMENTA: captura o menu e a tela de batalha (no meio de uma luta).
##   godot --path . --fixed-fps 60 res://tools/screenshot.tscn   (LB_OUT = pasta)
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
	if OS.get_environment("LB_OUT") != "":
		out = OS.get_environment("LB_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	GameSettings.quality = 1
	get_tree().change_scene_to_file.call_deferred("res://scenes/main_menu/main_menu.tscn")

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("salvo ", name)

func _process(_d: float) -> void:
	_f += 1
	var sc := get_tree().current_scene
	match _step:
		0:
			if _f == 12:
				sc._show_panel(sc._opponents)
			if _f == 26:
				_shot("menu")
			if _f == 30:
				GameState.save_code(LBBotLibrary.TEMPLATE)
				GameState.start_battle(OS.get_environment("LB_BOT") if OS.get_environment("LB_BOT") != "" else "sentinela")
				_step = 1
				_f = 0
		1:
			if sc == null or sc.name != "Battle":
				_f = 0
				return
			if _f == 3:
				sc.panel.ready_requested.emit()
				sc.state = sc.State.FIGHTING
				# avança a luta sem renderizar até um momento de ação
				for i in 140:
					sc.sim.step()
				sc.arena.sync_with_sim(sc.sim, 1.0)
				sc.arena._update_camera(3.0)
			if _f == 14:
				_shot("batalha")
			if _f == 16 and OS.get_environment("LB_ONLY_MENU") == "":
				# avança até o fim do turno 1: mostra a tela de planejamento
				var n := 0
				while not sc.sim.aguardando_turno and n < 2000:
					sc._sim_step()
					n += 1
			if _f == 20 and OS.get_environment("LB_TAB_INIMIGO") != "":
				var tabs: TabContainer = sc.panel._right_tabs
				tabs.current_tab = tabs.get_tab_count() - 1
			if _f == 30:
				_shot("planejamento")
			if _f == 32 and OS.get_environment("LB_RESULT") != "":
				# termina a luta (continuando os turnos) para fotografar a tela de resultado
				sc.state = sc.State.FIGHTING
				var n := 0
				while not sc.sim.terminou and n < 20000:
					if sc.sim.aguardando_turno:
						sc.sim.proximo_turno()
					sc._sim_step()
					n += 1
			if _f == 400 and OS.get_environment("LB_RESULT") != "":
				_shot("resultado")
			if (_f > 32 and OS.get_environment("LB_RESULT") == "") or _f > 402 or OS.get_environment("LB_ONLY_MENU") != "":
				get_tree().quit()
