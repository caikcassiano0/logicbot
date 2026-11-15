class_name LBRobotVisual
extends Node3D
## Robô 3D PROVISÓRIO construído por código (primitivas + materiais PBR).
##
## Por que procedural? Não há modelos 3D prontos e livres de direitos no
## projeto ainda. Este robô já tem esqueleto articulado (ombros, cotovelos,
## quadris, joelhos, tronco, cabeça) e animações sincronizadas com o combate.
##
## Para trocar por um modelo de verdade (ex.: feito no Blender, exportado em
## .glb), basta criar uma cena com os mesmos nós de articulação (veja JOINTS)
## ou reescrever apenas [method update_from_fighter]. O combate não depende
## de nada deste arquivo.

const JOINTS := ["torso", "head", "sh_l", "el_l", "sh_r", "el_r", "hip_l", "knee_l", "hip_r", "knee_r"]
const R = preload("res://scripts/combat/lb_combat_rules.gd")

var accent := Color("22d3ee")
var paint := Color("1d4ed8")
var is_enemy := false
var labels_enabled := true
var facing := 1   ## +1 olha para a direita

var rig: Node3D
var hips: Node3D
var joints := {}
var _cur := {}
var _hips_y := 0.0
var _rig_tilt := 0.0
var _time := 0.0
var _ko_t := 0.0
var _victory := false
var _hit_flash := 0.0
var _special_charge := 0.0

var mat_armor: StandardMaterial3D
var mat_paint: StandardMaterial3D
var mat_dark: StandardMaterial3D
var mat_glow: StandardMaterial3D
var core_light: OmniLight3D
var shield: MeshInstance3D
var shield_mat: StandardMaterial3D
var action_label: Label3D
var fist_r: Node3D
var fist_l: Node3D


var armadura := "padrao"


## look (opcional, só para o jogador): {"pintura": Color, "brilho": Color, "armadura": String}
func build(enemy: bool, look: Dictionary = {}) -> void:
	is_enemy = enemy
	facing = -1 if enemy else 1
	accent = Color("ff3b4e") if enemy else Color("22d3ee")
	paint = Color("7f1d1d") if enemy else Color("1e40af")
	if not enemy and not look.is_empty():
		paint = look.get("pintura", paint)
		accent = look.get("brilho", accent)
		armadura = look.get("armadura", "padrao")
	_make_materials()

	rig = Node3D.new()
	rig.name = "Rig"
	add_child(rig)
	hips = Node3D.new()
	hips.name = "Hips"
	hips.position.y = 1.02
	rig.add_child(hips)

	var bulk := 1.12 if enemy else 1.0
	_box(hips, Vector3(0.44 * bulk, 0.22, 0.3), Vector3(0, 0, 0), mat_armor)
	_box(hips, Vector3(0.3, 0.12, 0.05), Vector3(0, -0.02, 0.16), mat_paint)

	# --- tronco
	var torso := _joint(hips, "torso", Vector3(0, 0.08, 0))
	_cyl(torso, 0.17, 0.15, 0.26, Vector3(0, 0.15, 0), mat_dark)
	_box(torso, Vector3(0.66 * bulk, 0.44, 0.38), Vector3(0, 0.46, 0), mat_paint)
	_box(torso, Vector3(0.52 * bulk, 0.3, 0.07), Vector3(0, 0.5, 0.2), mat_armor)
	_box(torso, Vector3(0.7 * bulk, 0.1, 0.4), Vector3(0, 0.7, 0), mat_armor)
	var core := _cyl(torso, 0.075, 0.075, 0.05, Vector3(0, 0.49, 0.24), mat_glow)
	core.rotation.x = PI / 2
	_box(torso, Vector3(0.03, 0.22, 0.02), Vector3(-0.17, 0.48, 0.24), mat_glow)
	_box(torso, Vector3(0.03, 0.22, 0.02), Vector3(0.17, 0.48, 0.24), mat_glow)
	_box(torso, Vector3(0.42, 0.38, 0.2), Vector3(0, 0.46, -0.27), mat_armor)
	for sx in [-0.11, 0.11]:
		var ex := _cyl(torso, 0.055, 0.07, 0.12, Vector3(sx, 0.34, -0.4), mat_dark)
		ex.rotation.x = PI / 2
		var ring := _cyl(torso, 0.04, 0.04, 0.02, Vector3(sx, 0.34, -0.465), mat_glow)
		ring.rotation.x = PI / 2
	core_light = OmniLight3D.new()
	core_light.light_color = accent
	core_light.light_energy = 0.8
	core_light.omni_range = 1.6
	core_light.position = Vector3(0, 0.5, 0.45)
	core_light.shadow_enabled = false
	torso.add_child(core_light)

	# --- cabeça
	var head := _joint(torso, "head", Vector3(0, 0.76, 0))
	_cyl(head, 0.07, 0.08, 0.14, Vector3(0, -0.02, 0), mat_dark)
	_box(head, Vector3(0.27, 0.27, 0.31), Vector3(0, 0.13, 0), mat_armor)
	_box(head, Vector3(0.29, 0.08, 0.22), Vector3(0, 0.25, -0.03), mat_paint)
	_box(head, Vector3(0.23, 0.055, 0.05), Vector3(0, 0.13, 0.155), mat_glow)
	_box(head, Vector3(0.16, 0.06, 0.06), Vector3(0, 0.04, 0.15), mat_dark)
	if enemy:
		for sx in [-1.0, 1.0]:
			var horn := _cyl(head, 0.0, 0.045, 0.24, Vector3(sx * 0.12, 0.33, -0.02), mat_paint)
			horn.rotation.z = -sx * 0.45
	else:
		_box(head, Vector3(0.04, 0.12, 0.26), Vector3(0, 0.33, -0.03), mat_paint)
		_box(head, Vector3(0.02, 0.06, 0.16), Vector3(0, 0.33, 0.02), mat_glow)

	# --- braços
	for side in [-1, 1]:
		var tag := "l" if side > 0 else "r"
		var sh := _joint(torso, "sh_" + tag, Vector3(side * 0.42 * bulk, 0.6, 0))
		var pad := _sphere(sh, 0.17, Vector3(side * 0.03, 0.03, 0), mat_paint)
		pad.scale = Vector3(1.15, 0.85, 1.1)
		_box(sh, Vector3(0.05, 0.03, 0.22), Vector3(side * 0.16, 0.06, 0), mat_glow)
		if enemy:
			var spike := _cyl(sh, 0.0, 0.06, 0.22, Vector3(side * 0.06, 0.2, 0), mat_armor)
			spike.rotation.z = -side * 0.3
		_capsule(sh, 0.075, 0.36, Vector3(0, -0.2, 0), mat_armor)
		var el := _joint(sh, "el_" + tag, Vector3(0, -0.38, 0))
		_sphere(el, 0.075, Vector3.ZERO, mat_dark)
		_box(el, Vector3(0.17, 0.3, 0.17), Vector3(0, -0.17, 0), mat_paint)
		_box(el, Vector3(0.025, 0.2, 0.03), Vector3(0, -0.17, 0.09), mat_glow)
		var fist := Node3D.new()
		fist.position = Vector3(0, -0.37, 0)
		el.add_child(fist)
		_box(fist, Vector3(0.15, 0.14, 0.15), Vector3.ZERO, mat_armor)
		_box(fist, Vector3(0.155, 0.04, 0.05), Vector3(0, 0.0, 0.06), mat_dark)
		if tag == "r":
			fist_r = fist
		else:
			fist_l = fist

	# --- pernas
	for side in [-1, 1]:
		var tag := "l" if side > 0 else "r"
		var hip := _joint(hips, "hip_" + tag, Vector3(side * 0.16, -0.06, 0))
		_capsule(hip, 0.1, 0.46, Vector3(0, -0.24, 0), mat_armor)
		_box(hip, Vector3(0.05, 0.22, 0.04), Vector3(side * 0.09, -0.24, 0.05), mat_paint)
		var knee := _joint(hip, "knee_" + tag, Vector3(0, -0.48, 0))
		_box(knee, Vector3(0.15, 0.13, 0.08), Vector3(0, 0.0, 0.1), mat_paint)
		_box(knee, Vector3(0.18, 0.42, 0.2), Vector3(0, -0.22, 0), mat_paint)
		_box(knee, Vector3(0.025, 0.26, 0.03), Vector3(0, -0.22, 0.105), mat_glow)
		_box(knee, Vector3(0.19, 0.08, 0.32), Vector3(0, -0.47, 0.05), mat_armor)

	_build_armor_extras()

	# --- escudo de energia (visível ao defender)
	shield = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.62
	disc.bottom_radius = 0.62
	disc.height = 0.02
	disc.radial_segments = 6
	shield.mesh = disc
	shield_mat = StandardMaterial3D.new()
	shield_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	shield_mat.albedo_color = Color(accent, 0.0)
	shield_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shield.material_override = shield_mat
	shield.rotation.x = PI / 2
	shield.position = Vector3(0, 1.45, 0.55)
	shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rig.add_child(shield)

	# --- rótulo da ação atual (ajuda a entender o que o código está fazendo)
	action_label = Label3D.new()
	action_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	action_label.font = LBUITheme.font(LBUITheme.FONT_CODE, 700)
	action_label.font_size = 44
	action_label.pixel_size = 0.004
	action_label.outline_size = 10
	action_label.outline_modulate = Color(0, 0, 0, 0.85)
	action_label.modulate = accent.lightened(0.35)
	# alturas diferentes para os rótulos não se sobreporem quando os robôs estão colados
	action_label.position = Vector3(0, 2.32 if enemy else 2.62, 0)
	action_label.no_depth_test = true
	action_label.render_priority = 10
	add_child(action_label)

	rotation.y = deg_to_rad(68.0) * facing
	_cur = _stance(0.0)
	_apply(_cur)


# ------------------------------------------------------------ construção

func _make_materials() -> void:
	mat_armor = StandardMaterial3D.new()
	mat_armor.albedo_color = Color("5b6473") if not is_enemy else Color("4a4448")
	mat_armor.metallic = 0.9
	mat_armor.roughness = 0.32
	mat_armor.metallic_specular = 0.7
	mat_paint = StandardMaterial3D.new()
	mat_paint.albedo_color = paint
	mat_paint.metallic = 0.65
	mat_paint.roughness = 0.38
	mat_paint.clearcoat_enabled = true
	mat_paint.clearcoat = 0.6
	mat_paint.clearcoat_roughness = 0.2
	mat_dark = StandardMaterial3D.new()
	mat_dark.albedo_color = Color("15181e")
	mat_dark.metallic = 0.5
	mat_dark.roughness = 0.7
	mat_glow = StandardMaterial3D.new()
	mat_glow.albedo_color = accent
	mat_glow.emission_enabled = true
	mat_glow.emission = accent
	mat_glow.emission_energy_multiplier = 2.6


func _joint(parent: Node3D, n: String, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.name = n
	j.position = pos
	parent.add_child(j)
	joints[n] = j
	return j


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mesh(parent, m, pos, mat)


func _cyl(parent: Node3D, top: float, bottom: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = 20
	m.rings = 1
	return _mesh(parent, m, pos, mat)


func _sphere(parent: Node3D, r: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 20
	m.rings = 10
	return _mesh(parent, m, pos, mat)


func _capsule(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 16
	m.rings = 4
	return _mesh(parent, m, pos, mat)


# ------------------------------------------------------------ animação
# Convenções (modelo olhando para +Z):
#   ombro/quadril rotação X negativa = membro para a frente
#   cotovelo X negativo = antebraço dobra para a frente; joelho X positivo = dobra para trás

func _stance(t: float) -> Dictionary:
	var breath := sin(t * 2.2)
	return {
		"torso": Vector3(-0.08 + breath * 0.02, 0, 0),
		"head": Vector3(0.05, 0, 0),
		"sh_l": Vector3(-0.75, 0, -0.18), "el_l": Vector3(-1.85, 0, 0),
		"sh_r": Vector3(-0.55, 0, 0.18), "el_r": Vector3(-1.95, 0, 0),
		"hip_l": Vector3(-0.38, 0, -0.06), "knee_l": Vector3(0.55, 0, 0),
		"hip_r": Vector3(0.22, 0, 0.06), "knee_r": Vector3(0.38, 0, 0),
		"_y": -0.07 + breath * 0.012,
		"_tilt": 0.0,
	}


func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


func update_from_fighter(f: LBFighter, delta: float, finished: bool, won: bool) -> void:
	_time += delta
	position.x = f.x
	position.y = f.altura_pulo()
	var target := _stance(_time)
	var k := 16.0
	var shield_alpha := 0.0
	_special_charge = move_toward(_special_charge, 0.0, delta * 3.0)
	var tw := float(facing)   # torção do tronco em direção ao inimigo

	if f.nocauteado:
		_ko_t += delta
		target = _stance(0.0)
		target.torso = Vector3(0.3, 0, 0)
		target.head = Vector3(0.5, 0, 0.3)
		target.sh_l = Vector3(0.3, 0, -1.1)
		target.sh_r = Vector3(0.3, 0, 1.1)
		target.el_l = Vector3(-0.3, 0, 0)
		target.el_r = Vector3(-0.3, 0, 0)
		target.hip_l = Vector3(-0.6, 0, 0)
		target.knee_l = Vector3(0.9, 0, 0)
		target._tilt = 1.42
		target._y = -0.7
		k = 6.0
		mat_glow.emission_energy_multiplier = lerpf(mat_glow.emission_energy_multiplier, 0.25, delta * 2.0)
		core_light.light_energy = lerpf(core_light.light_energy, 0.0, delta * 2.0)
	elif finished and won:
		target.sh_l = Vector3(-2.8, 0, -0.35)
		target.sh_r = Vector3(-2.8, 0, 0.35)
		target.el_l = Vector3(-0.4, 0, 0)
		target.el_r = Vector3(-0.4, 0, 0)
		target.head = Vector3(-0.25, 0, 0)
		target.torso = Vector3(0.1, 0, 0)
		k = 6.0
	elif f.atordoado > 0.0:
		var s := f.atordoado / R.ATORDOAMENTO
		target.torso = Vector3(0.45 * s, 0, 0)
		target.head = Vector3(-0.35 * s, 0.2 * s, 0)
		target.sh_l = Vector3(0.3, 0, -0.7)
		target.sh_r = Vector3(0.3, 0, 0.7)
		target.el_l = Vector3(-0.6, 0, 0)
		target.el_r = Vector3(-0.6, 0, 0)
		k = 28.0
	else:
		var d: Dictionary = f.def()
		var t := f.acao_t
		match _pose_of(f.acao):
			"atacar":
				var hit: float = d.hit_at
				if t < hit:
					var p := t / hit
					target.sh_r = Vector3(-0.45, 0, 0.35)
					target.el_r = Vector3(-2.35, 0, 0)
					target.torso.y = -0.3 * tw * p
					target.torso.x = 0.02
					k = 30.0
				else:
					var ext := 1.0 - smoothstep(0.35, 1.0, (t - hit) / (f.acao_dur - hit))
					target.sh_r = Vector3(-1.55, 0, 0.12).lerp(target.sh_r, 1.0 - ext)
					target.el_r = Vector3(-0.08, 0, 0).lerp(target.el_r, 1.0 - ext)
					target.torso.y = 0.42 * tw * ext
					target.torso.x = -0.2 * ext
					target.hip_l.x -= 0.15 * ext
					k = 45.0
			"golpe_especial":
				var hit: float = d.hit_at
				if t < hit:
					var p := t / hit
					_special_charge = p
					target.sh_l = Vector3(0.25, 0, -0.35)
					target.sh_r = Vector3(0.25, 0, 0.35)
					target.el_l = Vector3(-2.3, 0, 0)
					target.el_r = Vector3(-2.3, 0, 0)
					target.torso.x = 0.2 * p
					target.torso.y = -0.25 * tw * p
					target._y = -0.16 * p
					k = 14.0
				else:
					var ext := 1.0 - smoothstep(0.5, 1.0, (t - hit) / (f.acao_dur - hit))
					target.sh_l = Vector3(-1.5, 0, 0.05)
					target.sh_r = Vector3(-1.5, 0, -0.05)
					target.el_l = Vector3(-0.1, 0, 0)
					target.el_r = Vector3(-0.1, 0, 0)
					target.torso.x = -0.28 * ext
					target.torso.y = 0.3 * tw * ext
					target._y = -0.1
					k = 40.0
			"defender":
				target.sh_l = Vector3(-1.35, 0, 0.55)
				target.sh_r = Vector3(-1.35, 0, -0.55)
				target.el_l = Vector3(-1.75, 0, 0)
				target.el_r = Vector3(-1.75, 0, 0)
				target.torso.x = -0.18
				target.torso.y = 0.25 * tw
				target.head.x = 0.25
				target._y = -0.12
				shield_alpha = 0.35 * (1.0 - smoothstep(0.8, 1.0, f.progresso()))
				k = 30.0
			"avancar", "recuar":
				var ph := t * 16.0 * (1.0 if f.acao == "avancar" else -1.0)
				target.hip_l.x = -0.3 + sin(ph) * 0.55
				target.hip_r.x = -0.1 - sin(ph) * 0.55
				target.knee_l.x = 0.35 + maxf(0.0, cos(ph)) * 0.7
				target.knee_r.x = 0.35 + maxf(0.0, -cos(ph)) * 0.7
				target._y = -0.06 + absf(sin(ph)) * 0.04
				target.torso.x = -0.15 if f.acao == "avancar" else 0.05
				k = 22.0
			"esquivar":
				target.torso.x = 0.6
				target.torso.y = -0.3 * tw
				target.head.x = 0.25
				target.sh_l = Vector3(-0.2, 0, -0.75)
				target.sh_r = Vector3(-0.2, 0, 0.75)
				target.el_l = Vector3(-1.0, 0, 0)
				target.el_r = Vector3(-1.0, 0, 0)
				target.hip_l.x = -0.7
				target.knee_l.x = 1.1
				target.knee_r.x = 0.9
				target._y = -0.25
				k = 32.0
			"pular":
				target.hip_l = Vector3(-1.2, 0, 0)
				target.hip_r = Vector3(-0.8, 0, 0)
				target.knee_l = Vector3(1.9, 0, 0)
				target.knee_r = Vector3(1.6, 0, 0)
				target.sh_l = Vector3(-1.0, 0, -0.5)
				target.sh_r = Vector3(-1.0, 0, 0.5)
				target.torso.x = -0.25
				k = 24.0
			"falha":
				var shake := sin(_time * 60.0) * 0.06
				target.torso = Vector3(-0.35, shake, 0)
				target.head = Vector3(0.45, 0, 0)
				target.sh_l = Vector3(0.15, 0, -0.25)
				target.sh_r = Vector3(0.15, 0, 0.25)
				target.el_l = Vector3(-0.3, 0, 0)
				target.el_r = Vector3(-0.3, 0, 0)
				target._y = -0.15
				k = 18.0

	var w := 1.0 - exp(-k * delta)
	for j in JOINTS:
		_cur[j] = (_cur[j] as Vector3).lerp(target[j], w)
	_cur._y = lerpf(_cur._y, target._y, w)
	_cur._tilt = lerpf(_cur._tilt, target._tilt, w)
	_apply(_cur)

	shield_mat.albedo_color.a = lerpf(shield_mat.albedo_color.a, shield_alpha, 1.0 - exp(-20.0 * delta))
	shield.visible = shield_mat.albedo_color.a > 0.01
	shield.scale = Vector3.ONE * (0.9 + shield_mat.albedo_color.a * 0.4)

	if not f.nocauteado:
		_hit_flash = move_toward(_hit_flash, 0.0, delta * 4.0)
		mat_glow.emission_energy_multiplier = 2.6 + _special_charge * 9.0 + _hit_flash * 5.0
		core_light.light_energy = 0.8 + _special_charge * 4.0

	_update_label(f, finished)


func _apply(p: Dictionary) -> void:
	for j in JOINTS:
		joints[j].rotation = p[j]
	hips.position.y = 1.02 + p._y
	rig.rotation.x = -p._tilt


func flash() -> void:
	_hit_flash = 1.0


## Posição da mão que soca (para efeitos de impacto).
func fist_position() -> Vector3:
	return fist_r.global_position if fist_r else global_position + Vector3(0, 1.4, 0)


func chest_position() -> Vector3:
	return joints.torso.global_position + Vector3(0, 0.45, 0)


func _update_label(f: LBFighter, finished: bool) -> void:
	action_label.visible = labels_enabled and GameSettings.show_action_labels and not finished
	if not action_label.visible:
		return
	var txt := ""
	if f.programa_travado:
		txt = "⚠ PROGRAMA PARADO"
		action_label.modulate = Color("ffc94a")
	elif f.atordoado > 0.0:
		txt = "atordoado"
		action_label.modulate = Color(1, 1, 1, 0.7)
	elif f.acao == "falha":
		txt = "SEM ENERGIA!"
		action_label.modulate = Color("ffc94a")
	elif f.acao != "":
		txt = f.acao + "()"
		if f.acao_linha > 0:
			txt = "L%d  %s" % [f.acao_linha, txt]
		action_label.modulate = accent.lightened(0.35)
	action_label.text = txt


## Peças extras de cada armadura (personalização desbloqueada na progressão).
func _build_armor_extras() -> void:
	match armadura:
		"vanguarda":
			for tag in ["l", "r"]:
				var side := 1.0 if tag == "l" else -1.0
				var pad := _box(joints["sh_" + tag], Vector3(0.34, 0.1, 0.36), Vector3(side * 0.06, 0.2, 0), mat_armor)
				pad.rotation.z = -side * 0.25
				_box(joints["sh_" + tag], Vector3(0.05, 0.03, 0.3), Vector3(side * 0.2, 0.22, 0), mat_glow)
				_box(joints["el_" + tag], Vector3(0.21, 0.24, 0.07), Vector3(0, -0.17, 0.1), mat_armor)
			_box(joints.torso, Vector3(0.6, 0.14, 0.08), Vector3(0, 0.3, 0.22), mat_armor)
		"espectro":
			for side in [-1.0, 1.0]:
				var wing := _box(joints.torso, Vector3(0.035, 0.75, 0.02), Vector3(side * 0.3, 0.62, -0.38), mat_glow)
				wing.rotation.z = side * 0.55
				var wing2 := _box(joints.torso, Vector3(0.025, 0.5, 0.02), Vector3(side * 0.22, 0.5, -0.4), mat_glow)
				wing2.rotation.z = side * 0.9
			_box(joints.head, Vector3(0.03, 0.22, 0.34), Vector3(0, 0.38, -0.06), mat_glow)
		"campeao":
			var gold := StandardMaterial3D.new()
			gold.albedo_color = Color("fbbf24")
			gold.metallic = 1.0
			gold.roughness = 0.2
			gold.emission_enabled = true
			gold.emission = Color("f59e0b")
			gold.emission_energy_multiplier = 1.5
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.15
			tm.outer_radius = 0.19
			ring.mesh = tm
			ring.material_override = gold
			ring.position = Vector3(0, 0.3, 0)
			joints.head.add_child(ring)
			for i in 5:
				var a := TAU * i / 5.0
				_cyl(joints.head, 0.0, 0.03, 0.14, Vector3(cos(a) * 0.17, 0.38, sin(a) * 0.17), gold)



## Robô provisório: os golpes e defesas de boxe (2.0) reaproveitam as poses
## antigas até o modelo 3D novo com animações entrar (Fase 3).
static func _pose_of(acao: String) -> String:
	if acao in ["jab", "direto", "cruzado_frente", "cruzado_tras", "uppercut_frente", "uppercut_tras",
			"jab_corpo", "direto_corpo", "gancho_figado", "overhand"]:
		return "atacar"
	if acao in ["bloqueio_alto", "bloqueio_baixo"]:
		return "defender"
	if acao in ["esquivar_esquerda", "esquivar_direita", "abaixar", "recuar_tronco", "passo_lado"]:
		return "esquivar"
	return acao
