extends Control
## ABERTURA (2.0): primeira tela ao abrir o app — robô dançando enquanto o jogo carrega.
## O carregamento pesado (menu, robô 3D, animações) acontece em segundo plano, então a
## dança não trava. Para trocar a animação: gere de novo com tools/gera_abertura.tscn.

const MENU := "res://scenes/main_menu/main_menu.tscn"
const PESADOS := [MENU, "res://assets/robo/robo.scn", "res://assets/robo/animacoes.res"]
const QUADROS := 32
const FPS := 10.0
const TEMPO_MINIMO := 1.6

var _danca: TextureRect
var _quadros: Array[AtlasTexture] = []
var _barra: ProgressBar
var _t := 0.0
var _pronto := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.027, 0.043, 0.078)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var centro := VBoxContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	centro.alignment = BoxContainer.ALIGNMENT_CENTER
	centro.add_theme_constant_override("separation", 10)
	centro.grow_horizontal = Control.GROW_DIRECTION_BOTH
	centro.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(centro)
	var titulo := Label.new()
	titulo.text = "LOGICBOT"
	titulo.theme_type_variation = "TitleLabel"
	titulo.add_theme_font_size_override("font_size", 54)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centro.add_child(titulo)
	var folha: Texture2D = load("res://assets/interface/abertura_danca.png")
	for i in QUADROS:
		var a := AtlasTexture.new()
		a.atlas = folha
		a.region = Rect2((i % 8) * 256, (i / 8) * 320, 256, 320)
		_quadros.append(a)
	_danca = TextureRect.new()
	_danca.texture = _quadros[0]
	_danca.custom_minimum_size = Vector2(256, 320)
	_danca.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_danca.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	centro.add_child(_danca)
	_barra = ProgressBar.new()
	_barra.custom_minimum_size = Vector2(260, 10)
	_barra.show_percentage = false
	_barra.add_theme_stylebox_override("background", LBUITheme.box(Color("0b1424"), LBUITheme.BORDER, 1, 3, 0.0))
	_barra.add_theme_stylebox_override("fill", LBUITheme.box(LBUITheme.CYAN, Color.TRANSPARENT, 0, 3, 0.0))
	centro.add_child(_barra)
	var txt := Label.new()
	txt.text = "Carregando…"
	txt.theme_type_variation = "DimLabel"
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centro.add_child(txt)
	for p in PESADOS:
		ResourceLoader.load_threaded_request(p, "", false)


func _process(delta: float) -> void:
	_t += delta
	if OS.get_environment("LB_DEBUG_ABERTURA") != "" and Engine.get_process_frames() == 20:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/claude-0/abertura.png")
	_danca.texture = _quadros[int(_t * FPS) % QUADROS]
	if _pronto:
		return
	var total := 0.0
	var feito := true
	for p in PESADOS:
		var prog := []
		var st := ResourceLoader.load_threaded_get_status(p, prog)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			total += 1.0
		elif st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			total += float(prog[0]) if not prog.is_empty() else 0.0
			feito = false
		else:
			feito = st != ResourceLoader.THREAD_LOAD_FAILED and feito
			if st == ResourceLoader.THREAD_LOAD_FAILED:
				total += 1.0
	_barra.value = total / PESADOS.size() * 100.0
	if feito and _t >= TEMPO_MINIMO:
		_pronto = true
		for p in PESADOS.slice(1):
			ResourceLoader.load_threaded_get(p)   # fica no cache: o robô abre na hora
		LBRoboMixamo.preparar()
		var menu: PackedScene = ResourceLoader.load_threaded_get(MENU)
		get_tree().change_scene_to_packed(menu)
