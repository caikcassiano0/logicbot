class_name LBCodeEditor
extends CodeEdit
## Editor de pseudocódigo inspirado no Visualg.
##   * números de linha e destaque de sintaxe (palavras-chave, comandos, sensores);
##   * indentação automática depois de ENTAO, FACA, SENAO, INICIO, REPITA...;
##   * autocompletar (Ctrl+Espaço ou ao digitar 2 letras);
##   * destaque da linha que o robô está executando durante a luta;
##   * marcação da linha com erro.

const INDENT := "   "
const OPENERS := ["entao", "faca", "senao", "inicio", "repita", "var"]
const CLOSERS := ["fimse", "senao", "fimenquanto", "fimpara", "ate", "fimalgoritmo", "inicio", "fimprocedimento"]

const C_KEYWORD := Color("c084fc")
const C_TYPE := Color("f9a8d4")
const C_ACTION := Color("22d3ee")
const C_SENSOR := Color("fbbf24")
const C_LITERAL := Color("4ade80")
const C_NUMBER := Color("fb923c")
const C_SYMBOL := Color("94a3b8")
const C_COMMENT := Color("4b6587")
const C_STRING := Color("86efac")

var _exec_line := -1
var _error_line := -1


func _ready() -> void:
	gutters_draw_line_numbers = true
	gutters_zero_pad_line_numbers = false
	highlight_current_line = true
	draw_tabs = false
	indent_use_spaces = true
	indent_size = 3
	auto_brace_completion_enabled = true
	auto_brace_completion_pairs = {"(": ")", "\"": "\""}
	code_completion_enabled = true
	caret_blink = true
	scroll_past_end_of_file = true
	minimap_draw = false
	wrap_mode = TextEdit.LINE_WRAPPING_NONE
	syntax_highlighter = _make_highlighter()
	apply_font_size(GameSettings.editor_font_size)
	text_changed.connect(_on_text_changed)
	_last_line_count = get_line_count()


func _make_highlighter() -> CodeHighlighter:
	var h := CodeHighlighter.new()
	h.number_color = C_NUMBER
	h.symbol_color = C_SYMBOL
	h.function_color = C_ACTION
	h.member_variable_color = Color("d7e3f4")
	for kw in LBLexer.KEYWORDS:
		var c := C_KEYWORD
		if kw in ["inteiro", "real", "logico", "caractere"]:
			c = C_TYPE
		elif kw in ["verdadeiro", "falso"]:
			c = C_LITERAL
		h.add_keyword_color(kw, c)
		h.add_keyword_color(kw.to_upper(), c)
	# variantes acentuadas comuns
	for kw in ["então", "senão", "faça", "início", "lógico", "até", "não", "ENTÃO", "SENÃO", "FAÇA", "INÍCIO", "ATÉ", "NÃO"]:
		h.add_keyword_color(kw, C_KEYWORD)
	for a in LBRobotAPI.ACTIONS:
		h.add_keyword_color(a, C_ACTION)
	h.add_keyword_color("avançar", C_ACTION)
	for s in LBRobotAPI.SENSORS:
		h.add_keyword_color(s, C_SENSOR)
	h.add_color_region("//", "", C_COMMENT, true)
	h.add_color_region("\"", "\"", C_STRING, false)
	return h


# ------------------------------------------------------------ indentação
# A Godot já copia a indentação da linha anterior ao apertar Enter. Aqui só
# acrescentamos um nível quando a linha anterior abre um bloco (ENTAO, FACA...).

var _last_line_count := 0


func _ends_with_opener(line_text: String) -> bool:
	var t := line_text.strip_edges()
	if t == "":
		return false
	var words := t.split(" ", false)
	var last := LBLexer.normalize_word(words[words.size() - 1])
	var first := LBLexer.normalize_word(words[0])
	return last in OPENERS or first == "repita" or first == "procedimento"


func _leading_ws(s: String) -> String:
	var out := ""
	for ch in s:
		if ch == " " or ch == "\t":
			out += ch
		else:
			break
	return out


func _on_text_changed() -> void:
	clear_error_line()
	var added_line := get_line_count() > _last_line_count
	_last_line_count = get_line_count()
	if added_line:
		var ln := get_caret_line()
		var cur := get_line(ln)
		if ln > 0 and cur.strip_edges() == "" and _ends_with_opener(get_line(ln - 1)) \
				and _leading_ws(cur) == _leading_ws(get_line(ln - 1)):
			insert_text_at_caret(INDENT)
			return
	# des-indenta automaticamente fimse/senao/fimenquanto... ao terminar de digitar
	var line := get_caret_line()
	var current := get_line(line)
	var word := LBLexer.normalize_word(current.strip_edges())
	if word in CLOSERS and line > 0:
		var prev_indent := _leading_ws(_prev_code_line(line))
		var prev_word := LBLexer.normalize_word(_prev_code_line(line).strip_edges().get_slice(" ", 0))
		var target := prev_indent
		var prev_last := LBLexer.normalize_word(_prev_code_line(line).strip_edges().get_slice(" ", _prev_code_line(line).strip_edges().get_slice_count(" ") - 1))
		if not (prev_last in OPENERS or prev_word == "repita"):
			target = prev_indent.substr(0, maxi(0, prev_indent.length() - INDENT.length()))
		if word == "inicio" or word == "fimalgoritmo":
			target = ""
		if _leading_ws(current) != target and _leading_ws(current).length() > target.length():
			var col := get_caret_column()
			var diff := _leading_ws(current).length() - target.length()
			set_line(line, target + current.strip_edges(true, false))
			set_caret_column(maxi(0, col - diff))
	# autocompletar ao digitar
	var before := current.substr(0, get_caret_column())
	var w := _word_before(before)
	if w.length() >= 2 and not is_in_string(line, get_caret_column()) and not is_in_comment(line, get_caret_column()):
		request_code_completion()


func _prev_code_line(line: int) -> String:
	var i := line - 1
	while i >= 0:
		if get_line(i).strip_edges() != "":
			return get_line(i)
		i -= 1
	return ""


func _word_before(s: String) -> String:
	var i := s.length() - 1
	while i >= 0 and (LBLexer._is_ident_char(s[i])):
		i -= 1
	return s.substr(i + 1)


# ------------------------------------------------------------ autocompletar

func _request_code_completion(_force: bool) -> void:
	var before := get_line(get_caret_line()).substr(0, get_caret_column())
	var w := LBLexer.normalize_word(_word_before(before))
	for a in LBRobotAPI.ACTIONS:
		if a.begins_with(w):
			add_code_completion_option(CodeEdit.KIND_FUNCTION, a + "()", a + "()", C_ACTION)
	for s in LBRobotAPI.SENSORS:
		if s.begins_with(w):
			add_code_completion_option(CodeEdit.KIND_MEMBER, s, s, C_SENSOR)
	for kw in ["entao", "senao", "fimse", "enquanto", "faca", "fimenquanto", "repita", "para", "fimpara", "verdadeiro", "falso", "inteiro", "real", "logico", "caractere", "escreval", "procedimento", "fimprocedimento"]:
		if kw.begins_with(w) and kw != w:
			add_code_completion_option(CodeEdit.KIND_PLAIN_TEXT, kw, kw, C_KEYWORD)
	update_code_completion_options(_force)


# ------------------------------------------------------------ marcações

func set_exec_line(line_1based: int) -> void:
	var l := line_1based - 1
	if l == _exec_line:
		return
	if _exec_line >= 0 and _exec_line < get_line_count() and _exec_line != _error_line:
		set_line_background_color(_exec_line, Color(0, 0, 0, 0))
	_exec_line = l
	if l >= 0 and l < get_line_count():
		set_line_background_color(l, Color(LBUITheme.CYAN, 0.16))
		if not is_line_visible(l):
			set_line_as_center_visible(l)


func clear_exec_line() -> void:
	set_exec_line(0)
	_exec_line = -1


func set_error_line(line_1based: int) -> void:
	clear_error_line()
	var l := line_1based - 1
	if l >= 0 and l < get_line_count():
		_error_line = l
		set_line_background_color(l, Color(LBUITheme.RED, 0.22))
		set_caret_line(l)
		set_line_as_center_visible(l)


func clear_error_line() -> void:
	if _error_line >= 0 and _error_line < get_line_count():
		set_line_background_color(_error_line, Color(0, 0, 0, 0))
	_error_line = -1


func is_line_visible(l: int) -> bool:
	var first := get_first_visible_line()
	return l >= first and l <= first + get_visible_line_count() - 1


## Insere um trecho no cursor, respeitando a indentação da linha atual.
func insert_snippet(snippet: String) -> void:
	var line := get_caret_line()
	var current := get_line(line)
	var indent := _leading_ws(current)
	var lines := snippet.split("\n")
	var out := ""
	for i in lines.size():
		out += (lines[i] if i == 0 else indent + lines[i])
		if i < lines.size() - 1:
			out += "\n"
	if current.strip_edges() != "" and get_caret_column() >= current.length():
		out = "\n" + indent + out
	begin_complex_operation()
	insert_text_at_caret(out)
	end_complex_operation()
	grab_focus()


func apply_font_size(size_px: int) -> void:
	add_theme_font_size_override("font_size", size_px)
