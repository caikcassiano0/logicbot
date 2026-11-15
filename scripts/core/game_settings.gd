extends Node
## Configurações gráficas e de jogo (autoload "GameSettings").
## Salvas em user://configuracoes.cfg — no Windows fica em
## %APPDATA%/Godot/app_userdata/LogicBot/ e no Linux em
## ~/.local/share/godot/app_userdata/LogicBot/.

signal changed

enum Quality { BAIXA, MEDIA, ALTA }

const PATH := "user://configuracoes.cfg"
const QUALITY_NAMES := ["Baixa", "Média", "Alta"]
## 2.0: estilos de câmera da luta
enum Camera { REAL_STEEL, LATERAL, TV, DINAMICA }
const CAMERA_NAMES := ["Real Steel (atrás do seu robô)", "Lateral (clássica)", "Transmissão de TV", "Dinâmica (muda sozinha)"]

var quality: int = Quality.MEDIA
var fullscreen := false
var vsync := true
var render_scale := 1.0
var show_action_labels := true   ## mostra o nome da ação acima de cada robô
var battle_speed := 1.0
var volume_master := 0.8
var editor_font_size := 17   ## 13 a 26, ajustável com Ctrl + / Ctrl -
var volume_music := 0.6
var volume_sfx := 0.9
var camera_style: int = Camera.REAL_STEEL
## 2.1: cenário da luta — 0 automático (um por fase/bot), 1 aleatório, 2 arena neon
const CENARIO_NAMES := ["Automático (um por fase)", "Aleatório (muda a cada luta)", "Arena Neon (clássica)"]
var cenario_modo := 0


func _ready() -> void:
	load_settings()
	apply_window()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		quality = _guess_quality()
		return
	quality = clampi(int(cfg.get_value("grafico", "qualidade", Quality.MEDIA)), 0, 2)
	fullscreen = bool(cfg.get_value("grafico", "tela_cheia", false))
	vsync = bool(cfg.get_value("grafico", "vsync", true))
	render_scale = clampf(float(cfg.get_value("grafico", "escala", 1.0)), 0.5, 1.0)
	show_action_labels = bool(cfg.get_value("jogo", "rotulos_acao", true))
	editor_font_size = clampi(int(cfg.get_value("jogo", "fonte_editor", 17)), 13, 26)
	volume_master = clampf(float(cfg.get_value("audio", "geral", 0.8)), 0.0, 1.0)
	volume_music = clampf(float(cfg.get_value("audio", "musica", 0.6)), 0.0, 1.0)
	volume_sfx = clampf(float(cfg.get_value("audio", "efeitos", 0.9)), 0.0, 1.0)
	camera_style = clampi(int(cfg.get_value("jogo", "camera", Camera.REAL_STEEL)), 0, CAMERA_NAMES.size() - 1)
	cenario_modo = clampi(int(cfg.get_value("jogo", "cenario", 0)), 0, CENARIO_NAMES.size() - 1)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("grafico", "qualidade", quality)
	cfg.set_value("grafico", "tela_cheia", fullscreen)
	cfg.set_value("grafico", "vsync", vsync)
	cfg.set_value("grafico", "escala", render_scale)
	cfg.set_value("jogo", "rotulos_acao", show_action_labels)
	cfg.set_value("jogo", "fonte_editor", editor_font_size)
	cfg.set_value("audio", "geral", volume_master)
	cfg.set_value("audio", "musica", volume_music)
	cfg.set_value("audio", "efeitos", volume_sfx)
	cfg.set_value("jogo", "camera", camera_style)
	cfg.set_value("jogo", "cenario", cenario_modo)
	cfg.save(PATH)


func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


func set_camera(estilo: int) -> void:
	camera_style = clampi(estilo, 0, CAMERA_NAMES.size() - 1)
	changed.emit()


func set_volumes(master: float, music: float, sfx: float) -> void:
	volume_master = master
	volume_music = music
	volume_sfx = sfx


func set_and_apply(p_quality: int, p_fullscreen: bool, p_vsync: bool, p_scale: float, p_labels: bool) -> void:
	quality = p_quality
	fullscreen = p_fullscreen
	vsync = p_vsync
	render_scale = p_scale
	show_action_labels = p_labels
	save_settings()
	apply_window()
	changed.emit()


## Primeira execução: escolhe uma qualidade inicial segura conforme a placa de vídeo.
func _guess_quality() -> int:
	# navegador e celular/tablet: começa na qualidade mais leve e segura
	if OS.has_feature("web") or OS.has_feature("mobile"):
		return Quality.BAIXA
	# Linux com driver aberto (Mesa: Intel/AMD integradas): a Alta "estourou" a
	# arena num notebook de teste — começa na Média, que funcionou bem.
	if is_risky_gpu():
		return Quality.MEDIA
	var adapter := RenderingServer.get_video_adapter_type()
	match adapter:
		RenderingDevice.DEVICE_TYPE_DISCRETE_GPU:
			return Quality.ALTA
		RenderingDevice.DEVICE_TYPE_CPU:
			return Quality.BAIXA
	return Quality.MEDIA


## Nome da placa de vídeo (mostrado nas Configurações para diagnóstico).
func gpu_name() -> String:
	var n := RenderingServer.get_video_adapter_name()
	var v := RenderingServer.get_video_adapter_vendor()
	return n if v == "" or n.contains(v) else "%s (%s)" % [n, v]


## Placas em que os efeitos pesados da Alta (névoa volumétrica e reflexos de tela)
## já deram imagem estourada: Linux com drivers Mesa ou placa integrada.
func is_risky_gpu() -> bool:
	if OS.get_name() != "Linux":
		return false
	var info := (RenderingServer.get_video_adapter_name() + " " + RenderingServer.get_video_adapter_vendor() + " " \
		+ RenderingServer.get_video_adapter_api_version()).to_lower()
	if info.contains("mesa") or info.contains("llvmpipe") or info.contains("intel"):
		return true
	return RenderingServer.get_video_adapter_type() != RenderingDevice.DEVICE_TYPE_DISCRETE_GPU
