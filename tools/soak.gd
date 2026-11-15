extends Node
## FERRAMENTA: teste de longa duração — várias lutas seguidas medindo memória e objetos.
##   xvfb-run godot --path . res://tools/soak.tscn   (LB_SOAK=n lutas)
var _runner := false
var _f := 0
var _n := 0
var _total := 8
var _fase := 0

func _ready():
	if not _runner:
		var r := Node.new(); r.set_script(get_script()); r.set("_runner", true)
		get_tree().root.add_child.call_deferred(r); set_process(false); return
	if OS.get_environment("LB_SOAK") != "": _total = int(OS.get_environment("LB_SOAK"))
	GameSettings.quality = 0
	Progress.data.tutorial_concluido = true
	get_tree().change_scene_to_file.call_deferred("res://scenes/main_menu/main_menu.tscn")

func _medir(tag: String):
	print("%s luta=%d mem=%.1fMB obj=%d nos=%d orfaos=%d recursos=%d video=%.1fMB" % [tag, _n,
		OS.get_static_memory_usage() / 1048576.0, Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])

func _process(_d):
	_f += 1
	var sc := get_tree().current_scene
	if sc == null: return
	match _fase:
		0:
			if sc.name != "Battle" and _f > 20:
				_medir("menu")
				GameState.save_code(LBBotLibrary.TEMPLATE)
				GameState.start_battle("brutus")
				_fase = 1; _f = 0
		1:
			if sc.name == "Battle" and _f > 10:
				sc._start_fight()
				_fase = 2; _f = 0
		2:
			if _f == 30:
				sc.state = sc.State.FIGHTING
			if _f > 30 and _f < 400 and _f % 60 == 0:
				print("tempo_script=%.2fms" % (Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0))
			if _f > 30 and _f < 400:
				# roda a luta em tempo de jogo acelerado (com a arena desenhando efeitos)
				for k in 6:
					if sc.sim.aguardando_turno: sc._continue_turn()
					if sc.state == sc.State.FIGHTING: sc._sim_step()
			if _f == 400 or (sc.state == sc.State.RESULT and _f > 60):
				_n += 1
				_medir("batalha")
				if _n >= _total:
					get_tree().quit(); return
				GameState.go_to_menu()
				_fase = 0; _f = 0
