extends Control
## TELA DE BATALHA — junta tudo:
##   arena 3D + HUD (em cima)  |  painel de programação (embaixo)  |  resultado (sobreposto)
##
## Modos (GameState.mode):
##   "tutorial"  — roteiro guiado (LBTutorial); o resto do jogo só libera ao concluir.
##   "campanha"  — fase com objetivo, requisitos e dicas conforme a dificuldade.
##   "treino"    — luta livre contra um bot.
##
## Fluxo:  EDITANDO → (PRONTO) → INTRO → LUTANDO ⇄ PLANEJANDO → FIM → RESULTADO → EDITANDO
## Luta por turnos: a cada 5 s a luta pausa (PLANEJANDO); o aluno pode mudar o
## código e clica em CONTINUAR. O código novo vale a partir do turno seguinte.
## A simulação roda em passos fixos de 1/60 s (acumulador): velocidade e pausa
## mudam só a exibição, nunca o resultado.

enum State { EDITING, INTRO, FIGHTING, ENDING, RESULT, PLANNING }

const R = preload("res://scripts/combat/lb_combat_rules.gd")
const PLAYER_NAME := "TITAN-A"
const HINTS_ALLOWED := [3, 2, 0]   ## por dificuldade: Fácil, Médio, Difícil
const TEMPO_PLANEJAMENTO := [0.0, 90.0, 45.0]  ## segundos para reprogramar entre turnos (0 = sem limite)

var state: int = State.EDITING
var mode := "treino"
var bot: Dictionary
var fase: Dictionary = {}          ## fase da campanha (ou a usada pelo passo do tutorial)
var tut_i := 0
var dificuldade := 0
var sim: LBCombatSim
var arena: LBArena
var hud: LBBattleHUD
var panel: LBProgrammingPanel
var result_panel: LBResultPanel
var guide: LBGuideCard
var paused := false
var _split: VSplitContainer
var _acc := 0.0
var _speed := 1.0
var _timer := 0.0
var _log_seen := 0
var _watch_t := 0.0
var _hints_shown := 0
var _last_compile: LBCompiler.Result
var _used_step := false
var _confirm: ConfirmationDialog
var _turn_code := ""          ## código que está rodando no turno atual
var _turns_explained := false  ## tutorial: explica os turnos só na primeira pausa
var _plan_left := 0.0          ## tempo que resta para reprogramar (0 = sem limite)
var _plan_tick := 0


func _ready() -> void:
	mode = GameState.mode
	dificuldade = Progress.data.dificuldade
	Sfx.play_music("musica_batalha")
	_build_ui()
	panel.snippets_filled = dificuldade == 0 or mode == "tutorial"
	# golpes de boxe liberados conforme a campanha (o treino respeita o mesmo progresso)
	LBRobotAPI.bloqueados = LBRobotAPI.bloqueios_para(func(fid): return Progress.data.fase_concluida(fid))
	panel.refresh_locks()
	match mode:
		"tutorial":
			_tut_enter(0)
		"campanha":
			fase = LBCampaign.get_fase(GameState.fase_id)
			bot = LBCampaign.bot_of(fase)
			panel.editor.text = GameState.load_fase_code(fase, dificuldade)
			_hints_shown = 1 if dificuldade == 0 else 0
			_show_objective()
			panel.log_line("Fase %d — %s (%s)" % [LBCampaign.index_of(fase.id) + 1, fase.titulo, LBCampaign.DIFICULDADES[dificuldade]], LBUITheme.CYAN)
			panel.log_line(fase.objetivo, LBUITheme.TEXT_DIM)
		_:
			bot = LBBotLibrary.get_bot(GameState.selected_bot_id)
			panel.editor.text = GameState.player_code
			panel.log_line("Oponente: %s — %s (%s)" % [bot.nome, bot.titulo, bot.nivel], Color(bot.cor))
			panel.log_line(bot.descricao, LBUITheme.TEXT_DIM)
			panel.log_line("Escreva a estratégia do seu robô e clique em PRONTO.", LBUITheme.TEXT_DIM)
	panel.editor.clear_undo_history()
	panel.log_line("Atalhos: F5 lutar · Ctrl+Enter validar · Esc pausar · F6 passo · F7 câmera · F1 dica · Ctrl+/Ctrl- tamanho da fonte", LBUITheme.TEXT_DIM)
	_update_hint_button()
	_setup_example_button()
	_reset_idle()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = LBUITheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_split = VSplitContainer.new()
	_split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_split)

	var top := Control.new()
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var compact := LBDevice.compact()
	# no celular a arena fica mais baixa (proporção larga mostra os dois robôs)
	top.size_flags_stretch_ratio = 0.5 if compact else 1.15
	top.custom_minimum_size.y = 230 if compact else 260
	_split.add_child(top)
	var svc := LBVista3D.new()
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top.add_child(svc)
	var sv := svc.sv
	arena = LBArena.new()
	arena.player_look = LBRewards.look_for(Progress.data)
	arena.enemy_look = LBRoboMixamo.look_do_bot(bot)
	# 2.0: cada fase da campanha tem o seu cenário de pós-guerra; no treino, um por bot
	arena.cenario = LBCenarios.escolher(GameState.mode, GameState.fase_id if GameState.mode == "campanha" else GameState.selected_bot_id)
	sv.add_child(arena)
	hud = LBBattleHUD.new()
	top.add_child(hud)

	var back := Button.new()
	back.text = "◀  MENU"
	back.position = Vector2(10, 96) if compact else Vector2(20, 132)
	back.pressed.connect(_go_menu)
	top.add_child(back)

	guide = LBGuideCard.new()
	# à esquerda, para não cobrir os robôs (que ficam no centro da arena)
	if compact:
		# celular: cartão na largura toda, logo abaixo do HUD
		guide.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		guide.offset_left = 8
		guide.offset_right = -8
		guide.offset_top = 92
		guide.compact = true
	else:
		guide.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		guide.offset_left = 20
		guide.offset_top = 178
	guide.visible = false
	top.add_child(guide)

	panel = LBProgrammingPanel.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.y = 420 if compact else 250
	_split.add_child(panel)
	panel.validate_requested.connect(func(): _validate(true))
	panel.ready_requested.connect(_on_ready_pressed)
	panel.stop_requested.connect(_stop_fight)
	panel.speed_changed.connect(func(v): _speed = v)
	panel.restore_example_requested.connect(_on_example_pressed)
	panel.pause_toggled.connect(_toggle_pause)
	panel.step_requested.connect(_step_one_action)
	panel.hint_requested.connect(_show_next_hint)

	result_panel = LBResultPanel.new()
	add_child(result_panel)
	result_panel.edit_requested.connect(_back_to_edit)
	result_panel.rematch_requested.connect(func():
		_back_to_edit()
		_start_fight())
	result_panel.menu_requested.connect(_go_menu)
	result_panel.next_requested.connect(_go_next_fase)

	_confirm = ConfirmationDialog.new()
	_confirm.title = "Restaurar código inicial"
	_confirm.dialog_text = "Substituir o seu código pelo código inicial?\nO código atual será perdido."
	_confirm.ok_button_text = "Substituir"
	_confirm.cancel_button_text = "Cancelar"
	_confirm.confirmed.connect(_restore_starting_code)
	add_child(_confirm)


# ------------------------------------------------------------ código e validação

func _starting_code() -> String:
	if not fase.is_empty():
		return fase.inicio[dificuldade if mode == "campanha" else 0]
	return LBBotLibrary.TEMPLATE


func _restore_starting_code() -> void:
	panel.editor.text = _starting_code()
	_save_code()
	panel.log_line("Código inicial restaurado.", LBUITheme.TEXT_DIM)


func _save_code() -> void:
	match mode:
		"campanha":
			GameState.save_fase_code(fase.id, dificuldade, panel.editor.text)
		"treino":
			GameState.save_code(panel.editor.text)


func _validate(verbose: bool) -> LBCompiler.Result:
	_save_code()
	var r := LBCompiler.compile_source(panel.editor.text)
	_last_compile = r
	panel.editor.clear_error_line()
	if verbose:
		panel.log_clear()
	if not r.ok:
		var e := r.first_error()
		panel.log_diagnostic(e)
		panel.editor.set_error_line(e.line)
		Progress.data.registrar_erro(e.category)
		Progress.save()
		return r
	for w in r.warnings():
		panel.log_diagnostic(w)
	if verbose:
		panel.log_line("✔ Programa válido! %d instruções compiladas." % r.ops.size(), LBUITheme.GREEN)
		if state == State.PLANNING:
			_show_preview()
		if not fase.is_empty():
			var falta := LBCampaign.missing_requirements(fase, r.program)
			if not falta.is_empty():
				panel.log_line("Para esta fase ainda falta: " + ", ".join(falta) + ".", LBUITheme.YELLOW)
	return r


# ------------------------------------------------------------ fluxo da luta

func _reset_idle() -> void:
	sim = LBCombatSim.new()
	sim.setup(null, null, PLAYER_NAME, bot.nome)
	hud.setup(PLAYER_NAME, bot.nome, LBRewards.nivel(Progress.data.xp))
	hud.hide_announce()
	hud.update_from(sim)


func _start_fight() -> void:
	if state != State.EDITING:
		return
	if mode == "tutorial" and LBTutorial.step(tut_i).tipo != "luta":
		panel.log_line("Leia o cartão sobre a arena e clique em PRÓXIMO.", LBUITheme.YELLOW)
		return
	panel.log_clear()
	var r := _validate(false)
	arena.set_enemy_look(LBRoboMixamo.look_do_bot(bot))
	if not r.ok:
		panel.log_line("Corrija o erro acima para lutar.", LBUITheme.TEXT_DIM)
		if mode == "tutorial":
			guide.show_card("TUTORIAL", "Quase lá!", "O código ainda tem um erro — veja a linha em [color=#ff3b4e]vermelho[/color] e a explicação no console.\n[i]%s[/i]" % LBProgrammingPanel.esc(r.first_error().hint))
		return
	if mode == "tutorial":
		var falta := LBCampaign.missing_requirements(fase, r.program)
		if not falta.is_empty():
			guide.show_card("TUTORIAL", "Ainda falta uma coisa", "Para este passo você precisa: [b]%s[/b]." % ", ".join(falta))
			return
	elif mode == "campanha":
		var falta := LBCampaign.missing_requirements(fase, r.program)
		if not falta.is_empty():
			panel.log_line("Atenção: para a vitória contar nesta fase, falta " + ", ".join(falta) + ".", LBUITheme.YELLOW)
		Progress.data.registrar_tentativa(fase.id)
		Progress.save()
	# inimigo com táticas: semente muda a cada luta (variedade), mas é reproduzível
	sim = LBBotLibrary.nova_luta(LBVM.new(r), bot, Progress.data.lutas + 1, PLAYER_NAME)
	sim.turnos = true
	_turn_code = panel.editor.text
	_log_seen = 0
	_acc = 0.0
	paused = false
	_used_step = false
	_speed = panel.current_speed()
	hud.setup(PLAYER_NAME, bot.nome, LBRewards.nivel(Progress.data.xp))
	guide.hide_card()
	panel.set_running(true)
	panel.log_line("▶ Luta iniciada contra %s." % bot.nome, LBUITheme.CYAN)
	state = State.INTRO
	_timer = 0.0
	var onde := LBCenarios.nome(int(arena.cenario)).to_upper() if arena.cenario.is_valid_int() else "ARENA NEON"
	hud.announce("ROUND 1", Color.WHITE, "%s  ·  %s" % [String(bot.titulo).to_upper(), onde], 0.45)
	Sfx.play("round", 0.0)


func _on_ready_pressed() -> void:
	if state == State.PLANNING:
		_continue_turn()
	else:
		_start_fight()


## Fim de um turno: pausa e devolve o código para o aluno.
func _enter_planning(turno: int) -> void:
	state = State.PLANNING
	paused = false
	_flush_program_output()
	_update_watch()
	panel.editor.clear_exec_line()
	panel.set_planning(true, turno + 1)
	_plan_left = 0.0 if mode == "tutorial" else float(TEMPO_PLANEJAMENTO[dificuldade])
	_plan_tick = int(ceil(_plan_left))
	if _plan_left > 0.0:
		panel.set_planning_time(_plan_left)
		panel.log_line("◷ Você tem %d s para ajustar o código (%s)." % [int(_plan_left), LBCampaign.DIFICULDADES[dificuldade]], LBUITheme.TEXT_DIM)
	hud.announce("FIM DO TURNO %d" % turno, LBUITheme.YELLOW, "", 0.6)
	panel.log_line("❚❚ Fim do turno %d de %d. Veja o que aconteceu, ajuste o código se quiser e clique em CONTINUAR." % [turno, sim.total_turnos()], LBUITheme.YELLOW)
	_show_enemy_code(turno)
	_show_preview()
	if mode == "tutorial" and not _turns_explained:
		_turns_explained = true
		guide.show_card("TUTORIAL", "A luta é por turnos",
			"A cada [b]5 segundos[/b] a luta pausa. É a sua chance de [b]mudar o código[/b] — o inimigo também pode mudar o dele.\nSe estiver tudo certo, só clique em [b]CONTINUAR ▶[/b].",
			[["ENTENDI", func(): guide.hide_card(), true]])


## Aba "Inimigo": o código que ele rodou no turno que acabou (nome da tática, se tiver).
func _show_enemy_code(turno: int) -> void:
	if sim.cerebro != null:
		var tat := LBTactics.get_tatica(sim.cerebro.atual)
		panel.show_enemy("Turno %d · tática \"%s\": %s" % [turno, tat.nome, tat.resumo], tat.codigo)
	else:
		panel.show_enemy("Turno %d · o programa do %s" % [turno, bot.nome], bot.codigo)
	if mode != "tutorial":
		panel.log_line("◉ Veja na aba Inimigo o código que o %s usou neste turno." % bot.nome, Color(bot.cor))


## Prévia: o que o SEU programa faria na situação de agora (sem mexer na luta).
func _show_preview() -> void:
	var acoes := preview_actions(panel.editor.text, sim._sensores(0))
	if not acoes.is_empty():
		panel.log_line("▶ Prévia: na situação de agora, seu robô faria " + " → ".join(acoes), Color("a5f3fc"))


## Roda o programa "de mentira" com os sensores parados e devolve as próximas ações.
static func preview_actions(code: String, sensores: Dictionary, quantas := 3) -> Array[String]:
	var out: Array[String] = []
	var r := LBCompiler.compile_source(code)
	if not r.ok:
		return out
	var vm := LBVM.new(r)
	for i in quantas:
		var a := vm.next_action(sensores)
		if a.type != "action":
			break
		out.append(String(a.name) + "()")
	return out


## CONTINUAR: valida o código; se mudou, o programa novo vale a partir deste turno.
## tempo_esgotado: com erro no código, o robô segue com o programa anterior.
func _continue_turn(tempo_esgotado := false) -> void:
	var r := _validate(false)
	if not r.ok and not tempo_esgotado:
		panel.log_line("Corrija o erro acima para continuar a luta.", LBUITheme.TEXT_DIM)
		return
	if not r.ok:
		panel.log_line("◷ Tempo esgotado com erro no código: o robô continua com o programa anterior.", LBUITheme.YELLOW)
	elif tempo_esgotado:
		panel.log_line("◷ Tempo esgotado: a luta continua.", LBUITheme.YELLOW)
	_plan_left = 0.0
	var novo: LBVM = null
	if r.ok and panel.editor.text != _turn_code:
		novo = LBVM.new(r)
		_turn_code = panel.editor.text
		panel.editor.clear_error_line()
	sim.proximo_turno(novo)
	if novo != null:
		_log_seen = 0          # programa novo: o registro de escreval recomeça
	if novo != null:
		panel.log_line("✎ Código novo a partir do turno %d." % sim.turno, LBUITheme.CYAN)
	if sim.ultima_troca != "":
		var tat := LBTactics.get_tatica(sim.ultima_troca)
		panel.log_line("⟳ %s mudou de tática: %s — %s" % [bot.nome, tat.nome, tat.resumo], Color(bot.cor))
	if mode == "tutorial":
		guide.hide_card()
	panel.set_planning(false)
	_speed = panel.current_speed()
	_acc = 0.0
	hud.announce("TURNO %d" % sim.turno, Color.WHITE, "", 0.3)
	state = State.FIGHTING


func _stop_fight() -> void:
	if state == State.INTRO or state == State.FIGHTING or state == State.ENDING or state == State.PLANNING:
		panel.log_line("■ Luta interrompida.", LBUITheme.TEXT_DIM)
		_back_to_edit()


func _back_to_edit() -> void:
	result_panel.visible = false
	state = State.EDITING
	paused = false
	panel.set_running(false)
	_reset_idle()
	if mode == "campanha":
		_show_objective()
	elif mode == "tutorial" and not guide.visible:
		_tut_enter(tut_i)


func _exit_tree() -> void:
	LBRobotAPI.bloqueados = {}   # fora da batalha (testes, menu) nada fica bloqueado


func _go_menu() -> void:
	_save_code()
	GameState.go_to_menu()


func _process(delta: float) -> void:
	match state:
		State.INTRO:
			_timer += delta
			if _timer >= 0.9 and _timer - delta < 0.9:
				hud.announce("LUTEM!", LBUITheme.CYAN, "", 0.35)
				Sfx.play("lutem", 0.0)
				Sfx.play("sino", 0.0, -4.0)
			if _timer >= 1.5:
				state = State.FIGHTING
		State.FIGHTING:
			if not paused and arena.hitstop > 0.0:
				arena.hitstop -= delta   # golpe forte: a luta "congela" por um instante
			elif not paused:
				_acc += delta * _speed
				var guard := 0
				while _acc >= R.DT and state == State.FIGHTING and guard < 8:
					_acc -= R.DT
					guard += 1
					_sim_step()
				_watch_t += delta
				if _watch_t >= 0.1:
					_watch_t = 0.0
					_update_watch()
			_update_exec_line()
			_flush_program_output()
		State.PLANNING:
			if _plan_left > 0.0:
				_plan_left = maxf(0.0, _plan_left - delta)
				panel.set_planning_time(_plan_left)
				var s_int := int(ceil(_plan_left))
				if s_int != _plan_tick:
					_plan_tick = s_int
					if s_int <= 5 and s_int > 0:
						Sfx.play("ui_clique", 0.0)
				if _plan_left <= 0.0:
					_continue_turn(true)
		State.ENDING:
			_timer += delta
			if _timer >= 3.0:
				_finish()
	var vis_delta := 0.0 if paused else delta * (_speed if state == State.FIGHTING else 1.0)
	arena.sync_with_sim(sim, vis_delta)
	hud.update_from(sim)


func _sim_step() -> void:
	var ev := sim.step()
	arena.handle_events(ev, sim)
	_on_events(ev)


# ------------------------------------------------------------ depuração

func _toggle_pause() -> void:
	if state != State.FIGHTING:
		return
	paused = not paused
	panel.set_paused(paused)
	if paused:
		_update_watch()
		var f := sim.lutadores[0]
		panel.log_line("❚❚ Pausado na linha %d (%s())." % [f.acao_linha, f.acao] if f.acao_linha > 0 else "❚❚ Pausado.", LBUITheme.TEXT_DIM)


## Avança a simulação até o robô do jogador decidir a próxima ação.
func _step_one_action() -> void:
	if state != State.FIGHTING or not paused:
		return
	_used_step = true
	var vm := sim.lutadores[0].vm
	var target := vm.decisions + 1
	var n := 0
	while vm.decisions < target and not sim.terminou and n < 900:
		_sim_step()
		n += 1
	_update_exec_line()
	_flush_program_output()
	_update_watch()
	var f := sim.lutadores[0]
	if f.acao_linha > 0:
		panel.log_line("▸ Linha %d: %s()" % [f.acao_linha, f.acao], Color("a5f3fc"))


func _update_watch() -> void:
	var f := sim.lutadores[0]
	if f.vm == null:
		return
	panel.update_watch(sim._sensores(0), f.vm.vars, f.acao_linha, f.acao)


# ------------------------------------------------------------ eventos e fim

func _on_events(events: Array) -> void:
	for e in events:
		match e.tipo:
			"erro_programa":
				if e.lutador == 0:
					panel.log_diagnostic(e.diagnostico)
					panel.editor.set_error_line(e.diagnostico.line)
					Progress.data.registrar_erro(e.diagnostico.category)
			"nocaute_folego":
				var quem: String = PLAYER_NAME if e.alvo == 0 else String(bot.nome)
				panel.log_line("✸ %s ficou sem fôlego e foi derrubado por %s()!" % [quem, e.acao], LBUITheme.RED)
			"sem_energia":
				if e.lutador == 0:
					panel.log_line("⚠ Linha %d: %s() sem energia suficiente — o robô perdeu tempo." % [e.linha, e.acao], LBUITheme.YELLOW)
			"fim_turno":
				if not sim.terminou:
					_enter_planning(e.turno)
			"fim_luta":
				state = State.ENDING
				paused = false
				_timer = 0.0
				_flush_program_output()
				var win: bool = e.vencedor == 0
				hud.announce("K.O." if e.motivo == "nocaute" else "TEMPO!", LBUITheme.RED if e.motivo == "nocaute" else LBUITheme.YELLOW, "", 0.9)
				var title := "VITÓRIA" if win else ("EMPATE" if e.vencedor == 2 else "DERROTA")
				var color := LBUITheme.CYAN if win else (LBUITheme.YELLOW if e.vencedor == 2 else LBUITheme.RED)
				get_tree().create_timer(1.4).timeout.connect(func():
					if state == State.ENDING:
						hud.announce(title, color, "", 1.4)
						Sfx.play("vitoria" if win else "derrota", 0.0))
				panel.log_line("■ Fim da luta: %s." % title.to_lower(), color)


func _finish() -> void:
	state = State.RESULT
	panel.set_running(false)
	var win := sim.vencedor == 0
	Progress.data.registrar_luta(win)
	match mode:
		"tutorial":
			Progress.save()
			_tut_result(win)
			return
		"campanha":
			_campaign_result(win)
		_:
			result_panel.show_result(sim, bot)
			var rr := LBRewards.processar(Progress.data, _reward_ctx(win, false))
			_show_rewards(rr)
			_give_coins(true)
	Progress.save()


## 2.0: moedas pela qualidade do algoritmo (LBCoins). Só ganha o que superar o recorde.
func _give_coins(requisitos_ok: bool) -> void:
	var prog: Dictionary = _last_compile.program if _last_compile != null and _last_compile.ok else {}
	var n := LBCoins.nota(sim, prog, requisitos_ok)
	var k := LBCoins.chave(mode, String(fase.get("id", "")), String(bot.get("id", "")))
	var r := LBCoins.receber(Progress.data, k, int(n.total))
	result_panel.set_coins_info(n, r, Progress.data.moedas)
	if int(r.ganho) > 0:
		get_tree().create_timer(0.3).timeout.connect(func(): Sfx.play("moedas_contagem", 0.0, -2.0))


func _reward_ctx(win: bool, cumpriu: bool) -> Dictionary:
	var p := sim.lutadores[0]
	return {
		"modo": mode, "venceu": win, "fase_id": fase.get("id", ""), "cumpriu_requisitos": cumpriu,
		"vida": p.vida, "dificuldade": dificuldade,
		"tentativas": int(Progress.data.fases.get(fase.get("id", ""), {}).get("tentativas", 0)),
		"bot_id": bot.get("id", ""), "usou_passo": _used_step,
		"usou_escreval": p.vm != null and not p.vm.output_log.is_empty(),
		"especiais": p.stats.especiais_ok, "falhas_energia": p.stats.falhas_sem_energia,
		"dano_recebido": p.stats.dano_recebido,
	}


func _show_rewards(rr: Dictionary) -> void:
	result_panel.set_rewards_info(LBRewards.resumo_texto(rr, Progress.data))
	if rr.nivel_depois > rr.nivel_antes:
		get_tree().create_timer(0.6).timeout.connect(func(): Sfx.play("nivel", 0.0))
	elif not rr.conquistas.is_empty():
		get_tree().create_timer(0.6).timeout.connect(func(): Sfx.play("conquista", 0.0))


func _campaign_result(win: bool) -> void:
	result_panel.show_result(sim, bot)
	var falta := LBCampaign.missing_requirements(fase, _last_compile.program)
	var vida_min := int(fase.get("requisitos", {}).get("vida_minima", 0))
	var vida := sim.lutadores[0].vida
	var ok := win and falta.is_empty() and vida >= vida_min
	_show_rewards(LBRewards.processar(Progress.data, _reward_ctx(win, ok)))
	_give_coins(falta.is_empty())
	if ok:
		var idx := LBCampaign.index_of(fase.id)
		var has_next := idx + 1 < LBCampaign.count()
		result_panel.set_campaign_info("★ FASE CONCLUÍDA! " + ("Próxima fase liberada." if has_next else "Você venceu a campanha!"), LBUITheme.GREEN, has_next)
	elif win and not falta.is_empty():
		result_panel.set_campaign_info("Vitória, mas a fase ainda não conta: falta " + ", ".join(falta) + ".", LBUITheme.YELLOW, false)
	elif win:
		result_panel.set_campaign_info("Vitória, mas esta fase pede terminar com vida ≥ %d (você terminou com %d)." % [vida_min, vida], LBUITheme.YELLOW, false)
	else:
		var msg := "Ainda não foi desta vez — veja a análise e tente de novo."
		if dificuldade == 0 and _hints_shown < fase.dicas.size():
			_hints_shown += 1
			msg += " Uma nova dica foi liberada."
		result_panel.set_campaign_info(msg, LBUITheme.TEXT_DIM, false)
	_update_hint_button()


func _go_next_fase() -> void:
	var idx := LBCampaign.index_of(fase.id)
	if idx + 1 < LBCampaign.count():
		GameState.start_campaign(LBCampaign.FASES[idx + 1].id)


# ------------------------------------------------------------ campanha: objetivo e dicas

func _hints_allowed() -> int:
	if mode == "tutorial":
		return 3
	if mode == "campanha":
		return HINTS_ALLOWED[dificuldade]
	return 0


func _update_hint_button() -> void:
	var allowed := _hints_allowed()
	var remaining := mini(allowed, fase.get("dicas", []).size()) - _hints_shown
	panel.set_hint_button(allowed > 0 and not fase.is_empty(), "DICA (%d)" % maxi(remaining, 0))


func _show_next_hint() -> void:
	var dicas: Array = fase.get("dicas", [])
	if _hints_shown < mini(_hints_allowed(), dicas.size()):
		_hints_shown += 1
	_update_hint_button()
	if mode == "campanha":
		_show_objective()
	elif mode == "tutorial":
		_tut_enter(tut_i)
	if _hints_shown > 0:
		panel.log_line("✦ Dica: " + dicas[_hints_shown - 1], LBUITheme.YELLOW)


## EXEMPLO (2.0): Fácil mostra o que pôr no lugar dos ???; Médio dá uma dica; Difícil não tem.
func _setup_example_button() -> void:
	var b: Button = panel._btn_example
	b.visible = dificuldade < 2 or mode == "tutorial"
	if mode in ["campanha", "tutorial"]:
		b.tooltip_text = "Mostra o que colocar no código." if dificuldade == 0 or mode == "tutorial" else "Mostra uma dica."


func _on_example_pressed() -> void:
	if not (mode in ["campanha", "tutorial"]) or fase.is_empty():
		_confirm.popup_centered()   # treino livre: volta ao programa inicial
		return
	if dificuldade == 1 and mode == "campanha":
		var dicas: Array = fase.get("dicas", [])
		if _hints_shown < dicas.size():
			_hints_shown += 1
			_update_hint_button()
			_show_objective()
			panel.log_line("✦ Dica: " + dicas[_hints_shown - 1], LBUITheme.YELLOW)
		else:
			guide.show_card("EXEMPLO", "Você já viu todas as dicas", "Releia as dicas da fase e veja a aba [b]Comandos[/b] (Comandos e Sensores): clique num item para ler o que ele faz.",
				[["OK", func(): guide.hide_card(), false]])
		return
	var ex := example_text(fase, panel.editor.text)
	guide.show_card("EXEMPLO  ·  FÁCIL", "O que colocar no código", ex,
		[["OK", func():
			if mode == "tutorial":
				_tut_enter(tut_i)
			else:
				_show_objective(), false]], true)
	# também no Console (no celular o cartão é pequeno; lá dá para ler com calma)
	panel.log_line("❖ EXEMPLO — " + example_text(fase, panel.editor.text, false), LBUITheme.CYAN)


## Texto do exemplo: as linhas da solução que entram no lugar dos ??? (ou a solução inteira).
static func example_text(f: Dictionary, atual: String, bb := true) -> String:
	var sol: PackedStringArray = String(f.get("solucao", "")).split("\n")
	var esq: PackedStringArray = String(f.get("inicio", [""])[0]).split("\n")
	var cod := func(x: String) -> String: return ("[code]%s[/code]" % LBProgrammingPanel.esc(x)) if bb else x
	var t := ""
	if atual.contains("???") and sol.size() == esq.size():
		t = ("No lugar dos [color=#ffc94a]???[/color], coloque:\n" if bb else "No lugar dos ???, coloque:\n")
		for i in esq.size():
			if esq[i].contains("???"):
				t += cod.call("Linha %d:  %s" % [i + 1, sol[i].strip_edges()]) + "\n"
		t += ("[color=#7f93b0]Tente entender POR QUE funciona — é isso que vale nas próximas fases![/color]" if bb else "Tente entender POR QUE funciona!")
	else:
		t = "Um programa que vence esta fase:\n" + cod.call(String(f.get("solucao", "")).strip_edges())
	return t


func _hints_bbcode() -> String:
	var t := ""
	var dicas: Array = fase.get("dicas", [])
	for i in mini(_hints_shown, dicas.size()):
		t += "\n[color=#ffc94a]✦ %s[/color]" % LBProgrammingPanel.esc(dicas[i])
	return t


func _show_objective() -> void:
	var idx := LBCampaign.index_of(fase.id)
	var body := "%s\n[color=#7f93b0]%s[/color]" % [LBProgrammingPanel.esc(fase.objetivo), LBCampaign.requirements_text(fase)]
	body += _hints_bbcode()
	guide.show_card("FASE %d/%d  ·  %s  ·  %s" % [idx + 1, LBCampaign.count(), String(fase.conceito).to_upper(), LBCampaign.DIFICULDADES[dificuldade].to_upper()],
		fase.titulo, body, [["OCULTAR", func(): guide.hide_card(), false]])


# ------------------------------------------------------------ tutorial

func _tut_enter(i: int) -> void:
	tut_i = i
	var st := LBTutorial.step(i)
	var tag := "TUTORIAL  ·  %d/%d" % [i + 1, LBTutorial.count()]
	match st.tipo:
		"info":
			if bot.is_empty():
				fase = LBCampaign.get_fase("f1_sequencia")
				bot = LBCampaign.bot_of(fase)
				panel.editor.text = fase.inicio[0]
			guide.show_card(tag, st.titulo, st.texto, [["PRÓXIMO ▶", func(): _tut_enter(tut_i + 1), true]])
		"luta":
			var new_fase := LBCampaign.get_fase(st.fase)
			if fase.get("id", "") != new_fase.id or panel.editor.text.strip_edges() == "":
				fase = new_fase
				bot = LBCampaign.bot_of(fase)
				panel.editor.text = fase.inicio[0]
				_hints_shown = 0
				_reset_idle()
			var body: String = st.texto + _hints_bbcode()
			guide.show_card(tag, st.titulo, body, [["DICA", _show_next_hint, false]])
			_update_hint_button()
		"fim":
			var rr := LBRewards.processar(Progress.data, {"modo": "tutorial"})
			Progress.save()
			if not rr.conquistas.is_empty():
				Sfx.play("conquista", 0.0)
			guide.show_card(tag, st.titulo, st.texto + "\n[color=#ffc94a]%s[/color]" % LBRewards.resumo_texto(rr, Progress.data), [
				["MENU", _go_menu, false],
				["IR PARA A CAMPANHA ▶", func(): GameState.start_campaign(LBCampaign.FASES[0].id), true],
			])


func _tut_result(win: bool) -> void:
	var st := LBTutorial.step(tut_i)
	var p := sim.lutadores[0]
	var stats := "\n[color=#7f93b0]Acertos: %d de %d ataques · dano causado: %d · instruções executadas: %d[/color]" % [
		p.stats.acertos, p.stats.ataques, p.stats.dano_causado, p.vm.instructions_executed if p.vm else 0]
	state = State.EDITING
	_reset_idle()
	if win:
		guide.show_card("TUTORIAL  ·  RESULTADO", "Vitória!", st.sucesso + stats, [["CONTINUAR ▶", func(): _tut_enter(tut_i + 1), true]])
	else:
		var sug := LBFightAnalyzer.analisar(sim)
		var expl := "Seu robô não venceu desta vez."
		if not sug.is_empty():
			expl += "\n[b]%s:[/b] %s" % [LBProgrammingPanel.esc(sug[0].titulo), LBProgrammingPanel.esc(sug[0].texto)]
		guide.show_card("TUTORIAL  ·  RESULTADO", "Vamos tentar de novo", expl + stats, [["TENTAR DE NOVO", func(): _tut_enter(tut_i), true]])


# ------------------------------------------------------------ exibição

func _update_exec_line() -> void:
	var f := sim.lutadores[0]
	if f.acao_linha > 0 and f.acao != "":
		panel.editor.set_exec_line(f.acao_linha)


func _flush_program_output() -> void:
	var vm := sim.lutadores[0].vm
	if vm == null:
		return
	while _log_seen < vm.output_log.size():
		panel.log_line("» " + vm.output_log[_log_seen], Color("a5f3fc"))
		_log_seen += 1



# ------------------------------------------------------------ atalhos de teclado

func _unhandled_key_input(event: InputEvent) -> void:
	_shortcut(event)


func _input(event: InputEvent) -> void:
	# O editor de código "come" as teclas; os atalhos com F e Ctrl precisam vir antes dele.
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode in [KEY_F1, KEY_F5, KEY_F6, KEY_F7, KEY_ESCAPE] or (k.ctrl_pressed and k.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_EQUAL, KEY_PLUS, KEY_KP_ADD, KEY_MINUS, KEY_KP_SUBTRACT]):
			if _shortcut(event):
				get_viewport().set_input_as_handled()


func _shortcut(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	var k := event as InputEventKey
	if k.ctrl_pressed and k.keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD, KEY_MINUS, KEY_KP_SUBTRACT]:
		var delta := -1 if k.keycode in [KEY_MINUS, KEY_KP_SUBTRACT] else 1
		GameSettings.editor_font_size = clampi(GameSettings.editor_font_size + delta, 13, 26)
		GameSettings.save_settings()
		panel.editor.apply_font_size(GameSettings.editor_font_size)
		return true
	if result_panel.visible:
		return false
	match k.keycode:
		KEY_F5:
			if state == State.EDITING:
				_start_fight()
				return true
			if state == State.PLANNING:
				_continue_turn()
				return true
		KEY_ENTER, KEY_KP_ENTER:
			if k.ctrl_pressed and state == State.EDITING:
				_validate(true)
				return true
		KEY_ESCAPE:
			if state == State.FIGHTING:
				_toggle_pause()
				return true
		KEY_F7:
			# troca o estilo da câmera da luta (também nas Configurações)
			GameSettings.camera_style = (GameSettings.camera_style + 1) % GameSettings.CAMERA_NAMES.size()
			GameSettings.save_settings()
			hud.announce("CÂMERA: " + String(GameSettings.CAMERA_NAMES[GameSettings.camera_style]).to_upper(), Color.WHITE, "", 0.4)
			return true
		KEY_F6:
			if state == State.FIGHTING and paused:
				_step_one_action()
				return true
		KEY_F1:
			if state == State.EDITING and panel._btn_hint.visible:
				_show_next_hint()
				return true
	return false
