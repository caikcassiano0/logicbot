class_name LBDevice
extends RefCounted
## Descobre em que tipo de aparelho o jogo está rodando e qual layout usar.
##
##   "pc"      — tela deitada, mouse e teclado (layout completo).
##   "tablet"  — tela deitada com toque (mesmo layout, interface maior).
##   "celular" — tela em pé (layout compacto com abas).
##
## Celular deitado usa o layout de PC com a interface bem ampliada.
## Para testar no computador: variável de ambiente LB_DEVICE=celular|tablet|pc.

static var forced := ""


static func kind() -> String:
	if forced != "":
		return forced
	var env := OS.get_environment("LB_DEVICE")
	if env != "":
		return env
	var size := DisplayServer.window_get_size()
	if size.y > size.x:
		return "celular"
	if is_touch():
		return "tablet"
	return "pc"


static func is_touch() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") \
		or OS.has_feature("web_android") or OS.has_feature("web_ios")


## Layout compacto (telas em pé).
static func compact() -> bool:
	return kind() == "celular"


## Tamanho base da interface: quanto menor, maior tudo fica na tela.
static func base_size() -> Vector2i:
	var env := OS.get_environment("LB_BASE")   # testes: força o tamanho base (ex.: 1100x620)
	if env.contains("x"):
		return Vector2i(int(env.get_slice("x", 0)), int(env.get_slice("x", 1)))
	match kind():
		"celular":
			return Vector2i(480, 960)
		"tablet":
			var s := DisplayServer.window_get_size()
			var dpi := maxf(float(DisplayServer.screen_get_dpi()), 96.0)
			var altura_pol := float(mini(s.x, s.y)) / dpi
			# celular deitado (tela baixa) precisa de interface ainda maior
			return Vector2i(1100, 620) if altura_pol < 3.2 else Vector2i(1366, 800)
	return Vector2i(1600, 900)
