extends Node
## TESTE DE FUMAÇA da interface (sem placa de vídeo):
##   godot --headless --path . --fixed-fps 60 res://tools/smoke_test.tscn
## ATENÇÃO: apaga o progresso salvo (user://progresso.json) para começar do zero.
## Percorre: menu bloqueado → tutorial completo → campanha (fase 1) → depuração → treino livre.

var _is_runner := false
var _step := 0
var _frames := 0
var _fails := 0
var _planejamentos := 0   ## quantas vezes a luta pausou entre turnos
var _esgotou_turno := 0
var _relogio_testado := false


func _find_label(n: Node, prefixo: String) -> bool:
	if n is Label and (n as Label).text.begins_with(prefixo):
		return true
	for c in n.get_children():
		if _find_label(c, prefixo):
			return true
	return false


func _ok(name: String, cond: bool) -> void:
	print("  [%s] %s" % ["PASSOU " if cond else "FALHOU ", name])
	if not cond:
		_fails += 1


func _ready() -> void:
	if not _is_runner:
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set("_is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		set_process(false)
		return
	print("== Teste de fumaça da interface ==")
	Progress.reset_all()
	Progress.data.dificuldade = 1
	get_tree().change_scene_to_file.call_deferred("res://scenes/main_menu/main_menu.tscn")


func _next(step: int) -> void:
	_step = step
	_frames = 0


func _find_button(root: Node, prefix: String) -> Button:
	for n in root.find_children("*", "Button", true, false):
		if (n as Button).text.begins_with(prefix):
			return n
	return null


func _fight_done(sc) -> bool:
	return sc.state == sc.State.RESULT or (sc.mode == "tutorial" and sc.state == sc.State.EDITING and sc.guide.visible and sc._timer > 0.0)


func _process(_d: float) -> void:
	_frames += 1
	var sc = get_tree().current_scene
	# Luta por turnos: a cada 5 s a luta pausa. Na primeira pausa confere a tela;
	# depois continua sozinho (como um aluno que clica em CONTINUAR).
	if sc != null and sc.name == "Battle" and sc.state == sc.State.PLANNING:
		_planejamentos += 1
		if _planejamentos == 1:
			var passos: int = sc.sim.passos
			_ok("a luta pausa no fim do turno 1", sc.sim.aguardando_turno and sc.sim.turno == 1)
			_ok("na pausa o código pode ser editado", sc.panel.editor.editable)
			_ok("o botão principal vira CONTINUAR", sc.panel._btn_ready.visible and sc.panel._btn_ready.text.begins_with("CONTINUAR"))
			_ok("na pausa, a aba Inimigo mostra o código dele", sc.panel.enemy_view.text.contains("algoritmo"))
			_ok("na pausa, aparece a prévia do que o seu robô faria", sc.panel.console.get_parsed_text().contains("Prévia"))
			sc.panel.editor.text += "\n// ajuste feito no intervalo"
			sc.panel.ready_requested.emit()
			_ok("CONTINUAR retoma a luta no turno 2", sc.state == sc.State.FIGHTING and sc.sim.turno == 2 and sc.sim.passos == passos)
			_ok("código alterado no intervalo é avisado", sc.panel.console.get_parsed_text().contains("Código novo a partir do turno 2"))
		elif sc.mode == "tutorial":
			if _planejamentos == 2:
				_ok("no tutorial a pausa não tem relógio", sc._plan_left == 0.0)
			sc.panel.ready_requested.emit()
		elif not _relogio_testado:
			_relogio_testado = true
			_ok("Médio: a pausa tem relógio de 90 s", sc._plan_left > 88.0 and sc._plan_left <= 90.0)
			sc._plan_left = 0.001   # simula o tempo acabando
			_esgotou_turno = sc.sim.turno
		else:
			sc.panel.ready_requested.emit()
		return
	if _esgotou_turno > 0 and sc != null and sc.name == "Battle":
		_ok("tempo esgotado: a luta continua sozinha", sc.state != sc.State.PLANNING and sc.sim.turno == _esgotou_turno + 1)
		_esgotou_turno = 0
	match _step:
		0:
			if _frames > 45:
				_ok("menu principal abre", sc != null and sc.name == "MainMenu")
				var camp := _find_button(sc, "CAMPANHA")
				var treino := _find_button(sc, "TREINO LIVRE")
				_ok("antes do tutorial, CAMPANHA está bloqueada", camp != null and camp.disabled)
				_ok("antes do tutorial, TREINO LIVRE está bloqueado", treino != null and treino.disabled)
				_ok("botão COMEÇAR TUTORIAL existe", _find_button(sc, "▶  COMEÇAR TUTORIAL") != null)
				GameState.start_tutorial()
				_next(1)
		1:
			if _frames > 45:
				_ok("tutorial abre na tela de batalha", sc.name == "Battle" and sc.mode == "tutorial" and sc.guide.visible)
				sc.panel.ready_requested.emit()
				_ok("no passo de explicação, PRONTO não inicia luta", sc.state == sc.State.EDITING)
				sc._tut_enter(sc.tut_i + 1)
				sc._tut_enter(sc.tut_i + 1)
				_ok("chega ao passo da sequência", LBTutorial.step(sc.tut_i).id == "sequencia")
				sc.panel.ready_requested.emit()
				_ok("código com lacunas ??? não inicia a luta", sc.state == sc.State.EDITING)
				sc.panel.editor.text = "algoritmo \"x\"\ninicio\n   avancar()\nfimalgoritmo"
				sc.panel.ready_requested.emit()
				_ok("requisito faltando (jab) é avisado antes da luta", sc.state == sc.State.EDITING and sc.guide.visible and sc.guide._body.text.contains("jab()"))
				sc.panel.editor.text = sc.fase.solucao
				sc.panel.ready_requested.emit()
				_ok("código correto inicia a luta do tutorial", sc.state == sc.State.INTRO)
				_next(2)
		2:
			sc._speed = 2.0
			if sc.state == sc.State.EDITING and sc._timer > 0.0:
				_ok("após a luta, o tutorial explica o resultado", sc.guide.visible and sc.guide._title.text == "Vitória!")
				sc._tut_enter(sc.tut_i + 1)
				_ok("avança para o passo do SE", LBTutorial.step(sc.tut_i).id == "se")
				sc.panel.editor.text = sc.fase.solucao
				sc.panel.ready_requested.emit()
				_next(3)
		3:
			sc._speed = 2.0
			if sc.state == sc.State.EDITING and sc._timer > 0.0:
				sc._tut_enter(sc.tut_i + 1)
				_ok("tutorial concluído é salvo", Progress.data.tutorial_concluido)
				GameState.go_to_menu()
				_next(4)
		4:
			if _frames > 45:
				var camp := _find_button(sc, "CAMPANHA")
				_ok("depois do tutorial, CAMPANHA libera", camp != null and not camp.disabled)
				GameState.start_campaign("f1_sequencia")
				_next(5)
		5:
			if _frames > 45:
				_ok("fase 1 abre com objetivo visível", sc.mode == "campanha" and sc.guide.visible)
				_ok("Médio começa com esqueleto (sem ???)", not sc.panel.editor.text.contains("???"))
				sc._show_next_hint()
				_ok("Médio permite pedir dica", sc._hints_shown == 1)
				sc.panel.editor.text = sc.fase.solucao
				sc.panel.ready_requested.emit()
				_next(6)
		6:
			if sc.state == sc.State.FIGHTING and _frames > 120 and not sc.paused:
				sc._toggle_pause()
				_ok("pausa congela a luta", sc.paused)
				var passos: int = sc.sim.passos
				for i in 5:
					sc._process(1.0 / 60.0)
				_ok("pausado, a simulação não anda", sc.sim.passos == passos)
				var dec: int = sc.sim.lutadores[0].vm.decisions
				sc._step_one_action()
				_ok("PASSO avança exatamente uma decisão do robô", sc.sim.lutadores[0].vm.decisions == dec + 1)
				_ok("aba Variáveis mostra sensores", sc.panel._watch.get_parsed_text().contains("inimigo_perto"))
				sc._toggle_pause()
				_next(7)
		7:
			sc._speed = 2.0
			if sc.state == sc.State.RESULT:
				_ok("fase 1 concluída e salva", Progress.data.fase_concluida("f1_sequencia"))
				_ok("experiência foi ganha (tutorial + fase)", Progress.data.xp > LBRewards.XP_TUTORIAL)
				_ok("conquista do depurador registrada (usou PASSO)", Progress.data.conquistas.has("depurador"))
				_ok("resultado mostra XP/nível", sc.result_panel._rewards_lbl.visible and sc.result_panel._rewards_lbl.text.contains("Nível"))
				_ok("botão PRÓXIMA FASE aparece", sc.result_panel._btn_next.visible)
				_ok("fase 2 desbloqueada", Progress.data.fase_desbloqueada(1))
				sc.result_panel.next_requested.emit()
				_next(8)
		8:
			if _frames > 45:
				_ok("PRÓXIMA FASE abre a fase 2", sc.mode == "campanha" and sc.fase.id == "f2_se_senao")
				GameState.start_battle("treino")
				_next(9)
		9:
			if _frames > 45:
				sc.panel.editor.text = LBBotLibrary.TEMPLATE
				var fs: int = GameSettings.editor_font_size
				var plus := InputEventKey.new()
				plus.keycode = KEY_EQUAL
				plus.ctrl_pressed = true
				plus.pressed = true
				sc._shortcut(plus)
				_ok("Ctrl+= aumenta a fonte do editor", GameSettings.editor_font_size == mini(fs + 1, 26))
				var minus := plus.duplicate()
				minus.keycode = KEY_MINUS
				sc._shortcut(minus)
				var f5 := InputEventKey.new()
				f5.keycode = KEY_F5
				f5.pressed = true
				sc._shortcut(f5)
				_ok("F5 inicia a luta (treino livre)", sc.state == sc.State.INTRO)
				_next(10)
		10:
			sc._speed = 2.0
			if sc.state == sc.State.RESULT:
				_ok("treino livre mostra resultado", sc.result_panel.visible)
				_ok("lutas são contadas no progresso", Progress.data.lutas >= 4)
				Progress.data.xp = 1000
				GameState.go_to_menu()
				_next(11)
		11:
			if _frames > 45:
				var g := _find_button(sc, "GARAGEM")
				_ok("botão GARAGEM liberado", g != null and not g.disabled)
				g.pressed.emit()
				_ok("garagem abre", sc._garage.visible)
				_ok("garagem mostra as moedas", _find_label(sc._garage, "MOEDAS:"))
				Progress.data.moedas = 500
				sc._refresh_garage()
				var antenas := _find_button(sc._garage, "Antenas")
				_ok("peça Antenas aparece na loja", antenas != null and not antenas.disabled)
				antenas.pressed.emit()
				_ok("comprar desconta as moedas (500 - 110)", Progress.data.moedas == 390)
				_ok("peça comprada fica equipada no robô do menu", sc._arena.player_visual.pecas.get("capacete", "") == "cap_antenas")
				_ok("dança grátis Hip Hop 3 já vem equipada", _find_button(sc._garage, "✔ Hip Hop 3") != null)
				_ok("as lutas pausaram entre os turnos (%d pausas)" % _planejamentos, _planejamentos >= 3)
				Progress.reset_all()
				print("Resumo do teste de fumaça: %s" % ("TUDO OK" if _fails == 0 else "%d falha(s)" % _fails))
				get_tree().quit(1 if _fails > 0 else 0)
	if _frames > 60 * 120:
		_ok("etapa %d terminou a tempo" % _step, false)
		get_tree().quit(1)
