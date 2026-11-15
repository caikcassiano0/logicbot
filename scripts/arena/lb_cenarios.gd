class_name LBCenarios
extends RefCounted
## 10 CENÁRIOS DE PÓS-GUERRA (2.1), todos no mesmo estilo da "Zona de Guerra":
## feitos por código (leves no celular), com o ringue sempre no meio.
## Cada fase da campanha usa um; o treino livre usa um por bot.

const NOMES := [
	"Pátio Industrial", "Cidade em Ruínas", "Base no Deserto", "Porto Destruído", "Inverno de Guerra",
	"Floresta Queimada", "Refinaria Tóxica", "Estação Ferroviária", "Viaduto Caído", "Fortaleza Final",
]

const G = preload("res://scripts/arena/lb_cenario_guerra.gd")

static var _r := RandomNumberGenerator.new()


static func nome(n: int) -> String:
	return NOMES[clampi(n, 1, 10) - 1]


## Cenário de uma fase da campanha (1 a 10) e de um bot do treino.
static func da_fase(id: String) -> int:
	return clampi(LBCampaign.index_of(id) + 1, 1, 10)


static func do_bot(bot_id: String) -> int:
	var ids := LBBotLibrary.BOTS.map(func(b): return b.id)
	return [2, 3, 4, 7, 10][clampi(ids.find(bot_id), 0, 4)]


## Qual cenário usar numa luta, conforme a opção das Configurações.
## modo: "campanha"/"treino"/"tutorial"; id: fase ou bot. Devolve "1".."10" ou "industrial".
static func escolher(modo: String, id: String) -> String:
	match GameSettings.cenario_modo:
		1: return str(randi_range(1, 10))
		2: return "industrial"
	if modo == "campanha":
		return str(da_fase(id))
	if modo == "treino":
		return str(do_bot(id))
	return "1"   # tutorial: o pátio industrial


static func montar(a: LBArena, n: int) -> void:
	if n <= 1:
		G.montar(a)
		return
	_r.seed = n * 101
	match n:
		2: _cidade(a)
		3: _deserto(a)
		4: _porto(a)
		5: _inverno(a)
		6: _floresta(a)
		7: _refinaria(a)
		8: _estacao(a)
		9: _viaduto(a)
		_: _fortaleza(a)


# ------------------------------------------------------------ base comum

static func _ceu(a: LBArena, topo: Color, horiz: Color, amb: Color, nevoa: Color, dens: float, sol: Color) -> void:
	var env: Environment = a._env
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = topo
	sm.sky_horizon_color = horiz
	sm.ground_horizon_color = horiz.darkened(0.4)
	sm.ground_bottom_color = Color(0.03, 0.03, 0.03)
	sm.sun_angle_max = 0.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = amb
	env.ambient_light_energy = 0.9
	env.fog_light_color = nevoa
	env.fog_density = dens
	a._key_light.light_color = sol


static func _chao(a: Node3D, cor: Color) -> void:
	G._caixa(a, Vector3(70, 0.2, 50), Vector3(0, -0.1, -6), G._mat(cor, 0.0, 0.95))
	var esc := G._mat(cor.darkened(0.6), 0.0, 1.0)
	for i in 12:
		G._caixa(a, Vector3(_r.randf_range(1.5, 5), 0.02, 0.06), Vector3(_r.randf_range(-14, 14), 0.005, _r.randf_range(-12, 5)), esc, Vector3(0, _r.randf_range(0, 180), 0))
	for c in [Vector3(-10, 0, -4), Vector3(11, 0, 2)]:
		G._cil(a, 1.5, 0.04, c, esc)


## true se a posição atrapalha o ringue (nada perto dele)
static func _livre(p: Vector3) -> bool:
	return absf(p.x) > 8.5 or absf(p.z) > 8.5


static func _predios(a: Node3D, cor: Color, qtd: int, z: float, hmin: float, hmax: float, fogo_jan := 0.1) -> void:
	var tij := G._mat(cor, 0.0, 0.9)
	var esc := G._mat(Color(0.04, 0.04, 0.04), 0.0, 1.0)
	var luz := StandardMaterial3D.new()
	luz.albedo_color = Color(1, 0.45, 0.1)
	luz.emission_enabled = true
	luz.emission = Color(1, 0.4, 0.08)
	luz.emission_energy_multiplier = 3.0
	for i in qtd:
		var x := -28.0 + i * (56.0 / qtd) + _r.randf_range(-1, 1)
		var h := _r.randf_range(hmin, hmax)
		var w := _r.randf_range(4, 6)
		var pr := Node3D.new()
		pr.position = Vector3(x, 0, z + _r.randf_range(-3, 3))
		a.add_child(pr)
		G._caixa(pr, Vector3(w, h, 4), Vector3(0, h * 0.5, 0), tij)
		for k in 3:
			G._caixa(pr, Vector3(w * _r.randf_range(0.2, 0.5), _r.randf_range(0.8, 2.5), 3.8), Vector3(_r.randf_range(-w * 0.3, w * 0.3), h + 0.5, 0), tij, Vector3(0, 0, _r.randf_range(-25, 25)))
		for fy in int(h / 2.2):
			for fx in 2:
				if _r.randf() < 0.85:
					G._caixa(pr, Vector3(0.9, 1.1, 0.1), Vector3(-w * 0.25 + fx * w * 0.5, 1.6 + fy * 2.2, 2.02), luz if _r.randf() < fogo_jan else esc)


static func _destrocos(a: Node3D, m: Material, qtd := 18) -> void:
	for i in qtd:
		var p := Vector3(_r.randf_range(-16, 16), 0.1, _r.randf_range(-14, 8))
		if _livre(p):
			G._caixa(a, Vector3(_r.randf_range(0.6, 3), 0.15, _r.randf_range(0.2, 0.6)), p, m, Vector3(_r.randf_range(-15, 15), _r.randf_range(0, 180), 0))


static func _entulho(a: Node3D, p: Vector3, m: Material, tam := 1.0) -> void:
	for i in 10:
		var q := p + Vector3(_r.randf_range(-1.5, 1.5), 0, _r.randf_range(-1.2, 1.2)) * tam
		var s := _r.randf_range(0.3, 0.9) * tam
		G._caixa(a, Vector3(s, s * 0.6, s * 0.8), q + Vector3(0, s * 0.3, 0), m, Vector3(_r.randf_range(-30, 30), _r.randf_range(0, 180), _r.randf_range(-30, 30)))


static func _barris(a: Node3D, qtd: int, cores: Array) -> void:
	for i in qtd:
		var b := Vector3(_r.randf_range(-12, 12), 0.45, _r.randf_range(-11, -8.5))
		var deitado := _r.randf() < 0.3
		G._cil(a, 0.3, 0.9, b + (Vector3(0, -0.15, 0) if deitado else Vector3.ZERO), G._mat(cores[i % cores.size()], 0.6, 0.7), Vector3(90 if deitado else 0, 0, 0))


static func _tanque(a: Node3D, p: Vector3, rot: float, cor: Color) -> void:
	var t := Node3D.new()
	t.position = p
	t.rotation_degrees = Vector3(0, rot, _r.randf_range(-6, 6))
	a.add_child(t)
	var m := G._mat(cor, 0.5, 0.8)
	var esc := G._mat(cor.darkened(0.6), 0.4, 0.9)
	G._caixa(t, Vector3(5.5, 1.1, 3.0), Vector3(0, 0.95, 0), m)
	G._caixa(t, Vector3(5.8, 0.8, 0.7), Vector3(0, 0.45, 1.5), esc)
	G._caixa(t, Vector3(5.8, 0.8, 0.7), Vector3(0, 0.45, -1.5), esc)
	G._caixa(t, Vector3(2.4, 0.8, 2.0), Vector3(-0.3, 1.9, 0), m, Vector3(0, 15, 0))
	G._cil(t, 0.12, 3.5, Vector3(1.6, 2.0, 0.6), esc, Vector3(0, 0, 80))   # canhão caído


static func _carro(a: Node3D, p: Vector3, rot: float, cor: Color) -> void:
	var c := Node3D.new()
	c.position = p
	c.rotation_degrees = Vector3(0, rot, _r.randf_range(-8, 8))
	a.add_child(c)
	var m := G._mat(cor, 0.5, 0.85)
	var esc := G._mat(Color(0.05, 0.05, 0.05), 0.0, 1.0)
	G._caixa(c, Vector3(4.0, 0.8, 1.8), Vector3(0, 0.7, 0), m)
	G._caixa(c, Vector3(2.0, 0.7, 1.6), Vector3(-0.3, 1.45, 0), m)
	G._caixa(c, Vector3(1.9, 0.5, 1.62), Vector3(-0.3, 1.45, 0), esc)
	for w in [Vector3(1.3, 0.35, 0.9), Vector3(-1.3, 0.35, 0.9), Vector3(1.3, 0.35, -0.9), Vector3(-1.3, 0.35, -0.9)]:
		G._cil(c, 0.35, 0.25, w, esc, Vector3(90, 0, 0))


static func _sacos(a: Node3D, p: Vector3, rot: float, cor: Color) -> void:
	var s := Node3D.new()
	s.position = p
	s.rotation_degrees.y = rot
	a.add_child(s)
	var m := G._mat(cor, 0.0, 1.0)
	for fila in 3:
		for i in 6 - fila:
			var mi := MeshInstance3D.new()
			var cap := CapsuleMesh.new()
			cap.radius = 0.22
			cap.height = 0.9
			mi.mesh = cap
			mi.material_override = m
			mi.rotation_degrees.z = 90
			mi.position = Vector3(-1.1 + i * 0.85 + fila * 0.42, 0.2 + fila * 0.36, 0)
			s.add_child(mi)


static func _arvore_seca(a: Node3D, p: Vector3, cor: Color) -> void:
	var m := G._mat(cor, 0.0, 1.0)
	var h := _r.randf_range(3, 6)
	G._cil(a, 0.18, h, p + Vector3(0, h * 0.5, 0), m, Vector3(_r.randf_range(-6, 6), 0, _r.randf_range(-6, 6)))
	for i in 3:
		var y := _r.randf_range(h * 0.45, h * 0.9)
		G._cil(a, 0.07, _r.randf_range(1, 2), p + Vector3(0, y, 0), m, Vector3(0, _r.randf_range(0, 180), _r.randf_range(35, 60) * (1 if i % 2 else -1)))


static func _poste(a: Node3D, p: Vector3, torto: float) -> void:
	var m := G._mat(Color(0.25, 0.25, 0.26), 0.8, 0.5)
	G._cil(a, 0.1, 6.0, p + Vector3(0, 3, 0), m, Vector3(0, 0, torto))


static func _fumaca(a: Node3D, pontos: Array) -> void:
	for f in pontos:
		G._fogo(a, f)


static func _neve(a: LBArena) -> void:
	var d: GPUParticles3D = a._dust
	var q: QuadMesh = (d.draw_pass_1 as QuadMesh).duplicate()
	var m: StandardMaterial3D = (q.material as StandardMaterial3D).duplicate()
	m.albedo_color = Color(0.95, 0.97, 1.0, 0.9)
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	q.material = m
	q.size = Vector2(0.05, 0.05)
	d.draw_pass_1 = q
	var pm: ParticleProcessMaterial = (d.process_material as ParticleProcessMaterial).duplicate()
	pm.gravity = Vector3(0.1, -0.6, 0)
	d.process_material = pm


## Partículas no ar: "brasas" (laranja subindo), "neve" ou "poeira" (marrom).
static func ar(a: LBArena, n: int) -> void:
	match n:
		5: _neve(a)
		3, 9:
			G._brasas(a)
			var q: QuadMesh = a._dust.draw_pass_1
			(q.material as StandardMaterial3D).albedo_color = Color(0.75, 0.6, 0.4, 0.6)
		_: G._brasas(a)


# ------------------------------------------------------------ os cenários

static func _cidade(a: LBArena) -> void:
	_ceu(a, Color(0.02, 0.03, 0.07), Color(0.18, 0.12, 0.2), Color(0.45, 0.48, 0.65), Color(0.12, 0.1, 0.16), 0.02, Color(0.7, 0.75, 1.0))
	_chao(a, Color(0.17, 0.17, 0.19))
	_predios(a, Color(0.24, 0.22, 0.24), 10, -22, 9, 22, 0.15)
	for sx in [-1.0, 1.0]:
		_predios(a, Color(0.2, 0.19, 0.2), 1, -10, 6, 10)   # prédio perto, em pé
	var asf := G._mat(Color(0.3, 0.29, 0.3), 0.0, 0.9)
	_entulho(a, Vector3(-12, 0, -2), asf, 1.4)
	_entulho(a, Vector3(13, 0, -6), asf, 1.2)
	_carro(a, Vector3(-11, 0, 5), 30, Color(0.25, 0.08, 0.06))
	_carro(a, Vector3(12, 0, 3), -70, Color(0.12, 0.12, 0.14))
	for x in [-14.0, 14.0]:
		_poste(a, Vector3(x, 0, -9), _r.randf_range(-25, 25))
	_destrocos(a, asf)
	_fumaca(a, [Vector3(-12, 0.3, -2), Vector3(9, 0.3, -18)])


static func _deserto(a: LBArena) -> void:
	_ceu(a, Color(0.35, 0.3, 0.25), Color(0.8, 0.55, 0.3), Color(0.8, 0.7, 0.55), Color(0.6, 0.45, 0.28), 0.018, Color(1.0, 0.85, 0.6))
	_chao(a, Color(0.55, 0.43, 0.28))
	for i in 7:   # dunas
		var d := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = _r.randf_range(5, 9)
		sm.height = sm.radius * 0.7
		d.mesh = sm
		d.material_override = G._mat(Color(0.58, 0.45, 0.29), 0.0, 1.0)
		d.position = Vector3(-30 + i * 10, -1.2, -26 + _r.randf_range(-4, 2))
		a.add_child(d)
	_tanque(a, Vector3(-13, 0, -6), 35, Color(0.42, 0.37, 0.25))
	_tanque(a, Vector3(14, 0, 3), -110, Color(0.38, 0.33, 0.22))
	_sacos(a, Vector3(-10, 0, 6), 70, Color(0.6, 0.5, 0.33))
	_sacos(a, Vector3(10, 0, -10), 10, Color(0.6, 0.5, 0.33))
	var tenda := G._mat(Color(0.36, 0.33, 0.22), 0.0, 1.0)
	G._caixa(a, Vector3(4, 0.1, 4), Vector3(11, 2.0, -5), tenda, Vector3(0, 20, 12))
	_barris(a, 6, [Color(0.35, 0.33, 0.2), Color(0.5, 0.18, 0.1)])
	_destrocos(a, G._mat(Color(0.35, 0.32, 0.28), 0.7, 0.7))
	_fumaca(a, [Vector3(-13, 1.5, -6)])


static func _porto(a: LBArena) -> void:
	_ceu(a, Color(0.12, 0.14, 0.17), Color(0.4, 0.42, 0.45), Color(0.55, 0.6, 0.65), Color(0.3, 0.33, 0.36), 0.03, Color(0.85, 0.9, 1.0))
	_chao(a, Color(0.22, 0.22, 0.22))
	var agua := StandardMaterial3D.new()
	agua.albedo_color = Color(0.05, 0.08, 0.1)
	agua.metallic = 0.3
	agua.roughness = 0.1
	G._caixa(a, Vector3(80, 0.1, 30), Vector3(0, -0.6, -32), agua)
	var cores := [Color(0.5, 0.15, 0.1), Color(0.1, 0.25, 0.4), Color(0.2, 0.35, 0.2), Color(0.55, 0.4, 0.1)]
	for i in 8:
		var p := Vector3(_r.randf_range(-18, 18), 1.3, _r.randf_range(-15, -10))
		G._caixa(a, Vector3(6, 2.6, 2.4), p, G._mat(cores[i % 4], 0.6, 0.7), Vector3(0, _r.randf_range(-20, 20), 0))
		if i % 3 == 0:
			G._caixa(a, Vector3(6, 2.6, 2.4), p + Vector3(0, 2.6, 0), G._mat(cores[(i + 1) % 4], 0.6, 0.7), Vector3(0, _r.randf_range(-20, 20), _r.randf_range(-8, 8)))
	var aco := G._mat(Color(0.55, 0.4, 0.12), 0.7, 0.6)   # guindaste tombado
	for x in [-16.0, 15.0]:
		G._caixa(a, Vector3(0.6, 14, 0.6), Vector3(x, 7, -20), aco, Vector3(0, 0, 12 if x < 0 else -18))
		G._caixa(a, Vector3(12, 0.6, 0.6), Vector3(x + 3, 13, -20), aco, Vector3(0, 0, -8))
	_barris(a, 5, [Color(0.25, 0.25, 0.3)])
	_destrocos(a, G._mat(Color(0.3, 0.3, 0.3), 0.7, 0.6))
	_fumaca(a, [Vector3(14, 0.3, -12)])


static func _inverno(a: LBArena) -> void:
	_ceu(a, Color(0.3, 0.34, 0.4), Color(0.6, 0.62, 0.66), Color(0.5, 0.55, 0.65), Color(0.5, 0.52, 0.56), 0.028, Color(0.7, 0.75, 0.85))
	_chao(a, Color(0.55, 0.57, 0.6))
	_predios(a, Color(0.4, 0.38, 0.38), 7, -24, 5, 12, 0.0)
	for i in 10:
		var p := Vector3(_r.randf_range(-20, 20), 0, _r.randf_range(-18, 6))
		if _livre(p):
			_arvore_seca(a, p, Color(0.15, 0.13, 0.12))
	_tanque(a, Vector3(-12, 0, 2), 60, Color(0.33, 0.36, 0.33))
	_sacos(a, Vector3(11, 0, -2), -80, Color(0.75, 0.75, 0.72))
	var neve := G._mat(Color(0.7, 0.72, 0.76), 0.0, 1.0)
	for i in 8:
		var p := Vector3(_r.randf_range(-16, 16), 0, _r.randf_range(-14, 6))
		if _livre(p):
			G._cil(a, _r.randf_range(0.8, 1.6), 0.4, p, neve)
	_fumaca(a, [Vector3(-12, 1.0, 2)])


static func _floresta(a: LBArena) -> void:
	_ceu(a, Color(0.08, 0.06, 0.06), Color(0.45, 0.2, 0.1), Color(0.55, 0.42, 0.38), Color(0.25, 0.14, 0.1), 0.03, Color(1.0, 0.65, 0.45))
	_chao(a, Color(0.12, 0.1, 0.08))
	for i in 34:
		var p := Vector3(_r.randf_range(-28, 28), 0, _r.randf_range(-28, 8))
		if _livre(p):
			_arvore_seca(a, p, Color(0.05, 0.04, 0.04))
	var tronco := G._mat(Color(0.08, 0.06, 0.05), 0.0, 1.0)
	for i in 6:
		var p := Vector3(_r.randf_range(-14, 14), 0.25, _r.randf_range(-12, 6))
		if _livre(p):
			G._cil(a, 0.25, _r.randf_range(3, 5), p, tronco, Vector3(90, _r.randf_range(0, 180), 0))
	_fumaca(a, [Vector3(-12, 0.3, -6), Vector3(13, 0.3, -9), Vector3(-6, 0.3, -18), Vector3(9, 0.3, 4)])


static func _refinaria(a: LBArena) -> void:
	_ceu(a, Color(0.05, 0.07, 0.05), Color(0.25, 0.35, 0.15), Color(0.45, 0.55, 0.42), Color(0.18, 0.24, 0.12), 0.025, Color(0.8, 1.0, 0.7))
	_chao(a, Color(0.18, 0.19, 0.17))
	var aco := G._mat(Color(0.45, 0.46, 0.44), 0.8, 0.5)
	var fer := G._mat(Color(0.35, 0.22, 0.12), 0.7, 0.75)
	for i in 5:   # tanques de combustível
		var x := -20.0 + i * 10
		G._cil(a, 3.0, 6.0, Vector3(x, 3, -20), aco if i % 2 else fer)
	for x in [-12.0, 6.0, 16.0]:   # chaminés
		G._cil(a, 0.8, 16.0, Vector3(x, 8, -26), fer)
		G._fogo(a, Vector3(x, 16.2, -26))
	var verde := StandardMaterial3D.new()   # poças tóxicas
	verde.albedo_color = Color(0.3, 0.9, 0.2)
	verde.emission_enabled = true
	verde.emission = Color(0.3, 1.0, 0.2)
	verde.emission_energy_multiplier = 1.5
	for p in [Vector3(-11, 0.02, 4), Vector3(12, 0.02, -4)]:
		G._cil(a, 1.8, 0.03, p, verde)
	for z in [-12.0, -14.0]:   # canos
		G._cil(a, 0.4, 30, Vector3(0, 1.2, z), aco, Vector3(0, 0, 90))
	_barris(a, 8, [Color(0.6, 0.55, 0.1), Color(0.2, 0.3, 0.2)])
	_destrocos(a, aco)


static func _estacao(a: LBArena) -> void:
	_ceu(a, Color(0.15, 0.13, 0.12), Color(0.55, 0.4, 0.3), Color(0.62, 0.55, 0.5), Color(0.35, 0.28, 0.22), 0.022, Color(1.0, 0.82, 0.65))
	_chao(a, Color(0.25, 0.22, 0.2))
	var ferro := G._mat(Color(0.3, 0.28, 0.26), 0.8, 0.5)
	var dorm := G._mat(Color(0.22, 0.15, 0.1), 0.0, 1.0)
	for z in [-11.0, -15.0]:   # trilhos
		for t in range(-30, 31, 2):
			G._caixa(a, Vector3(0.3, 0.1, 2.4), Vector3(t, 0.05, z), dorm)
		for dz in [-0.75, 0.75]:
			G._caixa(a, Vector3(60, 0.15, 0.1), Vector3(0, 0.15, z + dz), ferro)
	var vag := [Color(0.35, 0.12, 0.08), Color(0.18, 0.22, 0.25), Color(0.3, 0.25, 0.12)]
	for i in 4:   # vagões tombados
		var p := Vector3(-18 + i * 11, 1.7, -14 + _r.randf_range(-2, 2))
		G._caixa(a, Vector3(9, 3.2, 3), p, G._mat(vag[i % 3], 0.6, 0.7), Vector3(0, _r.randf_range(-15, 15), 0 if i % 2 else 80))
	_predios(a, Color(0.35, 0.28, 0.24), 4, -26, 6, 9, 0.05)   # estação ao fundo
	_entulho(a, Vector3(12, 0, 3), ferro)
	_fumaca(a, [Vector3(-7, 0.3, -14)])


static func _viaduto(a: LBArena) -> void:
	_ceu(a, Color(0.2, 0.18, 0.16), Color(0.65, 0.45, 0.3), Color(0.65, 0.58, 0.52), Color(0.4, 0.32, 0.25), 0.02, Color(1.0, 0.8, 0.6))
	_chao(a, Color(0.23, 0.23, 0.24))
	var conc := G._mat(Color(0.45, 0.43, 0.4), 0.0, 0.9)
	for x in [-20.0, -6.0, 8.0, 22.0]:   # pilares
		G._caixa(a, Vector3(1.6, 8, 1.6), Vector3(x, 4, -16), conc)
	G._caixa(a, Vector3(16, 1, 6), Vector3(-13, 8.5, -16), conc)
	G._caixa(a, Vector3(14, 1, 6), Vector3(1, 4.5, -16), conc, Vector3(0, 0, 32))   # pedaço caído
	G._caixa(a, Vector3(16, 1, 6), Vector3(15, 8.5, -16), conc)
	var cores := [Color(0.3, 0.07, 0.05), Color(0.1, 0.1, 0.12), Color(0.35, 0.33, 0.3), Color(0.15, 0.2, 0.3)]
	for i in 7:
		var p := Vector3(_r.randf_range(-18, 18), 0, _r.randf_range(-13, 7))
		if _livre(p):
			_carro(a, p, _r.randf_range(0, 360), cores[i % 4])
	_entulho(a, Vector3(1, 0, -14), conc, 1.6)
	for x in [-14.0, 14.0]:
		_poste(a, Vector3(x, 0, -8), _r.randf_range(-35, 35))
	_fumaca(a, [Vector3(3, 0.3, -12), Vector3(-15, 0.3, 4)])


static func _fortaleza(a: LBArena) -> void:
	_ceu(a, Color(0.03, 0.02, 0.03), Color(0.35, 0.05, 0.05), Color(0.5, 0.38, 0.4), Color(0.2, 0.05, 0.05), 0.025, Color(1.0, 0.55, 0.5))
	_chao(a, Color(0.14, 0.13, 0.13))
	var muro := G._mat(Color(0.28, 0.27, 0.27), 0.1, 0.9)
	for i in 9:   # muralha com ameias
		var x := -24.0 + i * 6
		G._caixa(a, Vector3(5.8, 7, 2), Vector3(x, 3.5, -18), muro)
		G._caixa(a, Vector3(1.8, 1.2, 2), Vector3(x - 1.5, 7.6, -18), muro)
		G._caixa(a, Vector3(1.8, 1.2, 2), Vector3(x + 1.5, 7.6, -18), muro)
	for x in [-16.0, 16.0]:   # torres
		G._cil(a, 2.2, 14, Vector3(x, 7, -16), muro)
		var holo := SpotLight3D.new()
		holo.light_color = Color(1, 0.15, 0.1)
		holo.light_energy = 6.0
		holo.spot_range = 30
		holo.spot_angle = 12
		holo.position = Vector3(x, 14.5, -16)
		a.add_child(holo)
		holo.look_at(Vector3(0, 0, 0), Vector3.UP)
	G._caixa(a, Vector3(8, 2.5, 5), Vector3(-13, 1.25, -6), muro)   # bunker
	G._caixa(a, Vector3(6, 0.4, 0.3), Vector3(-13, 1.6, -3.5), G._mat(Color(0.02, 0.02, 0.02), 0, 1))
	_tanque(a, Vector3(13, 0, 2), -60, Color(0.18, 0.18, 0.18))
	_sacos(a, Vector3(-10, 0, 6), 80, Color(0.3, 0.28, 0.22))
	_destrocos(a, G._mat(Color(0.25, 0.25, 0.26), 0.7, 0.6))
	_fumaca(a, [Vector3(13, 1.5, 2), Vector3(-6, 0.3, -14)])
