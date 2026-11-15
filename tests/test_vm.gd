extends RefCounted
## Testes da máquina virtual: execução, variáveis, condições, laços e limites.


func _vm(src: String) -> LBVM:
	var r := LBCompiler.compile_source(src)
	if not r.ok:
		push_error(r.first_error().to_text())
		return null
	return LBVM.new(r)


func _sensors(over: Dictionary = {}) -> Dictionary:
	var s := {
		"vida": 100, "energia": 20, "vida_inimigo": 100, "energia_inimigo": 20,
		"distancia_inimigo": 5.0, "inimigo_perto": false, "inimigo_atacando": false,
		"inimigo_defendendo": false, "defesa_ativa": false, "tempo_restante": 60,
	}
	s.merge(over, true)
	return s


## Pede N ações em sequência e devolve os nomes (ou "fim"/"erro").
func _actions(vm: LBVM, n: int, sensors: Dictionary = {}) -> Array:
	var out := []
	for i in n:
		var r := vm.next_action(_sensors(sensors))
		out.append(r.name if r.type == "action" else r.type)
	return out


func run(t: LBTestContext) -> void:
	t.suite("Máquina virtual: variáveis e operadores")
	var vm := _vm("""algoritmo "v"
var
   a, b: inteiro
   r: real
   ok: logico
   s: caractere
inicio
   a <- 7
   b <- a div 2
   r <- a / 2
   ok <- (a mod 2 = 1) e nao falso
   s <- "Ti" + "tan"
   atacar()
fimalgoritmo""")
	_actions(vm, 1)
	t.equal("atribuição e div (7 div 2 = 3)", vm.vars.b, 3)
	t.equal("divisão real (7 / 2 = 3.5)", vm.vars.r, 3.5)
	t.equal("mod, = e nao", vm.vars.ok, true)
	t.equal("concatenação de textos", vm.vars.s, "Titan")
	t.check("variável real guarda float", vm.vars.r is float)

	vm = _vm("""algoritmo "v"
var
   n: real
inicio
   n <- 3
   atacar()
fimalgoritmo""")
	_actions(vm, 1)
	t.check("real recebe inteiro e converte para real", vm.vars.n is float and vm.vars.n == 3.0)

	t.suite("Máquina virtual: SE / SENÃO / SENÃO SE")
	var src_if := """algoritmo "c"
inicio
   se vida < 30 entao
      defender()
   senao se inimigo_perto entao
      atacar()
   senao
      avancar()
   fimse
fimalgoritmo"""
	vm = _vm(src_if)
	t.equal("SE verdadeiro executa o primeiro bloco", _actions(vm, 1, {"vida": 10})[0], "defender")
	vm = _vm(src_if)
	t.equal("SENÃO SE verdadeiro executa o segundo bloco", _actions(vm, 1, {"inimigo_perto": true})[0], "atacar")
	vm = _vm(src_if)
	t.equal("nenhuma condição verdadeira executa o SENÃO", _actions(vm, 1)[0], "avancar")
	t.check("estatística de condições registrada", vm.condition_stats.has(3) and vm.condition_stats[3].f == 1)

	vm = _vm("""algoritmo "e"
inicio
   se energia >= 50 e inimigo_perto entao
      golpe_especial()
   senao
      aguardar()
   fimse
fimalgoritmo""")
	t.equal("E: só uma condição verdadeira -> falso", _actions(vm, 1, {"energia": 80})[0], "aguardar")
	vm.reset()
	t.equal("E: as duas verdadeiras -> verdadeiro", _actions(vm, 1, {"energia": 80, "inimigo_perto": true})[0], "golpe_especial")

	t.suite("Máquina virtual: sequência, pausa e laço principal")
	vm = _vm("""algoritmo "s"
inicio
   avancar()
   atacar()
   defender()
fimalgoritmo""")
	t.equal("ações saem na ordem e o programa recomeça no fim sem pausa", _actions(vm, 5), ["avancar", "atacar", "defender", "avancar", "atacar"])
	t.equal("conta voltas completas", vm.cycles_completed, 1)

	vm = _vm("""algoritmo "p"
var
   c: inteiro
inicio
   c <- c + 1
   atacar()
fimalgoritmo""")
	_actions(vm, 6)
	t.equal("variáveis mantêm valor entre voltas", vm.vars.c, 6)
	vm.reset()
	t.equal("reset() zera as variáveis", vm.vars.c, 0)

	vm = _vm("""algoritmo "sem"
inicio
   se inimigo_perto entao
      atacar()
   fimse
fimalgoritmo""")
	t.equal("volta inteira sem ação devolve 'fim' (robô espera)", _actions(vm, 2), ["fim", "fim"])
	t.equal("...e não executa o programa duas vezes na mesma decisão", vm.line_hits.get(3, 0), 2)
	vm = _vm("""algoritmo "meio"
var
   n: inteiro
inicio
   n <- n + 1
   se n = 1 entao
      atacar()
   fimse
fimalgoritmo""")
	t.equal("ação no meio, depois volta sem ação: espera em vez de travar", _actions(vm, 3), ["atacar", "fim", "fim"])

	t.suite("Máquina virtual: laços")
	vm = _vm("""algoritmo "l"
var
   i, soma: inteiro
inicio
   soma <- 0
   para i de 1 ate 4 faca
      soma <- soma + i
   fimpara
   para i de 3 ate 1 passo -1 faca
      atacar()
   fimpara
fimalgoritmo""")
	t.equal("PARA com passo negativo executa 3 vezes por volta", _actions(vm, 4), ["atacar", "atacar", "atacar", "atacar"])
	t.equal("PARA soma 1..4 = 10", vm.vars.soma, 10)

	vm = _vm("""algoritmo "l"
var
   n: inteiro
inicio
   n <- 0
   enquanto n < 3 faca
      n <- n + 1
      defender()
   fimenquanto
   repita
      n <- n - 1
   ate n = 0
   atacar()
fimalgoritmo""")
	t.equal("ENQUANTO e REPITA", _actions(vm, 4), ["defender", "defender", "defender", "atacar"])
	t.equal("REPITA terminou com n = 0", vm.vars.n, 0)

	t.suite("Máquina virtual: segurança")
	vm = _vm("""algoritmo "inf"
var
   x: inteiro
inicio
   enquanto verdadeiro faca
      x <- x + 1
   fimenquanto
fimalgoritmo""")
	var t0 := Time.get_ticks_msec()
	var r := vm.next_action(_sensors())
	var ms := Time.get_ticks_msec() - t0
	t.check("laço infinito é interrompido com erro", r.type == "erro" and vm.halted, str(r))
	t.check("interrupção é rápida (< 100 ms)", ms < 100, "%d ms" % ms)
	t.check("mensagem explica o laço", vm.error != null and vm.error.category == LBDiagnostic.CAT_LACO)
	t.equal("programa travado continua retornando erro", vm.next_action(_sensors()).type, "erro")

	vm = _vm("""algoritmo "inf2"
inicio
   enquanto verdadeiro faca
      atacar()
   fimenquanto
fimalgoritmo""")
	t.equal("laço infinito COM ação é permitido (é o laço do robô)", _actions(vm, 3), ["atacar", "atacar", "atacar"])

	vm = _vm("""algoritmo "z"
var
   a: inteiro
   r: real
inicio
   a <- 0
   r <- 10 / a
   atacar()
fimalgoritmo""")
	r = vm.next_action(_sensors())
	t.check("divisão por zero vira erro de execução, sem travar", r.type == "erro" and vm.error.message.contains("zero"))

	vm = _vm("""algoritmo "str"
var
   s: caractere
inicio
   enquanto verdadeiro faca
      s <- s + "abcdefghij"
      aguardar()
   fimenquanto
fimalgoritmo""")
	var acts := _actions(vm, 30)
	t.check("textos têm tamanho máximo (proteção de memória)", acts.has("erro"), str(acts))

	vm = _vm("""algoritmo "w"
inicio
   escreval("Vida: ", vida, " perto: ", inimigo_perto)
   aguardar()
fimalgoritmo""")
	_actions(vm, 1, {"vida": 42})
	t.equal("ESCREVAL registra a saída com sensores", vm.output_log[0], "Vida: 42 perto: FALSO")
	t.check("sensores são somente leitura (bloqueado na compilação)", not LBCompiler.compile_source("algoritmo \"x\"\ninicio\nenergia <- 100\natacar()\nfimalgoritmo").ok)

	t.suite("Procedimentos")
	vm = _vm("""algoritmo "proc"
var
   n: inteiro
procedimento contra_ataque()
inicio
   defender()
   atacar()
fimprocedimento
procedimento combo()
   contra_ataque()
   n <- n + 1
   golpe_especial()
fimprocedimento
inicio
   avancar()
   combo()
fimalgoritmo""")
	t.equal("procedimentos executam na ordem, inclusive um chamando outro", _actions(vm, 6), ["avancar", "defender", "atacar", "golpe_especial", "avancar", "defender"])
	t.equal("procedimento altera variável do algoritmo", vm.vars.n, 1)
	vm = _vm("""algoritmo "rec"
procedimento eco()
inicio
   eco()
fimprocedimento
inicio
   eco()
fimalgoritmo""")
	var rr := vm.next_action(_sensors())
	t.check("recursão infinita é interrompida com explicação", rr.type == "erro" and vm.error.message.contains("Procedimentos"))
	var ok := LBCompiler.compile_source("algoritmo \"x\"\nprocedimento p()\ninicio\natacar()\nfimprocedimento\ninicio\np()\nfimalgoritmo")
	t.check("programa com procedimento compila", ok.ok)
	var e1 := LBCompiler.compile_source("algoritmo \"x\"\nprocedimento p()\ninicio\natacar()\ninicio\np()\nfimalgoritmo").first_error()
	t.check("procedimento sem FIMPROCEDIMENTO é apontado", e1 != null and (e1.message + e1.hint).contains("FIMPROCEDIMENTO"), e1.to_text() if e1 else "")
	var e2 := LBCompiler.compile_source("algoritmo \"x\"\nprocedimento atacar()\ninicio\ndefender()\nfimprocedimento\ninicio\natacar()\nfimalgoritmo").first_error()
	t.check("procedimento com nome de comando é recusado", e2 != null and e2.message.contains("já é usado"))
	var e3 := LBCompiler.compile_source("algoritmo \"x\"\ninicio\nprocedimento p()\natacar()\nfimprocedimento\nfimalgoritmo").first_error()
	t.check("procedimento dentro do INICIO explica onde declarar", e3 != null and e3.message.contains("ANTES do INICIO"))
	var e4 := LBCompiler.compile_source("algoritmo \"x\"\nprocedimento contra_ataque()\ninicio\ndefender()\nfimprocedimento\ninicio\ncontra_atak()\nfimalgoritmo").first_error()
	t.check("chamada com nome errado sugere o procedimento certo", e4 != null and e4.hint.contains("contra_ataque"))
	var w := LBCompiler.compile_source("algoritmo \"x\"\nprocedimento p()\ninicio\ndefender()\nfimprocedimento\ninicio\natacar()\nfimalgoritmo")
	t.check("procedimento nunca chamado gera aviso", w.ok and w.warnings().any(func(d): return d.message.contains("nunca é chamado")))
