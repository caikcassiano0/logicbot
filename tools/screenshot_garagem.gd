extends Node
## FERRAMENTA: captura a Garagem com progresso de exemplo (não altera o progresso real ao final).
var _is_runner := false
var _f := 0

func _ready() -> void:
	if not _is_runner:
		var r := Node.new()
		r.set_script(get_script())
		r.set("_is_runner", true)
		get_tree().root.add_child.call_deferred(r)
		set_process(false)
		return
	GameSettings.quality = 1
	Progress.reset_all()
	var d: LBProgressData = Progress.data
	d.tutorial_concluido = true
	d.xp = 1150
	for c in ["tutorial", "primeira_vitoria", "de_primeira", "depurador", "escritor", "estrategista"]:
		d.conquistas[c] = true
	d.cor = "azul"
	d.moedas = 340
	for id in ["ombro_titan", "cap_antenas", "nucleo_hex", "danca_house"]:
		d.compradas[id] = true
	d.equipado = {"ombreiras": "ombro_titan", "capacete": "cap_antenas", "nucleo": "nucleo_hex", "danca": "danca_house"}
	get_tree().change_scene_to_file.call_deferred("res://scenes/main_menu/main_menu.tscn")

func _process(_d: float) -> void:
	_f += 1
	var sc = get_tree().current_scene
	if _f == 12:
		sc._refresh_garage()
		sc._show_panel(sc._garage)
	if _f == 40:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/lb_shots/garagem.png")
		for s in sc._garage.find_children("*", "ScrollContainer", true, false):
			s.scroll_vertical = 330
	if _f == 70:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/lb_shots/garagem2.png")
		sc._load_settings_ui()
		sc._show_panel(sc._settings)
	if _f == 90:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/lb_shots/config.png")
		print("salvo garagem")
		Progress.reset_all()
		get_tree().quit()
