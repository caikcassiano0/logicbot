extends Node3D
## FERRAMENTA: robô sozinho, fundo transparente, luz de contorno vermelha (para o pôster/ícone).
##   xvfb-run godot --path . --resolution 1200x1200 res://tools/poster.tscn   (OUT=pasta, LB_POSE=clip)
var r: LBRoboMixamo
var _f := 0
var _luta := LBFighter.new("A", 1)

func _ready():
	get_viewport().transparent_bg = true
	LBRoboMixamo.preparar()
	r = LBRoboMixamo.new()
	add_child(r)
	if OS.get_environment("LB_BOT_NOME") != "":
		r.build(true, LBRoboMixamo.look_do_bot({"nome": OS.get_environment("LB_BOT_NOME"), "cor": OS.get_environment("LB_BOT_COR")}))
	elif OS.get_environment("LB_LOOK") == "azul":
		r.build(false, {"pintura": Color("1e40af"), "brilho": Color("22d3ee")})
	else:
		r.build(false, {"pintura": Color("6b7280"), "brilho": Color("ff2a2a")})
	r.labels_enabled = false
	if OS.get_environment("LB_GIRO") != "":
		r.rotation_degrees.y = float(OS.get_environment("LB_GIRO"))
	var pose := OS.get_environment("LB_POSE") if OS.get_environment("LB_POSE") != "" else "guarda"
	r.mostrar(pose, 999.0)
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.25, 0.25, 0.28); e.ambient_light_energy = 0.6
	env.environment = e; add_child(env)
	var key := DirectionalLight3D.new(); key.light_energy = 1.6; key.shadow_enabled = true
	key.rotation_degrees = Vector3(-40, 70, 0); add_child(key)
	var rim := DirectionalLight3D.new(); rim.light_color = Color(1, 0.15, 0.1) if OS.get_environment("LB_LOOK") != "azul" and OS.get_environment("LB_BOT_NOME") == "" else Color(1, 0.85, 0.7); rim.light_energy = 3.0 if OS.get_environment("LB_LOOK") != "azul" and OS.get_environment("LB_BOT_NOME") == "" else 1.6
	rim.rotation_degrees = Vector3(-15, -110, 0); add_child(rim)
	if OS.get_environment("LB_LUZ_FRENTE") != "":
		var fr := OmniLight3D.new(); fr.light_color = Color(1, 0.25, 0.2); fr.light_energy = 1.0; fr.omni_range = 4.0
		fr.position = Vector3(1.6, 0.6, -0.6); add_child(fr)
	var cam := Camera3D.new(); add_child(cam)
	cam.fov = float(OS.get_environment("LB_FOV")) if OS.get_environment("LB_FOV") != "" else 38.0
	var cp := OS.get_environment("LB_CAMPOS").split(",") if OS.get_environment("LB_CAMPOS") != "" else PackedStringArray(["3.0", "0.35", "2.0", "0", "1.15", "0"])
	cam.position = Vector3(float(cp[0]), float(cp[1]), float(cp[2]))
	cam.look_at(Vector3(float(cp[3]), float(cp[4]), float(cp[5])), Vector3.UP)
	cam.current = true

func _process(_d):
	_f += 1
	r.update_from_fighter(_luta, 1.0 / 60.0, false, false)
	var inc := float(OS.get_environment("LB_CABECA")) if OS.get_environment("LB_CABECA") != "" else 0.0
	if inc != 0.0:
		var cab := r.sk.find_bone("mixamorig_Head")
		r.sk.set_bone_pose_rotation(cab, r.sk.get_bone_pose_rotation(cab) * Quaternion(Vector3.RIGHT, inc))
	if OS.get_environment("LB_DEBUG") != "" and _f % 3 == 0:
		print(_f, " punho_E=", r._osso_global("LeftHand"), " punho_D=", r._osso_global("RightHand"), " ombroE=", r._osso_global("LeftShoulder"), " cab=", r.head_position())
		if _f > 33: get_tree().quit()
	if OS.get_environment("LB_SERIE") != "":
		var passo := int(OS.get_environment("LB_PASSO")) if OS.get_environment("LB_PASSO") != "" else 3
		var fim := int(OS.get_environment("LB_FIM")) if OS.get_environment("LB_FIM") != "" else 90
		if _f % passo == 0 and _f >= 4 and _f <= fim:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT") + "/f_%03d.png" % _f)
		if _f > (int(OS.get_environment("LB_FIM")) if OS.get_environment("LB_FIM") != "" else 90):
			get_tree().quit()
		return
	if _f == int(OS.get_environment("LB_FRAME") if OS.get_environment("LB_FRAME") != "" else "40"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT") + "/robo.png")
		get_tree().quit()
