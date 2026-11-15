class_name LBProgrammingPanel
extends PanelContainer
## Metade de baixo da tela de batalha: referência da linguagem, editor e console.
##
## [Referência]  |  [Editor de código]  |  [Console + botões]

signal validate_requested
signal ready_requested
signal stop_requested
signal speed_changed(value: float)
signal restore_example_requested
signal pause_toggled
signal step_requested
signal hint_requested

const SPEEDS := [0.5, 1.0, 2.0]

## [nome, explicação, exemplo preenchido (Fácil), estrutura vazia (Médio/Difícil)]
const SNIPPETS := [
	["se ... entao", "Executa um bloco só se a condição for verdadeira.", "se inimigo_perto entao\n   atacar()\nfimse", "se ??? entao\n   ???\nfimse"],
	["se ... senao", "Escolhe entre dois caminhos.", "se inimigo_perto entao\n   atacar()\nsenao\n   avancar()\nfimse", "se ??? entao\n   ???\nsenao\n   ???\nfimse"],
	["senao se", "Testa várias condições em ordem; a primeira verdadeira ganha.", "se vida < 30 entao\n   defender()\nsenao se inimigo_perto entao\n   atacar()\nsenao\n   avancar()\nfimse", "se ??? entao\n   ???\nsenao se ??? entao\n   ???\nsenao\n   ???\nfimse"],
	["enquanto", "Repete enquanto a condição for verdadeira. Coloque uma ação dentro!", "enquanto inimigo_perto faca\n   atacar()\nfimenquanto", "enquanto ??? faca\n   ???\nfimenquanto"],
	["repita ... ate", "Repete o bloco até a condição ficar verdadeira.", "repita\n   avancar()\nate inimigo_perto", "repita\n   ???\nate ???"],
	["para", "Repete um número fixo de vezes. Declare o contador (i: inteiro) em VAR.", "para i de 1 ate 3 faca\n   atacar()\nfimpara", "para ??? de ??? ate ??? faca\n   ???\nfimpara"],
	["variável", "Guarda um valor. Declare em VAR (ex: contador: inteiro) e use <- para atribuir.", "contador <- contador + 1", "??? <- ???"],
	["escreval", "Mostra valores no console durante a luta (ótimo para depurar).", "escreval(\"vida: \", vida, \" energia: \", energia)", "escreval(???)"],
	["procedimento", "Dá um nome a um grupo de comandos. Declare ANTES do INICIO e chame pelo nome.", "procedimento contra_ataque()\ninicio\n   defender()\n   atacar()\nfimprocedimento", "procedimento ???()\ninicio\n   ???\nfimprocedimento"],
	["e / ou / nao", "Combinam condições.", "se inimigo_perto e energia >= 50 entao\n   golpe_especial()\nfimse", "se ??? e ??? entao\n   ???\nfimse"],
]

## Fácil: as estruturas da Referência entram preenchidas com um exemplo.
## Médio/Difícil: entram só com a estrutura vazia (??? para completar).
var snippets_filled := true
var enemy_view: LBCodeEditor     ## 2.0: aba "Inimigo" — código que o inimigo usou no turno
var _enemy_title: Label
var _actions_list: ItemList

var editor: LBCodeEditor
var console: RichTextLabel
var _tabs: TabContainer
var _lists: Array[ItemList] = []
var _desc: RichTextLabel
var _insert_btn: Button
var _btn_validate: Button
var _btn_ready: Button
var _btn_stop: Button
var _btn_speed: Button
var _btn_example: Button
var _status: Label
var _btn_pause: Button
var _btn_step: Button
var _btn_hint: Button
var _right_tabs: TabContainer
var _watch: RichTextLabel
var _speed_i := 1
var _pending_insert := ""


var compact := false          ## layout de celular (abas em vez de colunas)
var _main_tabs: TabContainer
var _row1: HBoxContainer
var _row2: HBoxContainer


func _ready() -> void:
	theme_type_variation = "DarkPanel"
	compact = LBDevice.compact()
	var ref := _build_reference()
	var ed := _build_editor()
	var con := _build_console()
	if not compact:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		add_child(row)
		row.add_child(ref)
		row.add_child(ed)
		row.add_child(con)
		return
	# Celular: uma aba de cada vez + botões sempre visíveis embaixo.
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	_main_tabs = TabContainer.new()
	_main_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_main_tabs)
	ed.name = "Código"
	ref.name = "Comandos"
	ref.custom_minimum_size.x = 0
	ed.custom_minimum_size.x = 0
	_main_tabs.add_child(ed)
	_main_tabs.add_child(ref)
	for page in [console, _watch, enemy_view.get_parent()]:
		_right_tabs.remove_child(page)
		_main_tabs.add_child(page)
	con.remove_child(_row1)
	con.remove_child(_row2)
	con.queue_free()
	_right_tabs = _main_tabs
	v.add_child(_row1)
	v.add_child(_row2)
	for b in [_btn_validate, _btn_example, _btn_hint]:
		b.custom_minimum_size.y = 48


# ------------------------------------------------------------ construção

## Texto completo no PC; versão curta no celular (tela estreita).
func _txt(longo: String, curto: String) -> String:
	return curto if LBDevice.compact() else longo


func _header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = "HeaderLabel"
	l.add_theme_font_size_override("font_size", 15)
	return l


func _build_reference() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 250
	col.size_flags_stretch_ratio = 0.9
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_header("REFERÊNCIA"))
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_tabs)

	_actions_list = _make_list("Comandos")
	refresh_locks()
	var sensors := _make_list("Sensores")
	for s in LBRobotAPI.SENSORS:
		var info: Dictionary = LBRobotAPI.SENSORS[s]
		var i := sensors.add_item("%s : %s" % [s, info.tipo])
		sensors.set_item_metadata(i, {"insert": s, "desc": "[b]%s[/b] ([i]%s, somente leitura[/i]) — %s" % [s, info.tipo, info.desc]})
		sensors.set_item_custom_fg_color(i, LBCodeEditor.C_SENSOR)
	var structs := _make_list("Estruturas")
	for sn in SNIPPETS:
		var i := structs.add_item(sn[0])
		structs.set_item_metadata(i, {"insert": sn[2], "skeleton": sn[3], "desc": "[b]%s[/b] — %s" % [sn[0], sn[1]]})
		structs.set_item_custom_fg_color(i, LBCodeEditor.C_KEYWORD)

	_desc = RichTextLabel.new()
	_desc.theme_type_variation = "ProseText"
	_desc.bbcode_enabled = true
	_desc.fit_content = true
	_desc.custom_minimum_size.y = 72
	_desc.add_theme_font_size_override("normal_font_size", 16)
	_desc.add_theme_font_size_override("bold_font_size", 16)
	_desc.text = "[color=#7f93b0]Clique em um item para ver a explicação. Duplo clique insere no código.[/color]"
	col.add_child(_desc)
	_insert_btn = Button.new()
	_insert_btn.text = "INSERIR NO CÓDIGO"
	_insert_btn.disabled = true
	_insert_btn.pressed.connect(func(): _insert(_pending_insert))
	col.add_child(_insert_btn)
	return col


func _make_list(title: String) -> ItemList:
	var list := ItemList.new()
	list.name = title
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.item_selected.connect(func(idx: int): _on_item_selected(list, idx))
	list.item_activated.connect(func(idx: int): _insert(_snippet_of(list.get_item_metadata(idx))))
	_tabs.add_child(list)
	_lists.append(list)
	return list


func _on_item_selected(list: ItemList, idx: int) -> void:
	var meta: Dictionary = list.get_item_metadata(idx)
	_desc.text = meta.desc
	if meta.has("skeleton") and not snippets_filled:
		_desc.text += "\n[color=#7f93b0]Insere só a estrutura: troque cada ??? pelo que o seu robô precisa.[/color]"
	_pending_insert = _snippet_of(meta)
	_insert_btn.disabled = not editor.editable or _pending_insert == ""


func _build_editor() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 2.2
	var top := HBoxContainer.new()
	top.add_child(_header("SEU PROGRAMA"))
	_status = Label.new()
	_status.theme_type_variation = "DimLabel"
	# texto longo não pode alargar a tela (celular): corta com "…"
	_status.clip_text = true
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.text = _txt("Editando — clique em PRONTO para lutar", "Editando")
	top.add_child(_status)
	col.add_child(top)
	editor = LBCodeEditor.new()
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.custom_minimum_size = Vector2(0 if LBDevice.compact() else 360, 160)
	col.add_child(editor)
	return col


func _build_console() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 300
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 1.1
	_right_tabs = TabContainer.new()
	_right_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_right_tabs)
	console = RichTextLabel.new()
	console.name = "Console"
	console.bbcode_enabled = true
	console.scroll_following = true
	console.selection_enabled = true
	_right_tabs.add_child(console)
	_watch = RichTextLabel.new()
	_watch.name = "Variáveis"
	_watch.bbcode_enabled = true
	_watch.text = "[color=#7f93b0]Durante a luta, aqui aparecem os valores dos sensores e das suas variáveis. Use ❚❚ para pausar e PASSO para avançar uma ação por vez.[/color]"
	_right_tabs.add_child(_watch)
	var enemy_box := VBoxContainer.new()
	enemy_box.name = "Inimigo"
	_enemy_title = Label.new()
	_enemy_title.theme_type_variation = "DimLabel"
	_enemy_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_enemy_title.text = "A cada pausa entre turnos, aqui aparece o código que o inimigo usou."
	enemy_box.add_child(_enemy_title)
	enemy_view = LBCodeEditor.new()
	enemy_view.editable = false
	enemy_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemy_view.custom_minimum_size.y = 120
	enemy_box.add_child(enemy_view)
	_right_tabs.add_child(enemy_box)

	var row1 := HBoxContainer.new()
	_row1 = row1
	row1.add_theme_constant_override("separation", 8)
	_btn_validate = Button.new()
	_btn_validate.text = "VALIDAR"
	_btn_validate.tooltip_text = "Confere se o programa está correto, sem lutar. (Ctrl+Enter)"
	_btn_validate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_validate.pressed.connect(func(): validate_requested.emit())
	row1.add_child(_btn_validate)
	_btn_example = Button.new()
	_btn_example.text = "EXEMPLO"
	_btn_example.tooltip_text = "Restaura o programa inicial (pede confirmação)."
	_btn_example.pressed.connect(func(): restore_example_requested.emit())
	row1.add_child(_btn_example)
	_btn_hint = Button.new()
	_btn_hint.text = "DICA"
	_btn_hint.tooltip_text = "Mostra uma dica para esta fase. (F1)"
	_btn_hint.visible = false
	_btn_hint.pressed.connect(func(): hint_requested.emit())
	row1.add_child(_btn_hint)
	col.add_child(row1)

	var row2 := HBoxContainer.new()
	_row2 = row2
	row2.add_theme_constant_override("separation", 8)
	_btn_ready = Button.new()
	_btn_ready.text = "PRONTO  ▶"
	_btn_ready.theme_type_variation = "PrimaryButton"
	_btn_ready.custom_minimum_size.y = 50
	_btn_ready.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_ready.tooltip_text = "Valida o programa e começa a luta. (F5)"
	_btn_ready.pressed.connect(func(): ready_requested.emit())
	row2.add_child(_btn_ready)
	_btn_stop = Button.new()
	_btn_stop.text = "PARAR"
	_btn_stop.theme_type_variation = "DangerButton"
	_btn_stop.custom_minimum_size.y = 50
	_btn_stop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_stop.visible = false
	_btn_stop.pressed.connect(func(): stop_requested.emit())
	row2.add_child(_btn_stop)
	_btn_pause = Button.new()
	_btn_pause.text = "❚❚"
	_btn_pause.tooltip_text = "Pausar / continuar a luta. (Esc)"
	_btn_pause.custom_minimum_size = Vector2(48 if LBDevice.compact() else 56, 50)
	_btn_pause.visible = false
	_btn_pause.pressed.connect(func(): pause_toggled.emit())
	row2.add_child(_btn_pause)
	_btn_step = Button.new()
	_btn_step.text = "PASSO"
	_btn_step.tooltip_text = "Com a luta pausada: avança até o seu robô decidir a próxima ação. (F6)"
	_btn_step.custom_minimum_size = Vector2(70 if LBDevice.compact() else 80, 50)
	_btn_step.visible = false
	_btn_step.pressed.connect(func(): step_requested.emit())
	row2.add_child(_btn_step)
	_btn_speed = Button.new()
	_btn_speed.text = "1x"
	_btn_speed.tooltip_text = "Velocidade da luta (câmera lenta ajuda a entender o código)."
	_btn_speed.custom_minimum_size = Vector2(56 if LBDevice.compact() else 64, 50)
	_btn_speed.visible = false
	_btn_speed.pressed.connect(_cycle_speed)
	row2.add_child(_btn_speed)
	col.add_child(row2)
	return col


# ------------------------------------------------------------ API pública

## (Re)monta a lista de comandos: golpes ainda bloqueados aparecem com ⊘,
## explicam como liberar e não são inseridos no código.
func refresh_locks() -> void:
	if _actions_list == null:
		return
	_actions_list.clear()
	for a in LBRobotAPI.ACTIONS:
		if a in LBRobotAPI.ANTIGOS:
			continue
		var info: Dictionary = LBRobotAPI.ACTIONS[a]
		var locked := LBRobotAPI.bloqueados.has(a)
		var i := _actions_list.add_item(("⊘ " if locked else "") + a + "()")
		var desc := "[b]%s()[/b] — %s" % [a, info.desc]
		if locked:
			desc += "\n[color=#ffc94a]⊘ %s[/color]" % LBRobotAPI.bloqueados[a]
		_actions_list.set_item_metadata(i, {"insert": "" if locked else a + "()", "desc": desc})
		_actions_list.set_item_custom_fg_color(i, LBUITheme.TEXT_DIM if locked else LBCodeEditor.C_ACTION)

## Texto que a Referência insere: exemplo pronto (Fácil) ou estrutura vazia.
func _snippet_of(meta: Dictionary) -> String:
	if meta.has("skeleton") and not snippets_filled:
		return meta.skeleton
	return meta.insert


func _insert(snippet: String) -> void:
	if snippet == "" or not editor.editable:
		return
	if compact:
		_main_tabs.current_tab = 0
	editor.insert_snippet(snippet)


func _cycle_speed() -> void:
	_speed_i = (_speed_i + 1) % SPEEDS.size()
	var v: float = SPEEDS[_speed_i]
	_btn_speed.text = ("%.1fx" % v).replace(".0x", "x").replace(".", ",")
	speed_changed.emit(v)


func current_speed() -> float:
	return SPEEDS[_speed_i]


func set_running(running: bool) -> void:
	editor.editable = not running
	_btn_ready.visible = not running
	_btn_validate.disabled = running
	_btn_example.disabled = running
	_btn_stop.visible = running
	_btn_speed.visible = running
	_btn_pause.visible = running
	_btn_step.visible = running
	_btn_hint.disabled = running
	set_paused(false)
	if running:
		_right_tabs.current_tab = 0
	_insert_btn.disabled = running or _pending_insert == ""
	_status.text = _txt("Lutando — a linha em destaque é a que o robô está executando", "Lutando") if running else _txt("Editando — clique em PRONTO para lutar", "Editando")
	_status.remove_theme_color_override("font_color")
	if not running:
		editor.clear_exec_line()
	_btn_ready.text = "PRONTO  ▶"


## Mostra o código que o inimigo usou (com o nome da tática, se ele tiver).
func show_enemy(title: String, code: String) -> void:
	_enemy_title.text = title
	enemy_view.text = code
	enemy_view.clear_undo_history()


## Relógio da pausa (Médio/Difícil): mostra quanto falta, em vermelho no fim.
func set_planning_time(seconds: float) -> void:
	var sec := int(ceil(seconds))
	_status.text = ("Planejando — %d s" % sec) if LBDevice.compact() else ("Fim do turno — ajuste o código e clique em CONTINUAR · ◷ %d s" % sec)
	_status.add_theme_color_override("font_color", LBUITheme.RED if sec <= 10 else LBUITheme.YELLOW)


## Entre os turnos: o código volta a ser editável e o botão principal vira
## CONTINUAR. PARAR continua disponível (desiste da luta).
func set_planning(planning: bool, proximo_turno: int = 0) -> void:
	if not planning:
		set_running(true)
		return
	set_running(true)
	editor.editable = true
	_btn_ready.visible = true
	_btn_ready.text = "CONTINUAR  ▶" if LBDevice.compact() else "CONTINUAR  ▶  (turno %d)" % proximo_turno
	_btn_validate.disabled = false
	_btn_hint.disabled = false
	_btn_speed.visible = false
	_btn_pause.visible = false
	_btn_step.visible = false
	_insert_btn.disabled = _pending_insert == ""
	_status.text = _txt("Fim do turno — ajuste o código se quiser e clique em CONTINUAR", "Planejando")


static func esc(t: String) -> String:
	return t.replace("[", "[lb]")


func log_clear() -> void:
	console.clear()


func log_line(text: String, color: Color = LBUITheme.TEXT) -> void:
	console.append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), esc(text)])


func log_diagnostic(d: LBDiagnostic) -> void:
	var c := LBUITheme.RED if d.is_error() else LBUITheme.YELLOW
	var where := "Linha %d — " % d.line if d.line > 0 else ""
	console.append_text("[color=#%s][b]%s%s[/b][/color]\n" % [c.to_html(false), "✖ " if d.is_error() else "⚠ ", esc(where + d.message)])
	if d.hint != "":
		console.append_text("[color=#7f93b0]   Dica: %s[/color]\n" % esc(d.hint))


# ------------------------------------------------------------ depuração e dicas

func set_paused(paused: bool) -> void:
	_btn_pause.text = "▶" if paused else "❚❚"
	_btn_step.disabled = not paused
	if paused:
		_status.text = _txt("PAUSADO — veja a aba Variáveis; PASSO avança uma ação", "PAUSADO")


func set_hint_button(visible_: bool, label: String = "DICA") -> void:
	_btn_hint.visible = visible_
	_btn_hint.text = label


## Atualiza a aba Variáveis com os sensores e as variáveis do aluno.
func update_watch(sensors: Dictionary, vars: Dictionary, line: int, action: String) -> void:
	var t := "[b]Executando:[/b] "
	t += ("linha %d — %s()" % [line, action]) if line > 0 and action != "" else "—"
	t += "\n\n[color=#fbbf24][b]SENSORES[/b][/color]\n"
	for k in LBRobotAPI.SENSORS:
		if sensors.has(k):
			t += "%s = %s\n" % [k, _fmt(sensors[k])]
	var own := vars.keys().filter(func(n): return not String(n).begins_with("__"))
	t += "\n[color=#c084fc][b]SUAS VARIÁVEIS[/b][/color]\n"
	if own.is_empty():
		t += "[color=#7f93b0](nenhuma — declare em VAR)[/color]\n"
	for k in own:
		t += "%s = %s\n" % [k, _fmt(vars[k])]
	_watch.text = t


func _fmt(v: Variant) -> String:
	if v is bool:
		return "[color=%s]%s[/color]" % ["#4ade80" if v else "#ff6b7a", "VERDADEIRO" if v else "FALSO"]
	if v is String:
		return "\"%s\"" % esc(v)
	return esc(LBVM.format_value(v))
