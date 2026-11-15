class_name LBRoboMixamo
extends Node3D
## Robô 3D 2.0: modelo gerado no TRELLIS, esqueleto e animações do Mixamo.
##
## Só APRESENTAÇÃO: lê o estado do lutador (LBFighter) a cada quadro e escolhe a
## animação. Os golpes são "esticados" para o soco encostar exatamente no
## instante em que a simulação resolve o acerto (hit_at) — o que se vê é o que conta.
##
## Arquivos (gerados por uma ferramenta a partir dos .fbx do Mixamo):
##   assets/robo/robo.scn        malha + esqueleto (33 ossos)
##   assets/robo/animacoes.res   biblioteca com ~45 animações já tratadas
##   assets/robo/animacoes.json  instante do impacto e mão de cada golpe

const R = preload("res://scripts/combat/lb_combat_rules.gd")
const ALTURA := 2.3          ## altura do robô em metros (o modelo do Mixamo vem com 1,8 cm)
const MISTURA := 0.09        ## tempo de transição entre animações (s)

## ação da simulação -> [animação, janela início, janela fim] (janela em segundos do clipe; -1 = até o fim)
const MAPA := {
	"jab": ["jab"], "direto": ["direto"], "atacar": ["direto"],
	"cruzado_frente": ["cruzado_frente"], "cruzado_tras": ["cruzado_tras"], "overhand": ["cruzado_tras"],
	"uppercut_frente": ["uppercut_frente"], "uppercut_tras": ["uppercut_tras"],
	"jab_corpo": ["jab_corpo"], "direto_corpo": ["direto_corpo"], "gancho_figado": ["gancho_figado"],
	"golpe_especial": ["especial"],
	"bloqueio_alto": ["bloqueio_alto", 0.0, 0.85], "defender": ["bloqueio_alto", 0.0, 0.85],
	"bloqueio_baixo": ["bloqueio_baixo", 0.0, 0.8],
	"esquivar_direita": ["esquiva_direita", 0.0, 0.9], "esquivar": ["esquiva_direita", 0.0, 0.9],
	"esquivar_esquerda": ["esquiva_esquerda", 0.0, 0.9],
	"abaixar": ["esquiva_frente", 0.2, 1.3], "pular": ["esquiva_frente", 0.2, 1.3],
	"recuar_tronco": ["esquiva_tras", 0.1, 1.2],
	"passo_lado": ["passo_direita", 0.0, -1],
	"avancar": ["passo_frente", 0.0, -1], "recuar": ["passo_tras", 0.0, -1],
	"falha": ["hit_corpo", 0.0, 0.8], "aguardar": ["guarda_parada", 0.0, -1],
}

static var _cena: PackedScene
static var _lib: AnimationLibrary
static var _meta: Dictionary = {}

var accent := Color("22d3ee")
var paint := Color("1e40af")
var is_enemy := false
var labels_enabled := true
var facing := 1
var armadura := "padrao"        ## mantido por compatibilidade com a Garagem (peças chegam na fase 4)
var danca := "danca_hiphop_3"   ## dança da vitória (Hip Hop 3 é a grátis)
var oponente_x := 0.0           ## a arena informa, para o soco "chegar" no outro robô
var base_y := 0.0               ## altura do chão (tablado do ringue)
var afastar := 0.0              ## colados, os robôs grandes se atravessariam: a arena os afasta um pouco

var modelo: Node3D
var sk: Skeleton3D
var malha: MeshInstance3D
var mat: StandardMaterial3D
var nucleo: OmniLight3D
var action_label: Label3D

var _trilhas := {}              ## animação -> Array de [osso, tipo, índice]
var _rest_rot: Array[Quaternion] = []
var _hips := -1
var _hips_rest := Vector3.ZERO
var _out_rot: Array[Quaternion] = []
var _out_hips := Vector3.ZERO
var _de_rot: Array[Quaternion] = []
var _de_hips := Vector3.ZERO
var _mistura := 1.0
var _clip := ""
var _chave := ""                ## identifica a "instância" da animação (troca = nova mistura)
var _time := 0.0
var _acao_anterior := ""
var _reacao := ""
var _reacao_t := 0.0
var _fim_t := 0.0
var _ko_body := false
var _hit_flash := 0.0
var _tranco := 0.0              ## golpe leve: a cabeça "balança" um pouco
var _avanco := 0.0
var _mao := "RightHand"


static func _carregar() -> void:
	if _cena != null:
		return
	_cena = load("res://assets/robo/robo.scn")
	_lib = load("res://assets/robo/animacoes.res")
	var f := FileAccess.open("res://assets/robo/animacoes.json", FileAccess.READ)
	if f:
		_meta = JSON.parse_string(f.get_as_text())


## Carrega o robô e as animações antes da primeira luta (chamado na tela de abertura).
static func preparar() -> void:
	_carregar()


static func animacoes() -> PackedStringArray:
	_carregar()
	return _lib.get_animation_list()


## Tipos de corpo (2.0: o mesmo esqueleto, silhuetas diferentes)
##   padrao · pesado (peito e ombros largos, mais alto) · leve (magro e mais baixo)
const CORPOS := {
	"padrao": {"altura": 2.3, "peito": 1.0},
	"pesado": {"altura": 2.45, "peito": 1.16},
	"leve": {"altura": 2.2, "peito": 0.9},
}
const CORPO_DOS_BOTS := {
	"SACO-01": "pesado", "TOURO": "pesado", "MURALHA": "pesado", "TORRE": "pesado", "BRUTUS": "pesado",
	"SERPENTE": "leve", "ESQUIVO": "leve", "VÓRTEX": "leve",
}

var corpo := "padrao"
var acabamento := "padrao"
var pecas := {}                 ## categoria -> id (LBShop) — só no robô do jogador
var _forcado := ""              ## vitrine da garagem: mostra uma animação (ex.: dança)
var _forcado_t := 0.0
var _altura := ALTURA


## Aparência do inimigo a partir do bot (cor do bot e tipo de corpo pelo estilo de luta).
static func look_do_bot(bot: Dictionary) -> Dictionary:
	var l := {"corpo": CORPO_DOS_BOTS.get(String(bot.get("nome", "")), "padrao")}
	if bot.has("cor"):
		var c := Color(String(bot.cor))
		# azul/ciano confundiria com o robô do jogador: esses bots lutam com pintura prateada
		l["pintura"] = Color("d1d5db") if c.h > 0.45 and c.h < 0.72 else c
	return l


## look: {"pintura": Color, "brilho": Color, "armadura": String, "danca": String, "corpo": String}
## (no inimigo, só "pintura" e "corpo" são usados)
func build(enemy: bool, look: Dictionary = {}) -> void:
	_carregar()
	is_enemy = enemy
	facing = -1 if enemy else 1
	accent = Color("ff3b4e") if enemy else Color("22d3ee")
	paint = Color("b91c1c") if enemy else Color("2563eb")
	if not enemy and not look.is_empty():
		paint = look.get("pintura", paint)
		accent = look.get("brilho", accent)
		armadura = look.get("armadura", "padrao")
		danca = look.get("danca", danca)
	if enemy and look.has("pintura"):
		paint = look.pintura
	corpo = String(look.get("corpo", "padrao"))
	if not CORPOS.has(corpo):
		corpo = "padrao"
	var cfg: Dictionary = CORPOS[corpo]
	_altura = float(cfg.altura)

	modelo = _cena.instantiate()
	add_child(modelo)
	sk = modelo.find_children("*", "Skeleton3D", true, false)[0]
	malha = modelo.find_children("*", "MeshInstance3D", true, false)[0]
	var aabb := malha.get_aabb()
	modelo.scale = Vector3.ONE * (float(cfg.altura) / maxf(aabb.size.y, 0.0001))
	modelo.rotation.y = PI * 0.5 * facing

	mat = (malha.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
	# a textura é cinza (placas claras, juntas escuras): a pintura tinge só as placas
	var tinta := Color.WHITE.lerp(paint.lightened(0.1), 0.62)
	mat.albedo_color = Color(tinta.r * 0.82, tinta.g * 0.82, tinta.b * 0.82)
	mat.metallic = 0.6
	mat.roughness = 0.38
	acabamento = String(look.get("acabamento", "padrao")) if not enemy else "padrao"
	match acabamento:
		"fosco":
			mat.metallic = 0.15
			mat.roughness = 0.85
		"cromado":
			mat.metallic = 0.9
			mat.roughness = 0.18
			mat.albedo_color = mat.albedo_color.lightened(0.45)
		"carbono":
			mat.albedo_color = mat.albedo_color.darkened(0.62)
			mat.metallic = 0.5
			mat.roughness = 0.3
	mat.emission_enabled = true
	mat.emission = accent
	mat.emission_energy_multiplier = 0.0
	malha.material_override = mat

	nucleo = OmniLight3D.new()
	nucleo.light_color = accent
	nucleo.light_energy = 0.7
	nucleo.omni_range = 2.2
	nucleo.position = Vector3(0, float(cfg.altura) * 0.62, 0.0)
	add_child(nucleo)

	for b in sk.get_bone_count():
		_rest_rot.append(sk.get_bone_rest(b).basis.get_rotation_quaternion())
	_hips = sk.find_bone("mixamorig_Hips")
	_hips_rest = sk.get_bone_rest(_hips).origin
	_out_rot = _rest_rot.duplicate()
	_out_hips = _hips_rest
	# silhueta: peito/ombros maiores (ou menores) sem mudar o tamanho da cabeça
	var peito := float(cfg.peito)
	if peito != 1.0:
		sk.set_bone_pose_scale(sk.find_bone("mixamorig_Spine2"), Vector3.ONE * peito)
		sk.set_bone_pose_scale(sk.find_bone("mixamorig_Neck"), Vector3.ONE / peito)

	action_label = Label3D.new()
	action_label.font = LBUITheme.font(LBUITheme.FONT_CODE, 700)
	action_label.font_size = 44
	action_label.pixel_size = 0.004
	action_label.outline_size = 10
	action_label.outline_modulate = Color(0, 0, 0, 0.85)
	action_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	action_label.no_depth_test = true
	action_label.render_priority = 10
	# alturas diferentes para os rótulos não se sobreporem quando os robôs estão colados
	action_label.position = Vector3(0, float(cfg.altura) + (0.12 if enemy else 0.42), 0)
	add_child(action_label)
	if not enemy:
		pecas = look.get("pecas", {})
		_montar_pecas()
	_tocar("guarda", "inicio")


func _faixas(nome: String) -> Array:
	if _trilhas.has(nome):
		return _trilhas[nome]
	var a := _lib.get_animation(nome)
	var lista := []
	for i in a.get_track_count():
		var osso := sk.find_bone(String(a.track_get_path(i)).get_slice(":", 1))
		if osso >= 0:
			lista.append([osso, a.track_get_type(i), i])
	_trilhas[nome] = lista
	return lista


## Troca a animação (com mistura curta). "chave" diferente = recomeça mesmo se for o mesmo clipe.
func _tocar(clip: String, chave: String) -> void:
	if chave == _chave:
		return
	_chave = chave
	_clip = clip
	_de_rot = _out_rot.duplicate()
	_de_hips = _out_hips
	_mistura = 0.0


func _amostrar(t: float) -> void:
	var a := _lib.get_animation(_clip)
	var alvo_rot := _rest_rot.duplicate()
	var alvo_hips := _hips_rest
	for tr in _faixas(_clip):
		if tr[1] == Animation.TYPE_ROTATION_3D:
			alvo_rot[tr[0]] = a.rotation_track_interpolate(tr[2], t)
		elif tr[1] == Animation.TYPE_POSITION_3D and tr[0] == _hips:
			alvo_hips = a.position_track_interpolate(tr[2], t)
	var w := clampf(_mistura, 0.0, 1.0)
	w = w * w * (3.0 - 2.0 * w)
	for b in alvo_rot.size():
		_out_rot[b] = _de_rot[b].slerp(alvo_rot[b], w) if w < 1.0 else alvo_rot[b]
	_out_hips = _de_hips.lerp(alvo_hips, w)


## Mapeia o tempo da ação (0..dur) para o tempo do clipe, alinhando o impacto.
func _tempo_golpe(clip: String, t: float, d: Dictionary, dur: float) -> float:
	var m: Dictionary = _meta.get(clip, {})
	var imp := float(m.get("impacto", 0.4))
	var fim := maxf(float(m.get("fim", imp + 0.3)), imp + 0.15)
	var hit := float(d.get("hit_at", dur * 0.45))
	if t <= hit:
		return imp * (t / maxf(hit, 0.001))
	return imp + (fim - imp) * clampf((t - hit) / maxf(dur - hit, 0.001), 0.0, 1.0)


func update_from_fighter(f: LBFighter, delta: float, finished: bool, won: bool) -> void:
	_time += delta
	position.x = f.x - facing * afastar
	position.y = base_y + f.altura_pulo()
	var t_clip := 0.0
	var avanco_alvo := 0.0

	if _forcado != "" and _forcado_t > 0.0:
		_forcado_t -= delta
		_tocar(_forcado, "forcado:" + _forcado)
		t_clip = fmod(_time - _forcado_ini, _lib.get_animation(_forcado).length)
		if _forcado_t <= 0.0:
			_forcado = ""
	elif f.nocauteado:
		_tocar("nocaute_figado" if _ko_body else "nocaute", "ko")
		_fim_t += delta
		t_clip = minf(_fim_t, _lib.get_animation(_clip).length - 0.02)
		mat.emission_energy_multiplier = lerpf(mat.emission_energy_multiplier, 0.0, delta * 2.0)
		nucleo.light_energy = lerpf(nucleo.light_energy, 0.0, delta * 2.0)
	elif finished:
		_fim_t += delta
		if won:
			var v_len := _lib.get_animation("vitoria").length
			if _fim_t < v_len - 0.3 or not _lib.has_animation(danca):
				_tocar("vitoria", "vitoria")
				t_clip = minf(_fim_t, v_len - 0.02)
			else:
				_tocar(danca, "danca")
				t_clip = _fim_t - (v_len - 0.3)
		else:
			_tocar("derrota", "derrota")
			t_clip = minf(_fim_t, _lib.get_animation("derrota").length - 0.02)
	elif f.atordoado > 0.0 and _reacao != "":
		_tocar(_reacao, "reacao%d" % int(_reacao_t * 1000))
		t_clip = 0.12 + (_time - _reacao_t) * 1.6
	elif f.acao != "" and MAPA.has(f.acao):
		var m: Array = MAPA[f.acao]
		var clip: String = m[0]
		var d := f.def()
		# cada ação nova (mesmo repetida) recomeça a animação
		if f.acao_t < _acao_anterior_t or f.acao != _acao_anterior:
			_n_acao += 1
		_tocar(clip, "%s#%d" % [f.acao, _n_acao])
		if d.has("hit_at") and m.size() == 1:
			t_clip = _tempo_golpe(clip, f.acao_t, d, f.acao_dur)
			_mao = String(_meta.get(clip, {}).get("mao", "RightHand"))
			# o soco "vai até" o outro robô: um passo à frente proporcional à distância
			var dist := absf(oponente_x - f.x)
			var p := f.acao_t / maxf(float(d.hit_at), 0.001)
			var sino := sin(clampf(p, 0.0, 1.0) * PI * 0.5) if p <= 1.0 else 1.0 - clampf((f.acao_t - float(d.hit_at)) / maxf(f.acao_dur - float(d.hit_at), 0.001), 0.0, 1.0)
			# alcance natural do soco no clipe (já com o passo que o Mixamo dá) vs. onde está o peito do outro
			var alcance := float(_meta.get(clip, {}).get("alcance", 0.8)) * _altura
			avanco_alvo = clampf(dist + afastar * 2.0 - 0.3 - alcance, -0.5, 0.7) * sino
		else:
			var a0: float = m[1]
			var a1: float = m[2] if m[2] >= 0.0 else _lib.get_animation(clip).length
			var p := f.acao_t / maxf(f.acao_dur, 0.001)
			if clip.begins_with("passo") or clip == "guarda_parada":
				t_clip = fmod(_time, a1 - a0) + a0 if clip == "guarda_parada" else a0 + p * (a1 - a0)
			else:
				t_clip = a0 + p * (a1 - a0)
	else:
		_tocar("guarda", "guarda")
		t_clip = fmod(_time, _lib.get_animation("guarda").length)
	_acao_anterior = f.acao
	_acao_anterior_t = f.acao_t

	_mistura += delta / MISTURA
	_amostrar(t_clip)
	_avanco = lerpf(_avanco, avanco_alvo, 1.0 - exp(-25.0 * delta))
	_aplicar(delta)

	if not f.nocauteado:
		_hit_flash = move_toward(_hit_flash, 0.0, delta * 4.0)
		mat.emission_energy_multiplier = _hit_flash * 0.45
		nucleo.light_energy = 0.7 + _hit_flash * 2.0
	_update_label(f, finished)


var _acao_anterior_t := 0.0
var _forcado_ini := 0.0


## Vitrine (garagem): toca uma animação por alguns segundos (ex.: a dança escolhida).
func mostrar(clip: String, segundos: float) -> void:
	if not _lib.has_animation(clip):
		return
	_forcado = clip
	_forcado_t = segundos
	_forcado_ini = _time
	_chave = ""
var _n_acao := 0


func _aplicar(delta: float) -> void:
	_tranco = move_toward(_tranco, 0.0, delta * 5.0)
	for b in _out_rot.size():
		sk.set_bone_pose_rotation(b, _out_rot[b])
	if _tranco > 0.0:
		var cab := sk.find_bone("mixamorig_Head")
		var esp := sk.find_bone("mixamorig_Spine2")
		var giro := Quaternion(Vector3.RIGHT, -0.45 * _tranco * sin(_tranco * PI))
		sk.set_bone_pose_rotation(cab, _out_rot[cab] * giro)
		sk.set_bone_pose_rotation(esp, _out_rot[esp] * Quaternion(Vector3.RIGHT, -0.15 * _tranco))
	sk.set_bone_pose_position(_hips, _out_hips)
	modelo.position.x = _avanco * facing


## A arena avisa quando este robô leva um golpe (escolhe a reação).
func levar_golpe(acao: String, dano: int) -> void:
	var d: Dictionary = R.ACOES.get(acao, {})
	var corpo: bool = d.get("altura", "") == "baixo"
	_ko_body = corpo
	if dano >= R.GOLPE_PESADO or acao == "golpe_especial" or not d.has("altura"):
		_reacao = "hit_forte" if dano >= 15 else ("hit_corpo" if corpo else "hit_cabeca")
		_reacao_t = _time
	else:
		_tranco = 1.0
	flash()


func flash() -> void:
	_hit_flash = 1.0


func _osso_global(nome: String) -> Vector3:
	var b := sk.find_bone("mixamorig_" + nome)
	if b < 0:
		return global_position + Vector3(0, _altura * 0.7, 0)
	return sk.global_transform * sk.get_bone_global_pose(b).origin


## Posição da mão que soca (para efeitos de impacto).
func fist_position() -> Vector3:
	return _osso_global(_mao)


func chest_position() -> Vector3:
	return _osso_global("Spine2")


func head_position() -> Vector3:
	return _osso_global("Head")


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


# ------------------------------------------------------------ peças da loja (2.0)

const _OSSO := "mixamorig_"


## Malha "facetada" (normais retas), no mesmo estilo low-poly das placas do robô.
static func _facetada(m: Mesh) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.create_from(m, 0)
	st.deindex()
	st.generate_normals(true)
	return st.commit()


func _mat_peca() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = mat.albedo_color.lightened(0.08)
	m.metallic = mat.metallic
	m.roughness = mat.roughness
	return m


func _mat_luz() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = accent
	m.emission_enabled = true
	m.emission = accent
	m.emission_energy_multiplier = 3.0
	return m


## Prende uma peça a um osso. pos/rot em METROS e graus, nos eixos do robô
## (x = esquerda do robô, y = cima, z = frente), medidos a partir do osso na pose T.
func _anexar(osso: String, peca: Node3D, pos: Vector3, rot_graus := Vector3.ZERO) -> void:
	var b := sk.find_bone(_OSSO + osso)
	if b < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = _OSSO + osso
	sk.add_child(att)
	var esc := 1.0 / modelo.scale.x
	var rest := sk.get_bone_global_rest(b)
	var base := Basis.from_euler(rot_graus * (PI / 180.0)).scaled(Vector3.ONE * esc)
	var desejado := Transform3D(base, rest.origin + pos * esc)
	peca.transform = rest.affine_inverse() * desejado
	att.add_child(peca)


func _malha(m: Mesh, material: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, esc := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _facetada(m)
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = esc
	return mi


func _esfera(r: float, seg := 6) -> SphereMesh:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = seg
	sm.rings = 3
	return sm


func _caixa(t: Vector3) -> BoxMesh:
	var bm := BoxMesh.new()
	bm.size = t
	return bm


func _cone(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 5
	c.rings = 1
	return c


func _montar_pecas() -> void:
	var m := _mat_peca()
	var luz := _mat_luz()
	for lado in ["Left", "Right"]:
		var sx := 1.0 if lado == "Left" else -1.0
		match String(pecas.get("ombreiras", "")):
			"ombro_titan":
				var p := Node3D.new()
				p.add_child(_malha(_esfera(0.17), m, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.65, 1.0)))
				_anexar(lado + "Arm", p, Vector3(sx * 0.05, 0.1, 0.0))
			"ombro_espinho":
				var p := Node3D.new()
				p.add_child(_malha(_esfera(0.16), m, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.6, 1.0)))
				for k in 3:
					p.add_child(_malha(_cone(0.04, 0.18), m, Vector3(sx * (-0.05 + k * 0.06), 0.13, -0.03 + k * 0.02), Vector3(0, 0, -sx * 20)))
				_anexar(lado + "Arm", p, Vector3(sx * 0.05, 0.1, 0.0))
			"ombro_escudo":
				var p := Node3D.new()
				p.add_child(_malha(_esfera(0.21), m, Vector3.ZERO, Vector3.ZERO, Vector3(1.15, 0.5, 1.1)))
				p.add_child(_malha(_caixa(Vector3(0.36, 0.05, 0.4)), m, Vector3(sx * 0.03, -0.03, 0), Vector3(0, 0, -sx * 15)))
				_anexar(lado + "Arm", p, Vector3(sx * 0.05, 0.1, 0.0))
		match String(pecas.get("luvas", "")):
			"luva_pesada":
				_anexar(lado + "Hand", _malha(_esfera(0.19, 6), m, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.85, 0.95)), Vector3(sx * 0.1, 0.0, 0.0))
			"luva_plasma":
				var lm := _mat_luz()
				lm.albedo_color = accent.darkened(0.3)
				lm.emission_energy_multiplier = 1.4
				_anexar(lado + "Hand", _malha(_esfera(0.19, 6), lm, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.85, 0.95)), Vector3(sx * 0.1, 0.0, 0.0))
	match String(pecas.get("capacete", "")):
		"cap_crista":
			_anexar("Head", _malha(_caixa(Vector3(0.05, 0.13, 0.34)), m, Vector3.ZERO, Vector3(-12, 0, 0)), Vector3(0, 0.12, -0.03))
		"cap_antenas":
			for sx in [-1.0, 1.0]:
				var p := Node3D.new()
				var c := CylinderMesh.new()
				c.top_radius = 0.012
				c.bottom_radius = 0.02
				c.height = 0.3
				c.radial_segments = 5
				p.add_child(_malha(c, m))
				p.add_child(_malha(_esfera(0.03), luz, Vector3(0, 0.16, 0)))
				_anexar("Head", p, Vector3(sx * 0.1, 0.32, -0.04), Vector3(-15, 0, sx * 12))
		"cap_chifres":
			for sx in [-1.0, 1.0]:
				_anexar("Head", _malha(_cone(0.05, 0.22), m), Vector3(sx * 0.14, 0.25, 0.04), Vector3(20, 0, sx * 45))
	match String(pecas.get("nucleo", "")):
		"nucleo_hex":
			var c := CylinderMesh.new()
			c.top_radius = 0.08
			c.bottom_radius = 0.08
			c.height = 0.04
			c.radial_segments = 6
			c.rings = 1
			_anexar("Spine2", _malha(c, luz, Vector3.ZERO, Vector3(90, 0, 0)), Vector3(0, 0.04, 0.17))
		"nucleo_reator":
			var p := Node3D.new()
			var t := TorusMesh.new()
			t.inner_radius = 0.07
			t.outer_radius = 0.1
			t.rings = 8
			t.ring_segments = 4
			p.add_child(_malha(t, m, Vector3.ZERO, Vector3(90, 0, 0)))
			p.add_child(_malha(_esfera(0.06), luz))
			_anexar("Spine2", p, Vector3(0, 0.04, 0.17))
