class_name LBUITheme
extends RefCounted
## Tema visual de toda a interface, montado por código.
## Vantagem: cores, fontes e bordas ficam centralizadas aqui — mudar a
## identidade visual do jogo é editar este arquivo.

const BG := Color("070b14")
const PANEL := Color(0.043, 0.075, 0.133, 0.94)
const PANEL_DARK := Color(0.02, 0.035, 0.07, 0.96)
const BORDER := Color("1b3150")
const CYAN := Color("22d3ee")
const CYAN_DIM := Color("0e7490")
const RED := Color("ff3b4e")
const RED_DIM := Color("8b1d2a")
const YELLOW := Color("ffc94a")
const GREEN := Color("4ade80")
const TEXT := Color("d7e3f4")
const TEXT_DIM := Color("7f93b0")

const FONT_TITLE := "res://assets/fonts/Orbitron.ttf"
const FONT_UI := "res://assets/fonts/Rajdhani-SemiBold.ttf"
const FONT_UI_BOLD := "res://assets/fonts/Rajdhani-Bold.ttf"
const FONT_CODE := "res://assets/fonts/JetBrainsMono.ttf"
const FONT_SIMBOLOS := "res://assets/fonts/DejaVuSans-Simbolos.ttf"   ## DejaVu (licença livre)

static var _cache := {}


static func font(path: String, weight: int = 0) -> Font:
	var key := "%s:%d" % [path, weight]
	if _cache.has(key):
		return _cache[key]
	var base: Font = load(path)
	# 2.1.2: fonte reserva com símbolos (▶ ✔ ⚠ ★ ⊘...): no navegador não existe a fonte do sistema
	if base is FontFile and path != FONT_SIMBOLOS:
		var fb: Font = load(FONT_SIMBOLOS)
		if not (base as FontFile).fallbacks.has(fb):
			(base as FontFile).fallbacks = [fb]
	var result: Font = base
	if weight > 0:
		var fv := FontVariation.new()
		fv.base_font = base
		var ts := TextServerManager.get_primary_interface()
		fv.variation_opentype = {ts.name_to_tag("wght"): weight}
		result = fv
	_cache[key] = result
	return result


static func title_font() -> Font:
	return font(FONT_TITLE, 800)


static func code_font() -> Font:
	return font(FONT_CODE, 500)


static func box(bg: Color, border: Color = Color.TRANSPARENT, border_w: int = 0, radius: int = 4, margin: float = 8.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin * 0.6
	s.content_margin_bottom = margin * 0.6
	s.anti_aliasing = true
	return s


static func panel_box(accent: Color = BORDER, radius: int = 6) -> StyleBoxFlat:
	var s := box(PANEL, accent, 1, radius, 12.0)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 10
	return s


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font(FONT_UI)
	t.default_font_size = 19

	# ---- Rótulos
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.5))
	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", title_font())
	t.set_font_size("font_size", "TitleLabel", 64)
	t.set_color("font_color", "TitleLabel", Color.WHITE)
	t.set_type_variation("HeaderLabel", "Label")
	t.set_font("font", "HeaderLabel", font(FONT_TITLE, 700))
	t.set_font_size("font_size", "HeaderLabel", 20)
	t.set_color("font_color", "HeaderLabel", CYAN)
	t.set_type_variation("DimLabel", "Label")
	t.set_color("font_color", "DimLabel", TEXT_DIM)
	t.set_font_size("font_size", "DimLabel", 17)

	# ---- Painéis
	t.set_stylebox("panel", "Panel", panel_box())
	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_type_variation("DarkPanel", "PanelContainer")
	t.set_stylebox("panel", "DarkPanel", box(PANEL_DARK, BORDER, 1, 4, 10.0))
	t.set_type_variation("GlassPanel", "PanelContainer")
	var glass := box(Color(0.03, 0.06, 0.12, 0.72), Color(CYAN, 0.35), 1, 8, 18.0)
	glass.shadow_color = Color(0, 0, 0, 0.5)
	glass.shadow_size = 16
	t.set_stylebox("panel", "GlassPanel", glass)

	# ---- Botões (borda inclinada, visual "tech")
	_button(t, "Button", Color("0e1a2e"), BORDER, CYAN, TEXT)
	t.set_type_variation("PrimaryButton", "Button")
	_button(t, "PrimaryButton", Color("0b4a5a"), CYAN, Color("67e8f9"), Color.WHITE)
	t.set_font("font", "PrimaryButton", font(FONT_TITLE, 700))
	t.set_font_size("font_size", "PrimaryButton", 18)
	t.set_type_variation("DangerButton", "Button")
	_button(t, "DangerButton", Color("3a0f17"), RED_DIM, RED, Color.WHITE)
	t.set_type_variation("NavButton", "Button")
	_button(t, "NavButton", Color(0.05, 0.09, 0.16, 0.85), Color(CYAN, 0.25), CYAN, TEXT, 18.0)
	t.set_font("font", "NavButton", font(FONT_TITLE, 600))
	t.set_font_size("font_size", "NavButton", 20)

	# ---- Editor de código
	var code_bg := box(Color("050912"), BORDER, 1, 4, 6.0)
	for type in ["CodeEdit", "TextEdit"]:
		t.set_stylebox("normal", type, code_bg)
		t.set_stylebox("focus", type, box(Color.TRANSPARENT, CYAN_DIM, 1, 4))
		t.set_stylebox("read_only", type, box(Color("070c18"), BORDER, 1, 4, 6.0))
		t.set_font("font", type, code_font())
		t.set_font_size("font_size", type, 17)
		t.set_color("font_color", type, TEXT)
		t.set_color("font_readonly_color", type, TEXT)
		t.set_color("caret_color", type, CYAN)
		t.set_color("selection_color", type, Color(CYAN, 0.22))
		t.set_color("current_line_color", type, Color(1, 1, 1, 0.035))
		t.set_color("word_highlighted_color", type, Color(CYAN, 0.12))
		t.set_color("background_color", type, Color("050912"))
	t.set_color("line_number_color", "CodeEdit", Color("3d5578"))
	t.set_color("completion_background_color", "CodeEdit", Color("0b1424"))
	t.set_color("completion_selected_color", "CodeEdit", Color(CYAN, 0.25))
	t.set_color("completion_existing_color", "CodeEdit", Color(CYAN, 0.35))
	t.set_color("completion_font_color", "CodeEdit", TEXT)
	t.set_color("brace_mismatch_color", "CodeEdit", RED)

	# ---- Texto rico (console)
	t.set_font("normal_font", "RichTextLabel", code_font())
	t.set_font("bold_font", "RichTextLabel", font(FONT_CODE, 800))
	t.set_font_size("normal_font_size", "RichTextLabel", 15)
	t.set_font_size("bold_font_size", "RichTextLabel", 15)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("normal", "RichTextLabel", box(Color("050912"), BORDER, 1, 4, 8.0))
	t.set_type_variation("ProseText", "RichTextLabel")
	t.set_font("normal_font", "ProseText", font(FONT_UI))
	t.set_font("bold_font", "ProseText", font(FONT_UI_BOLD))
	t.set_font_size("normal_font_size", "ProseText", 18)
	t.set_font_size("bold_font_size", "ProseText", 18)
	t.set_stylebox("normal", "ProseText", StyleBoxEmpty.new())

	# ---- Abas
	t.set_stylebox("panel", "TabContainer", box(PANEL_DARK, BORDER, 1, 4, 6.0))
	t.set_stylebox("tab_selected", "TabContainer", _tab(Color("0f2238"), CYAN))
	t.set_stylebox("tab_unselected", "TabContainer", _tab(Color("08101d"), Color.TRANSPARENT))
	t.set_stylebox("tab_hovered", "TabContainer", _tab(Color("0c1a2c"), Color(CYAN, 0.4)))
	t.set_color("font_selected_color", "TabContainer", Color.WHITE)
	t.set_color("font_unselected_color", "TabContainer", TEXT_DIM)
	t.set_color("font_hovered_color", "TabContainer", TEXT)
	t.set_font("font", "TabContainer", font(FONT_UI_BOLD))
	t.set_font_size("font_size", "TabContainer", 17)

	# ---- Listas
	t.set_stylebox("panel", "ItemList", box(Color("050912"), BORDER, 1, 4, 4.0))
	t.set_stylebox("selected", "ItemList", box(Color(CYAN, 0.18), Color.TRANSPARENT, 0, 3))
	t.set_stylebox("selected_focus", "ItemList", box(Color(CYAN, 0.25), Color(CYAN, 0.5), 1, 3))
	t.set_stylebox("hovered", "ItemList", box(Color(1, 1, 1, 0.05), Color.TRANSPARENT, 0, 3))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_font("font", "ItemList", code_font())
	t.set_font_size("font_size", "ItemList", 15)
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	t.set_constant("v_separation", "ItemList", 6)

	# ---- Barras de rolagem finas
	for sb in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb, box(Color(0, 0, 0, 0.2), Color.TRANSPARENT, 0, 3, 0.0))
		t.set_stylebox("grabber", sb, box(Color("1e3656"), Color.TRANSPARENT, 0, 3, 0.0))
		t.set_stylebox("grabber_highlight", sb, box(CYAN_DIM, Color.TRANSPARENT, 0, 3, 0.0))
		t.set_stylebox("grabber_pressed", sb, box(CYAN, Color.TRANSPARENT, 0, 3, 0.0))

	# ---- Separadores arrastáveis
	t.set_constant("separation", "VSplitContainer", 8)
	t.set_constant("separation", "HSplitContainer", 8)
	t.set_constant("minimum_grab_thickness", "VSplitContainer", 10)

	# ---- Controles de formulário
	t.set_stylebox("normal", "OptionButton", box(Color("0e1a2e"), BORDER, 1, 4, 10.0))
	t.set_stylebox("hover", "OptionButton", box(Color("12223a"), CYAN_DIM, 1, 4, 10.0))
	t.set_stylebox("pressed", "OptionButton", box(Color("12223a"), CYAN, 1, 4, 10.0))
	t.set_stylebox("focus", "OptionButton", box(Color.TRANSPARENT, CYAN, 1, 4))
	t.set_stylebox("panel", "PopupMenu", box(Color("0b1424"), CYAN_DIM, 1, 4, 6.0))
	t.set_stylebox("hover", "PopupMenu", box(Color(CYAN, 0.2), Color.TRANSPARENT, 0, 3))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", Color.WHITE)
	t.set_color("font_pressed_color", "CheckBox", CYAN)
	t.set_stylebox("slider", "HSlider", box(Color("12223a"), Color.TRANSPARENT, 0, 3, 3.0))
	t.set_stylebox("grabber_area", "HSlider", box(CYAN_DIM, Color.TRANSPARENT, 0, 3, 3.0))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(CYAN, Color.TRANSPARENT, 0, 3, 3.0))

	# ---- Dicas (tooltip)
	t.set_stylebox("panel", "TooltipPanel", box(Color("0b1424"), CYAN_DIM, 1, 4, 10.0))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 17)
	return t


static func _button(t: Theme, type: String, bg: Color, border: Color, accent: Color, fg: Color, margin: float = 14.0) -> void:
	var normal := box(bg, border, 1, 3, margin)
	normal.skew = Vector2(-0.12, 0)
	var hover := box(bg.lightened(0.12), accent, 1, 3, margin)
	hover.skew = normal.skew
	hover.shadow_color = Color(accent, 0.35)
	hover.shadow_size = 8
	var pressed := box(bg.darkened(0.2), accent, 2, 3, margin)
	pressed.skew = normal.skew
	var disabled := box(Color(bg, 0.5), Color(border, 0.4), 1, 3, margin)
	disabled.skew = normal.skew
	var focus := box(Color.TRANSPARENT, Color(accent, 0.8), 1, 3)
	focus.skew = normal.skew
	t.set_stylebox("normal", type, normal)
	t.set_stylebox("hover", type, hover)
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("hover_pressed", type, pressed)
	t.set_stylebox("disabled", type, disabled)
	t.set_stylebox("focus", type, focus)
	t.set_color("font_color", type, fg)
	t.set_color("font_hover_color", type, Color.WHITE)
	t.set_color("font_pressed_color", type, accent)
	t.set_color("font_disabled_color", type, Color(fg, 0.35))
	t.set_color("font_focus_color", type, fg)


static func _tab(bg: Color, line: Color) -> StyleBoxFlat:
	var s := box(bg, Color.TRANSPARENT, 0, 3, 12.0)
	s.border_width_top = 2
	s.border_color = line
	return s


static func clear_cache() -> void:
	_cache.clear()
