class_name LBParser
extends RefCounted
## ANÁLISE SINTÁTICA — confere se os tokens formam frases válidas da linguagem
## e monta a "árvore sintática" (AST): uma estrutura que representa o programa.
##
## A gramática completa está em documentation/LINGUAGEM.md.
## Técnica usada: "descida recursiva" — uma função para cada regra da gramática.
##
## O parser para no PRIMEIRO erro. Para iniciantes, uma mensagem clara de cada
## vez é mais útil do que uma lista de 10 erros em cascata.

const T := LBLexer.T

const CLOSERS: Array[String] = ["fimalgoritmo", "fimse", "senao", "fimenquanto", "ate", "fimpara", "fimprocedimento"]
const OPENER_NAME := {"se": "SE", "enquanto": "ENQUANTO", "para": "PARA", "repita": "REPITA", "inicio": "INICIO", "procedimento": "PROCEDIMENTO"}
const OPENER_CLOSER := {"se": "FIMSE", "enquanto": "FIMENQUANTO", "para": "FIMPARA", "repita": "ATE <condição>", "inicio": "FIMALGORITMO", "procedimento": "FIMPROCEDIMENTO"}
const RELOPS: Array[String] = ["=", "<>", "<", ">", "<=", ">="]
const VAR_TYPES: Array[String] = ["inteiro", "real", "logico", "caractere"]
const MAX_NESTING := 12

var diagnostic: LBDiagnostic = null
var _toks: Array[Dictionary] = []
var _pos := 0
var _depth := 0


func failed() -> bool:
	return diagnostic != null


## Retorna o programa como Dictionary, ou {} se houver erro (veja [member diagnostic]).
func parse(tokens: Array[Dictionary]) -> Dictionary:
	_toks = tokens
	_pos = 0
	_depth = 0
	diagnostic = null
	var program := _program()
	return {} if failed() else program


# ---------------------------------------------------------------- utilidades

func _peek(offset: int = 0) -> Dictionary:
	return _toks[mini(_pos + offset, _toks.size() - 1)]


func _advance() -> Dictionary:
	var t := _peek()
	if _pos < _toks.size() - 1:
		_pos += 1
	return t


func _is_kw(tok: Dictionary, kw: String) -> bool:
	return tok.type == T.KEYWORD and tok.value == kw


func _check_kw(kw: String) -> bool:
	return _is_kw(_peek(), kw)


func _match_kw(kw: String) -> bool:
	if _check_kw(kw):
		_advance()
		return true
	return false


func _skip_newlines() -> void:
	while _peek().type == T.NEWLINE:
		_advance()


func _describe(tok: Dictionary) -> String:
	match tok.type:
		T.NEWLINE:
			return "o fim da linha"
		T.EOF:
			return "o fim do programa"
		T.STRING:
			return "o texto \"%s\"" % tok.value
		T.KEYWORD:
			return "'%s'" % String(tok.value).to_upper()
		_:
			return "'%s'" % str(tok.value)


func _fail(tok: Dictionary, msg: String, hint: String = "", cat: String = LBDiagnostic.CAT_SINTAXE) -> void:
	if diagnostic == null:
		diagnostic = LBDiagnostic.make_error(tok.line, tok.col, msg, hint, cat)


func _expect_newline(after: String) -> void:
	var tok := _peek()
	if tok.type == T.NEWLINE:
		_advance()
	elif tok.type != T.EOF:
		_fail(tok, "Depois de %s esperava o fim da linha, mas encontrei %s." % [after, _describe(tok)],
			"Coloque cada instrução em uma linha separada.")


# ---------------------------------------------------------------- programa

func _program() -> Dictionary:
	_skip_newlines()
	var first := _peek()
	if not _is_kw(first, "algoritmo"):
		_fail(first, "Todo programa começa com a linha:  algoritmo \"NomeDoRobo\"",
			"Escreva na primeira linha: algoritmo \"MeuRobo\"")
		return {}
	_advance()
	var name := "SemNome"
	if _peek().type == T.STRING:
		name = _advance().value
	_expect_newline("o nome do algoritmo")
	if failed():
		return {}

	var decls: Array[Dictionary] = []
	_skip_newlines()
	if _match_kw("var"):
		_expect_newline("VAR")
		while not failed():
			_skip_newlines()
			if _peek().type != T.IDENT:
				break
			_declaration(decls)
	if failed():
		return {}

	var procs: Array[Dictionary] = []
	_skip_newlines()
	while _check_kw("procedimento") and not failed():
		procs.append(_procedure())
		_skip_newlines()
	if failed():
		return {}

	_skip_newlines()
	var start := _peek()
	if not _is_kw(start, "inicio"):
		var hint := "As instruções do robô ficam entre INICIO e FIMALGORITMO."
		if start.type == T.IDENT:
			hint = "Se '%s' é uma variável, declare-a depois de VAR assim:  %s: inteiro" % [start.value, start.value]
		_fail(start, "Esperava INICIO, mas encontrei %s." % _describe(start), hint)
		return {}
	_advance()
	_expect_newline("INICIO")
	var body := _block(["fimalgoritmo"], "inicio", start.line)
	if failed():
		return {}
	_advance() # fimalgoritmo
	_skip_newlines()
	if _peek().type != T.EOF:
		_fail(_peek(), "Há instruções depois de FIMALGORITMO.",
			"FIMALGORITMO deve ser a última linha do programa.")
		return {}
	return {"name": name, "decls": decls, "procs": procs, "body": body, "line": first.line}


## procedimento nome()  [inicio]  ...  fimprocedimento
func _procedure() -> Dictionary:
	var tok := _advance()
	var name_tok := _peek()
	if name_tok.type != T.IDENT:
		_fail(name_tok, "Depois de PROCEDIMENTO vem o nome dele.", "Ex: procedimento contra_ataque()")
		return {}
	_advance()
	if _peek().type == T.LPAREN:
		_advance()
		if _peek().type != T.RPAREN:
			_fail(_peek(), "Os procedimentos do LogicBot ainda não recebem parâmetros.",
				"Escreva apenas  procedimento %s()" % name_tok.value)
			return {}
		_advance()
	_expect_newline("o nome do procedimento")
	_skip_newlines()
	if _check_kw("var"):
		_fail(_peek(), "Procedimentos não têm variáveis próprias (ainda).",
			"Declare as variáveis no VAR do algoritmo; os procedimentos podem usá-las.", LBDiagnostic.CAT_VARIAVEL)
		return {}
	if _match_kw("inicio"):
		_expect_newline("INICIO")
	var body := _block(["fimprocedimento"], "procedimento", tok.line)
	if failed():
		return {}
	_advance()
	_expect_newline("FIMPROCEDIMENTO")
	return {"name": name_tok.value, "body": body, "line": tok.line}


func _declaration(decls: Array[Dictionary]) -> void:
	var first := _advance()
	var names: Array[Dictionary] = [first]
	while _peek().type == T.COMMA:
		_advance()
		var tok := _peek()
		if tok.type != T.IDENT:
			_fail(tok, "Depois da vírgula esperava o nome de outra variável.", "Ex: x, y: inteiro", LBDiagnostic.CAT_VARIAVEL)
			return
		names.append(_advance())
	if _peek().type != T.COLON:
		_fail(_peek(), "Na declaração de variável, depois do nome vem dois-pontos e o tipo.",
			"Ex:  %s: inteiro" % first.value, LBDiagnostic.CAT_VARIAVEL)
		return
	_advance()
	var type_tok := _peek()
	if type_tok.type != T.KEYWORD or not (type_tok.value in VAR_TYPES):
		_fail(type_tok, "Tipo de variável desconhecido: %s." % _describe(type_tok),
			"Tipos válidos: inteiro, real, logico, caractere.", LBDiagnostic.CAT_TIPO)
		return
	_advance()
	for n in names:
		decls.append({"name": n.value, "type": type_tok.value, "line": n.line})
	_expect_newline("a declaração da variável")


# ---------------------------------------------------------------- blocos

func _block(terminators: Array, opener: String, opener_line: int) -> Array:
	var stmts: Array = []
	_depth += 1
	if _depth > MAX_NESTING:
		_fail(_peek(), "Há estruturas demais umas dentro das outras (máximo %d níveis)." % MAX_NESTING,
			"Tente simplificar: estruturas muito aninhadas são difíceis de entender.")
		return stmts
	while not failed():
		_skip_newlines()
		var tok := _peek()
		if tok.type == T.EOF:
			if opener == "inicio":
				_fail(tok, "Falta FIMALGORITMO no final do programa.", "A última linha deve ser: fimalgoritmo")
			else:
				_fail(tok, "O %s da linha %d não foi fechado. Falta %s." % [OPENER_NAME[opener], opener_line, OPENER_CLOSER[opener]],
					"Toda estrutura que abre precisa fechar.", _category_for(opener))
			break
		if tok.type == T.KEYWORD and tok.value in terminators:
			break
		if _is_kw(tok, "inicio") and opener != "inicio":
			if opener == "procedimento":
				_fail(tok, "O PROCEDIMENTO da linha %d não foi fechado. Falta FIMPROCEDIMENTO antes deste INICIO." % opener_line,
					"Termine cada procedimento com  fimprocedimento  antes de começar o programa principal.")
			else:
				_fail(tok, "INICIO só aparece uma vez, no começo do programa principal.",
					"Feche o %s da linha %d com %s." % [OPENER_NAME[opener], opener_line, OPENER_CLOSER[opener]], _category_for(opener))
			break
		if tok.type == T.KEYWORD and tok.value in CLOSERS:
			_mismatch(tok, opener, opener_line)
			break
		var s := _statement()
		if failed():
			break
		stmts.append(s)
	_depth -= 1
	return stmts


func _category_for(opener: String) -> String:
	match opener:
		"se":
			return LBDiagnostic.CAT_CONDICIONAL
		"enquanto", "para", "repita":
			return LBDiagnostic.CAT_LACO
	return LBDiagnostic.CAT_SINTAXE


func _mismatch(tok: Dictionary, opener: String, opener_line: int) -> void:
	var found := String(tok.value).to_upper()
	if opener == "inicio":
		var msg := "Encontrei %s sem uma estrutura aberta correspondente." % found
		var hint := "Confira se cada SE, ENQUANTO, PARA e REPITA tem o seu fechamento certo."
		if tok.value == "senao":
			msg = "SENAO sem um SE aberto."
			hint = "SENAO só pode aparecer dentro de um SE ... ENTAO."
		_fail(tok, msg, hint, LBDiagnostic.CAT_SINTAXE)
	elif opener == "se" and tok.value == "senao":
		_fail(tok, "O SE da linha %d já tem um SENAO final; não pode ter outro." % opener_line,
			"Para mais de duas opções use SENAO SE ... ENTAO antes do SENAO final.", LBDiagnostic.CAT_CONDICIONAL)
	else:
		_fail(tok, "Encontrei %s, mas o %s da linha %d ainda está aberto." % [found, OPENER_NAME[opener], opener_line],
			"Feche o %s com %s antes." % [OPENER_NAME[opener], OPENER_CLOSER[opener]], _category_for(opener))


# ---------------------------------------------------------------- instruções

func _statement() -> Dictionary:
	var tok := _peek()
	if tok.type == T.KEYWORD:
		match tok.value:
			"se":
				return _if_stmt()
			"enquanto":
				return _while_stmt()
			"repita":
				return _repeat_stmt()
			"para":
				return _for_stmt()
			"escreva", "escreval":
				return _print_stmt()
			"var":
				_fail(tok, "VAR só pode aparecer uma vez, antes de INICIO.",
					"Declare todas as variáveis no começo do programa.", LBDiagnostic.CAT_VARIAVEL)
				return {}
			"entao":
				_fail(tok, "ENTAO apareceu sem um SE antes.", "Ex: se inimigo_perto entao", LBDiagnostic.CAT_CONDICIONAL)
				return {}
			"procedimento":
				_fail(tok, "Procedimentos são declarados ANTES do INICIO do algoritmo.",
					"Mova o bloco procedimento ... fimprocedimento para logo depois do VAR.")
				return {}
			_:
				_fail(tok, "Não esperava %s aqui." % _describe(tok), "Comece a instrução com um comando, uma variável ou uma estrutura como SE.")
				return {}

	if tok.type == T.IDENT:
		_advance()
		var nxt := _peek()
		if nxt.type == T.OP and nxt.value == "<-":
			_advance()
			var expr := _expression()
			if failed():
				return {}
			_expect_newline("a atribuição")
			return {"k": "assign", "name": tok.value, "expr": expr, "line": tok.line}
		if nxt.type == T.OP and nxt.value == "=":
			_fail(nxt, "Para guardar um valor em uma variável use a seta <- (e não =).",
				"Ex:  %s <- 10     (o sinal = serve para comparar dentro de condições)" % tok.value, LBDiagnostic.CAT_OPERADOR)
			return {}
		if nxt.type == T.LPAREN:
			_advance()
			if _peek().type != T.RPAREN:
				_fail(_peek(), "O comando %s() não recebe valores dentro dos parênteses." % tok.value,
					"Escreva apenas  %s()" % tok.value, LBDiagnostic.CAT_COMANDO)
				return {}
			_advance()
			_expect_newline("%s()" % tok.value)
			return {"k": "call", "name": tok.value, "line": tok.line}
		if nxt.type == T.NEWLINE or nxt.type == T.EOF:
			if nxt.type == T.NEWLINE:
				_advance()
			return {"k": "call", "name": tok.value, "line": tok.line, "no_parens": true}
		_fail(nxt, "Não entendi a instrução que começa com '%s'." % tok.value,
			"Instruções válidas: um comando como atacar(), uma atribuição como x <- 5, ou uma estrutura como SE.")
		return {}

	_fail(tok, "Uma instrução não pode começar com %s." % _describe(tok),
		"Comece com um comando (ex: atacar()), uma variável (ex: x <- 1) ou uma estrutura (ex: se ... entao).")
	return {}


func _if_stmt() -> Dictionary:
	var se_tok := _advance()
	var branches: Array = []
	var cond := _condition("SE", "entao")
	if failed():
		return {}
	_expect_newline("ENTAO")
	var body := _block(["senao", "fimse"], "se", se_tok.line)
	if failed():
		return {}
	branches.append({"cond": cond, "body": body, "line": se_tok.line})
	var else_body: Array = []
	var has_else := false
	while _check_kw("senao"):
		var senao_tok := _advance()
		if _check_kw("se"):
			_advance()
			var c := _condition("SENAO SE", "entao")
			if failed():
				return {}
			_expect_newline("ENTAO")
			var b := _block(["senao", "fimse"], "se", se_tok.line)
			if failed():
				return {}
			branches.append({"cond": c, "body": b, "line": senao_tok.line})
		else:
			_expect_newline("SENAO")
			else_body = _block(["fimse"], "se", se_tok.line)
			has_else = true
			if failed():
				return {}
			break
	_advance() # fimse
	_expect_newline("FIMSE")
	return {"k": "if", "branches": branches, "else_body": else_body, "has_else": has_else, "line": se_tok.line}


func _condition(owner: String, closing_kw: String) -> Dictionary:
	var tok := _peek()
	if _is_kw(tok, closing_kw) or tok.type == T.NEWLINE:
		_fail(tok, "Falta a condição do %s." % owner,
			"Escreva o que deve ser verificado. Ex: %s inimigo_perto %s" % [owner.to_lower(), closing_kw],
			LBDiagnostic.CAT_CONDICIONAL)
		return {}
	var cond := _expression()
	if failed():
		return {}
	if not _match_kw(closing_kw):
		var cat := LBDiagnostic.CAT_CONDICIONAL if closing_kw == "entao" else LBDiagnostic.CAT_LACO
		_fail(_peek(), "Depois da condição do %s escreva %s (encontrei %s)." % [owner, closing_kw.to_upper(), _describe(_peek())],
			"Ex: %s energia >= 50 %s" % [owner.to_lower(), closing_kw], cat)
		return {}
	return cond


func _while_stmt() -> Dictionary:
	var tok := _advance()
	var cond := _condition("ENQUANTO", "faca")
	if failed():
		return {}
	_expect_newline("FACA")
	var body := _block(["fimenquanto"], "enquanto", tok.line)
	if failed():
		return {}
	_advance()
	_expect_newline("FIMENQUANTO")
	return {"k": "while", "cond": cond, "body": body, "line": tok.line}


func _repeat_stmt() -> Dictionary:
	var tok := _advance()
	_expect_newline("REPITA")
	var body := _block(["ate"], "repita", tok.line)
	if failed():
		return {}
	var ate_tok := _advance()
	if _peek().type == T.NEWLINE or _peek().type == T.EOF:
		_fail(_peek(), "Depois de ATE escreva a condição que encerra o REPITA.",
			"Ex: ate vida_inimigo = 0", LBDiagnostic.CAT_LACO)
		return {}
	var cond := _expression()
	if failed():
		return {}
	_expect_newline("a condição do ATE")
	return {"k": "repeat", "cond": cond, "body": body, "line": tok.line, "cond_line": ate_tok.line}


func _for_stmt() -> Dictionary:
	var tok := _advance()
	var var_tok := _peek()
	if var_tok.type != T.IDENT:
		_fail(var_tok, "Depois de PARA vem o nome da variável contadora.",
			"Ex: para i de 1 ate 3 faca", LBDiagnostic.CAT_LACO)
		return {}
	_advance()
	if not _match_kw("de"):
		_fail(_peek(), "No PARA, depois da variável escreva DE e o valor inicial.",
			"Ex: para %s de 1 ate 3 faca" % var_tok.value, LBDiagnostic.CAT_LACO)
		return {}
	var from_e := _expression()
	if failed():
		return {}
	if not _match_kw("ate"):
		_fail(_peek(), "No PARA, depois do valor inicial escreva ATE e o valor final.",
			"Ex: para %s de 1 ate 3 faca" % var_tok.value, LBDiagnostic.CAT_LACO)
		return {}
	var to_e := _expression()
	if failed():
		return {}
	var step_e: Variant = null
	if _match_kw("passo"):
		step_e = _expression()
		if failed():
			return {}
	if not _match_kw("faca"):
		_fail(_peek(), "O PARA precisa terminar a linha com FACA.",
			"Ex: para %s de 1 ate 3 faca" % var_tok.value, LBDiagnostic.CAT_LACO)
		return {}
	_expect_newline("FACA")
	var body := _block(["fimpara"], "para", tok.line)
	if failed():
		return {}
	_advance()
	_expect_newline("FIMPARA")
	return {"k": "for", "var": var_tok.value, "from": from_e, "to": to_e, "step": step_e, "body": body, "line": tok.line}


func _print_stmt() -> Dictionary:
	var tok := _advance()
	if _peek().type != T.LPAREN:
		_fail(_peek(), "%s precisa de parênteses." % String(tok.value).to_upper(),
			"Ex: %s(\"Vida: \", vida)" % tok.value)
		return {}
	_advance()
	var args: Array = []
	if _peek().type != T.RPAREN:
		while true:
			args.append(_expression())
			if failed():
				return {}
			if _peek().type == T.COMMA:
				_advance()
			else:
				break
	if _peek().type != T.RPAREN:
		_fail(_peek(), "Faltou fechar o parêntese do %s." % String(tok.value).to_upper(),
			"Separe os valores com vírgula e termine com ).")
		return {}
	_advance()
	_expect_newline(")")
	return {"k": "print", "args": args, "newline": tok.value == "escreval", "line": tok.line}


# ---------------------------------------------------------------- expressões
# Precedência (da menor para a maior):
#   OU  <  E  <  NAO  <  comparações  <  + -  <  * / div mod  <  - unário

func _expression() -> Dictionary:
	return _or_expr()


func _or_expr() -> Dictionary:
	var left := _and_expr()
	while not failed() and _check_kw("ou"):
		var op := _advance()
		var right := _and_expr()
		left = {"k": "bin", "op": "ou", "l": left, "r": right, "line": op.line}
	return left


func _and_expr() -> Dictionary:
	var left := _not_expr()
	while not failed() and _check_kw("e"):
		var op := _advance()
		var right := _not_expr()
		left = {"k": "bin", "op": "e", "l": left, "r": right, "line": op.line}
	return left


func _not_expr() -> Dictionary:
	if _check_kw("nao"):
		var op := _advance()
		var e := _not_expr()
		return {"k": "un", "op": "nao", "e": e, "line": op.line}
	return _rel_expr()


func _rel_expr() -> Dictionary:
	var left := _add_expr()
	if failed():
		return left
	var tok := _peek()
	if tok.type == T.OP and tok.value in RELOPS:
		_advance()
		var right := _add_expr()
		if failed():
			return right
		var nxt := _peek()
		if nxt.type == T.OP and nxt.value in RELOPS:
			_fail(nxt, "Compare uma coisa de cada vez.",
				"Para verificar um intervalo, junte duas comparações com E. Ex: se vida > 10 e vida < 30 entao",
				LBDiagnostic.CAT_OPERADOR)
			return {}
		return {"k": "bin", "op": tok.value, "l": left, "r": right, "line": tok.line}
	return left


func _add_expr() -> Dictionary:
	var left := _mul_expr()
	while not failed():
		var tok := _peek()
		if tok.type == T.OP and (tok.value == "+" or tok.value == "-"):
			_advance()
			var right := _mul_expr()
			left = {"k": "bin", "op": tok.value, "l": left, "r": right, "line": tok.line}
		else:
			break
	return left


func _mul_expr() -> Dictionary:
	var left := _unary()
	while not failed():
		var tok := _peek()
		var op := ""
		if tok.type == T.OP and tok.value in ["*", "/", "div", "mod"]:
			op = tok.value
		elif tok.type == T.KEYWORD and tok.value in ["div", "mod"]:
			op = tok.value
		if op == "":
			break
		_advance()
		var right := _unary()
		left = {"k": "bin", "op": op, "l": left, "r": right, "line": tok.line}
	return left


func _unary() -> Dictionary:
	var tok := _peek()
	if tok.type == T.OP and tok.value == "-":
		_advance()
		var e := _unary()
		return {"k": "un", "op": "-", "e": e, "line": tok.line}
	return _primary()


func _primary() -> Dictionary:
	var tok := _peek()
	match tok.type:
		T.INT:
			_advance()
			return {"k": "num", "v": tok.value, "t": "inteiro", "line": tok.line}
		T.REAL:
			_advance()
			return {"k": "num", "v": tok.value, "t": "real", "line": tok.line}
		T.STRING:
			_advance()
			return {"k": "str", "v": tok.value, "line": tok.line}
		T.IDENT:
			_advance()
			if _peek().type == T.LPAREN:
				_fail(tok, "Comandos de ação como %s() não podem ficar dentro de uma condição ou de um cálculo." % tok.value,
					"Para tomar decisões use as variáveis do robô, como inimigo_perto ou energia.", LBDiagnostic.CAT_COMANDO)
				return {}
			return {"k": "var", "name": tok.value, "line": tok.line}
		T.LPAREN:
			_advance()
			var e := _expression()
			if failed():
				return {}
			if _peek().type != T.RPAREN:
				_fail(_peek(), "Faltou fechar o parêntese.", "Cada ( precisa de um ) correspondente.", LBDiagnostic.CAT_OPERADOR)
				return {}
			_advance()
			return e
		T.KEYWORD:
			if tok.value == "verdadeiro" or tok.value == "falso":
				_advance()
				return {"k": "bool", "v": tok.value == "verdadeiro", "line": tok.line}
	var hint := "Aqui deveria vir um número, uma variável ou uma condição."
	if tok.type == T.NEWLINE or tok.type == T.EOF:
		hint = "A expressão terminou incompleta. Confira se não falta nada no final da linha."
	elif tok.type == T.KEYWORD and (tok.value == "e" or tok.value == "ou"):
		hint = "Antes e depois de %s precisa haver uma condição completa." % String(tok.value).to_upper()
	_fail(tok, "Esperava um valor ou uma variável, mas encontrei %s." % _describe(tok), hint, LBDiagnostic.CAT_OPERADOR)
	return {}
