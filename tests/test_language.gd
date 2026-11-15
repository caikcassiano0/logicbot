extends RefCounted
## Testes do analisador da linguagem (léxico, sintaxe e semântica).


func _compile(src: String) -> LBCompiler.Result:
	return LBCompiler.compile_source(src)


func _wrap(body: String, vars: String = "") -> String:
	var v := ("var\n" + vars + "\n") if vars != "" else ""
	return "algoritmo \"Teste\"\n" + v + "inicio\n" + body + "\nfimalgoritmo\n"


func _err_line(t: LBTestContext, name: String, src: String, line: int, contains: String = "") -> void:
	var r := _compile(src)
	var e := r.first_error()
	if e == null:
		t.check(name, false, "nenhum erro foi encontrado")
		return
	var ok := e.line == line and (contains == "" or e.message.to_lower().contains(contains.to_lower()) or e.hint.to_lower().contains(contains.to_lower()))
	t.check(name, ok, "linha %d: %s | %s" % [e.line, e.message, e.hint])


func run(t: LBTestContext) -> void:
	t.suite("Linguagem: programas válidos")
	t.check("modelo inicial do jogador compila", _compile(LBBotLibrary.TEMPLATE).ok)
	for b in LBBotLibrary.BOTS:
		var r := _compile(b.codigo)
		t.check("código do bot %s compila" % b.nome, r.ok, "" if r.ok else r.first_error().to_text())
	var completo := """algoritmo "Completo"
var
   i, total: inteiro
   media: real
   alerta: logico
   nome: caractere
inicio
   total <- 0
   para i de 1 ate 3 faca
      total <- total + i * 2
   fimpara
   media <- total / 4
   alerta <- vida < 30 ou (energia >= 50 e nao inimigo_perto)
   nome <- "Titan" + "-A"
   enquanto total > 10 faca
      total <- total - 5
   fimenquanto
   repita
      total <- total + 1
   ate total >= 12
   se alerta entao
      defender()
   senao se total mod 2 = 0 entao
      atacar()
   senao
      avancar()
   fimse
   escreval("Total: ", total, " media ", media)
fimalgoritmo
"""
	var rc := _compile(completo)
	t.check("programa usando todas as estruturas compila", rc.ok, "" if rc.ok else rc.first_error().to_text())
	var acentos := "ALGORITMO \"Acentos\"\nINÍCIO\n   SE inimigo_perto ENTÃO\n      atacar()\n   SENÃO\n      avançar()\n   FIMSE\nFIMALGORITMO"
	t.check("aceita maiúsculas e acentos (ENTÃO, SENÃO, avançar)", _compile(acentos).ok)
	t.check("aceita := como atribuição (estilo Visualg)", _compile(_wrap("x := 3\natacar()", "x: inteiro")).ok)
	t.check("aceita comando sem parênteses", _compile(_wrap("atacar")).ok)
	var w := _compile(_wrap("x <- 1", "x: inteiro"))
	t.check("aviso quando não há nenhuma ação", w.ok and w.warnings().size() > 0)

	t.suite("Linguagem: erros de sintaxe")
	_err_line(t, "falta ENTAO", _wrap("se inimigo_perto\natacar()\nfimse"), 3, "ENTAO")
	_err_line(t, "falta FIMSE", _wrap("se inimigo_perto entao\natacar()"), 5, "FIMSE")
	_err_line(t, "falta FIMALGORITMO", "algoritmo \"x\"\ninicio\natacar()\n", 4, "FIMALGORITMO")
	_err_line(t, "falta a linha algoritmo", "inicio\natacar()\nfimalgoritmo", 1, "algoritmo")
	_err_line(t, "uso de == explica que é =", _wrap("se vida == 10 entao\natacar()\nfimse"), 3, "=")
	_err_line(t, "uso de && sugere E", _wrap("se vida && energia entao\natacar()\nfimse"), 3, " e")
	_err_line(t, "atribuição com = sugere <-", _wrap("x = 5", "x: inteiro"), 5, "<-")
	_err_line(t, "SENAO duplicado", _wrap("se inimigo_perto entao\natacar()\nsenao\ndefender()\nsenao\navancar()\nfimse"), 7, "SENAO")
	_err_line(t, "FIMENQUANTO dentro de SE", _wrap("se inimigo_perto entao\natacar()\nfimenquanto"), 5, "SE")
	_err_line(t, "comando dentro de condição", _wrap("se atacar() entao\ndefender()\nfimse"), 3, "condição")
	_err_line(t, "comparação encadeada", _wrap("se 10 < vida < 30 entao\natacar()\nfimse"), 3, "E")
	_err_line(t, "texto sem fechar aspas", _wrap("escreva(\"oi)"), 3, "aspas")
	_err_line(t, "ponto e vírgula", _wrap("atacar();"), 3, ";")
	_err_line(t, "condição vazia no SE", _wrap("se entao\natacar()\nfimse"), 3, "condição")

	t.suite("Linguagem: erros semânticos")
	_err_line(t, "variável não declarada sugere nome parecido", _wrap("se inimigo_pert entao\natacar()\nfimse"), 3, "inimigo_perto")
	_err_line(t, "não pode alterar sensor", _wrap("vida <- 100\natacar()"), 3, "sensor")
	_err_line(t, "tipo incompatível (logico <- número)", _wrap("ok <- 5\natacar()", "ok: logico"), 5, "logico")
	_err_line(t, "inteiro não recebe divisão real", _wrap("x <- 5 / 2\natacar()", "x: inteiro"), 5, "div")
	_err_line(t, "SE precisa de condição lógica", _wrap("se vida entao\natacar()\nfimse"), 3, "verdadeiro ou falso")
	_err_line(t, "comando inexistente sugere o certo", _wrap("atacr()"), 3, "atacar")
	_err_line(t, "E com números", _wrap("se vida e energia entao\natacar()\nfimse"), 3, "E")
	_err_line(t, "comparar lógico com < explica", _wrap("se inimigo_perto > 1 entao\natacar()\nfimse"), 3, "lógicas")
	_err_line(t, "variável declarada duas vezes", "algoritmo \"x\"\nvar\nx: inteiro\nx: real\ninicio\natacar()\nfimalgoritmo", 4, "duas vezes")
	_err_line(t, "variável com nome de sensor", "algoritmo \"x\"\nvar\nvida: inteiro\ninicio\natacar()\nfimalgoritmo", 3, "sensor")
	_err_line(t, "contador do PARA precisa ser inteiro", _wrap("para r de 1 ate 3 faca\natacar()\nfimpara", "r: real"), 5, "inteiro")
	_err_line(t, "PASSO zero", _wrap("para i de 1 ate 3 passo 0 faca\natacar()\nfimpara", "i: inteiro"), 5, "PASSO")
