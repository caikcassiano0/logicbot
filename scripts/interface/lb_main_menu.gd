extends Control
## MENU PRINCIPAL — arena 3D ao fundo ("vitrine"), botões à esquerda e painéis
## de escolha de oponente e de configurações à direita.

var _arena: LBArena
var _side: Control
var _opponents: Control
var _settings: Control
var _campaign: Control
var _camp_list: VBoxContainer
var _diff_opt: OptionButton
var _diff_desc: Label
var _summary: Label
var _garage: Control
var _garage_box: VBoxContainer
var _q_opt: OptionButton
var _full_chk: CheckBox
var _vsync_chk: CheckBox
var _labels_chk: CheckBox
var _cam_opt: OptionButton
var _cen_opt: OptionButton
var _scale_slider: HSlider
var _scale_lbl: Label
var _vol := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Sfx.play_music("musica_menu")
	var svc := LBVista3D.new()
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(svc)
	var sv := svc.sv
	_arena = LBArena.new()
	_arena.player_look = LBRewards.look_for(Progress.data)
	_arena.showcase = true
	# 2.1: o menu mostra um cenário de pós-guerra diferente a cada vez (ou a arena neon, se escolhida)
	_arena.cenario = "industrial" if GameSettings.cenario_modo == 2 else str(randi_range(1, 10))
	sv.add_child(_arena)

	var shade := TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(0.01, 0.02, 0.05, 0.82), Color(0.01, 0.02, 0.05, 0.35), Color(0, 0, 0, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 64
	gt.height = 4
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_side = _build_side()
	add_child(_side)
	if LBDevice.compact():
		_side.set_anchors_and_offsets_preset.call_deferred(Control.PRESET_FULL_RECT)
	_opponents = _build_opponents()
	add_child(_opponents)
	_settings = _build_settings()
	add_child(_settings)
	_campaign = _build_campaign()
	add_child(_campaign)
	var gparts := _right_panel("GARAGEM E PROGRESSO")
	_garage = gparts[0]
	if LBDevice.compact():
		# celular em pé: o robô aparece em cima e as opções da garagem embaixo
		_garage.anchor_top = 0.40
	var gscroll := ScrollContainer.new()
	gscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gparts[1].add_child(gscroll)
	_garage_box = VBoxContainer.new()
	_garage_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_garage_box.add_theme_constant_override("separation", 10)
	gscroll.add_child(_garage_box)
	add_child(_garage)
	_show_panel(null)
	_intro_animation()


# ------------------------------------------------------------ coluna principal

func _build_side() -> Control:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	m.offset_right = 0 if LBDevice.compact() else 560
	if LBDevice.compact():
		m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		m.add_theme_constant_override("margin_right", 24)
	m.add_theme_constant_override("margin_left", 24 if LBDevice.compact() else 84)
	m.add_theme_constant_override("margin_top", 60 if LBDevice.compact() else (30 if LBDevice.base_size().y < 700 else 120))
	m.add_theme_constant_override("margin_bottom", 48)
	# a coluna rola se a tela for baixa (celular deitado, notebook pequeno)
	var rol := ScrollContainer.new()
	rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	m.add_child(rol)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rol.add_child(v)
	var baixa := LBDevice.base_size().y < 700

	var title := Label.new()
	title.text = "LOGICBOT"
	title.theme_type_variation = "TitleLabel"
	title.add_theme_font_size_override("font_size", 50 if LBDevice.compact() or baixa else 82)
	title.add_theme_color_override("font_shadow_color", Color(LBUITheme.CYAN, 0.45))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 0)
	title.add_theme_constant_override("shadow_outline_size", 22)
	v.add_child(title)
	var sub := Label.new()
	sub.text = "PROGRAME.  LUTE.  APRENDA."
	sub.theme_type_variation = "HeaderLabel"
	sub.add_theme_font_size_override("font_size", 20)
	v.add_child(sub)
	var desc := Label.new()
	desc.text = "Escreva a lógica do seu robô em Portugol e assista ele lutar sozinho."
	desc.theme_type_variation = "DimLabel"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 0 if LBDevice.compact() else 420
	v.add_child(desc)

	var gap := Control.new()
	gap.custom_minimum_size.y = 12 if baixa else 40
	v.add_child(gap)

	var tut_done: bool = Progress.data.tutorial_concluido
	if not tut_done:
		_nav_button(v, "▶  COMEÇAR TUTORIAL", "Obrigatório: aprenda o básico em poucos minutos.", func(): GameState.start_tutorial(), true)
	_nav_button(v, "CAMPANHA", "Fases progressivas: cada uma ensina um conceito.", func():
		_refresh_campaign()
		_show_panel(_campaign), false, not tut_done)
	_nav_button(v, "TREINO LIVRE", "Escolha um oponente e teste qualquer estratégia.", func(): _show_panel(_opponents), false, not tut_done)
	_nav_button(v, "GARAGEM", "Nível, conquistas e aparência do seu robô.", func():
		_refresh_garage()
		_show_panel(_garage), false, not tut_done)
	if tut_done:
		_nav_button(v, "REVER TUTORIAL", "Refaça o tutorial quando quiser.", func(): GameState.start_tutorial())
	_nav_button(v, "CONFIGURAÇÕES", "Qualidade gráfica, tela cheia e opções de jogo.", func():
		_load_settings_ui()
		_show_panel(_settings))
	_nav_button(v, "SAIR", "", func(): get_tree().quit())

	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill)
	var foot := Label.new()
	foot.text = "v%s  ·  Godot %s" % [ProjectSettings.get_setting("application/config/version", "0"), Engine.get_version_info().string]
	foot.theme_type_variation = "DimLabel"
	foot.add_theme_font_size_override("font_size", 14)
	v.add_child(foot)
	return m


func _nav_button(parent: Control, text: String, tip: String, cb: Callable, primary := false, locked := false) -> void:
	var b := Button.new()
	b.text = text + ("   ⊘" if locked else "")
	b.theme_type_variation = "PrimaryButton" if primary else "NavButton"
	b.disabled = locked
	if locked:
		tip = "Conclua o tutorial primeiro."
	b.custom_minimum_size = Vector2(0 if LBDevice.compact() else 380, 58)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL if LBDevice.compact() else Control.SIZE_SHRINK_BEGIN
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.tooltip_text = tip
	b.pressed.connect(cb)
	b.mouse_entered.connect(func(): _hover(b, true))
	b.mouse_exited.connect(func(): _hover(b, false))
	parent.add_child(b)


func _hover(b: Control, on: bool) -> void:
	var tw := b.create_tween()
	b.pivot_offset = Vector2(0, b.size.y * 0.5)
	tw.tween_property(b, "scale", Vector2(1.04, 1.04) if on else Vector2.ONE, 0.12).set_trans(Tween.TRANS_CUBIC)


func _intro_animation() -> void:
	_side.modulate.a = 0.0
	_side.position.x -= 40
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_side, "modulate:a", 1.0, 0.6).set_delay(0.15)
	tw.tween_property(_side, "position:x", _side.position.x + 40, 0.6).set_delay(0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _show_panel(p: Control) -> void:
	for x in [_opponents, _settings, _campaign, _garage]:
		x.visible = x == p
	_arena.foco_garagem = p == _garage and p != null
	if LBDevice.compact() and _side:
		_side.visible = p == null   # celular em pé: o menu some enquanto um painel está aberto
	if p:
		p.modulate.a = 0.0
		create_tween().tween_property(p, "modulate:a", 1.0, 0.2)


# ------------------------------------------------------------ oponentes

func _right_panel(title_text: String) -> Array:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	m.offset_left = -720
	m.add_theme_constant_override("margin_right", 64)
	var baixa := LBDevice.base_size().y < 700
	m.add_theme_constant_override("margin_top", 16 if baixa else 110)
	m.add_theme_constant_override("margin_bottom", 16 if baixa else 90)
	if LBDevice.compact():
		# celular: o painel ocupa a tela toda, por cima do menu
		m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for lado in ["left", "right", "top", "bottom"]:
			m.add_theme_constant_override("margin_" + lado, 10)
	var p := PanelContainer.new()
	p.theme_type_variation = "GlassPanel"
	m.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	var h := Label.new()
	h.text = title_text
	h.theme_type_variation = "HeaderLabel"
	h.add_theme_font_size_override("font_size", 20 if LBDevice.compact() else 24)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var topo := HBoxContainer.new()
	topo.add_child(h)
	var voltar := Button.new()
	voltar.text = "◀ VOLTAR"
	voltar.custom_minimum_size = Vector2(0, 44)
	voltar.pressed.connect(func(): _show_panel(null))
	topo.add_child(voltar)
	v.add_child(topo)
	return [m, v]


func _build_opponents() -> Control:
	var parts := _right_panel("ESCOLHA SEU OPONENTE")
	var rol := ScrollContainer.new()   # a lista rola (com o dedo no celular)
	rol.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parts[1].add_child(rol)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 14)
	rol.add_child(v)
	for b in LBBotLibrary.BOTS:
		var card := PanelContainer.new()
		card.theme_type_variation = "DarkPanel"
		var accent := Color(b.cor)
		var sb := LBUITheme.box(Color(0.02, 0.035, 0.07, 0.9), Color(accent, 0.55), 1, 6, 14.0)
		sb.border_width_left = 4
		card.add_theme_stylebox_override("panel", sb)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		card.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 12)
		var n := Label.new()
		n.text = b.nome
		n.theme_type_variation = "HeaderLabel"
		n.add_theme_font_size_override("font_size", 22)
		n.add_theme_color_override("font_color", accent)
		top.add_child(n)
		var lvl := Label.new()
		lvl.text = b.nivel.to_upper()
		lvl.theme_type_variation = "DimLabel"
		lvl.add_theme_font_size_override("font_size", 14)
		lvl.add_theme_stylebox_override("normal", LBUITheme.box(Color(accent, 0.15), Color(accent, 0.5), 1, 3, 6.0))
		lvl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(lvl)
		info.add_child(top)
		var t := Label.new()
		t.text = b.titulo
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.add_theme_font_size_override("font_size", 18)
		info.add_child(t)
		var d := Label.new()
		d.text = b.descricao
		d.theme_type_variation = "DimLabel"
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 0 if LBDevice.compact() else 380
		info.add_child(d)
		var go := Button.new()
		go.text = "LUTAR"
		go.theme_type_variation = "PrimaryButton"
		go.custom_minimum_size = Vector2(96 if LBDevice.compact() else 130, 52)
		go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var id: String = b.id
		go.pressed.connect(func(): GameState.start_battle(id))
		row.add_child(go)
		v.add_child(card)
	var tip := Label.new()
	tip.text = "Dica: comece pelo TREINO-01. Depois de vencer, leia o código de cada inimigo na tela de resultado."
	tip.theme_type_variation = "DimLabel"
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tip)
	return parts[0]


# ------------------------------------------------------------ configurações

func _build_settings() -> Control:
	var parts := _right_panel("CONFIGURAÇÕES")
	var v: VBoxContainer = parts[1]
	var compacto := LBDevice.compact()
	# celular em pé: tudo numa coluna só, dentro de uma área que rola com o dedo
	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(rolagem)
	var grid := GridContainer.new()
	grid.columns = 1 if compacto else 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8 if compacto else 14)
	rolagem.add_child(grid)

	_q_opt = OptionButton.new()
	_q_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in GameSettings.QUALITY_NAMES.size():
		_q_opt.add_item(GameSettings.QUALITY_NAMES[i], i)
	_row(grid, "Qualidade gráfica", _q_opt)
	var q_help := Label.new()
	q_help.text = "Baixa: sem sombras e menos partículas (PCs modestos).  Alta: sombras, reflexos, oclusão e névoa volumétrica."
	q_help.theme_type_variation = "DimLabel"
	q_help.add_theme_font_size_override("font_size", 15)
	q_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q_help.custom_minimum_size.x = 0 if compacto else 300
	q_help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not compacto:
		grid.add_child(Control.new())
	grid.add_child(q_help)
	var gpu := Label.new()
	gpu.text = "Placa de vídeo: " + GameSettings.gpu_name() + ("  ·  modo seguro na Alta" if GameSettings.is_risky_gpu() else "")
	gpu.theme_type_variation = "DimLabel"
	gpu.add_theme_font_size_override("font_size", 14)
	gpu.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gpu.custom_minimum_size.x = 0 if compacto else 300
	gpu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not compacto:
		grid.add_child(Control.new())
	grid.add_child(gpu)

	var scale_row := HBoxContainer.new()
	_scale_slider = HSlider.new()
	_scale_slider.min_value = 50
	_scale_slider.max_value = 100
	_scale_slider.step = 5
	_scale_slider.custom_minimum_size.x = 160 if compacto else 220
	_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scale_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_scale_lbl = Label.new()
	_scale_lbl.custom_minimum_size.x = 60
	_scale_slider.value_changed.connect(func(val): _scale_lbl.text = "%d%%" % int(val))
	scale_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_row.add_child(_scale_slider)
	scale_row.add_child(_scale_lbl)
	_row(grid, "Resolução 3D", scale_row)
	_full_chk = CheckBox.new()
	_full_chk.text = "Ativada"
	_row(grid, "Tela cheia", _full_chk)
	_vsync_chk = CheckBox.new()
	_vsync_chk.text = "Ativado"
	_row(grid, "V-Sync", _vsync_chk)
	_labels_chk = CheckBox.new()
	_labels_chk.text = "Mostrar ação acima dos robôs" if compacto else "Mostrar linha e ação acima dos robôs"
	_row(grid, "Rótulos de ação", _labels_chk)
	_cam_opt = OptionButton.new()
	_cam_opt.clip_text = true
	_cam_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in GameSettings.CAMERA_NAMES.size():
		_cam_opt.add_item(GameSettings.CAMERA_NAMES[i], i)
	_row(grid, "Câmera da luta", _cam_opt)
	_cen_opt = OptionButton.new()
	_cen_opt.clip_text = true
	_cen_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in GameSettings.CENARIO_NAMES.size():
		_cen_opt.add_item(GameSettings.CENARIO_NAMES[i], i)
	_row(grid, "Cenário da luta", _cen_opt)
	for k in [["geral", "Volume geral"], ["musica", "Música"], ["efeitos", "Efeitos sonoros"]]:
		var sl := HSlider.new()
		sl.min_value = 0
		sl.max_value = 100
		sl.step = 5
		sl.custom_minimum_size.x = 160 if compacto else 220
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sl.value_changed.connect(func(_v):
			GameSettings.set_volumes(_vol.geral.value / 100.0, _vol.musica.value / 100.0, _vol.efeitos.value / 100.0)
			Sfx.apply_volumes())
		_vol[k[0]] = sl
		_row(grid, k[1], sl)

	var cred := Label.new()
	cred.text = "Créditos: robô gerado no TRELLIS · animações Mixamo · sons Kenney (CC0) e Mixkit · sino \"Boxing Round Bell\" por BudgetPixel AI (CC BY 4.0)."
	cred.theme_type_variation = "DimLabel"
	cred.add_theme_font_size_override("font_size", 13)
	cred.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(cred)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	v.add_child(fill)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	btns.alignment = BoxContainer.ALIGNMENT_END
	var back := Button.new()
	back.text = "VOLTAR"
	back.pressed.connect(func(): _show_panel(null))
	btns.add_child(back)
	var save := Button.new()
	save.text = "APLICAR E SALVAR"
	save.theme_type_variation = "PrimaryButton"
	save.pressed.connect(func():
		GameSettings.camera_style = _cam_opt.selected
		GameSettings.cenario_modo = _cen_opt.selected
		GameSettings.set_and_apply(_q_opt.selected, _full_chk.button_pressed, _vsync_chk.button_pressed,
			_scale_slider.value / 100.0, _labels_chk.button_pressed)
		_show_panel(null))
	btns.add_child(save)
	v.add_child(btns)
	return parts[0]


func _row(grid: GridContainer, label: String, control: Control) -> void:
	var l := Label.new()
	l.text = label
	grid.add_child(l)
	grid.add_child(control)


func _load_settings_ui() -> void:
	_q_opt.select(GameSettings.quality)
	_full_chk.button_pressed = GameSettings.fullscreen
	_vsync_chk.button_pressed = GameSettings.vsync
	_labels_chk.button_pressed = GameSettings.show_action_labels
	_cam_opt.select(GameSettings.camera_style)
	_cen_opt.select(GameSettings.cenario_modo)
	_scale_slider.value = GameSettings.render_scale * 100.0
	_vol.geral.set_value_no_signal(GameSettings.volume_master * 100.0)
	_vol.musica.set_value_no_signal(GameSettings.volume_music * 100.0)
	_vol.efeitos.set_value_no_signal(GameSettings.volume_sfx * 100.0)
	_scale_lbl.text = "%d%%" % int(_scale_slider.value)


# ------------------------------------------------------------ campanha

func _build_campaign() -> Control:
	var parts := _right_panel("CAMPANHA")
	var v: VBoxContainer = parts[1]
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 14)
	var dl := Label.new()
	dl.text = "Dificuldade"
	drow.add_child(dl)
	_diff_opt = OptionButton.new()
	for i in LBCampaign.DIFICULDADES.size():
		_diff_opt.add_item(LBCampaign.DIFICULDADES[i], i)
	_diff_opt.item_selected.connect(func(i: int):
		Progress.data.dificuldade = i
		Progress.save()
		_diff_desc.text = LBCampaign.DIFICULDADE_DESC[i])
	drow.add_child(_diff_opt)
	v.add_child(drow)
	_diff_desc = Label.new()
	_diff_desc.theme_type_variation = "DimLabel"
	_diff_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_diff_desc)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_camp_list = VBoxContainer.new()
	_camp_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camp_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_camp_list)
	_summary = Label.new()
	_summary.theme_type_variation = "DimLabel"
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_summary)
	return parts[0]


func _refresh_campaign() -> void:
	var d: LBProgressData = Progress.data
	_diff_opt.select(d.dificuldade)
	_diff_desc.text = LBCampaign.DIFICULDADE_DESC[d.dificuldade]
	for c in _camp_list.get_children():
		c.queue_free()
	for i in LBCampaign.count():
		var f: Dictionary = LBCampaign.FASES[i]
		var done := d.fase_concluida(f.id)
		var open := d.fase_desbloqueada(i)
		var row := PanelContainer.new()
		var accent := LBUITheme.GREEN if done else (LBUITheme.CYAN if open else LBUITheme.BORDER)
		var sb := LBUITheme.box(Color(0.02, 0.035, 0.07, 0.9), Color(accent, 0.6), 1, 5, 10.0)
		sb.border_width_left = 4
		row.add_theme_stylebox_override("panel", sb)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		var num := Label.new()
		num.text = "%02d" % (i + 1)
		num.theme_type_variation = "HeaderLabel"
		num.add_theme_color_override("font_color", accent)
		h.add_child(num)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", -2)
		var t := Label.new()
		t.text = f.titulo
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		t.custom_minimum_size.x = 80
		t.add_theme_font_override("font", LBUITheme.font(LBUITheme.FONT_UI_BOLD))
		info.add_child(t)
		var c := Label.new()
		var st: Dictionary = d.fases.get(f.id, {})
		var status := "✔ concluída" if done else ("disponível" if open else "⊘ bloqueada")
		if int(st.get("tentativas", 0)) > 0:
			status += " · %d tentativa(s)" % int(st.tentativas)
		c.text = "%s  ·  %s" % [f.conceito, status]
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.custom_minimum_size.x = 120
		c.theme_type_variation = "DimLabel"
		c.add_theme_font_size_override("font_size", 15)
		info.add_child(c)
		h.add_child(info)
		var go := Button.new()
		go.text = "JOGAR" if not done else "REJOGAR"
		go.theme_type_variation = "PrimaryButton" if open and not done else "Button"
		go.disabled = not open
		go.custom_minimum_size = Vector2(100 if LBDevice.compact() else 120, 44)
		go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var id: String = f.id
		go.pressed.connect(func(): GameState.start_campaign(id))
		h.add_child(go)
		_camp_list.add_child(row)
	var txt := "Progresso: %d de %d fases  ·  %d lutas, %d vitórias." % [d.fases_concluidas(), LBCampaign.count(), d.lutas, d.vitorias]
	var comuns := d.erros_mais_comuns(2)
	if not comuns.is_empty():
		var nomes := []
		for e in comuns:
			nomes.append("%s (%d)" % [Progress.CATEGORIA_NOME.get(e[0], e[0]), e[1]])
		txt += "\nVale praticar: " + ", ".join(nomes) + ". Errar faz parte — cada erro é uma pista do que estudar."
	_summary.text = txt


# ------------------------------------------------------------ garagem

func _section(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = "HeaderLabel"
	l.add_theme_font_size_override("font_size", 16)
	_garage_box.add_child(l)


func _refresh_garage() -> void:
	var d: LBProgressData = Progress.data
	for c in _garage_box.get_children():
		_garage_box.remove_child(c)
		c.queue_free()
	var nv := LBRewards.nivel(d.xp)
	var prog := LBRewards.progresso_nivel(d.xp)
	var lvl := Label.new()
	lvl.text = "NÍVEL %d" % nv
	lvl.theme_type_variation = "TitleLabel"
	lvl.add_theme_font_size_override("font_size", 34)
	_garage_box.add_child(lvl)
	var bar := ProgressBar.new()
	bar.max_value = maxi(1, prog[1])
	bar.value = prog[0] if prog[1] > 0 else 1
	bar.show_percentage = false
	bar.custom_minimum_size.y = 14
	bar.add_theme_stylebox_override("background", LBUITheme.box(Color("0b1424"), LBUITheme.BORDER, 1, 3, 0.0))
	bar.add_theme_stylebox_override("fill", LBUITheme.box(LBUITheme.YELLOW, Color.TRANSPARENT, 0, 3, 0.0))
	_garage_box.add_child(bar)
	var info := Label.new()
	info.theme_type_variation = "DimLabel"
	info.text = ("%d / %d XP para o nível %d" % [prog[0], prog[1], nv + 1]) if prog[1] > 0 else "Nível máximo!"
	info.text += "   ·   XP vem de aprender coisas novas: fases inéditas, dificuldade maior, bots novos."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_garage_box.add_child(info)

	_section("CORES")
	var cores := HFlowContainer.new()
	cores.add_theme_constant_override("h_separation", 8)
	cores.add_theme_constant_override("v_separation", 8)
	for c in LBRewards.CORES:
		var b := Button.new()
		var ok := LBRewards.cor_liberada(d, c)
		b.text = c.nome if ok else "⊘ Nível %d" % c.nivel
		b.disabled = not ok
		b.custom_minimum_size = Vector2(118, 40)
		var st := LBUITheme.box(Color(c.pintura), Color(c.brilho), 3 if d.cor == c.id else 1, 4, 8.0)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st)
		var id: String = c.id
		b.pressed.connect(func():
			d.cor = id
			_apply_look())
		cores.add_child(b)
	_garage_box.add_child(cores)

	_section("MOEDAS: %d" % d.moedas)
	var mi := Label.new()
	mi.theme_type_variation = "DimLabel"
	mi.text = "Moedas vêm da NOTA do seu algoritmo em cada luta (até 60 pelo código + até 40 pela vida que sobrou, vencendo). Em cada fase ou bot você ganha só o que passar do seu recorde. As peças são só visuais: quem vence é o código!"
	mi.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_garage_box.add_child(mi)
	for cat in LBShop.CATEGORIAS:
		_section(LBShop.NOMES_CATEGORIA[cat])
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		var eq := LBShop.equipados(d)
		if cat in LBShop.OPCIONAIS:
			var nb := Button.new()
			nb.text = ("✔ " if not eq.has(cat) else "") + "Nenhum"
			nb.custom_minimum_size = Vector2(110, 40)
			var c0: String = cat
			nb.pressed.connect(func():
				LBShop.tirar(d, c0)
				_apply_look())
			flow.add_child(nb)
		for it in LBShop.itens_da(cat):
			var b := Button.new()
			var tem := LBShop.tem(d, it.id)
			var usando: bool = eq.get(cat, "") == it.id
			if usando:
				b.text = "✔ " + it.nome
			elif tem:
				b.text = it.nome
			else:
				b.text = "%s  ·  %d moedas" % [it.nome, it.preco]
				b.disabled = d.moedas < int(it.preco)
			b.tooltip_text = it.desc
			b.custom_minimum_size = Vector2(150, 40)
			var id: String = it.id
			var categoria: String = cat
			b.pressed.connect(func():
				if not LBShop.tem(d, id):
					if not LBShop.comprar(d, id):
						return
					Sfx.play("compra_loja", 0.0, -2.0)
				LBShop.equipar(d, id)
				_apply_look()
				if categoria == "danca":
					_arena.player_visual.mostrar(id, 8.0))
			flow.add_child(b)
		_garage_box.add_child(flow)

	_section("CONQUISTAS  %d / %d" % [d.conquistas.size(), LBRewards.CONQUISTAS.size()])
	for id in LBRewards.CONQUISTAS:
		var cq: Dictionary = LBRewards.CONQUISTAS[id]
		var got: bool = d.conquistas.has(id)
		var l := RichTextLabel.new()
		l.theme_type_variation = "ProseText"
		l.bbcode_enabled = true
		l.fit_content = true
		l.scroll_active = false
		l.add_theme_font_size_override("normal_font_size", 16)
		l.add_theme_font_size_override("bold_font_size", 16)
		l.text = ("[color=#ffc94a]★ [b]%s[/b][/color] — %s" if got else "[color=#4b6587]⊘ [b]%s[/b] — %s[/color]") % [cq.nome, cq.desc]
		_garage_box.add_child(l)


func _apply_look() -> void:
	Progress.save()
	_arena.rebuild_player(LBRewards.look_for(Progress.data))
	_refresh_garage()
