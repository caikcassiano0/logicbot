extends Node
## FERRAMENTA: gera a imagem de capa (1920x1080) com os robôs de verdade e um cenário.
##   xvfb-run godot --path . --resolution 1920x1080 res://tools/capa.tscn
var arena: LBArena
var a := LBFighter.new("A", 1)
var b := LBFighter.new("B", -1)
var _f := 0

func _ready():
	GameSettings.quality = 2
	arena = LBArena.new()
	arena.cenario = OS.get_environment("LB_CENARIO") if OS.get_environment("LB_CENARIO") != "" else "1"
	arena.player_look = {"pintura": Color("1e40af"), "brilho": Color("22d3ee"), "pecas": {"nucleo": "nucleo_reator"}}
	arena.enemy_look = {"pintura": Color("b91c1c"), "corpo": "pesado"}
	add_child(arena)
	arena.set_process(false)
	a.x = -0.75
	b.x = 0.75
	a.acao = "cruzado_tras"; a.acao_dur = 0.7
	b.atordoado = 0.3
	var cam := arena.camera
	cam.fov = 40
	cam.position = Vector3(-2.7, 0.9, 5.0)
	cam.look_at(Vector3(0.3, 1.75, 0), Vector3.UP)
	arena.player_visual.labels_enabled = false
	arena.enemy_visual.labels_enabled = false
	# título
	var V := get_viewport().get_visible_rect().size
	var cl := CanvasLayer.new()
	add_child(cl)
	var sombra := ColorRect.new()
	sombra.color = Color(0, 0, 0, 0)
	cl.add_child(sombra)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0, 0.55, 1])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0.0, 0.01, 0.03, 0.85)])
	var gt := GradientTexture2D.new(); gt.gradient = g; gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(0, 1)
	var tr := TextureRect.new(); tr.texture = gt; tr.size = V; tr.stretch_mode = TextureRect.STRETCH_SCALE
	cl.add_child(tr)
	var t := Label.new()
	t.text = "LOGICBOT"
	t.add_theme_font_override("font", LBUITheme.title_font())
	t.add_theme_font_size_override("font_size", int(V.y * 0.16))
	t.add_theme_color_override("font_color", Color("e0faff"))
	t.add_theme_color_override("font_outline_color", Color("0e7490"))
	t.add_theme_constant_override("outline_size", 18)
	t.add_theme_color_override("font_shadow_color", Color(0.13, 0.83, 0.93, 0.6))
	t.add_theme_constant_override("shadow_outline_size", 40)
	t.add_theme_constant_override("shadow_offset_x", 0)
	t.add_theme_constant_override("shadow_offset_y", 0)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.size = Vector2(V.x, V.y * 0.2); t.position = Vector2(0, V.y * 0.68)
	cl.add_child(t)
	var s := Label.new()
	s.text = "PROGRAME  ·  LUTE  ·  APRENDA"
	s.add_theme_font_override("font", LBUITheme.font(LBUITheme.FONT_UI_BOLD))
	s.add_theme_font_size_override("font_size", int(V.y * 0.05))
	s.add_theme_color_override("font_color", Color("fde047"))
	s.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	s.add_theme_constant_override("outline_size", 10)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.size = Vector2(V.x, V.y * 0.07); s.position = Vector2(0, V.y * 0.88)
	cl.add_child(s)
	if OS.get_environment("LB_SEM_TITULO") != "":
		cl.visible = false

func _process(_d):
	_f += 1
	a.acao_t = 0.36
	arena.player_visual.oponente_x = b.x
	arena.enemy_visual.oponente_x = a.x
	arena._afastar(absf(b.x - a.x))
	arena.player_visual.update_from_fighter(a, 1.0 / 30.0, false, false)
	arena.enemy_visual.update_from_fighter(b, 1.0 / 30.0, false, false)
	if _f == 20:
		arena.enemy_visual.levar_golpe("cruzado_tras", 13)
		arena.effects.sparks(arena.enemy_visual.head_position() - Vector3(0.25, 0, 0), Color(1.0, 0.75, 0.35), 70, 1.0)
		arena.effects.shockwave(arena.enemy_visual.head_position() - Vector3(0.25, 0, 0), Color(1, 0.9, 0.7), 1.0)
	if _f == 23:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(OS.get_environment("OUT") + "/capa_%dx%d.png" % [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y])
		get_tree().quit()
