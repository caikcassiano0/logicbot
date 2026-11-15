extends Node
## Estado compartilhado entre as telas (autoload "GameState").
## Guarda o oponente escolhido e o código do jogador (salvo em disco
## para não se perder ao fechar o jogo).

const CODE_PATH := "user://meu_robo.por"

var selected_bot_id := "treino"
var player_code := ""
## "treino" (luta livre), "campanha" ou "tutorial"
var mode := "treino"
var fase_id := ""


var _fade: ColorRect
var _changing := false


var _layout := ""


func _ready() -> void:
	get_tree().root.theme = LBUITheme.build()
	player_code = _load_code()
	apply_layout()
	get_tree().root.size_changed.connect(_on_window_resized)
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.01, 0.015, 0.03, 0.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


## Troca de tela com escurecimento suave.
func change_scene(path: String) -> void:
	if _changing:
		return
	_changing = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.18)
	tw.tween_callback(func(): get_tree().change_scene_to_file(path))
	tw.tween_interval(0.05)
	tw.tween_property(_fade, "color:a", 0.0, 0.25)
	tw.tween_callback(func():
		_changing = false
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE)


func _load_code() -> String:
	if FileAccess.file_exists(CODE_PATH):
		var f := FileAccess.open(CODE_PATH, FileAccess.READ)
		if f:
			var txt := f.get_as_text()
			if txt.strip_edges() != "":
				return txt
	return LBBotLibrary.TEMPLATE


func save_code(code: String) -> void:
	player_code = code
	var f := FileAccess.open(CODE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(code)


func go_to_menu() -> void:
	change_scene("res://scenes/main_menu/main_menu.tscn")


func start_battle(bot_id: String) -> void:
	mode = "treino"
	selected_bot_id = bot_id
	change_scene("res://scenes/battle/battle.tscn")


func start_campaign(id: String) -> void:
	mode = "campanha"
	fase_id = id
	change_scene("res://scenes/battle/battle.tscn")


func start_tutorial() -> void:
	mode = "tutorial"
	fase_id = ""
	change_scene("res://scenes/battle/battle.tscn")


## Código salvo de cada fase (por dificuldade), para o aluno não perder o que escreveu.
func _fase_path(id: String, dificuldade: int) -> String:
	return "user://fase_%s_d%d.por" % [id, dificuldade]


func load_fase_code(fase: Dictionary, dificuldade: int) -> String:
	var path := _fase_path(fase.id, dificuldade)
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			var txt := f.get_as_text()
			if txt.strip_edges() != "":
				return txt
	return fase.inicio[dificuldade]


func save_fase_code(id: String, dificuldade: int, code: String) -> void:
	var f := FileAccess.open(_fase_path(id, dificuldade), FileAccess.WRITE)
	if f:
		f.store_string(code)


func _exit_tree() -> void:
	get_tree().root.theme = null
	LBUITheme.clear_cache()



## Ajusta a escala da interface ao aparelho (PC, tablet ou celular).
func apply_layout() -> void:
	_layout = LBDevice.kind()
	get_tree().root.content_scale_size = LBDevice.base_size()


## Ao girar o celular (em pé ↔ deitado), recarrega a tela com o layout certo.
func _on_window_resized() -> void:
	if LBDevice.kind() == _layout or _changing:
		return
	apply_layout()
	var cena := get_tree().current_scene
	if cena and cena.scene_file_path != "" and cena.name in ["MainMenu"]:
		get_tree().reload_current_scene()
