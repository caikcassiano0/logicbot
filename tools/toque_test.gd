extends Node
## TESTE: rolagem com o dedo (simula toques). LB_TOQUE=1 LB_DEVICE=celular
var _runner := false
var _f := 0
var _falhas := 0

func _ready():
	if not _runner:
		var r := Node.new(); r.set_script(get_script()); r.set("_runner", true)
		get_tree().root.add_child.call_deferred(r); set_process(false); return
	Progress.data.tutorial_concluido = true
	GameState.save_code(LBBotLibrary.TEMPLATE)
	GameState.start_battle.call_deferred("treino")

func _ok(n: String, c: bool):
	print("  [%s] %s" % ["PASSOU " if c else "FALHOU ", n])
	if not c: _falhas += 1

func _arrasta(p: Vector2, dy: float):
	var t := InputEventScreenTouch.new(); t.position = p; t.pressed = true; Input.parse_input_event(t)
	for i in 10:
		var d := InputEventScreenDrag.new(); d.position = p + Vector2(0, dy * (i + 1) / 10.0); d.relative = Vector2(0, dy / 10.0)
		Input.parse_input_event(d)
	var u := InputEventScreenTouch.new(); u.position = p + Vector2(0, dy); u.pressed = false; Input.parse_input_event(u)

func _process(_d):
	_f += 1
	var sc := get_tree().current_scene
	if sc == null or sc.name != "Battle": return
	var ed: TextEdit = sc.panel.editor
	if _f == 20:
		var txt := "algoritmo \"Longo\"\ninicio\n"
		for i in 60: txt += "   // linha %d\n" % i
		ed.text = txt + "fimalgoritmo\n"
		ed.scroll_vertical = 0
	if _f == 30:
		var r := ed.get_global_rect()
		_arrasta(r.get_center(), -260.0)
	if _f == 40:
		_ok("arrastar o dedo para cima rola o código (linha do topo: %.1f)" % ed.scroll_vertical, ed.scroll_vertical > 2.0)
		var antes := ed.scroll_vertical
		_arrasta(ed.get_global_rect().get_center(), 200.0)
		set_meta("antes", antes)
	if _f == 50:
		_ok("arrastar para baixo volta o código", ed.scroll_vertical < float(get_meta("antes")))
		# lista da Referência (aba Comandos)
		var tabs: TabContainer = sc.panel._main_tabs
		for i in tabs.get_tab_count():
			if tabs.get_tab_title(i) == "Comandos": tabs.current_tab = i
	if _f == 60:
		var lista: ItemList = null
		for n in sc.panel.find_children("*", "ItemList", true, false):
			if n.is_visible_in_tree(): lista = n; break
		_ok("lista da Referência visível", lista != null)
		if lista:
			set_meta("lista", lista)
			_arrasta(lista.get_global_rect().get_center(), -150.0)
	if _f == 70:
		var lista: ItemList = get_meta("lista")
		_ok("arrastar rola a lista de comandos (%.0f px)" % lista.get_v_scroll_bar().value, lista.get_v_scroll_bar().value > 10.0)
		print("Resumo toque: %s" % ("TUDO OK" if _falhas == 0 else "%d falha(s)" % _falhas))
		get_tree().quit(_falhas)
