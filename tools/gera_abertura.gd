extends Node3D
## FERRAMENTA: desenha a folha de quadros do robô dançando (tela de abertura).
## xvfb-run godot --path . res://tools/gera_abertura.tscn  -> assets/interface/abertura_danca.png
const N := 32
const W := 256
const H := 320
func _ready():
	get_viewport().transparent_bg = true
	get_window().size = Vector2i(W, H)
	var env := Environment.new(); env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.55, 0.65, 0.85); env.ambient_light_energy = 1.2
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var kl := DirectionalLight3D.new(); kl.rotation_degrees = Vector3(-30, 35, 0); kl.light_energy = 2.0; add_child(kl)
	var rim := DirectionalLight3D.new(); rim.rotation_degrees = Vector3(-20, 200, 0); rim.light_energy = 1.2; rim.light_color = Color("22d3ee"); add_child(rim)
	var r := LBRoboMixamo.new(); add_child(r)
	r.build(false, {"pintura": Color("1e40af"), "brilho": Color("22d3ee")})
	r.labels_enabled = false
	r.rotation_degrees.y = -60
	var cam := Camera3D.new(); add_child(cam); cam.fov = 30
	cam.position = Vector3(0, 1.4, 5.5); cam.look_at(Vector3(0, 1.3, 0))
	var f := LBFighter.new("A", 1)
	var dur := LBRoboMixamo._lib.get_animation("danca_hiphop_3").length
	r.mostrar("danca_hiphop_3", 999.0)
	var folha := Image.create(W * 8, H * 4, false, Image.FORMAT_RGBA8)
	for i in N:
		r.update_from_fighter(f, (dur / N) if i > 0 else 0.2, false, false)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		folha.blit_rect(img, Rect2i(0, 0, W, H), Vector2i((i % 8) * W, (i / 8) * H))
	folha.save_png("res://assets/interface/abertura_danca.png")
	print("FOLHA OK ", dur)
	get_tree().quit()
