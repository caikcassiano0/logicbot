class_name LBResultPanel
extends Control
## Tela de resultado: estatísticas, análise educativa, código do inimigo e saída.

signal edit_requested
signal rematch_requested
signal menu_requested
signal next_requested

var _title: Label
var _subtitle: Label
var _grid: GridContainer
var _analysis: RichTextLabel
var _enemy_code: LBCodeEditor
var _output: RichTextLabel
var _panel: PanelContainer
var _campaign_lbl: Label
var _rewards_lbl: Label
var _coins_lbl: RichTextLabel
var _btn_next: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.03, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.theme_type_variation = "GlassPanel"
	center.add_child(_panel)
	# tudo dentro de uma área que rola: em tela pequena (celular, notebook) nada fica cortado
	var rol := ScrollContainer.new()
	rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(rol)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rol.add_child(v)
	_ajustar_tamanho()
	get_viewport().size_changed.connect(_ajustar_tamanho)
	_title = Label.new()
	_title.theme_type_variation = "TitleLabel"
	_title.add_theme_font_size_override("font_size", 36 if LBDevice.compact() else 52)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	_subtitle = Label.new()
	_subtitle.theme_type_variation = "DimLabel"
	_subtitle.add_theme_font_size_override("font_size", 19)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_subtitle)
	_campaign_lbl = Label.new()
	_campaign_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_campaign_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_campaign_lbl.add_theme_font_override("font", LBUITheme.font(LBUITheme.FONT_UI_BOLD))
	_campaign_lbl.add_theme_font_size_override("font_size", 21)
	_campaign_lbl.visible = false
	v.add_child(_campaign_lbl)
	_rewards_lbl = Label.new()
	_rewards_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rewards_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rewards_lbl.add_theme_color_override("font_color", LBUITheme.YELLOW)
	_rewards_lbl.visible = false
	v.add_child(_rewards_lbl)
	_coins_lbl = RichTextLabel.new()
	_coins_lbl.bbcode_enabled = true
	_coins_lbl.fit_content = true
	_coins_lbl.scroll_active = false
	_coins_lbl.add_theme_font_override("normal_font", LBUITheme.font(LBUITheme.FONT_UI))
	_coins_lbl.add_theme_font_override("bold_font", LBUITheme.font(LBUITheme.FONT_UI_BOLD))
	_coins_lbl.add_theme_font_size_override("normal_font_size", 17)
	_coins_lbl.add_theme_font_size_override("bold_font_size", 18)
	_coins_lbl.visible = false
	v.add_child(_coins_lbl)

	var body: BoxContainer = VBoxContainer.new() if LBDevice.compact() else HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	v.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 0 if LBDevice.compact() else 380
	body.add_child(left)
	var h := Label.new()
	h.text = "ESTATÍSTICAS"
	h.theme_type_variation = "HeaderLabel"
	left.add_child(h)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 18)
	_grid.add_theme_constant_override("v_separation", 4)
	left.add_child(_grid)

	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.custom_minimum_size.y = 240
	body.add_child(tabs)
	_analysis = RichTextLabel.new()
	_analysis.name = "Análise"
	_analysis.theme_type_variation = "ProseText"
	_analysis.bbcode_enabled = true
	_analysis.add_theme_stylebox_override("normal", LBUITheme.box(Color(0, 0, 0, 0), Color.TRANSPARENT, 0, 0, 12.0))
	tabs.add_child(_analysis)
	_enemy_code = LBCodeEditor.new()
	_enemy_code.name = "Código do inimigo"
	_enemy_code.editable = false
	tabs.add_child(_enemy_code)
	_output = RichTextLabel.new()
	_output.name = "Saída do programa"
	_output.bbcode_enabled = true
	tabs.add_child(_output)

	var buttons := HFlowContainer.new()
	buttons.alignment = FlowContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	v.add_child(buttons)
	var b1 := Button.new()
	b1.text = "AJUSTAR O CÓDIGO"
	b1.theme_type_variation = "PrimaryButton"
	b1.custom_minimum_size = Vector2(200 if LBDevice.compact() else 280, 52)
	b1.pressed.connect(func(): edit_requested.emit())
	buttons.add_child(b1)
	_btn_next = Button.new()
	_btn_next.text = "PRÓXIMA FASE ▶"
	_btn_next.theme_type_variation = "PrimaryButton"
	_btn_next.custom_minimum_size = Vector2(200 if LBDevice.compact() else 240, 52)
	_btn_next.visible = false
	_btn_next.pressed.connect(func(): next_requested.emit())
	buttons.add_child(_btn_next)
	var b2 := Button.new()
	b2.text = "LUTAR DE NOVO"
	b2.custom_minimum_size = Vector2(150 if LBDevice.compact() else 200, 52)
	b2.pressed.connect(func(): rematch_requested.emit())
	buttons.add_child(b2)
	var b3 := Button.new()
	b3.text = "MENU"
	b3.custom_minimum_size = Vector2(110 if LBDevice.compact() else 140, 52)
	b3.pressed.connect(func(): menu_requested.emit())
	buttons.add_child(b3)


func _cell(text: String, color: Color = LBUITheme.TEXT, align := HORIZONTAL_ALIGNMENT_RIGHT, bold := false) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", LBUITheme.font(LBUITheme.FONT_UI_BOLD))
	_grid.add_child(l)


func show_result(sim: LBCombatSim, bot: Dictionary) -> void:
	var p := sim.lutadores[0]
	var e := sim.lutadores[1]
	_campaign_lbl.visible = false
	_rewards_lbl.visible = false
	if _coins_lbl:
		_coins_lbl.visible = false
	_btn_next.visible = false
	match sim.vencedor:
		0:
			_title.text = "VITÓRIA"
			_title.add_theme_color_override("font_color", LBUITheme.CYAN)
		1:
			_title.text = "DERROTA"
			_title.add_theme_color_override("font_color", LBUITheme.RED)
		_:
			_title.text = "EMPATE"
			_title.add_theme_color_override("font_color", LBUITheme.YELLOW)
	var motivo := "por nocaute" if sim.motivo_fim == "nocaute" else "por tempo"
	_subtitle.text = "%s %s  ·  vida final %d × %d  ·  %.1f s de luta" % [
		"Vencedor: " + (p.nome if sim.vencedor == 0 else e.nome) if sim.vencedor < 2 else "Empate", motivo,
		p.vida, e.vida, sim.passos / float(LBCombatRules.TICK_RATE)]

	for c in _grid.get_children():
		c.queue_free()
	_cell("", LBUITheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	_cell("VOCÊ", LBUITheme.CYAN, HORIZONTAL_ALIGNMENT_RIGHT, true)
	_cell(e.nome, LBUITheme.RED, HORIZONTAL_ALIGNMENT_RIGHT, true)
	var rows := [
		["Dano causado", "dano_causado"], ["Dano recebido", "dano_recebido"],
		["Ataques", "ataques"], ["Acertos em cheio", "acertos"], ["Golpes no vazio", "golpes_no_vazio"],
		["Defesas bem-sucedidas", "defesas_ok"], ["Esquivas", "esquivas_ok"],
		["Golpes especiais", "especiais_ok"], ["Falhas sem energia", "falhas_sem_energia"], ["Energia gasta", "energia_gasta"],
	]
	for r in rows:
		_cell(r[0], LBUITheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT)
		_cell(str(p.stats[r[1]]))
		_cell(str(e.stats[r[1]]))
	if p.vm:
		var prog := [
			["Instruções executadas", p.vm.instructions_executed],
			["Condições avaliadas", p.vm.total_conditions_evaluated()],
			["Voltas do programa", p.vm.cycles_completed],
		]
		for r in prog:
			_cell(r[0], LBUITheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT)
			_cell(str(r[1]))
			_cell("")

	var txt := ""
	for s in LBFightAnalyzer.analisar(sim):
		txt += "[font_size=20][color=#22d3ee][b]%s[/b][/color][/font_size]\n" % LBProgrammingPanel.esc(s.titulo)
		txt += "[color=#7f93b0]Conceito: %s[/color]\n" % LBProgrammingPanel.esc(s.conceito)
		txt += "%s\n" % LBProgrammingPanel.esc(s.texto)
		if s.exemplo != "":
			txt += "[code][color=#a5f3fc]%s[/color][/code]\n" % LBProgrammingPanel.esc(s.exemplo)
		txt += "\n"
	_analysis.text = txt
	_enemy_code.text = bot.codigo

	_output.clear()
	if p.erro_programa:
		_output.append_text("[color=#ff3b4e]%s[/color]\n\n" % LBProgrammingPanel.esc(p.erro_programa.to_text()))
	if p.vm and not p.vm.output_log.is_empty():
		for line in p.vm.output_log:
			_output.append_text(LBProgrammingPanel.esc(line) + "\n")
	elif not p.erro_programa:
		_output.append_text("[color=#7f93b0]Seu programa não usou escreva/escreval. Use escreval(\"vida: \", vida) para acompanhar valores durante a luta.[/color]")

	visible = true
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.96, 0.96)
	_panel.pivot_offset = _panel.size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.25)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Mensagem da campanha (fase concluída, requisito faltando...).
func set_campaign_info(text: String, color: Color, show_next: bool) -> void:
	_campaign_lbl.text = text
	_campaign_lbl.add_theme_color_override("font_color", color)
	_campaign_lbl.visible = true
	_btn_next.visible = show_next


## O painel ocupa no máximo a tela (menos uma margem); o conteúdo rola se não couber.
func _ajustar_tamanho() -> void:
	var vs := get_viewport().get_visible_rect().size
	var quer := Vector2(vs.x, vs.y) if LBDevice.compact() else Vector2(1060, 640)
	_panel.custom_minimum_size = Vector2(minf(quer.x, vs.x - 16.0), minf(quer.y, vs.y - 16.0))


## 2.0: nota do algoritmo e moedas ganhas (só o que passar do recorde).
func set_coins_info(n: Dictionary, r: Dictionary, saldo: int) -> void:
	var t := "[center][b][color=#fde047]NOTA %d/100[/color][/b]  (algoritmo %d/60 + vida %d/40)   →   " % [n.total, n.algoritmo, n.vida]
	if int(r.ganho) > 0:
		t += "[b][color=#fde047]+%d moedas[/color][/b]" % r.ganho
		if int(r.recorde_antes) > 0:
			t += " (novo recorde! antes: %d)" % r.recorde_antes
	else:
		t += "[color=#94a3b8]sem moedas novas — recorde desta luta: %d. Melhore o código para ganhar mais![/color]" % r.recorde_antes
	t += "   ·   saldo: [b]%d[/b][/center]\n[center][font_size=14][color=#94a3b8]" % saldo
	var partes: Array[String] = []
	for it in n.itens:
		partes.append("%s %d/%d" % [it[0], it[1], it[2]])
	t += "  ·  ".join(partes) + "[/color][/font_size][/center]"
	_coins_lbl.text = t
	_coins_lbl.visible = true


## Resumo de XP, nível e conquistas da luta.
func set_rewards_info(text: String) -> void:
	_rewards_lbl.text = text
	_rewards_lbl.visible = text != ""
