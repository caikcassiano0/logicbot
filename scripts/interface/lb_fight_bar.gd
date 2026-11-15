class_name LBFightBar
extends Control
## Barra de vida/energia no estilo jogo de luta, desenhada por código:
## formato inclinado, gradiente, rastro de dano e divisões.

@export var color := Color("22d3ee")
@export var mirrored := false
@export var segments := 10
@export var marker := -1.0       ## desenha um marcador (ex.: 0.5 = metade)
@export var low_threshold := 0.3

var value := 1.0
var _trail := 1.0
var _trail_hold := 0.0
var _pulse := 0.0


func set_value(v: float, instant: bool = false) -> void:
	v = clampf(v, 0.0, 1.0)
	if v < value:
		_trail_hold = 0.35
	value = v
	if instant or _trail < value:
		_trail = value
	queue_redraw()


func _process(delta: float) -> void:
	_pulse += delta
	if _trail_hold > 0.0:
		_trail_hold -= delta
	elif _trail > value:
		_trail = move_toward(_trail, value, delta * 0.6)
	queue_redraw()


func _quad(u0: float, u1: float) -> PackedVector2Array:
	var w := size.x
	var h := size.y
	var s := minf(h * 0.7, w * 0.1)
	var l := w - s
	if mirrored:
		return PackedVector2Array([Vector2(u0 * l, 0), Vector2(u1 * l, 0), Vector2(s + u1 * l, h), Vector2(s + u0 * l, h)])
	return PackedVector2Array([Vector2(s + u0 * l, 0), Vector2(s + u1 * l, 0), Vector2(u1 * l, h), Vector2(u0 * l, h)])


func _range(v: float) -> Vector2:
	return Vector2(1.0 - v, 1.0) if mirrored else Vector2(0.0, v)


func _draw() -> void:
	var bg := _quad(0.0, 1.0)
	draw_colored_polygon(bg, Color(0.02, 0.03, 0.06, 0.85))

	var tr := _range(_trail)
	if _trail > value and tr.y > tr.x:
		draw_colored_polygon(_quad(tr.x, tr.y), Color(1.0, 0.95, 0.85, 0.85))

	var r := _range(value)
	if r.y > r.x:
		var c := color
		if value <= low_threshold and low_threshold > 0.0:
			c = c.lerp(Color("ffc94a"), 0.5 + 0.5 * sin(_pulse * 8.0))
		var q := _quad(r.x, r.y)
		var top := c.lightened(0.35)
		var bottom := c.darkened(0.35)
		draw_polygon(q, PackedColorArray([top, top, bottom, bottom]))
		# brilho na metade superior
		var hl := q.duplicate()
		hl[2] = hl[1].lerp(hl[2], 0.38)
		hl[3] = hl[0].lerp(hl[3], 0.38)
		draw_colored_polygon(hl, Color(1, 1, 1, 0.16))

	for i in range(1, segments):
		var u := float(i) / segments
		var q := _quad(u, u)
		draw_line(q[0], q[3], Color(0, 0, 0, 0.45), 1.5)

	if marker > 0.0:
		var mu := 1.0 - marker if mirrored else marker
		var mq := _quad(mu, mu)
		draw_line(mq[0] + Vector2(0, -3), mq[3] + Vector2(0, 3), Color.WHITE, 2.0)

	var border := bg.duplicate()
	border.append(bg[0])
	draw_polyline(border, Color(color, 0.75), 1.5, true)
