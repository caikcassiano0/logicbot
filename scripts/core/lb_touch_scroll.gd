extends Node
## Autoload "Toque": rolar com o DEDO em celular e tablet.
##
## A Godot só rola listas, o editor de código e textos longos com a roda do mouse
## ou a barra de rolagem. Aqui, arrastar o dedo em cima de qualquer área rolável
## (lista, editor, texto, painel) faz ela rolar — com um pouco de "embalo" no fim.

const LIMIAR := 10.0        ## px de arrasto até virar rolagem (antes disso é um toque normal)
const ATRITO := 4.0         ## quanto o embalo freia por segundo

var _ativo := false
var _alvos: Array[Control] = []
var _alvo: Control = null
var _acum := Vector2.ZERO
var _rolando := false
var _vel := 0.0
var _vel_alvo: Control = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ativo = LBDevice.is_touch() or OS.get_environment("LB_TOQUE") != ""


func _input(e: InputEvent) -> void:
	if not _ativo:
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			_vel = 0.0
			_alvos = _rolaveis_em(e.position)
			_alvo = null
			_acum = Vector2.ZERO
			_rolando = false
		else:
			if _rolando:
				_vel_alvo = _alvo
			_alvos.clear()
			_alvo = null
			_rolando = false
	elif e is InputEventScreenDrag and not _alvos.is_empty():
		_acum += e.relative
		if not _rolando:
			if absf(_acum.y) < LIMIAR or absf(_acum.y) < absf(_acum.x):
				return
			# o mais interno que ainda consegue rolar nessa direção
			for c in _alvos:
				if _pode_rolar(c, -_acum.y):
					_alvo = c
					break
			if _alvo == null:
				_alvos.clear()
				return
			_rolando = true
		_rolar(_alvo, -e.relative.y)
		_vel = -e.relative.y / maxf(get_process_delta_time(), 0.008)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _vel_alvo == null or absf(_vel) < 30.0:
		_vel = 0.0
		_vel_alvo = null
		return
	if not is_instance_valid(_vel_alvo) or not _vel_alvo.is_visible_in_tree():
		_vel_alvo = null
		return
	_rolar(_vel_alvo, _vel * delta)
	_vel = lerpf(_vel, 0.0, clampf(ATRITO * delta, 0.0, 1.0))


## Áreas roláveis embaixo do dedo, da mais interna para a mais externa.
func _rolaveis_em(p: Vector2) -> Array[Control]:
	var achados: Array[Control] = []
	_procurar(get_tree().root, p, achados)
	achados.sort_custom(func(a, b): return a.get_global_rect().get_area() < b.get_global_rect().get_area())
	return achados


func _procurar(n: Node, p: Vector2, out: Array[Control]) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is SubViewport:
		return   # o 3D não rola
	if n is Control and _e_rolavel(n) and (n as Control).get_global_rect().has_point(p):
		out.append(n)
	for c in n.get_children():
		_procurar(c, p, out)


func _e_rolavel(c: Control) -> bool:
	return c is ScrollContainer or c is ItemList or c is TextEdit or c is Tree \
		or (c is RichTextLabel and (c as RichTextLabel).scroll_active)


func _barra(c: Control) -> ScrollBar:
	if c is ScrollContainer:
		return (c as ScrollContainer).get_v_scroll_bar()
	if c is ItemList:
		return (c as ItemList).get_v_scroll_bar()
	if c is TextEdit:
		return (c as TextEdit).get_v_scroll_bar()
	if c is RichTextLabel:
		return (c as RichTextLabel).get_v_scroll_bar()
	if c is Tree:
		return null
	return null


func _pode_rolar(c: Control, dy: float) -> bool:
	if c is TextEdit:
		var te := c as TextEdit
		return (dy > 0.0 and te.scroll_vertical < te.get_v_scroll_bar().max_value - te.get_visible_line_count()) \
			or (dy < 0.0 and te.scroll_vertical > 0.0)
	var b := _barra(c)
	if b == null:
		return false
	var fim := b.max_value - b.page
	return fim > 0.5 and ((dy > 0.0 and b.value < fim) or (dy < 0.0 and b.value > b.min_value))


func _rolar(c: Control, dy: float) -> void:
	if not is_instance_valid(c):
		return
	if c is ScrollContainer:
		(c as ScrollContainer).scroll_vertical += int(round(dy))
	elif c is TextEdit:
		var te := c as TextEdit
		te.scroll_vertical += dy / maxf(float(te.get_line_height()), 1.0)
		te.deselect()
	else:
		var b := _barra(c)
		if b:
			b.value += dy
