class_name LBGuideCard
extends PanelContainer
## Cartão de orientação sobre a arena: usado pelo tutorial e pelo objetivo da fase.

var _title: Label
var _body: RichTextLabel
var _scroll: ScrollContainer   ## o texto rola se não couber (nunca é cortado)
var _buttons: HBoxContainer
var _tag: Label
var compact := false   ## celular: texto menor e largura flexível


func _ready() -> void:
	theme_type_variation = "GlassPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	_tag = Label.new()
	_tag.theme_type_variation = "DimLabel"
	_tag.add_theme_font_size_override("font_size", 14)
	top.add_child(_tag)
	_title = Label.new()
	_title.theme_type_variation = "HeaderLabel"
	_title.add_theme_font_size_override("font_size", 20)
	v.add_child(_title)
	_body = RichTextLabel.new()
	_body.theme_type_variation = "ProseText"
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size.x = 0 if compact else 420
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if compact:
		_body.add_theme_font_size_override("normal_font_size", 15)
		_body.add_theme_font_size_override("bold_font_size", 15)
		_title.add_theme_font_size_override("font_size", 17)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.add_child(_body)
	v.add_child(_scroll)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	_buttons.add_theme_constant_override("separation", 10)
	v.add_child(_buttons)


## buttons: Array de [texto, Callable, primario: bool]
var _topo := false   ## true = mostra o começo do texto (exemplos); false = o final (dica mais nova)


func show_card(tag: String, title: String, body: String, buttons: Array = [], topo := false) -> void:
	_topo = topo
	_tag.text = tag
	_tag.visible = tag != ""
	_title.text = title
	_body.text = body
	for c in _buttons.get_children():
		c.queue_free()
	for b in buttons:
		var btn := Button.new()
		btn.text = b[0]
		if b.size() > 2 and b[2]:
			btn.theme_type_variation = "PrimaryButton"
		btn.pressed.connect(b[1])
		_buttons.add_child(btn)
	_buttons.visible = not buttons.is_empty()
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)
	_fit.call_deferred()


## Ajusta a altura do texto ao espaço que sobra na arena (o cartão não pode
## passar por cima do editor nem sair da tela). Se não couber, o texto rola e
## mostra o final (a dica mais nova).
var _fit_gen := 0

func _fit() -> void:
	if not is_inside_tree():
		return
	_fit_gen += 1
	var gen := _fit_gen
	await get_tree().process_frame
	if gen != _fit_gen:
		return                                      # outra chamada mais nova assume
	var content := float(_body.get_content_height())
	var parent := get_parent_control()
	var area_h := parent.size.y if parent else get_viewport_rect().size.y
	# título, etiqueta, botões e bordas = mínimo do cartão sem a área de texto
	var outros := get_combined_minimum_size().y - _scroll.get_combined_minimum_size().y
	var livre := area_h - position.y - outros - 10.0
	_scroll.custom_minimum_size.y = clampf(content, 48.0, maxf(48.0, livre))
	size.y = 0                                      # encolhe até o mínimo necessário
	await get_tree().process_frame
	_scroll.scroll_vertical = 0 if _topo else int(content)


func hide_card() -> void:
	visible = false
