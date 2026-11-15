extends Node
## Autoload "Sfx": efeitos sonoros e música.
## Barramentos: Master → "Musica" e "Efeitos" (volumes separados nas Configurações).
## Todo botão criado no jogo ganha som de clique/hover automaticamente.

const SOUNDS := ["soco", "soco_forte", "bloqueio", "esquiva", "carga", "disparo", "sem_energia", "nocaute",
	"ui_clique", "ui_hover", "round", "lutem", "vitoria", "derrota", "conquista", "nivel"]
## 2.0: sons de boxe de robô (pasta assets/audio/boxe). Vários arquivos = sorteia uma variação.
## Kenney Impact Sounds (CC0) · Mixkit (licença Mixkit) · sino: "Boxing Round Bell" por BudgetPixel AI (CC BY 4.0)
## · motor e moedas: gerados por código para o LogicBot.
const BOXE := {
	"soco": 5, "soco_forte": 5, "metal": 5, "metal_forte": 5, "bloqueio": 5,
	"vento": 0, "sino": 0, "servo_soco": 0, "servo_guarda": 0, "passo_robo": 0,
	"giro_tronco": 0, "hidraulico": 0, "servo_curto": 0,
	"moeda_ganhar": 0, "moedas_contagem": 0, "compra_loja": 0,
}
const POOL_SIZE := 16

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_name := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Musica", "Efeitos"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	for s in SOUNDS:
		_streams[s] = load("res://assets/audio/%s.wav" % s)
	for s in BOXE:
		var n: int = BOXE[s]
		if n == 0:
			_streams[s] = load("res://assets/audio/boxe/%s.ogg" % s)
		else:
			var lista := []
			for i in n:
				lista.append(load("res://assets/audio/boxe/%s_%d.ogg" % [s, i]))
			_streams[s] = lista
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Efeitos"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Musica"
	add_child(_music)
	apply_volumes()
	GameSettings.changed.connect(apply_volumes)
	get_tree().node_added.connect(_on_node_added)


func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(GameSettings.volume_master, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Musica"), linear_to_db(maxf(GameSettings.volume_music, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Efeitos"), linear_to_db(maxf(GameSettings.volume_sfx, 0.0001)))


## Toca um efeito. pitch_var deixa golpes repetidos menos monótonos.
func play(sound: String, pitch_var: float = 0.06, volume_db: float = 0.0) -> void:
	if not _streams.has(sound):
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	var st = _streams[sound]
	p.stream = st.pick_random() if st is Array else st
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.volume_db = volume_db
	p.play()


func play_music(name: String) -> void:
	if _music_name == name and _music.playing:
		return
	_music_name = name
	var s: AudioStreamWAV = load("res://assets/audio/%s.wav" % name)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate)
	_music.stream = s
	_music.volume_db = -30.0
	_music.play()
	create_tween().tween_property(_music, "volume_db", 0.0, 1.2)


func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		var b := n as BaseButton
		b.pressed.connect(func(): play("ui_clique", 0.0, -4.0))
		b.mouse_entered.connect(func():
			if not b.disabled:
				play("ui_hover", 0.0, -10.0))


func _exit_tree() -> void:
	# Libera os sons ao fechar o jogo (evita avisos de "recursos ainda em uso").
	for p in _pool:
		p.stop()
		p.stream = null
	_music.stop()
	_music.stream = null
	_streams.clear()
