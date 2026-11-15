class_name LBLexer
extends RefCounted
## ANÁLISE LÉXICA — transforma o texto do programa em uma lista de "tokens"
## (palavras-chave, nomes, números, operadores...).
##
## Exemplo: `se vida < 30 entao` vira
##   [KEYWORD se] [IDENT vida] [OP <] [INT 30] [KEYWORD entao]
##
## Acentos e maiúsculas são ignorados: "ENTÃO", "Entao" e "entao" são iguais.
## Isso evita frustração de iniciantes com detalhes de digitação.

enum T { INT, REAL, STRING, IDENT, KEYWORD, OP, LPAREN, RPAREN, COMMA, COLON, NEWLINE, EOF }

const KEYWORDS: Array[String] = [
	"algoritmo", "var", "inicio", "fimalgoritmo",
	"se", "entao", "senao", "fimse",
	"enquanto", "faca", "fimenquanto",
	"repita", "ate",
	"para", "de", "passo", "fimpara",
	"e", "ou", "nao", "verdadeiro", "falso",
	"inteiro", "real", "logico", "caractere",
	"div", "mod", "escreva", "escreval",
	"procedimento", "fimprocedimento",
]

const ACCENTS := {
	"á": "a", "à": "a", "â": "a", "ã": "a", "é": "e", "ê": "e", "í": "i",
	"ó": "o", "ô": "o", "õ": "o", "ú": "u", "ü": "u", "ç": "c",
}

const MAX_SOURCE_LENGTH := 20000

var tokens: Array[Dictionary] = []
var diagnostics: Array[LBDiagnostic] = []


static func normalize_word(word: String) -> String:
	var lower := word.to_lower()
	var out := ""
	for ch in lower:
		out += ACCENTS.get(ch, ch)
	return out


static func _is_digit(c: String) -> bool:
	var u := c.unicode_at(0)
	return u >= 48 and u <= 57


static func _is_ident_start(c: String) -> bool:
	return c == "_" or c.to_lower() != c.to_upper()


static func _is_ident_char(c: String) -> bool:
	return _is_ident_start(c) or _is_digit(c)


func _add(type: int, value: Variant, line: int, col: int) -> void:
	tokens.append({"type": type, "value": value, "line": line, "col": col})


func _error(line: int, col: int, msg: String, hint: String = "", cat: String = LBDiagnostic.CAT_SINTAXE) -> void:
	diagnostics.append(LBDiagnostic.make_error(line, col, msg, hint, cat))


## Retorna true se não houve erros.
func tokenize(source: String) -> bool:
	tokens.clear()
	diagnostics.clear()
	if source.length() > MAX_SOURCE_LENGTH:
		_error(1, 1, "O programa é grande demais (máximo de %d caracteres)." % MAX_SOURCE_LENGTH,
			"Programas de robô costumam ser curtos. Tente simplificar a estratégia.")
		return false

	var i := 0
	var line := 1
	var col := 1
	var n := source.length()

	while i < n:
		var c := source[i]

		if c == "\n":
			_add(T.NEWLINE, "\n", line, col)
			i += 1
			line += 1
			col = 1
			continue

		if c == " " or c == "\t" or c == "\r":
			i += 1
			col += 1
			continue

		# Comentário de linha: // até o fim da linha
		if c == "/" and i + 1 < n and source[i + 1] == "/":
			while i < n and source[i] != "\n":
				i += 1
			continue

		# Números: 10, 3.5
		if _is_digit(c):
			var start := i
			while i < n and _is_digit(source[i]):
				i += 1
			var is_real := false
			if i + 1 < n and source[i] == "." and _is_digit(source[i + 1]):
				is_real = true
				i += 1
				while i < n and _is_digit(source[i]):
					i += 1
			var text := source.substr(start, i - start)
			if is_real:
				_add(T.REAL, text.to_float(), line, col)
			else:
				if text.length() > 9:
					_error(line, col, "O número %s é grande demais." % text, "Use números menores que 1 bilhão.", LBDiagnostic.CAT_TIPO)
					return false
				_add(T.INT, text.to_int(), line, col)
			col += i - start
			continue

		# Textos: "Olá"
		if c == "\"":
			var start_col := col
			i += 1
			col += 1
			var text := ""
			while i < n and source[i] != "\"" and source[i] != "\n":
				text += source[i]
				i += 1
				col += 1
			if i >= n or source[i] != "\"":
				_error(line, start_col, "Um texto começou com aspas (\") mas não foi fechado.",
					"Feche o texto com outra aspa na mesma linha. Ex: \"MeuRobo\"")
				return false
			i += 1
			col += 1
			_add(T.STRING, text, line, start_col)
			continue

		# Nomes e palavras-chave
		if _is_ident_start(c):
			var start := i
			while i < n and _is_ident_char(source[i]):
				i += 1
			var raw := source.substr(start, i - start)
			var norm := normalize_word(raw)
			if norm in KEYWORDS:
				_add(T.KEYWORD, norm, line, col)
			else:
				_add(T.IDENT, norm, line, col)
			col += i - start
			continue

		# Operadores de dois caracteres
		var two := source.substr(i, 2)
		match two:
			"<-", ":=":
				_add(T.OP, "<-", line, col)
				i += 2
				col += 2
				continue
			"<=", ">=", "<>":
				_add(T.OP, two, line, col)
				i += 2
				col += 2
				continue
			"==":
				_error(line, col, "Em Portugol a comparação de igualdade usa um único sinal: =",
					"Troque == por =. Ex: se energia = 100 entao", LBDiagnostic.CAT_OPERADOR)
				return false
			"!=":
				_error(line, col, "Em Portugol \"diferente de\" é escrito <>",
					"Troque != por <>. Ex: se vida <> 100 entao", LBDiagnostic.CAT_OPERADOR)
				return false
			"&&":
				_error(line, col, "Para juntar duas condições use a palavra E.",
					"Ex: se inimigo_perto e energia >= 50 entao", LBDiagnostic.CAT_OPERADOR)
				return false
			"||":
				_error(line, col, "Para \"uma condição OU outra\" use a palavra OU.",
					"Ex: se vida < 30 ou inimigo_atacando entao", LBDiagnostic.CAT_OPERADOR)
				return false

		match c:
			"+", "-", "*", "/", "=", "<", ">":
				_add(T.OP, c, line, col)
			"%":
				_add(T.OP, "mod", line, col)
			"\\":
				_add(T.OP, "div", line, col)
			"(":
				_add(T.LPAREN, c, line, col)
			")":
				_add(T.RPAREN, c, line, col)
			",":
				_add(T.COMMA, c, line, col)
			":":
				_add(T.COLON, c, line, col)
			";":
				_error(line, col, "Não é preciso colocar ponto e vírgula (;) no final das instruções.",
					"Apague o ; — em Portugol cada instrução fica em sua própria linha.")
				return false
			"!":
				_error(line, col, "Para negar uma condição use a palavra NAO.",
					"Ex: se nao inimigo_perto entao", LBDiagnostic.CAT_OPERADOR)
				return false
			"?":
				_error(line, col, "Há uma lacuna (???) para completar nesta linha.",
					"Troque o ??? pelo comando ou pela condição que falta. Veja a aba Referência.")
				return false
			"'":
				_error(line, col, "Textos usam aspas duplas (\"), não simples (').",
					"Ex: escreva(\"Olá\")")
				return false
			_:
				_error(line, col, "Não reconheço o símbolo '%s'." % c,
					"Verifique se não há um caractere digitado por engano.")
				return false
		i += 1
		col += 1

	_add(T.NEWLINE, "\n", line, col)
	_add(T.EOF, "", line, col)
	return true
