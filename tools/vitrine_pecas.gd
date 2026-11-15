extends Node3D
func _ready():
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.08, 0.1, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.6, 0.65, 0.78); env.ambient_light_energy = 1.6
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var kl := DirectionalLight3D.new(); kl.rotation_degrees = Vector3(-35, 30, 0); kl.light_energy = 2.4; add_child(kl)
	var looks := [
		{"pecas": {"ombreiras": "ombro_espinho", "luvas": "luva_plasma", "capacete": "cap_antenas", "nucleo": "nucleo_reator"}, "acabamento": "padrao"},
		{"pecas": {"ombreiras": "ombro_escudo", "luvas": "luva_pesada", "capacete": "cap_chifres", "nucleo": "nucleo_hex"}, "acabamento": "cromado"},
		{"pecas": {"ombreiras": "ombro_titan", "capacete": "cap_crista"}, "acabamento": "carbono"},
	]
	var robos := []
	for i in looks.size():
		var r := LBRoboMixamo.new(); add_child(r)
		var l: Dictionary = looks[i]; l["pintura"] = Color("2563eb"); l["brilho"] = Color("22d3ee")
		r.build(false, l); r.labels_enabled = false
		robos.append(r)
	var f := LBFighter.new("A", 1)
	var cam := Camera3D.new(); add_child(cam); cam.fov = 40
	for k in 40:
		for i in robos.size():
			f.x = -2.6 + i * 2.6
			robos[i].update_from_fighter(f, 1.0 / 30.0, false, false)
		await get_tree().process_frame
	var n := 0
	for i in robos.size():
		var x := -2.6 + i * 2.6
		for vista in [Vector3(x + 2.2, 2.0, 2.0), Vector3(x - 0.6, 2.3, 2.6)]:
			cam.position = vista; cam.look_at(Vector3(x, 1.55, 0))
			await RenderingServer.frame_post_draw; await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT") + "/pecas_%d.png" % n)
			n += 1
	get_tree().quit()
