class_name LBChecker
extends RefCounted
## VALIDAÇÃO SEMÂNTICA — o programa está bem escrito, mas faz sentido?
##
## Exemplos do que é verificado aqui:
##   * variável usada sem ter sido declarada;
##   * tentativa de alterar um sensor (vida <- 100 não é permitido!);
##   * tipos incompatíveis (guardar um número em uma variável lógica);
##   * condição do SE que não resulta em verdadeiro/falso (se vida entao);
##   * comando que não existe (atacr() → "você quis dizer atacar()?").

const NUMERIC: Array[String] = ["inteiro", "real"]
const MAX_VARIABLES := 40
const MAX_ERRORS := 6

var diagnostics: Array[LBDiagnostic] = []
var var_types: Dictionary = {}
var _used: Dictionary = {}
var _decl_lines: Dictionary = {}
var _action_count := 0
var proc_names: Dictionary = {}     ## nome -> linha
var _procs_called: Dictionary = {}


func errors() -> Array[LBDiagnostic]:
	var out: Array[LBDiagnostic] = []
	for d in diagnostics:
		if d.is_error():
			out.append(d)
	return out


func has_errors() -> bool:
	return not errors().is_empty()


func check(program: Dictionary) -> bool:
	diagnostics.clear()
	var_types.clear()
	_used.clear()
	_decl_lines.clear()
	_action_count = 0
	proc_names.clear()
	_procs_called.clear()

	for d in program.decls:
		var n: String = d.name
		if LBRobotAPI.is_sensor(n):
			_err(d.line, "'%s' já é um sensor do robô. Escolha outro nome para a sua variável." % n,
				"Os sensores (vida, energia, inimigo_perto...) já existem e podem ser usados direto.", LBDiagnostic.CAT_VARIAVEL)
		elif LBRobotAPI.is_action(n):
			_err(d.line, "'%s' é o nome de um comando do robô. Escolha outro nome para a variável." % n, "", LBDiagnostic.CAT_VARIAVEL)
		elif n in LBLexer.KEYWORDS:
			_err(d.line, "'%s' é uma palavra reservada da linguagem." % n, "", LBDiagnostic.CAT_VARIAVEL)
		elif var_types.has(n):
			_err(d.line, "A variável '%s' foi declarada duas vezes (a primeira na linha %d)." % [n, _decl_lines[n]],
				"Apague uma das declarações.", LBDiagnostic.CAT_VARIAVEL)
		else:
			var_types[n] = d.type
			_decl_lines[n] = d.line
	if var_types.size() > MAX_VARIABLES:
		_err(1, "Há variáveis demais (máximo %d)." % MAX_VARIABLES, "", LBDiagnostic.CAT_VARIAVEL)

	for pr in program.get("procs", []):
		var pn: String = pr.name
		if LBRobotAPI.is_action(pn) or LBRobotAPI.is_sensor(pn) or var_types.has(pn):
			_err(pr.line, "O nome '%s' já é usado por um comando, sensor ou variável." % pn, "Escolha outro nome para o procedimento.", LBDiagnostic.CAT_COMANDO)
		elif proc_names.has(pn):
			_err(pr.line, "Já existe um procedimento chamado '%s' (linha %d)." % [pn, proc_names[pn]], "", LBDiagnostic.CAT_COMANDO)
		else:
			proc_names[pn] = pr.line
	for pr in program.get("procs", []):
		_block(pr.body)
	_block(program.body)

	if not has_errors():
		if _action_count == 0:
			diagnostics.append(LBDiagnostic.make_warning(program.line,
				"O programa não usa nenhum comando de ação. O robô vai ficar parado!",
				"Use comandos como atacar(), defender() ou avancar().", LBDiagnostic.CAT_COMANDO))
		for pn in proc_names:
			if not _procs_called.has(pn):
				diagnostics.append(LBDiagnostic.make_warning(proc_names[pn],
					"O procedimento '%s' foi criado mas nunca é chamado." % pn, "Chame-o escrevendo  %s()" % pn, LBDiagnostic.CAT_COMANDO))
		for n in var_types:
			if not _used.has(n):
				diagnostics.append(LBDiagnostic.make_warning(_decl_lines[n],
					"A variável '%s' foi declarada mas nunca é usada." % n, "Você pode apagá-la ou usá-la na sua estratégia.", LBDiagnostic.CAT_VARIAVEL))
	return not has_errors()


func _err(line: int, msg: String, hint: String, cat: String) -> void:
	if diagnostics.size() < MAX_ERRORS:
		diagnostics.append(LBDiagnostic.make_error(line, 0, msg, hint, cat))


func _block(stmts: Array) -> void:
	for s in stmts:
		_stmt(s)


func _stmt(s: Dictionary) -> void:
	match s.k:
		"assign":
			_assign(s)
		"call":
			_call(s)
		"print":
			for a in s.args:
				_type_of(a)
		"if":
			for b in s.branches:
				_require_logic(b.cond, "SE", b.line, LBDiagnostic.CAT_CONDICIONAL)
				_block(b.body)
			_block(s.else_body)
		"while":
			_require_logic(s.cond, "ENQUANTO", s.line, LBDiagnostic.CAT_LACO)
			_block(s.body)
		"repeat":
			_block(s.body)
			_require_logic(s.cond, "ATE", s.cond_line, LBDiagnostic.CAT_LACO)
		"for":
			_for(s)


func _assign(s: Dictionary) -> void:
	var n: String = s.name
	if LBRobotAPI.is_sensor(n):
		_err(s.line, "'%s' é um sensor do robô: ele pode ser lido, mas não alterado." % n,
			"Crie sua própria variável em VAR se precisar guardar um valor.", LBDiagnostic.CAT_VARIAVEL)
		return
	if not var_types.has(n):
		_undeclared(n, s.line)
		return
	_used[n] = true
	var t := _type_of(s.expr)
	if t == "?":
		return
	var target: String = var_types[n]
	if not _assignable(target, t):
		_err(s.line, "A variável '%s' é do tipo %s, mas o valor é do tipo %s." % [n, target, t],
			_type_hint(target), LBDiagnostic.CAT_TIPO)


func _assignable(target: String, value: String) -> bool:
	return target == value or (target == "real" and value == "inteiro")


func _type_hint(t: String) -> String:
	match t:
		"inteiro":
			return "Variáveis inteiro guardam números sem vírgula, como 3 ou -10. Para dividir use div."
		"real":
			return "Variáveis real guardam números como 2.5."
		"logico":
			return "Variáveis logico guardam verdadeiro, falso ou o resultado de uma comparação (ex: vida < 30)."
		"caractere":
			return "Variáveis caractere guardam textos entre aspas, como \"ataque\"."
	return ""


func _call(s: Dictionary) -> void:
	var n: String = s.name
	if LBRobotAPI.is_action(n):
		_action_count += 1
		if LBRobotAPI.bloqueados.has(n):
			_err(s.line, "O golpe %s() ainda está bloqueado." % n, LBRobotAPI.bloqueados[n], LBDiagnostic.CAT_COMANDO)
		return
	if proc_names.has(n):
		_procs_called[n] = true
		return
	if var_types.has(n) or LBRobotAPI.is_sensor(n):
		_used[n] = true
		_err(s.line, "'%s' é uma variável, não um comando. Sozinha na linha ela não faz nada." % n,
			"Use-a em uma condição (se %s ... entao) ou guarde um valor nela (%s <- ...)." % [n, n], LBDiagnostic.CAT_COMANDO)
		return
	var guess := LBRobotAPI.closest_name(n, LBRobotAPI.ACTIONS.keys() + proc_names.keys())
	var hint := "Você quis dizer %s()?" % guess if guess != "" else "Comandos disponíveis: " + ", ".join(LBRobotAPI.ACTIONS.keys().map(func(a): return a + "()"))
	_err(s.line, "O comando '%s' não existe." % n, hint, LBDiagnostic.CAT_COMANDO)


func _for(s: Dictionary) -> void:
	var n: String = s.var
	if LBRobotAPI.is_sensor(n):
		_err(s.line, "'%s' é um sensor e não pode ser usado como contador do PARA." % n,
			"Declare uma variável inteiro, como i, para contar.", LBDiagnostic.CAT_LACO)
		return
	if not var_types.has(n):
		_undeclared(n, s.line)
		return
	_used[n] = true
	if var_types[n] != "inteiro":
		_err(s.line, "O contador do PARA precisa ser do tipo inteiro ('%s' é %s)." % [n, var_types[n]], "", LBDiagnostic.CAT_LACO)
	for part in [s.from, s.to]:
		var t := _type_of(part)
		if t != "?" and t != "inteiro":
			_err(s.line, "Os limites do PARA precisam ser números inteiros.", "Ex: para i de 1 ate 3 faca", LBDiagnostic.CAT_LACO)
	if s.step != null:
		var v: Variant = step_value(s.step)
		if v == null or v == 0:
			_err(s.line, "O PASSO do PARA precisa ser um número inteiro fixo e diferente de zero.",
				"Ex: passo 2   ou   passo -1", LBDiagnostic.CAT_LACO)
	_block(s.body)


## Valor numérico constante do PASSO (aceita -1), ou null se não for constante inteira.
static func step_value(e: Variant) -> Variant:
	if e == null:
		return 1
	if e.k == "num" and e.t == "inteiro":
		return e.v
	if e.k == "un" and e.op == "-" and e.e.k == "num" and e.e.t == "inteiro":
		return -int(e.e.v)
	return null


func _require_logic(cond: Dictionary, owner: String, line: int, cat: String) -> void:
	var t := _type_of(cond)
	if t == "?" or t == "logico":
		return
	var example := "se vida < 30 entao" if owner == "SE" else "enquanto energia < 50 faca"
	_err(line, "A condição do %s precisa resultar em verdadeiro ou falso, mas resulta em um valor %s." % [owner, t],
		"Compare o valor com algo. Ex: %s" % example, cat)


func _undeclared(n: String, line: int) -> void:
	var candidates: Array = var_types.keys() + LBRobotAPI.SENSORS.keys()
	var guess := LBRobotAPI.closest_name(n, candidates)
	var hint := "Você quis dizer '%s'?" % guess if guess != "" else "Declare a variável depois de VAR. Ex:  %s: inteiro" % n
	if LBRobotAPI.is_action(n):
		hint = "%s é um comando: use-o sozinho em uma linha, como %s()" % [n, n]
	_err(line, "A variável '%s' não existe." % n, hint, LBDiagnostic.CAT_VARIAVEL)


## Descobre o tipo de uma expressão. Retorna "?" quando já houve erro.
func _type_of(e: Dictionary) -> String:
	match e.k:
		"num":
			return e.t
		"str":
			return "caractere"
		"bool":
			return "logico"
		"var":
			var n: String = e.name
			if LBRobotAPI.is_sensor(n):
				return LBRobotAPI.sensor_type(n)
			if var_types.has(n):
				_used[n] = true
				return var_types[n]
			_undeclared(n, e.line)
			return "?"
		"un":
			var t := _type_of(e.e)
			if t == "?":
				return t
			if e.op == "nao":
				if t != "logico":
					_err(e.line, "NAO só pode ser usado com condições (verdadeiro/falso).", "Ex: se nao inimigo_perto entao", LBDiagnostic.CAT_OPERADOR)
					return "?"
				return "logico"
			if not (t in NUMERIC):
				_err(e.line, "O sinal de menos só funciona com números.", "", LBDiagnostic.CAT_OPERADOR)
				return "?"
			return t
		"bin":
			return _bin_type(e)
	return "?"


func _bin_type(e: Dictionary) -> String:
	var lt := _type_of(e.l)
	var rt := _type_of(e.r)
	if lt == "?" or rt == "?":
		return "?"
	var op: String = e.op
	match op:
		"e", "ou":
			if lt != "logico" or rt != "logico":
				_err(e.line, "O operador %s liga duas condições (verdadeiro/falso), mas recebeu %s e %s." % [op.to_upper(), lt, rt],
					"Ex: se inimigo_perto e energia >= 50 entao", LBDiagnostic.CAT_OPERADOR)
				return "?"
			return "logico"
		"=", "<>":
			var both_num := lt in NUMERIC and rt in NUMERIC
			if not both_num and lt != rt:
				_err(e.line, "Não dá para comparar um valor %s com um valor %s." % [lt, rt], "", LBDiagnostic.CAT_OPERADOR)
				return "?"
			return "logico"
		"<", ">", "<=", ">=":
			if not (lt in NUMERIC and rt in NUMERIC):
				var hint := ""
				if lt == "logico" or rt == "logico":
					hint = "Variáveis lógicas já são verdadeiro/falso. Use direto: se inimigo_perto entao"
				_err(e.line, "O operador %s compara números, mas recebeu %s e %s." % [op, lt, rt], hint, LBDiagnostic.CAT_OPERADOR)
				return "?"
			return "logico"
		"+", "-", "*":
			if op == "+" and lt == "caractere" and rt == "caractere":
				return "caractere"
			if not (lt in NUMERIC and rt in NUMERIC):
				_err(e.line, "O operador %s só funciona com números (recebeu %s e %s)." % [op, lt, rt], "", LBDiagnostic.CAT_OPERADOR)
				return "?"
			return "inteiro" if lt == "inteiro" and rt == "inteiro" else "real"
		"/":
			if not (lt in NUMERIC and rt in NUMERIC):
				_err(e.line, "A divisão só funciona com números.", "", LBDiagnostic.CAT_OPERADOR)
				return "?"
			return "real"
		"div", "mod":
			if lt != "inteiro" or rt != "inteiro":
				_err(e.line, "%s só funciona com números inteiros." % op.to_upper(),
					"div é a divisão inteira (7 div 2 = 3) e mod é o resto (7 mod 2 = 1).", LBDiagnostic.CAT_OPERADOR)
				return "?"
			return "inteiro"
	return "?"
