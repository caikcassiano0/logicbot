class_name LBCompiler
extends RefCounted
## Junta todas as etapas: léxico → sintaxe → semântica → "código de máquina" do robô.
##
## O resultado é uma lista plana de operações simples (atribuir, agir, pular...).
## Lista plana + contador de programa (pc) permitem PAUSAR o programa no meio,
## enquanto o robô executa uma ação, e continuar depois — exatamente como um
## processador de verdade faz.
##
## Uso:
##   var result := LBCompiler.compile_source(texto)
##   if result.ok: var vm := LBVM.new(result)

## Resultado da compilação.
class Result:
	extends RefCounted
	var ok := false
	var diagnostics: Array[LBDiagnostic] = []
	var program: Dictionary = {}
	var ops: Array = []
	var initial_vars: Dictionary = {}
	var var_types: Dictionary = {}
	var source_lines: PackedStringArray = []

	func first_error() -> LBDiagnostic:
		for d in diagnostics:
			if d.is_error():
				return d
		return null

	func warnings() -> Array[LBDiagnostic]:
		var out: Array[LBDiagnostic] = []
		for d in diagnostics:
			if not d.is_error():
				out.append(d)
		return out


static func compile_source(source: String) -> Result:
	var r := Result.new()
	r.source_lines = source.split("\n")

	var lexer := LBLexer.new()
	if not lexer.tokenize(source):
		r.diagnostics.append_array(lexer.diagnostics)
		return r

	var parser := LBParser.new()
	var program := parser.parse(lexer.tokens)
	if parser.failed():
		r.diagnostics.append(parser.diagnostic)
		return r

	var checker := LBChecker.new()
	checker.check(program)
	r.diagnostics.append_array(checker.diagnostics)
	if checker.has_errors():
		return r

	r.program = program
	r.var_types = checker.var_types.duplicate()
	for n in r.var_types:
		r.initial_vars[n] = default_value(r.var_types[n])
	var c := LBCompiler.new()
	c._hidden_vars = r.initial_vars
	for pr in program.get("procs", []):
		c._proc_start[pr.name] = -1
	c._block(program.body)
	# fim do programa principal: volta ao início (laço principal do robô)
	c._emit({"op": "fim", "line": 0})
	for pr in program.get("procs", []):
		c._proc_start[pr.name] = c._ops.size()
		c._block(pr.body)
		c._emit({"op": "ret", "line": pr.line})
	for i in c._calls:
		c._ops[i].to = c._proc_start[c._ops[i].name]
	r.ops = c._ops
	r.ok = true
	return r


static func default_value(t: String) -> Variant:
	match t:
		"inteiro":
			return 0
		"real":
			return 0.0
		"logico":
			return false
		"caractere":
			return ""
	return null


var _ops: Array = []
var _hidden_vars: Dictionary
var _hidden_count := 0
var _proc_start: Dictionary = {}
var _calls: Array[int] = []


func _emit(op: Dictionary) -> int:
	_ops.append(op)
	return _ops.size() - 1


func _block(stmts: Array) -> void:
	for s in stmts:
		_stmt(s)


func _stmt(s: Dictionary) -> void:
	match s.k:
		"assign":
			_emit({"op": "assign", "name": s.name, "expr": s.expr, "line": s.line})
		"call":
			if _proc_start.has(s.name):
				_calls.append(_emit({"op": "call", "name": s.name, "to": -1, "line": s.line}))
			else:
				_emit({"op": "action", "name": s.name, "line": s.line})
		"print":
			_emit({"op": "print", "args": s.args, "newline": s.newline, "line": s.line})
		"if":
			var end_jumps: Array[int] = []
			for b in s.branches:
				var jf := _emit({"op": "jf", "cond": b.cond, "to": -1, "line": b.line, "kind": "se"})
				_block(b.body)
				end_jumps.append(_emit({"op": "jmp", "to": -1, "line": b.line}))
				_ops[jf].to = _ops.size()
			_block(s.else_body)
			for j in end_jumps:
				_ops[j].to = _ops.size()
		"while":
			var start := _ops.size()
			var jf := _emit({"op": "jf", "cond": s.cond, "to": -1, "line": s.line, "kind": "enquanto"})
			_block(s.body)
			_emit({"op": "jmp", "to": start, "line": s.line})
			_ops[jf].to = _ops.size()
		"repeat":
			var start := _ops.size()
			_block(s.body)
			# REPITA ... ATE cond  →  volta ao início enquanto a condição for FALSA
			_emit({"op": "jf", "cond": s.cond, "to": start, "line": s.cond_line, "kind": "repita"})
		"for":
			var step: int = LBChecker.step_value(s.step)
			var lim := "__limite_%d" % _hidden_count
			_hidden_count += 1
			_hidden_vars[lim] = 0
			_emit({"op": "assign", "name": s.var, "expr": s.from, "line": s.line})
			_emit({"op": "assign", "name": lim, "expr": s.to, "line": s.line})
			var cmp := "<=" if step > 0 else ">="
			var cond := {"k": "bin", "op": cmp, "l": {"k": "var", "name": s.var, "line": s.line},
				"r": {"k": "var", "name": lim, "line": s.line}, "line": s.line}
			var start := _ops.size()
			var jf := _emit({"op": "jf", "cond": cond, "to": -1, "line": s.line, "kind": "para"})
			_block(s.body)
			var inc := {"k": "bin", "op": "+", "l": {"k": "var", "name": s.var, "line": s.line},
				"r": {"k": "num", "v": step, "t": "inteiro", "line": s.line}, "line": s.line}
			_emit({"op": "assign", "name": s.var, "expr": inc, "line": s.line})
			_emit({"op": "jmp", "to": start, "line": s.line})
			_ops[jf].to = _ops.size()
