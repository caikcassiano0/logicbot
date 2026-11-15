class_name LBCenarioGuerra
extends RefCounted
## CENÁRIO "ZONA DE GUERRA" (protótipo 2.1): o ringue no meio de uma área industrial
## destruída — passarelas de metal, telhados de zinco caídos, contêineres, botijões,
## prédios em ruínas ao fundo, fogo, fumaça e brasas. Tudo feito por código (leve).
## Inspirado no estilo do kit "Post Apocalypse" (Oleg Ushenok); dá para trocar as peças
## por modelos de verdade depois, sem mudar a luta.

static var _rng := RandomNumberGenerator.new()


static func _mat(cor: Color, metal := 0.6, rug := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.metallic = metal
	m.roughness = rug
	return m


static func _caixa(a: Node3D, t: Vector3, p: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = t
	mi.mesh = bm
	mi.material_override = m
	mi.position = p
	mi.rotation_degrees = rot
	a.add_child(mi)
	return mi


static func _cil(a: Node3D, r: float, h: float, p: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 10
	mi.mesh = c
	mi.material_override = m
	mi.position = p
	mi.rotation_degrees = rot
	a.add_child(mi)
	return mi


static func montar(a: LBArena) -> void:
	_rng.seed = 7
	var env: Environment = a._env
	# céu de incêndio: fundo escuro, horizonte alaranjado, neblina de fumaça
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.05, 0.04, 0.05)
	sm.sky_horizon_color = Color(0.55, 0.22, 0.08)
	sm.ground_horizon_color = Color(0.3, 0.12, 0.05)
	sm.ground_bottom_color = Color(0.03, 0.03, 0.03)
	sm.sun_angle_max = 0.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.5, 0.45)
	env.ambient_light_energy = 0.9
	env.fog_light_color = Color(0.32, 0.17, 0.09)
	env.fog_density = 0.022
	a._key_light.light_color = Color(1.0, 0.72, 0.5)

	var concreto := _mat(Color(0.2, 0.19, 0.18), 0.0, 0.95)
	var ferrugem := _mat(Color(0.36, 0.2, 0.11), 0.7, 0.75)
	var aco := _mat(Color(0.3, 0.31, 0.33), 0.85, 0.45)
	var zinco := _mat(Color(0.42, 0.4, 0.36), 0.8, 0.55)
	var tijolo := _mat(Color(0.25, 0.17, 0.14), 0.0, 0.9)
	var escuro := _mat(Color(0.05, 0.05, 0.05), 0.0, 1.0)
	var amarelo := _mat(Color(0.7, 0.55, 0.1), 0.4, 0.6)
	var azul := _mat(Color(0.12, 0.22, 0.35), 0.6, 0.6)

	# chão de concreto rachado
	var chao := _caixa(a, Vector3(70, 0.2, 50), Vector3(0, -0.1, -6), concreto)
	chao.name = "Chao"
	for i in 14:
		var rach := _caixa(a, Vector3(_rng.randf_range(1.5, 5), 0.02, 0.06), Vector3(_rng.randf_range(-14, 14), 0.005, _rng.randf_range(-12, 5)), escuro, Vector3(0, _rng.randf_range(0, 180), 0))
		rach.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# crateras (anéis escuros)
	for c in [Vector3(-10, 0, -4), Vector3(11, 0, 2), Vector3(8, 0, -9)]:
		_cil(a, 1.6, 0.04, c, escuro)

	# prédios em ruínas no fundo (topo quebrado, janelas vazadas)
	for i in 9:
		var x := -26.0 + i * 6.5 + _rng.randf_range(-1, 1)
		var z := -24.0 + _rng.randf_range(-3, 3)
		var h := _rng.randf_range(7, 18)
		var w := _rng.randf_range(4, 6)
		var pr := Node3D.new()
		pr.position = Vector3(x, 0, z)
		a.add_child(pr)
		_caixa(pr, Vector3(w, h, 4), Vector3(0, h * 0.5, 0), tijolo)
		for k in 3:   # pedaços quebrados no topo
			_caixa(pr, Vector3(w * _rng.randf_range(0.2, 0.5), _rng.randf_range(0.8, 2.5), 3.8), Vector3(_rng.randf_range(-w * 0.3, w * 0.3), h + 0.5, 0), tijolo, Vector3(0, 0, _rng.randf_range(-25, 25)))
		for fy in int(h / 2.2):
			for fx in 2:
				if _rng.randf() < 0.85:
					var jan := _caixa(pr, Vector3(0.9, 1.1, 0.1), Vector3(-w * 0.25 + fx * w * 0.5, 1.6 + fy * 2.2, 2.02), escuro)
					if _rng.randf() < 0.12:   # janelas com fogo lá dentro
						var fm := StandardMaterial3D.new()
						fm.albedo_color = Color(1, 0.45, 0.1)
						fm.emission_enabled = true
						fm.emission = Color(1, 0.4, 0.08)
						fm.emission_energy_multiplier = 3.0
						jan.material_override = fm

	# passarelas de metal e escadas (laterais)
	for sx in [-1.0, 1.0]:
		var g := Node3D.new()
		g.position = Vector3(sx * 11.5, 0, -6)
		a.add_child(g)
		for px in [-3.0, 0.0, 3.0]:
			for pz in [-1.2, 1.2]:
				_caixa(g, Vector3(0.18, 4.2, 0.18), Vector3(px, 2.1, pz), ferrugem)
		_caixa(g, Vector3(7, 0.12, 2.6), Vector3(0, 4.2, 0), aco)   # piso da passarela
		for px in range(-3, 4):
			_caixa(g, Vector3(0.05, 1.0, 0.05), Vector3(px, 4.7, 1.25), aco)   # guarda-corpo
		_caixa(g, Vector3(7, 0.05, 0.05), Vector3(0, 5.2, 1.25), aco)
		_caixa(g, Vector3(1.2, 0.1, 5.5), Vector3(-sx * 3.6, 2.1, 2.5), aco, Vector3(-40, 0, 0))   # escada
		# telhado de zinco caído por cima
		_caixa(g, Vector3(8, 0.08, 3.6), Vector3(0.6, 6.4, 0.2), zinco, Vector3(8, 0, sx * 14))

	# contêineres amassados, caçambas, botijões e barris
	_caixa(a, Vector3(6, 2.6, 2.4), Vector3(-15, 1.3, 3), azul, Vector3(0, 20, 0))
	_caixa(a, Vector3(6, 2.6, 2.4), Vector3(-14.5, 3.9, 2.6), ferrugem, Vector3(0, 8, 6))
	_caixa(a, Vector3(6, 2.6, 2.4), Vector3(15.5, 1.3, -2), ferrugem, Vector3(0, -15, 0))
	_caixa(a, Vector3(2.4, 1.2, 1.4), Vector3(9.5, 0.6, 5.5), amarelo, Vector3(0, 30, 0))
	for i in 7:
		var b := Vector3(_rng.randf_range(-10, 10), 0.45, _rng.randf_range(-10, -7.5))
		var deitado := _rng.randf() < 0.3
		_cil(a, 0.3, 0.9, b + (Vector3(0, -0.15, 0) if deitado else Vector3.ZERO), ferrugem if i % 2 else amarelo, Vector3(90 if deitado else 0, 0, 0))
	for i in 5:
		_cil(a, 0.16, 0.9, Vector3(-8 + i * 0.4, 0.45, 7.5), _mat(Color(0.6, 0.12, 0.08), 0.5, 0.5))
	# destroços: vigas e placas jogadas
	for i in 18:
		var p := Vector3(_rng.randf_range(-16, 16), 0.1, _rng.randf_range(-14, 8))
		if absf(p.x) < 8 and absf(p.z) < 8:
			continue   # nada dentro / colado no ringue
		_caixa(a, Vector3(_rng.randf_range(0.6, 3), 0.15, _rng.randf_range(0.2, 0.6)), p, aco if i % 3 else ferrugem, Vector3(_rng.randf_range(-15, 15), _rng.randf_range(0, 180), 0))

	# fogo + fumaça em alguns pontos
	for f in [Vector3(-13, 0.3, -8), Vector3(12.5, 0.3, -11), Vector3(-6, 0.3, -16), Vector3(16, 0.3, 4)]:
		_fogo(a, f)


static func _fogo(a: Node3D, p: Vector3) -> void:
	var fogo := GPUParticles3D.new()
	fogo.amount = 40
	fogo.lifetime = 1.0
	fogo.position = p
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 15
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0, 1.0, 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.6
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0, 0.4, 1])
	g.colors = PackedColorArray([Color(1, 0.85, 0.4, 1), Color(1, 0.35, 0.05, 0.8), Color(0.2, 0.05, 0.0, 0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	fogo.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 0.7)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	q.material = m
	fogo.draw_pass_1 = q
	a.add_child(fogo)
	# fumaça escura subindo
	var fum := fogo.duplicate() as GPUParticles3D
	fum.amount = 24
	fum.lifetime = 5.0
	fum.position = p + Vector3(0, 1.5, 0)
	var pf: ParticleProcessMaterial = pm.duplicate()
	pf.initial_velocity_min = 0.8
	pf.initial_velocity_max = 1.4
	pf.spread = 20
	pf.scale_min = 2.0
	pf.scale_max = 4.0
	var g2 := Gradient.new()
	g2.offsets = PackedFloat32Array([0, 0.3, 1])
	g2.colors = PackedColorArray([Color(0.1, 0.08, 0.07, 0), Color(0.12, 0.1, 0.09, 0.55), Color(0.2, 0.18, 0.17, 0)])
	var gt2 := GradientTexture1D.new()
	gt2.gradient = g2
	pf.color_ramp = gt2
	fum.process_material = pf
	var q2 := QuadMesh.new()
	q2.size = Vector2(1.2, 1.2)
	var m2 := m.duplicate() as StandardMaterial3D
	m2.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	q2.material = m2
	fum.draw_pass_1 = q2
	a.add_child(fum)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1, 0.5, 0.15)
	luz.light_energy = 3.0
	luz.omni_range = 7.0
	luz.position = p + Vector3(0, 1.2, 0)
	a.add_child(luz)


static func _brasas(a: LBArena) -> void:
	# troca a poeira azul da arena por brasas alaranjadas subindo
	var d: GPUParticles3D = a._dust
	var q: QuadMesh = d.draw_pass_1
	var m: StandardMaterial3D = (q.material as StandardMaterial3D).duplicate()
	m.albedo_color = Color(1.0, 0.5, 0.15, 0.9)
	q = q.duplicate()
	q.material = m
	d.draw_pass_1 = q
	var pm: ParticleProcessMaterial = (d.process_material as ParticleProcessMaterial).duplicate()
	pm.gravity = Vector3(0.05, 0.25, 0)
	d.process_material = pm
