extends Node
## FERRAMENTA DE DESENVOLVIMENTO: roda uma luta real e salva capturas de tela
## dos momentos importantes. Não faz parte do jogo.
##   godot --path . --fixed-fps 60 res://tools/preview_capture.tscn
## Variáveis de ambiente: LB_OUT (pasta de saída), LB_QUALITY (0,1,2)

const R = preload("res://scripts/combat/lb_combat_rules.gd")

const PLAYER_CODE := """algoritmo "Contra"
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
var frame := 0
var shots := {}   # passo -> nome
var last_step := 0
var out_dir := "/tmp/lb_preview"


func _vm(src: String) -> LBVM:
	return LBVM.new(LBCompiler.compile_source(src))


func _new_sim() -> LBCombatSim:
	var s := LBCombatSim.new()
	s.setup(_vm(PLAYER_CODE), _vm(LBBotLibrary.get_bot("sentinela").codigo), "TITAN-A", "SENTINELA")
	return s


func _ready() -> void:
	if OS.get_environment("LB_OUT") != "":
		out_dir = OS.get_environment("LB_OUT")
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameSettings.quality = int(OS.get_environment("LB_QUALITY")) if OS.get_environment("LB_QUALITY") != "" else 2

	# Pré-simulação (determinística) para achar os momentos interessantes
	var pre := _new_sim()
	var found := {}
	while not pre.terminou:
		for e in pre.step():
			var key := ""
			if e.tipo in ["acerto", "bloqueio"] and e.acao == "golpe_especial":
				key = "especial"
			elif e.tipo == "bloqueio" and e.alvo == 0:
				key = "bloqueio"
			elif e.tipo == "acerto" and e.atacante == 0:
				key = "soco"
			elif e.tipo == "fim_luta":
				key = "fim"
			if key != "" and not found.has(key):
				found[key] = pre.passos
	shots[40] = "01_inicio"
	if found.has("bloqueio"): shots[found.bloqueio + 2] = "02_bloqueio"
	if found.has("soco"): shots[found.soco + 2] = "03_soco"
	if found.has("especial"): shots[found.especial + 5] = "04_especial"
	if found.has("fim"): shots[found.fim + 140] = "05_vitoria"
	for k in shots.keys():
		last_step = maxi(last_step, k)
	print("momentos: ", found, " capturas: ", shots)

	arena = LBArena.new()
	add_child(arena)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = LBBattleHUD.new()
	layer.add_child(hud)
	sim = _new_sim()
	hud.setup("TITAN-A", "SENTINELA")
	hud.announce("LUTEM!", Color.WHITE, "ROUND 1", 3.0)
	shots[16] = "00_lutem"


var virt := 0   # "tempo" da captura, em passos de 1/60 s
var _cleanup := 0  # quadros em que ainda limpamos efeitos atrasados do salto de tempo


func _next_target() -> int:
	var best := -1
	for k in shots.keys():
		if k > virt and (best < 0 or k < best):
			best = k
	return best


func _on_events(ev: Array, render: bool) -> void:
	if render:
		arena.handle_events(ev, sim)
	for e in ev:
		if e.tipo == "fim_luta":
			var win: bool = e.vencedor == 0
			var titulo := "VITÓRIA" if win else "DERROTA"
			hud.announce(titulo, Color("22d3ee") if win else Color("ff3b4e"), "TITAN-A VENCEU POR NOCAUTE" if win else "", 0.0)


func _advance(render: bool) -> void:
	virt += 1
	if not sim.terminou:
		_on_events(sim.step(), render)
	arena.sync_with_sim(sim, R.DT)
	hud.update_from(sim)


func _process(_delta: float) -> void:
	var target := _next_target()
	if target < 0:
		get_tree().quit()
		return
	# avança rápido (sem renderizar) até perto do próximo momento
	if virt < target - 16:
		while virt < target - 16:
			_advance(false)
		# limpa efeitos e anúncios que ficariam "congelados" pelo salto de tempo
		for c in arena.effects.get_children():
			c.queue_free()
		if not sim.terminou:
			hud.hide_announce()
		hud.snap()
		arena._update_camera(3.0)
		_cleanup = 4
		return
	if _cleanup > 0:
		_cleanup -= 1
		for c in arena.effects.get_children():
			c.queue_free()
	_advance(true)
	if shots.has(virt):
		var name: String = shots[virt]
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s.png" % [out_dir, name])
		print("salvo ", name, " (passo ", virt, ")")
