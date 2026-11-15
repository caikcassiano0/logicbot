class_name LBProgramInspector
extends RefCounted
## Descobre QUAIS estruturas um programa usa (SE, SENAO SE, PARA, variáveis...).
## Usado pela campanha para conferir requisitos como "vença usando SENAO SE".


static func features(program: Dictionary) -> Dictionary:
	var f := {
		"se": false, "senao": false, "senao_se": false, "enquanto": false, "repita": false,
		"para": false, "e": false, "ou": false, "nao": false, "variavel": false,
		"procedimento": false, "acoes": {}, "sensores_em_condicao": {}, "_procs": {},
	}
	f.variavel = not program.get("decls", []).is_empty()
	for pr in program.get("procs", []):
		f._procs[pr.name] = true
	for pr in program.get("procs", []):
		_block(pr.body, f)
	_block(program.get("body", []), f)
	return f


static func _block(stmts: Array, f: Dictionary) -> void:
	for s in stmts:
		match s.k:
			"call":
				if f._procs.has(s.name):
					f.procedimento = true
				else:
					f.acoes[s.name] = true
			"assign":
				_expr(s.expr, f, false)
			"print":
				for a in s.args:
					_expr(a, f, false)
			"if":
				f.se = true
				if s.has_else:
					f.senao = true
				if s.branches.size() > 1:
					f.senao_se = true
					f.senao = true
				for b in s.branches:
					_expr(b.cond, f, true)
					_block(b.body, f)
				_block(s.else_body, f)
			"while":
				f.enquanto = true
				_expr(s.cond, f, true)
				_block(s.body, f)
			"repeat":
				f.repita = true
				_expr(s.cond, f, true)
				_block(s.body, f)
			"for":
				f.para = true
				_block(s.body, f)


static func _expr(e: Dictionary, f: Dictionary, in_cond: bool) -> void:
	match e.k:
		"var":
			if in_cond and LBRobotAPI.is_sensor(e.name):
				f.sensores_em_condicao[e.name] = true
		"un":
			if e.op == "nao":
				f.nao = true
			_expr(e.e, f, in_cond)
		"bin":
			if e.op == "e":
				f.e = true
			elif e.op == "ou":
				f.ou = true
			_expr(e.l, f, in_cond)
			_expr(e.r, f, in_cond)
