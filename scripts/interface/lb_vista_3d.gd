class_name LBVista3D
extends TextureRect
## Mostra o mundo 3D (arena) na RESOLUÇÃO REAL da tela.
##
## Antes, o 3D era desenhado no tamanho "base" da interface (ex.: 480 px de largura no
## celular) e depois esticado para a tela (1080 px) — ficava borrado. Aqui o SubViewport
## acompanha os pixels de verdade do aparelho.

var sv: SubViewport


func _init() -> void:
	sv = SubViewport.new()
	sv.own_world_3d = true
	sv.handle_input_locally = false
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	texture = sv.get_texture()
	resized.connect(_ajustar)
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()


func _ajustar() -> void:
	var escala := get_viewport().get_final_transform().get_scale()
	var px := (size * escala).round()
	# limite de segurança para não pesar demais em telas enormes
	var maior := maxf(px.x, px.y)
	if maior > 2560.0:
		px *= 2560.0 / maior
	sv.size = Vector2i(maxi(int(px.x), 16), maxi(int(px.y), 16))
