class_name LBBattleHUD
extends Control
## HUD sobre a arena: nomes, barras de vida/energia, cronômetro e anúncios.

var _bars := {}
var _energy := {}
var _energy_lbl := {}
var _folego := {}   ## 2.0: barra de fôlego (verde-água) embaixo da energia
var _name_lbl := {}
var _lvl_lbl := {}
var _time_lbl: Label
var _round_lbl: Label
var _announce: Label
var _sub_announce: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0.45), Color(0, 0, 0, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	shade.offset_bottom = 150
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 8 if LBDevice.compact() else 28)
	margin.add_theme_constant_override("margin_top", 16)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8 if LBDevice.compact() else 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	row.add_child(_side(0))
	row.add_child(_timer_box())
	row.add_child(_side(1))

	_announce = Label.new()
	_announce.theme_type_variation = "TitleLabel"
	var compact := LBDevice.compact()
	_announce.add_theme_font_size_override("font_size", 54 if compact else 92)
	_announce.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_announce.add_theme_constant_override("outline_size", 18)
	_announce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_announce.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_announce.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_announce.visible = false
	add_child(_announce)

	_sub_announce = Label.new()
	_sub_announce.theme_type_variation = "HeaderLabel"
	_sub_announce.add_theme_font_size_override("font_size", 26)
	_sub_announce.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_sub_announce.add_theme_constant_override("outline_size", 10)
	_sub_announce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_announce.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_sub_announce.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_sub_announce.position.y += 70
	_sub_announce.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub_announce.visible = false
	add_child(_sub_announce)


func _side(i: int) -> Control:
	var color := LBUITheme.CYAN if i == 0 else LBUITheme.RED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 5)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_BEGIN if i == 0 else BoxContainer.ALIGNMENT_END
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_lbl := Label.new()
	name_lbl.theme_type_variation = "HeaderLabel"
	name_lbl.add_theme_font_size_override("font_size", 17 if LBDevice.compact() else 24)
	name_lbl.add_theme_color_override("font_color", color.lightened(0.2))
	if LBDevice.compact():
		# no celular o nome pode ser cortado com "…" em vez de alargar a tela
		name_lbl.clip_text = true
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
	var lvl := Label.new()
	lvl.text = "NV 1"
	_lvl_lbl[i] = lvl
	lvl.theme_type_variation = "DimLabel"
	var tag := Label.new()
	tag.text = "VOCÊ" if i == 0 else "BOT"
	tag.theme_type_variation = "DimLabel"
	tag.add_theme_color_override("font_color", color)
	lvl.visible = not LBDevice.compact()   # celular: sem "NV x" (falta espaço)
	if i == 0:
		top.add_child(name_lbl)
		top.add_child(lvl)
		top.add_child(tag)
	else:
		top.add_child(tag)
		top.add_child(lvl)
		top.add_child(name_lbl)
	box.add_child(top)
	_name_lbl[i] = name_lbl

	var bar := LBFightBar.new()
	bar.color = color
	bar.mirrored = i == 1
	bar.custom_minimum_size = Vector2(100, 22) if LBDevice.compact() else Vector2(200, 30)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar)
	_bars[i] = bar

	var erow := HBoxContainer.new()
	erow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	erow.add_theme_constant_override("separation", 10)
	var ebar := LBFightBar.new()
	ebar.color = Color("ffc94a")
	ebar.mirrored = i == 1
	ebar.segments = 4
	ebar.marker = 0.5
	ebar.low_threshold = 0.0
	ebar.custom_minimum_size = Vector2(60, 9) if LBDevice.compact() else Vector2(150, 11)
	ebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ebar.size_flags_stretch_ratio = 0.62
	ebar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ebar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var elbl := Label.new()
	elbl.theme_type_variation = "DimLabel"
	elbl.add_theme_font_size_override("font_size", 16)
	elbl.custom_minimum_size.x = 0 if LBDevice.compact() else 110
	if LBDevice.compact():
		elbl.visible = false   # celular: a barra amarela já mostra a energia
	elbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = 0.38
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if i == 0:
		erow.add_child(ebar)
		erow.add_child(elbl)
		erow.add_child(spacer)
	else:
		erow.add_child(spacer)
		erow.add_child(elbl)
		erow.add_child(ebar)
	box.add_child(erow)
	_energy[i] = ebar
	var fbar := LBFightBar.new()
	fbar.color = Color("5eead4")
	fbar.mirrored = i == 1
	fbar.segments = 4
	fbar.low_threshold = 0.25
	fbar.custom_minimum_size = Vector2(60, 6) if LBDevice.compact() else Vector2(150, 8)
	fbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fbar.tooltip_text = "Fôlego"
	var frow := HBoxContainer.new()
	frow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fsp := Control.new()
	fsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fsp.size_flags_stretch_ratio = 0.38
	fsp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fbar.size_flags_stretch_ratio = 0.62
	if i == 0:
		frow.add_child(fbar)
		frow.add_child(fsp)
	else:
		frow.add_child(fsp)
		frow.add_child(fbar)
	box.add_child(frow)
	_folego[i] = fbar
	_energy_lbl[i] = elbl
	return box


func _timer_box() -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "GlassPanel"
	panel.custom_minimum_size = Vector2(72, 0) if LBDevice.compact() else Vector2(118, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -6)
	panel.add_child(v)
	_round_lbl = Label.new()
	_round_lbl.text = "ROUND 1"
	_round_lbl.theme_type_variation = "DimLabel"
	_round_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_lbl.add_theme_font_size_override("font_size", 15)
	v.add_child(_round_lbl)
	_time_lbl = Label.new()
	_time_lbl.theme_type_variation = "TitleLabel"
	_time_lbl.add_theme_font_size_override("font_size", 30 if LBDevice.compact() else 44)
	_time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_lbl.text = "60"
	v.add_child(_time_lbl)
	return panel


func setup(name_a: String, name_b: String, level_a: int = 1) -> void:
	_name_lbl[0].text = name_a
	_name_lbl[1].text = name_b
	_lvl_lbl[0].text = "NV %d" % level_a
	for i in 2:
		_bars[i].set_value(1.0, true)
		_energy[i].set_value(LBCombatRules.ENERGIA_INICIAL / LBCombatRules.MAX_ENERGIA, true)
	_time_lbl.text = str(int(LBCombatRules.ROUND_TIME))


func update_from(sim: LBCombatSim) -> void:
	for i in 2:
		var f := sim.lutadores[i]
		_bars[i].set_value(float(f.vida) / LBCombatRules.MAX_VIDA)
		_energy[i].set_value(f.energia / LBCombatRules.MAX_ENERGIA)
		_energy_lbl[i].text = "ENERGIA %d" % f.energia_int()
		_folego[i].set_value(f.folego / LBCombatRules.FOLEGO_MAX)
	var t := int(ceil(sim.tempo_restante))
	_round_lbl.text = "TURNO %d/%d" % [sim.turno, sim.total_turnos()] if sim.turnos else "ROUND 1"
	_time_lbl.text = str(t)
	_time_lbl.add_theme_color_override("font_color", LBUITheme.RED if t <= 10 else Color.WHITE)


func announce(text: String, color: Color = Color.WHITE, sub: String = "", hold: float = 0.9) -> void:
	_announce.text = text
	# textos longos ("FIM DO TURNO 10") ficam menores para caberem na largura do celular
	var base := 54 if LBDevice.compact() else 92
	_announce.add_theme_font_size_override("font_size", base if text.length() <= 8 else int(base * 0.62))
	_announce.add_theme_color_override("font_color", color)
	_announce.visible = true
	_announce.pivot_offset = _announce.size * 0.5
	_announce.scale = Vector2(1.8, 1.8)
	_announce.modulate.a = 0.0
	_sub_announce.text = sub
	_sub_announce.visible = sub != ""
	_sub_announce.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_announce, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_announce, "modulate:a", 1.0, 0.15)
	tw.tween_property(_sub_announce, "modulate:a", 1.0, 0.3).set_delay(0.15)
	if hold > 0.0:
		tw.chain().tween_interval(hold)
		tw.chain().set_parallel(true)
		tw.tween_property(_announce, "modulate:a", 0.0, 0.25)
		tw.tween_property(_sub_announce, "modulate:a", 0.0, 0.25)


func hide_announce() -> void:
	_announce.visible = false
	_sub_announce.visible = false


## Encerra animações de barra (usado ao reiniciar ou pular tempo).
func snap() -> void:
	for i in 2:
		_bars[i].set_value(_bars[i].value, true)
		_energy[i].set_value(_energy[i].value, true)
