extends Node
## FERRAMENTA DE DESENVOLVIMENTO: roda uma luta real em tempo de jogo, para gravar
## com o Movie Maker da Godot:
##   godot --path . --write-movie saida.png --fixed-fps 30 res://tools/preview_video.tscn

const R = preload("res://scripts/combat/lb_combat_rules.gd")
const PLAYER_CODE := """algoritmo "ContraAtaque"
inicio
   se inimigo_atacando entao
      defender()
      atacar()
   senao se inimigo_perto e nao inimigo_defendendo entao
      atacar()
   senao se nao inimigo_perto entao
      avancar()
   senao
      aguardar()
   fimse
fimalgoritmo
"""

var arena: LBArena
var hud: LBBattleHUD
var sim: LBCombatSim
var _acc := 0.0
var _intro := 1.6
var _after := -1.0
var _pausa := 0.0


func _vm(src: String) -> LBVM:
	return LBVM.new(LBCompiler.compile_source(src))


func _ready() -> void:
	GameSettings.quality = int(OS.get_environment("LB_QUALITY")) if OS.get_environment("LB_QUALITY") != "" else 1
	if OS.get_environment("LB_CAM") != "":
		GameSettings.camera_style = int(OS.get_environment("LB_CAM"))
	arena = LBArena.new()
	if OS.get_environment("LB_CENARIO") != "":
		arena.cenario = OS.get_environment("LB_CENARIO")
	var bot_id0 := OS.get_environment("LB_BOT") if OS.get_environment("LB_BOT") != "" else "maestro"
	arena.enemy_look = LBRoboMixamo.look_do_bot(LBBotLibrary.get_bot(bot_id0))
	if OS.get_environment("LB_PECAS") != "":
		arena.player_look = {"pintura": Color("1e40af"), "brilho": Color("22d3ee"), "danca": "danca_hiphop_3",
			"pecas": {"ombreiras": "ombro_titan", "capacete": "cap_antenas", "nucleo": "nucleo_reator"}}
	add_child(arena)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = LBBattleHUD.new()
	layer.add_child(hud)
	var bot_id := OS.get_environment("LB_BOT") if OS.get_environment("LB_BOT") != "" else "maestro"
	var bot := LBBotLibrary.get_bot(bot_id)
	var codigo := PLAYER_CODE
	if OS.get_environment("LB_FASE") != "":
		codigo = LBCampaign.get_fase(OS.get_environment("LB_FASE")).solucao
	sim = LBBotLibrary.nova_luta(_vm(codigo), bot, 1)
	hud.setup("TITAN-A", bot.nome)
	hud.announce("ROUND 1", Color.WHITE, "", 0.5)
	get_tree().create_timer(0.9).timeout.connect(func(): hud.announce("LUTEM!", Color("22d3ee"), "", 0.4))


func _process(delta: float) -> void:
	if _intro > 0.0:
		_intro -= delta
	elif arena.hitstop > 0.0:
		arena.hitstop -= delta
	elif _pausa > 0.0:
		_pausa -= delta
		if _pausa <= 0.0:
			sim.proximo_turno()
			if sim.ultima_troca != "":
				hud.announce("TÁTICA: " + String(LBTactics.get_tatica(sim.ultima_troca).nome).to_upper(), Color("f59e0b"), "", 0.6)
	elif not sim.terminou:
		_acc += delta
		while _acc >= R.DT and not sim.terminou:
			_acc -= R.DT
			var ev := sim.step()
			arena.handle_events(ev, sim)
			if sim.aguardando_turno and not sim.terminou:
				_pausa = 1.0
				hud.announce("FIM DO TURNO %d" % sim.turno, Color.WHITE, "", 0.5)
				break
			for e in ev:
				if e.tipo == "fim_luta":
					_after = 0.0
					var win: bool = e.vencedor == 0
					hud.announce("K.O.", Color("ff3b4e"), "", 0.8)
					get_tree().create_timer(1.4).timeout.connect(func():
						hud.announce("VITÓRIA" if win else "DERROTA", Color("22d3ee") if win else Color("ff3b4e"),
							"TITAN-A VENCEU POR NOCAUTE" if win else "", 0.0))
	arena.sync_with_sim(sim, delta)
	hud.update_from(sim)
	if _after >= 0.0:
		_after += delta
		if _after > 9.5:
			get_tree().quit()
