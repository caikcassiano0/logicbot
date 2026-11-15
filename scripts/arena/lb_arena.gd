class_name LBArena
extends Node3D
## A arena 3D: ambiente, iluminação, estrutura, robôs, câmera e efeitos.
##
## É somente APRESENTAÇÃO: recebe o estado da simulação (LBCombatSim) e os
## eventos de cada passo e desenha. Nunca altera o combate.
##
## Modos:
##   * batalha  — câmera lateral de jogo de luta, acompanha os robôs;
##   * vitrine  — usado no menu: robôs "treinando" e câmera em órbita lenta.

const C_PLAYER := Color("22d3ee")
const C_ENEMY := Color("ff3b4e")
const RING_Y := 0.5        ## 2.0: altura do tablado do ringue (os robôs lutam em cima dele)
const RING_MEIO := 6.6     ## metade do lado do ringue (a simulação vai de -6 a +6)

var showcase := false
var foco_garagem := false
var cenario := "industrial"   ## "industrial" (arena neon), "guerra" (=1) ou "1".."10" (LBCenarios)


func _num_cenario() -> int:
	if cenario == "guerra":
		return 1
	return int(cenario) if cenario.is_valid_int() else 0   ## menu: a câmera mostra o SEU robô de perto (garagem)
var player_look: Dictionary = {}
var enemy_look: Dictionary = {}
var player_visual: LBRoboMixamo
var enemy_visual: LBRoboMixamo
var effects: LBEffects
var camera: Camera3D

var _env: Environment
var _world_env: WorldEnvironment
var _key_light: DirectionalLight3D
var _spots: Array[SpotLight3D] = []
var _probe: ReflectionProbe
var _dust: GPUParticles3D
var _floor_mat: ShaderMaterial
var _neon_mats: Array[StandardMaterial3D] = []

var _shake := 0.0
var hitstop := 0.0          ## 2.0: "congela" a luta por um instante nos golpes fortes (a tela de batalha lê)
var _cam_target := Vector3(0, 1.25, 0)
var _cam_dist := 8.0
var _cam_pos := Vector3(0, 2.2, 9.0)
var _time := 0.0
var _focus_winner := -1
var _cordas_frente: Array[Node3D] = []
var _dyn_t := 0.0
var _dyn_i := 0
var _cam_estilo := -1

# vitrine
var _demo_fighters: Array[LBFighter] = []
var _demo_step := 0
var _demo_wait := 1.0


func _ready() -> void:
	_build_environment()
	_build_lights()
	var n_cen := _num_cenario()
	if n_cen > 0:
		LBCenarios.montar(self, n_cen)
	else:
		_build_structure()
	_build_ring()
	_build_dust()
	if n_cen > 0:
		LBCenarios.ar(self, n_cen)

	player_visual = LBRoboMixamo.new()
	player_visual.name = "RoboJogador"
	add_child(player_visual)
	player_visual.build(false, player_look)
	enemy_visual = LBRoboMixamo.new()
	enemy_visual.name = "RoboInimigo"
	add_child(enemy_visual)
	enemy_visual.build(true, enemy_look)
	player_visual.base_y = RING_Y
	enemy_visual.base_y = RING_Y

	effects = LBEffects.new()
	effects.name = "Efeitos"
	add_child(effects)

	camera = Camera3D.new()
	camera.fov = 38.0
	camera.near = 0.1
	camera.far = 120.0
	add_child(camera)
	camera.current = true

	if showcase:
		player_visual.labels_enabled = false
		enemy_visual.labels_enabled = false
		var a := LBFighter.new("A", 1)
		var b := LBFighter.new("B", -1)
		a.x = -1.05
		b.x = 1.05
		_demo_fighters = [a, b]
		camera.position = Vector3(0, 1.6 + RING_Y, 7)

	apply_quality()
	GameSettings.changed.connect(apply_quality)


# ------------------------------------------------------------ qualidade gráfica

func apply_quality() -> void:
	var q: int = GameSettings.quality
	var alta := q == GameSettings.Quality.ALTA
	var media_ou_mais := q >= GameSettings.Quality.MEDIA
	# Em placas "arriscadas" (Linux/Mesa/integrada) a Alta mantém sombras e oclusão,
	# mas sem névoa volumétrica e reflexos de tela — os suspeitos da imagem estourada.
	var seguro := GameSettings.is_risky_gpu()
	_env.ssao_enabled = alta
	_env.ssr_enabled = alta and not seguro
	_env.volumetric_fog_enabled = alta and not seguro
	_env.glow_enabled = true
	_env.set_glow_level(0, 0.0)
	_env.set_glow_level(1, 1.0)
	_env.set_glow_level(2, 1.0 if media_ou_mais else 0.0)
	_env.set_glow_level(3, 0.6 if media_ou_mais else 0.0)
	_env.set_glow_level(4, 0.3 if alta else 0.0)
	_key_light.shadow_enabled = media_ou_mais
	_key_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_key_light.directional_shadow_max_distance = 30.0
	for i in _spots.size():
		_spots[i].shadow_enabled = alta
		# Baixa (celular fraco): só os 2 refletores principais — cada luz custa caro no modo Compatibilidade
		_spots[i].visible = media_ou_mais or i < 2
	for v in [player_visual, enemy_visual]:
		if v and v.nucleo:
			v.nucleo.visible = media_ou_mais
	_dust.visible = media_ou_mais
	_probe.visible = media_ou_mais
	if effects:
		effects.particle_scale = [0.35, 0.7, 1.0][q]
	_dust.amount = [40, 120, 260][q]
	var vp := get_viewport()
	if vp:
		# celular (modo Compatibilidade) não tem FXAA: usa MSAA também na Baixa para não serrilhar
		var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
		vp.msaa_3d = [Viewport.MSAA_2X if compat else Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][q]
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q == GameSettings.Quality.BAIXA and not compat else Viewport.SCREEN_SPACE_AA_DISABLED
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		# celular: o 3D é desenhado com menos pixels nas qualidades leves (a luta fica fluida)
		var movel := OS.has_feature("mobile") or OS.get_environment("LB_DEVICE") == "celular"
		var fator: float = ([0.65, 0.85, 1.0] if movel else [0.85, 1.0, 1.0])[q]
		vp.scaling_3d_scale = GameSettings.render_scale * fator
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_LOW if alta else RenderingServer.SHADOW_QUALITY_HARD)


# ------------------------------------------------------------ construção

func _build_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.085, 0.115, 0.17)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.5, 0.58, 0.74)
	_env.ambient_light_energy = 1.0
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_exposure = 1.4
	_env.tonemap_white = 6.0
	_env.glow_enabled = true
	_env.glow_intensity = 0.85
	_env.glow_strength = 1.0
	_env.glow_bloom = 0.04
	_env.glow_hdr_threshold = 0.9
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.17, 0.21, 0.3)
	_env.fog_density = 0.012
	_env.fog_sky_affect = 0.0
	_env.volumetric_fog_density = 0.025
	_env.volumetric_fog_albedo = Color(0.6, 0.7, 0.9)
	_env.volumetric_fog_length = 40.0
	_env.volumetric_fog_ambient_inject = 0.2
	_env.ssao_radius = 1.2
	_env.ssao_intensity = 1.6
	_env.ssr_max_steps = 48
	_env.ssr_fade_in = 0.15
	_env.ssr_fade_out = 2.0
	_env.adjustment_enabled = true
	_env.adjustment_contrast = 1.08
	_env.adjustment_saturation = 1.12
	_world_env = WorldEnvironment.new()
	_world_env.environment = _env
	add_child(_world_env)


func _build_lights() -> void:
	_key_light = DirectionalLight3D.new()
	_key_light.rotation_degrees = Vector3(-52, -18, 0)
	_key_light.light_color = Color(0.75, 0.82, 1.0)
	_key_light.light_energy = 1.2
	_key_light.shadow_blur = 1.5
	add_child(_key_light)

	_spot(Vector3(-4.5, 7.0, 3.5), Vector3(-1.8, 0.8, 0), C_PLAYER, 9.0, 32.0)
	_spot(Vector3(4.5, 7.0, 3.5), Vector3(1.8, 0.8, 0), C_ENEMY, 9.0, 32.0)
	_spot(Vector3(-2.5, 4.5, -4.0), Vector3(-1.5, 1.4, 0), Color(0.6, 0.85, 1.0), 7.0, 30.0)
	_spot(Vector3(2.5, 4.5, -4.0), Vector3(1.5, 1.4, 0), Color(1.0, 0.7, 0.75), 7.0, 30.0)
	_spot(Vector3(0, 9.0, 0.5), Vector3(0, 0, 0), Color(0.85, 0.9, 1.0), 4.0, 40.0)

	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 2.6, 5.5)
	fill.light_color = Color(0.85, 0.9, 1.0)
	fill.light_energy = 1.5
	fill.omni_range = 14.0
	add_child(fill)

	var back_fill := OmniLight3D.new()
	back_fill.position = Vector3(0, 5.0, -4.5)
	back_fill.light_color = Color(0.7, 0.78, 1.0)
	back_fill.light_energy = 1.4
	back_fill.omni_range = 14.0
	add_child(back_fill)

	_probe = ReflectionProbe.new()
	_probe.size = Vector3(26, 12, 16)
	_probe.position = Vector3(0, 3, 0)
	_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	_probe.box_projection = true
	_probe.interior = true
	_probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	add_child(_probe)


func _spot(pos: Vector3, look: Vector3, color: Color, energy: float, angle: float) -> void:
	var s := SpotLight3D.new()
	s.position = pos
	s.light_color = color
	s.light_energy = energy
	s.spot_range = 18.0
	s.spot_angle = angle
	s.spot_angle_attenuation = 0.9
	s.light_volumetric_fog_energy = 1.4
	add_child(s)
	s.look_at_from_position(pos, look, Vector3.UP)
	_spots.append(s)


func _mat(color: Color, metallic: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = rough
	return m


func _neon(color: Color, energy: float = 3.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	_neon_mats.append(m)
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	(parent if parent else self).add_child(mi)
	return mi


func _build_structure() -> void:
	# Piso
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 34)
	floor_mi.mesh = plane
	_floor_mat = ShaderMaterial.new()
	_floor_mat.shader = load("res://assets/shaders/arena_floor.gdshader")
	floor_mi.material_override = _floor_mat
	add_child(floor_mi)

	var wall := _mat(Color(0.24, 0.27, 0.33), 0.7, 0.45)
	var trim := _mat(Color(0.28, 0.31, 0.37), 0.9, 0.3)
	var dark := _mat(Color(0.14, 0.16, 0.19), 0.6, 0.6)

	# Parede de fundo em painéis, com faixas neon (azul à esquerda, vermelho à direita)
	for i in range(-6, 7):
		var x := i * 2.6
		var h: float = 7.0 + (absi(i) % 3) * 0.8
		_box(Vector3(2.4, h, 0.5), Vector3(x, h * 0.5, -8.0), wall)
		_box(Vector3(2.0, 0.12, 0.2), Vector3(x, 1.0, -7.7), trim)
		_box(Vector3(2.0, 0.08, 0.2), Vector3(x, 5.2, -7.7), trim)
		var c := C_PLAYER if x < 0 else C_ENEMY
		if i != 0:
			_box(Vector3(0.07, h - 1.2, 0.08), Vector3(x + 1.25, h * 0.5, -7.72), _neon(c, 2.5 if absi(i) % 2 == 0 else 1.2))
		_box(Vector3(1.6, 0.05, 0.05), Vector3(x, 3.2 + (i % 2) * 0.5, -7.72), _neon(c, 1.6))

	# Emblema central da arena
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.5
	tm.outer_radius = 1.62
	tm.rings = 64
	tm.ring_segments = 12
	ring.mesh = tm
	ring.material_override = _neon(Color(0.75, 0.82, 1.0), 3.0)
	ring.rotation.x = PI / 2
	ring.position = Vector3(0, 4.4, -7.65)
	add_child(ring)
	var ring2 := MeshInstance3D.new()
	var tm2 := TorusMesh.new()
	tm2.inner_radius = 1.12
	tm2.outer_radius = 1.17
	tm2.rings = 6
	tm2.ring_segments = 4
	ring2.mesh = tm2
	ring2.material_override = _neon(Color(0.5, 0.6, 1.0), 2.0)
	ring2.rotation.x = PI / 2
	ring2.position = Vector3(0, 4.4, -7.64)
	add_child(ring2)
	var title := Label3D.new()
	title.text = "LOGICBOT"
	title.font = LBUITheme.title_font()
	title.font_size = 120
	title.pixel_size = 0.006
	title.modulate = Color(0.85, 0.92, 1.0)
	title.outline_size = 0
	title.position = Vector3(0, 4.4, -7.6)
	title.shaded = false
	add_child(title)
	var sub := Label3D.new()
	sub.text = "ARENA 01  ·  SETOR INDUSTRIAL"
	sub.font = LBUITheme.font(LBUITheme.FONT_UI_BOLD)
	sub.font_size = 64
	sub.pixel_size = 0.005
	sub.modulate = Color(0.5, 0.6, 0.8)
	sub.position = Vector3(0, 3.55, -7.6)
	add_child(sub)

	# Pilares laterais com anéis de luz
	for sx in [-1, 1]:
		for z in [-4.5, 1.5]:
			var px: float = sx * 9.5
			var pil := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.45
			cm.bottom_radius = 0.55
			cm.height = 10.0
			pil.mesh = cm
			pil.material_override = trim
			pil.position = Vector3(px, 5.0, z)
			add_child(pil)
			for y in [1.2, 4.0, 7.0]:
				var r := MeshInstance3D.new()
				var rm := TorusMesh.new()
				rm.inner_radius = 0.5
				rm.outer_radius = 0.58
				r.mesh = rm
				r.material_override = _neon(C_PLAYER if sx < 0 else C_ENEMY, 2.0)
				r.position = Vector3(px, y, z)
				add_child(r)

	# Treliça no teto
	for z in [-5.0, -1.5, 2.0]:
		_box(Vector3(26, 0.35, 0.35), Vector3(0, 9.2, z), dark)
		_box(Vector3(26, 0.06, 0.06), Vector3(0, 8.95, z + 0.2), _neon(Color(0.6, 0.7, 1.0), 1.2))
	for x in range(-12, 13, 3):
		_box(Vector3(0.25, 0.25, 7.5), Vector3(x, 9.4, -1.5), dark)

	# Plataformas e grades nas laterais
	for sx in [-1, 1]:
		_box(Vector3(4.0, 0.6, 9.0), Vector3(sx * 11.0, 0.3, -2.0), wall)
		_box(Vector3(4.0, 0.06, 0.06), Vector3(sx * 11.0, 0.62, 2.4), _neon(C_PLAYER if sx < 0 else C_ENEMY, 2.0))
		_box(Vector3(0.08, 1.1, 9.0), Vector3(sx * 9.1, 1.15, -2.0), trim)

	# Telas holográficas inclinadas no fundo
	for sx in [-1, 1]:
		var screen := _box(Vector3(3.2, 1.8, 0.05), Vector3(sx * 6.2, 5.8, -7.2), _neon(Color(0.15, 0.3, 0.55) if sx < 0 else Color(0.45, 0.12, 0.18), 1.4))
		screen.rotation.y = -sx * 0.25
		var frame := _box(Vector3(3.4, 2.0, 0.04), Vector3(sx * 6.2, 5.8, -7.24), trim)
		frame.rotation.y = -sx * 0.25


## 2.0: ringue de boxe — tablado, quatro corners com protetores e três cordas.
func _build_ring() -> void:
	var lado := RING_MEIO * 2.0
	var lona := _mat(Color(0.05, 0.065, 0.11), 0.0, 0.92)
	var saia := _mat(Color(0.07, 0.08, 0.11), 0.3, 0.6)
	_box(Vector3(lado + 0.6, RING_Y - 0.04, lado + 0.6), Vector3(0, (RING_Y - 0.04) * 0.5, 0), saia)
	_box(Vector3(lado + 0.5, 0.04, lado + 0.5), Vector3(0, RING_Y - 0.02, 0), lona)
	# faixas de luz na borda do tablado (azul do seu lado, vermelho do lado do inimigo)
	for sx in [-1, 1]:
		_box(Vector3(lado * 0.5 + 0.3, 0.05, 0.05), Vector3(sx * (lado * 0.25 + 0.15), RING_Y - 0.12, RING_MEIO + 0.32), _neon(C_PLAYER if sx < 0 else C_ENEMY, 2.2))
		_box(Vector3(0.05, 0.05, lado + 0.6), Vector3(sx * (RING_MEIO + 0.32), RING_Y - 0.12, 0), _neon(C_PLAYER if sx < 0 else C_ENEMY, 2.2))
	# logotipo pintado na lona
	var logo := Label3D.new()
	logo.text = "LOGICBOT"
	logo.font = LBUITheme.title_font()
	logo.font_size = 200
	logo.pixel_size = 0.012
	logo.modulate = Color(0.55, 0.65, 0.95, 0.16)
	logo.outline_size = 0
	logo.shaded = false
	logo.double_sided = false
	logo.rotation.x = -PI / 2
	logo.position = Vector3(0, RING_Y + 0.005, 0)
	add_child(logo)
	var anel := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 2.4
	tm.outer_radius = 2.48
	tm.rings = 64
	tm.ring_segments = 4
	anel.mesh = tm
	anel.material_override = _neon(Color(0.45, 0.55, 0.95), 0.22)
	anel.scale = Vector3(1, 0.05, 1)
	anel.position = Vector3(0, RING_Y + 0.004, 0)
	add_child(anel)
	# postes
	var metal := _mat(Color(0.62, 0.66, 0.72), 0.95, 0.25)
	var alturas := [0.45, 0.9, 1.35]
	for cx in [-1, 1]:
		for cz in [-1, 1]:
			var poste := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.09
			cm.bottom_radius = 0.11
			cm.height = 1.65
			poste.mesh = cm
			poste.material_override = metal
			poste.position = Vector3(cx * RING_MEIO, RING_Y + 0.82, cz * RING_MEIO)
			add_child(poste)
			var cor_pad: Color = C_PLAYER if cx < 0 and cz < 0 else (C_ENEMY if cx > 0 and cz < 0 else Color(0.85, 0.88, 0.95))
			var pad := _box(Vector3(0.28, 1.1, 0.28), Vector3(cx * (RING_MEIO - 0.05), RING_Y + 0.9, cz * (RING_MEIO - 0.05)), _mat(cor_pad.darkened(0.25), 0.1, 0.55))
			pad.rotation.y = PI / 4
	# cordas (as da frente somem quando a câmera fica do lado de fora, para não tapar a luta)
	var cores := [Color(0.92, 0.94, 1.0), Color(0.75, 0.12, 0.18), Color(0.12, 0.35, 0.85)]
	for i in alturas.size():
		var cm := _mat(cores[i], 0.2, 0.4)
		cm.emission_enabled = true
		cm.emission = cores[i]
		cm.emission_energy_multiplier = 0.25
		for lado_i in 4:
			var corda := MeshInstance3D.new()
			var cy := CylinderMesh.new()
			cy.top_radius = 0.035
			cy.bottom_radius = 0.035
			cy.height = lado
			cy.radial_segments = 8
			corda.mesh = cy
			corda.material_override = cm
			var y: float = RING_Y + alturas[i]
			match lado_i:
				0: corda.position = Vector3(0, y, -RING_MEIO); corda.rotation.z = PI / 2
				1: corda.position = Vector3(0, y, RING_MEIO); corda.rotation.z = PI / 2; _cordas_frente.append(corda)
				2: corda.position = Vector3(-RING_MEIO, y, 0); corda.rotation.x = PI / 2
				3: corda.position = Vector3(RING_MEIO, y, 0); corda.rotation.x = PI / 2
			add_child(corda)


func _build_dust() -> void:
	_dust = GPUParticles3D.new()
	_dust.amount = 160
	_dust.lifetime = 9.0
	_dust.preprocess = 9.0
	_dust.visibility_aabb = AABB(Vector3(-16, -1, -10), Vector3(32, 12, 20))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(14, 4, 7)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.25
	pm.gravity = Vector3(0, 0.02, 0)
	pm.scale_min = 0.4
	pm.scale_max = 1.2
	_dust.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.025)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(0.6, 0.8, 1.0, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	q.material = m
	_dust.draw_pass_1 = q
	_dust.position = Vector3(0, 4, -2)
	add_child(_dust)


# ------------------------------------------------------------ atualização

## Chamado a cada quadro pela tela de batalha.
func sync_with_sim(sim: LBCombatSim, delta: float) -> void:
	var fin := sim.terminou
	player_visual.oponente_x = sim.lutadores[1].x
	enemy_visual.oponente_x = sim.lutadores[0].x
	_afastar(sim.distancia())
	player_visual.update_from_fighter(sim.lutadores[0], delta, fin, sim.vencedor == 0)
	enemy_visual.update_from_fighter(sim.lutadores[1], delta, fin, sim.vencedor == 1)
	_focus_winner = sim.vencedor if fin and sim.vencedor < 2 else -1


## Distância mínima VISUAL entre os robôs (a simulação deixa chegar a 0,9 m).
const DIST_VISUAL_MIN := 1.9


func _afastar(d: float) -> void:
	var extra := maxf(0.0, DIST_VISUAL_MIN - d) * 0.5
	player_visual.afastar = extra
	enemy_visual.afastar = extra


func _process(delta: float) -> void:
	_time += delta
	if showcase:
		_update_showcase(delta)
		return
	_update_camera(delta)


## Em telas estreitas (celular em pé) a câmera fixa a LARGURA visível,
## para os dois robôs continuarem enquadrados.
func _fit_camera_aspect(fov_largo: float = 38.0) -> void:
	var r := get_viewport().get_visible_rect().size
	var estreita := r.y > 0.0 and r.x / r.y < 1.25
	camera.keep_aspect = Camera3D.KEEP_WIDTH if estreita else Camera3D.KEEP_HEIGHT
	camera.fov = minf(fov_largo * 1.65, 75.0) if estreita else fov_largo


## Estilo da câmera (Configurações). Na "Dinâmica", troca sozinha a cada 4 s.
func _estilo_camera(delta: float) -> int:
	var e: int = GameSettings.camera_style
	if e != GameSettings.Camera.DINAMICA:
		return e
	_dyn_t += delta
	if _dyn_t > 4.0:
		_dyn_t = 0.0
		_dyn_i += 1
	return [GameSettings.Camera.REAL_STEEL, GameSettings.Camera.LATERAL, 10, GameSettings.Camera.TV][_dyn_i % 4]


func _update_camera(delta: float) -> void:
	var a := player_visual.position.x
	var b := enemy_visual.position.x
	var mid := (a + b) * 0.5
	var dist := absf(b - a)
	var y0 := RING_Y
	var estilo := _estilo_camera(delta)
	var want_pos: Vector3
	var want_target: Vector3
	var fov := 38.0
	match estilo:
		GameSettings.Camera.REAL_STEEL:
			# por cima do ombro do SEU robô, perto e baixo, olhando para o inimigo
			want_pos = Vector3(a - 1.7 - dist * 0.2, y0 + 2.1, 3.3 + dist * 0.45)
			want_target = Vector3(lerpf(mid, b, 0.25), y0 + 1.35, 0)
			fov = 52.0
		10:  # (só na Dinâmica) contraplano: por trás do inimigo
			want_pos = Vector3(b + 1.7 + dist * 0.2, y0 + 2.1, 3.3 + dist * 0.45)
			want_target = Vector3(lerpf(mid, a, 0.25), y0 + 1.35, 0)
			fov = 52.0
		GameSettings.Camera.TV:
			want_pos = Vector3(mid, y0 + 4.6, 10.5 + dist * 0.35)
			want_target = Vector3(mid, y0 + 0.9, 0)
			fov = 36.0
		_:
			var d := clampf(6.2 + dist * 0.75, 7.0, 11.0)
			want_pos = Vector3(mid, y0 + 1.75, d)
			want_target = Vector3(mid, y0 + 1.35, 0)
	if _focus_winner >= 0:
		var v := player_visual if _focus_winner == 0 else enemy_visual
		var lado := -1.0 if _focus_winner == 0 else 1.0
		want_target = Vector3(v.position.x, y0 + 1.45, 0)
		want_pos = Vector3(v.position.x + lado * 1.6, y0 + 1.9, 4.6)
		fov = 45.0
	# câmeras "dentro do ringue" não podem passar das cordas (perto do corner, a corda taparia tudo)
	if estilo in [GameSettings.Camera.REAL_STEEL, 10] or _focus_winner >= 0:
		var lim := RING_MEIO - 0.5
		want_pos.x = clampf(want_pos.x, -lim, lim)
		want_pos.z = minf(want_pos.z, RING_MEIO - 0.4) if absf(want_pos.x) >= lim - 0.01 else want_pos.z
	_fit_camera_aspect(fov)
	var corte := estilo != _cam_estilo
	_cam_estilo = estilo
	var w := 1.0 if corte else 1.0 - exp(-3.5 * delta)
	_cam_target = _cam_target.lerp(want_target, w)
	_cam_pos = _cam_pos.lerp(want_pos, w)
	_shake = move_toward(_shake, 0.0, delta * 1.8)
	var jitter := Vector3(sin(_time * 63.0), cos(_time * 57.0), 0) * _shake * 0.12
	camera.position = _cam_pos + jitter
	camera.look_at(_cam_target + jitter * 0.5, Vector3.UP)
	# cordas da frente atrapalham a visão quando a câmera está fora do ringue
	var fora := camera.position.z > RING_MEIO - 0.3
	for c in _cordas_frente:
		c.visible = not fora


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Transforma eventos da simulação em efeitos visuais.
func handle_events(events: Array, sim: LBCombatSim) -> void:
	for e in events:
		match e.tipo:
			"acerto", "bloqueio", "esquiva", "errou":
				_on_strike(e, sim)
			"inicio_acao":
				if e.acao == "golpe_especial":
					Sfx.play("carga", 0.02, -4.0)
				else:
					_som_motor(String(e.acao))
			"sem_energia":
				Sfx.play("sem_energia")
				var v := _visual(e.lutador)
				effects.sparks(v.chest_position(), Color(0.6, 0.6, 0.6), 10)
				effects.damage_number(v.head_position() + Vector3(0, 0.4, 0), 0, Color("ffc94a"), "SEM ENERGIA")
			"erro_programa":
				var v := _visual(e.lutador)
				effects.damage_number(v.head_position() + Vector3(0, 0.55, 0), 0, Color("ffc94a"), "ERRO NO PROGRAMA")
			"cortou":
				var v := _visual(e.alvo)
				effects.damage_number(v.head_position() + Vector3(0, 0.45, 0), 0, Color("fde047"), "CORTOU!")
				effects.shockwave(v.head_position(), Color("fde047"), 0.6)
			"nocaute_folego":
				var v := _visual(e.alvo)
				effects.damage_number(v.head_position() + Vector3(0, 0.6, 0), 0, Color("5eead4"), "SEM FÔLEGO!")
			"fim_luta":
				shake(0.6)
				Sfx.play("sino", 0.0, -2.0)
				if e.motivo == "nocaute":
					Sfx.play("nocaute", 0.0)
					hitstop = 0.35


## 2.0: motores do robô — cada movimento tem um zumbido de servo bem baixinho.
func _som_motor(acao: String) -> void:
	if acao in LBCombatRules.ACOES_DE_ATAQUE:
		Sfx.play("servo_soco", 0.12, -14.0)
	elif acao.begins_with("bloqueio") or acao == "defender":
		Sfx.play("servo_guarda", 0.1, -15.0)
	elif acao in ["avancar", "recuar", "passo_lado"]:
		Sfx.play("passo_robo", 0.15, -16.0)
	elif acao in ["esquivar_esquerda", "esquivar_direita", "abaixar", "recuar_tronco", "esquivar"]:
		Sfx.play("giro_tronco", 0.1, -14.0)


func _visual(i: int) -> LBRoboMixamo:
	return player_visual if i == 0 else enemy_visual


func _on_strike(e: Dictionary, _sim: LBCombatSim) -> void:
	var att := _visual(e.atacante)
	var tgt := _visual(e.alvo)
	var color := C_PLAYER if e.atacante == 0 else C_ENEMY
	var special: bool = e.acao == "golpe_especial"
	var dir := float(att.facing)
	var d: Dictionary = LBCombatRules.ACOES.get(e.acao, {})
	var no_corpo: bool = d.get("altura", "") == "baixo"
	# ponto do contato: cabeça ou corpo do alvo, um pouco virado para quem bateu
	var alvo_pos := tgt.chest_position() if no_corpo else tgt.head_position() - Vector3(0, 0.12, 0)
	var contact := alvo_pos - Vector3(dir * 0.28, 0, 0)
	var forte: bool = int(e.get("dano", 0)) >= LBCombatRules.GOLPE_PESADO
	var delay := 0.0
	if special:
		var from := att.chest_position() + Vector3(dir * 0.6, 0.0, 0.25)
		var to := contact if e.tipo != "errou" else from + Vector3(dir * 2.6, 0, 0)
		effects.muzzle(from, color)
		Sfx.play("disparo", 0.04)
		delay = 0.12
		effects.plasma_bolt(from, to, color, delay)
	var apply := func():
		match e.tipo:
			"acerto":
				Sfx.play("soco_forte" if special or forte else "soco")
				Sfx.play("metal_forte" if special or forte else "metal", 0.08, -6.0)
				tgt.levar_golpe(e.acao, int(e.dano))
				effects.sparks(contact, Color(1.0, 0.75, 0.35) if not special else color, 70 if special or forte else 32, dir)
				if special or forte:
					effects.shockwave(contact, Color(1.0, 0.9, 0.7) if not special else color, 1.3 if special else 0.9)
					effects.metal_chips(contact, dir, 12 if special else 8)
					hitstop = maxf(hitstop, 0.09 if special else 0.06)
				effects.damage_number(contact + Vector3(0, 0.22, 0.3), e.dano, Color.WHITE if not special else color.lightened(0.4))
				shake(0.55 if special else (0.35 if forte else 0.18))
			"bloqueio":
				Sfx.play("bloqueio")
				effects.block_flash(tgt.chest_position() + Vector3(-dir * 0.3, 0.15, 0.0), C_PLAYER if e.alvo == 0 else C_ENEMY)
				effects.sparks(contact, Color(0.75, 0.85, 1.0), 12, dir)
				effects.damage_number(contact + Vector3(0, 0.25, 0.3), e.dano, Color(0.75, 0.8, 0.9), "BLOQUEIO -%d" % e.dano)
				shake(0.12)
			"esquiva":
				Sfx.play("vento", 0.1, -4.0)
				effects.damage_number(tgt.head_position() + Vector3(0, 0.45, 0), 0, Color("a5f3fc"), "ESQUIVA")
			"errou":
				Sfx.play("vento", 0.12, -9.0)
				effects.damage_number(att.head_position() + Vector3(dir * 0.8, 0.2, 0), 0, Color(0.6, 0.65, 0.75), "no vazio")
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(apply)
	else:
		apply.call()


# ------------------------------------------------------------ vitrine (menu)

const _DEMO := [
	[0, "avancar"], [1, "bloqueio_alto"], [0, "jab"], [1, "direto"], [0, "esquivar_esquerda"],
	[1, "cruzado_frente"], [0, "abaixar"], [0, "uppercut_frente"], [1, "recuar_tronco"], [0, "gancho_figado"],
	[1, "bloqueio_baixo"], [0, "recuar"], [1, "recuar"],
]


func _update_showcase(delta: float) -> void:
	_fit_camera_aspect()
	for c in _cordas_frente:
		c.visible = false
	var ang := sin(_time * 0.12) * 0.45
	var r := 7.4
	enemy_visual.visible = not foco_garagem   # na garagem, só o seu robô
	if foco_garagem:
		# garagem: o seu robô de frente; no celular em pé ele fica na parte de cima da tela
		var px := player_visual.position.x
		var alto := LBDevice.compact()
		var alvo := Vector3(px, RING_Y + (-0.6 if alto else 1.3), 0)
		var pos := Vector3(px + 1.2 + sin(_time * 0.3) * 0.3, RING_Y + (1.9 if alto else 1.7), 4.6 if alto else 4.0)
		camera.position = camera.position.lerp(pos, clampf(delta * 3.0, 0.0, 1.0))
		camera.look_at(alvo, Vector3.UP)
		if alto:
			camera.fov = 48.0   # em pé, a câmera fixa a largura: um ângulo menor deixa o robô grande
	else:
		camera.position = Vector3(sin(ang) * r, RING_Y + 1.85 + sin(_time * 0.2) * 0.15, cos(ang) * r)
		camera.look_at(Vector3(0.9, RING_Y + 1.35, 0), Vector3.UP)
	for f in _demo_fighters:
		if f.acao != "":
			f.acao_t += delta
			var d := f.def()
			if d.has("speed"):
				var lim := [-1.9, -0.6] if f.lado > 0 else [0.6, 1.9]
				f.x = clampf(f.x + float(d.speed) * f.lado * delta * 0.4, lim[0], lim[1])
			if f.acao_t >= f.acao_dur:
				f.acao = ""
	_demo_wait -= delta
	if _demo_wait <= 0.0:
		var step: Array = _DEMO[_demo_step % _DEMO.size()]
		var f: LBFighter = _demo_fighters[step[0]]
		f.acao = step[1]
		f.acao_t = 0.0
		f.acao_dur = LBCombatRules.ACOES[step[1]].dur
		_demo_step += 1
		_demo_wait = 1.1
	player_visual.oponente_x = _demo_fighters[1].x
	enemy_visual.oponente_x = _demo_fighters[0].x
	player_visual.update_from_fighter(_demo_fighters[0], delta, false, false)
	enemy_visual.update_from_fighter(_demo_fighters[1], delta, false, false)



## Troca o robô inimigo (cor do bot e tipo de corpo) — usado quando muda o adversário.
func set_enemy_look(look: Dictionary) -> void:
	if look == enemy_look and enemy_visual != null:
		return
	enemy_look = look
	var old := enemy_visual
	enemy_visual = LBRoboMixamo.new()
	enemy_visual.name = "RoboInimigo"
	enemy_visual.labels_enabled = old.labels_enabled
	add_child(enemy_visual)
	enemy_visual.build(true, look)
	enemy_visual.base_y = RING_Y
	old.queue_free()
	apply_quality()


## Reconstrói o robô do jogador com outra aparência (usado na Garagem do menu).
func rebuild_player(look: Dictionary) -> void:
	player_look = look
	var old := player_visual
	player_visual = LBRoboMixamo.new()
	player_visual.name = "RoboJogador"
	player_visual.labels_enabled = old.labels_enabled
	add_child(player_visual)
	player_visual.build(false, look)
	player_visual.base_y = RING_Y
	old.queue_free()
	apply_quality()
