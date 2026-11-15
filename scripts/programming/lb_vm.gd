class_name LBVM
extends RefCounted
## MÁQUINA VIRTUAL — executa o programa do aluno de forma CONTROLADA.
##
## Como funciona:
##   * O combate pede "qual a próxima ação?" chamando [method next_action].
##   * A VM executa as instruções a partir de onde parou (pc) até encontrar um
##     comando de ação (atacar, defender...). Aí ela PAUSA e devolve a ação.
##   * Quando o programa chega em FIMALGORITMO, ele recomeça do início
##     imediatamente (o "laço principal" do robô). Só se uma volta INTEIRA
##     passar sem nenhuma ação é que o robô espera um instante (aguardar).
##     As variáveis do aluno mantêm seus valores entre uma volta e outra.
##
## Proteções (o aluno nunca consegue travar o jogo):
##   * No máximo MAX_STEPS instruções entre duas ações (protege contra laço infinito).
##   * No máximo MAX_DECISION_USEC microssegundos por decisão.
##   * Textos limitados a MAX_STRING caracteres; registro de saída limitado.
##   * Só sensores e comandos de LBRobotAPI são acessíveis — nada do motor do jogo.
##   * Erros de execução (ex.: divisão por zero) param o programa com segurança.

const MAX_STEPS := 500
const MAX_DECISION_USEC := 8000
const MAX_STRING := 200
const MAX_LOG := 200
const MAX_EXPR_DEPTH := 64
const MAX_CALL_DEPTH := 16

var ops: Array = []
var vars: Dictionary = {}
var var_types: Dictionary = {}
var pc := 0
var halted := false
var error: LBDiagnostic = null
var current_line := 0
var sensors: Dictionary = {}

# --- estatísticas (alimentam a análise depois da luta) ---
var instructions_executed := 0
var cycles_completed := 0
var decisions := 0
## linha -> {"v": vezes verdadeira, "f": vezes falsa, "kind": "se"/"enquanto"/...}
var condition_stats: Dictionary = {}
## linha -> quantas vezes executou
var line_hits: Dictionary = {}
var output_log: PackedStringArray = []

var _initial_vars: Dictionary = {}
var _stack: Array[int] = []
var _steps := 0
var _depth := 0


func _init(compiled: LBCompiler.Result = null) -> void:
	if compiled != null:
		load_program(compiled)


func load_program(compiled: LBCompiler.Result) -> void:
	ops = compiled.ops
	var_types = compiled.var_types
	_initial_vars = compiled.initial_vars.duplicate()
	reset()


## Volta ao estado inicial (usado a cada nova luta).
func reset() -> void:
	vars = _initial_vars.duplicate()
	pc = 0
	halted = false
	error = null
	current_line = 0
	instructions_executed = 0
	cycles_completed = 0
	decisions = 0
	condition_stats.clear()
	line_hits.clear()
	output_log.clear()
	_stack.clear()


## Executa até a próxima ação.
## Retorna {"type": "action", "name": String, "line": int}
##      ou {"type": "fim"}  (chegou em FIMALGORITMO sem nova ação nesta decisão)
##      ou {"type": "erro", "diagnostic": LBDiagnostic}
func next_action(p_sensors: Dictionary) -> Dictionary:
	if halted:
		return {"type": "erro", "diagnostic": error}
	sensors = p_sensors
	decisions += 1
	_steps = 0
	var t0 := Time.get_ticks_usec()
	# Se a última ação foi a última linha, recomeça já (não desperdiça tempo).
	if pc >= ops.size():
		pc = 0
		cycles_completed += 1
	var started_at_top := pc == 0
	var wraps := 0

	while true:
		if pc >= ops.size():
			pc = 0
			cycles_completed += 1
			wraps += 1
			# Uma volta inteira sem nenhuma ação: o robô espera um instante.
			if started_at_top or wraps >= 2:
				return {"type": "fim"}

		_steps += 1
		instructions_executed += 1
		if _steps > MAX_STEPS:
			return _runtime_error(current_line,
				"O programa executou %d instruções seguidas sem nenhuma ação de combate." % MAX_STEPS,
				"Provavelmente há um laço que nunca termina. Confira se a condição do ENQUANTO/REPITA muda dentro do laço, ou coloque uma ação dentro dele.",
				LBDiagnostic.CAT_LACO)
		if (_steps & 63) == 0 and Time.get_ticks_usec() - t0 > MAX_DECISION_USEC:
			return _runtime_error(current_line, "O programa demorou demais para decidir a próxima ação.",
				"Simplifique os cálculos ou os laços.", LBDiagnostic.CAT_LACO)

		var op: Dictionary = ops[pc]
		current_line = op.line
		line_hits[op.line] = int(line_hits.get(op.line, 0)) + 1

		match op.op:
			"assign":
				var v: Variant = _eval(op.expr)
				if halted:
					return {"type": "erro", "diagnostic": error}
				var t: String = var_types.get(op.name, "")
				if t == "real":
					v = float(v)
				vars[op.name] = v
				pc += 1
			"action":
				pc += 1
				return {"type": "action", "name": op.name, "line": op.line}
			"print":
				var parts := ""
				for a in op.args:
					var v: Variant = _eval(a)
					if halted:
						return {"type": "erro", "diagnostic": error}
					parts += format_value(v)
				_write(parts, op.newline)
				pc += 1
			"jf":
				var c: Variant = _eval(op.cond)
				if halted:
					return {"type": "erro", "diagnostic": error}
				var st: Dictionary = condition_stats.get(op.line, {"v": 0, "f": 0, "kind": op.kind})
				if c:
					st.v += 1
					pc += 1
				else:
					st.f += 1
					pc = op.to
				condition_stats[op.line] = st
			"jmp":
				pc = op.to
			"fim":
				_stack.clear()
				pc = ops.size()
			"call":
				if _stack.size() >= MAX_CALL_DEPTH:
					return _runtime_error(op.line, "Procedimentos chamaram uns aos outros %d vezes sem terminar." % MAX_CALL_DEPTH,
						"Um procedimento que chama a si mesmo (recursão) precisa de uma condição de parada. Verifique as chamadas.",
						LBDiagnostic.CAT_COMANDO)
				_stack.append(pc + 1)
				pc = op.to
			"ret":
				pc = _stack.pop_back() if not _stack.is_empty() else ops.size()
	return {"type": "fim"}


func total_conditions_evaluated() -> int:
	var n := 0
	for k in condition_stats:
		n += condition_stats[k].v + condition_stats[k].f
	return n


static func format_value(v: Variant) -> String:
	if v is bool:
		return "VERDADEIRO" if v else "FALSO"
	if v is float:
		return String.num(v, 2)
	return str(v)


func _write(text: String, _newline: bool) -> void:
	# Cada ESCREVA/ESCREVAL vira uma linha no registro (mais fácil de ler durante a luta).
	var line_text := text.substr(0, MAX_STRING)
	if output_log.size() < MAX_LOG:
		output_log.append(line_text)


func _runtime_error(line: int, msg: String, hint: String, cat: String = LBDiagnostic.CAT_EXECUCAO) -> Dictionary:
	if not halted:
		halted = true
		error = LBDiagnostic.make_error(line, 0, msg, hint, cat)
	return {"type": "erro", "diagnostic": error}


func _fail_eval(line: int, msg: String, hint: String) -> Variant:
	_runtime_error(line, msg, hint)
	return 0


func _eval(e: Dictionary) -> Variant:
	if halted:
		return 0
	_depth += 1
	if _depth > MAX_EXPR_DEPTH:
		_depth -= 1
		return _fail_eval(e.get("line", current_line), "Expressão complexa demais.", "Divida o cálculo em partes usando variáveis.")
	var result: Variant = _eval_inner(e)
	_depth -= 1
	return result


func _eval_inner(e: Dictionary) -> Variant:
	match e.k:
		"num", "str", "bool":
			return e.v
		"var":
			var n: String = e.name
			if vars.has(n):
				return vars[n]
			if sensors.has(n):
				return sensors[n]
			return _fail_eval(e.line, "A variável '%s' não tem valor." % n, "")
		"un":
			var v: Variant = _eval(e.e)
			if e.op == "nao":
				return not v
			return -v
		"bin":
			var op: String = e.op
			# Curto-circuito: em "a e b", se a é falso nem calcula b.
			if op == "e":
				return bool(_eval(e.l)) and bool(_eval(e.r))
			if op == "ou":
				return bool(_eval(e.l)) or bool(_eval(e.r))
			var a: Variant = _eval(e.l)
			var b: Variant = _eval(e.r)
			if halted:
				return 0
			match op:
				"+":
					if a is String:
						var s: String = a + b
						if s.length() > MAX_STRING:
							return _fail_eval(e.line, "O texto ficou grande demais (máximo %d caracteres)." % MAX_STRING, "")
						return s
					return a + b
				"-":
					return a - b
				"*":
					return a * b
				"/":
					if b == 0:
						return _fail_eval(e.line, "Divisão por zero!", "Antes de dividir, verifique se o divisor é diferente de zero com um SE.")
					return float(a) / float(b)
				"div":
					if b == 0:
						return _fail_eval(e.line, "Divisão por zero no DIV!", "Verifique se o divisor é diferente de zero.")
					return int(a) / int(b)
				"mod":
					if b == 0:
						return _fail_eval(e.line, "MOD por zero!", "Verifique se o divisor é diferente de zero.")
					return int(a) % int(b)
				"=":
					return a == b
				"<>":
					return a != b
				"<":
					return a < b
				">":
					return a > b
				"<=":
					return a <= b
				">=":
					return a >= b
	return _fail_eval(e.get("line", current_line), "Operação desconhecida.", "")
