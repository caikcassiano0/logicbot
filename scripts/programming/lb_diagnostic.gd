class_name LBDiagnostic
extends RefCounted
## Um erro ou aviso encontrado no programa do jogador.
##
## Toda mensagem é escrita para quem está aprendendo: diz ONDE está o problema,
## O QUE aconteceu e, quando possível, uma DICA de como corrigir.
## A [member category] alimenta as estatísticas de aprendizado (ex.: muitos erros
## de "condicional" indicam que o aluno precisa praticar SE/SENÃO).

enum Severity { ERROR, WARNING }

const CAT_SINTAXE := "sintaxe"
const CAT_VARIAVEL := "variavel"
const CAT_TIPO := "tipo"
const CAT_CONDICIONAL := "condicional"
const CAT_OPERADOR := "operador"
const CAT_LACO := "laco"
const CAT_COMANDO := "comando"
const CAT_EXECUCAO := "execucao"

var severity: int = Severity.ERROR
var line: int = 0
var column: int = 0
var message: String = ""
var hint: String = ""
var category: String = CAT_SINTAXE


static func make_error(p_line: int, p_col: int, p_message: String, p_hint: String = "", p_category: String = CAT_SINTAXE) -> LBDiagnostic:
	var d := LBDiagnostic.new()
	d.severity = Severity.ERROR
	d.line = p_line
	d.column = p_col
	d.message = p_message
	d.hint = p_hint
	d.category = p_category
	return d


static func make_warning(p_line: int, p_message: String, p_hint: String = "", p_category: String = CAT_SINTAXE) -> LBDiagnostic:
	var d := make_error(p_line, 0, p_message, p_hint, p_category)
	d.severity = Severity.WARNING
	return d


func is_error() -> bool:
	return severity == Severity.ERROR


func to_text() -> String:
	var prefix := "Erro" if is_error() else "Aviso"
	var where := " na linha %d" % line if line > 0 else ""
	var s := "%s%s: %s" % [prefix, where, message]
	if hint != "":
		s += "\n   Dica: " + hint
	return s
