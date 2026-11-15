extends SceneTree
## Executor de testes. Rode a partir da raiz do projeto:
##   godot --headless --path . --script res://tests/run_tests.gd
## (no VS Code: Terminal > Executar Tarefa > "Rodar testes")
## Código de saída 0 = tudo passou; 1 = alguma falha.

const SUITES := [
	"res://tests/test_language.gd",
	"res://tests/test_vm.gd",
	"res://tests/test_combat.gd",
	"res://tests/test_progression.gd",
]


func _initialize() -> void:
	var t := LBTestContext.new()
	for path in SUITES:
		var suite = load(path).new()
		suite.run(t)

	var current := ""
	for r in t.results:
		if r.suite != current:
			current = r.suite
			print("\n== %s ==" % current)
		var mark := "PASSOU " if r.ok == true else ("FALHOU " if r.ok == false else "PULADO ")
		var line: String = "  [%s] %s" % [mark, r.name]
		if r.detail != "" and r.ok != true:
			line += "  -> " + r.detail
		print(line)
	print("\nResumo: %d passaram, %d falharam, %d não executados (total %d)" % [t.passed(), t.failed(), t.skipped(), t.results.size()])
	quit(1 if t.failed() > 0 else 0)
