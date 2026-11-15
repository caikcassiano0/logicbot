extends Node
## FERRAMENTA: captura o cartão do tutorial (passo "Decidindo com SE") com as 3 dicas abertas.
##   godot --path . --fixed-fps 60 res://tools/tut_shot.tscn   (LB_OUT = pasta)
var _is_runner := false
var _f := 0
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
	GameState.start_tutorial.call_deferred()

func _process(_d: float) -> void:
	var sc := get_tree().current_scene
	if sc == null or sc.name != "Battle":
		return
	_f += 1
	if _f == 5:
		sc._tut_enter(3)
		for k in 3:
			sc._show_next_hint()
		if OS.get_environment("LB_SHOW_LOCK") != "":
			var lst: ItemList = sc.panel._actions_list
			var idx := LBRobotAPI.ACTIONS.keys().find("cruzado_frente")
			lst.select(idx)
			lst.ensure_current_is_visible()
			sc.panel._on_item_selected(lst, idx)
	if _f == 20:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/tutorial_%s.png" % [out, LBDevice.kind()])
		print("salvo tutorial")
		get_tree().quit()
