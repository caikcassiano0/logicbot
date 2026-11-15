class_name LBTestContext
extends RefCounted
## Mini-framework de testes (sem dependências externas).
## Cada verificação é registrada com nome, resultado e detalhe.

var results: Array[Dictionary] = []
var _suite := ""


func suite(name: String) -> void:
	_suite = name


func check(name: String, condition: bool, detail: String = "") -> void:
	results.append({"suite": _suite, "name": name, "ok": condition, "detail": detail})


func equal(name: String, actual: Variant, expected: Variant) -> void:
	var ok: bool = typeof(actual) == typeof(expected) and actual == expected
	if not ok and (actual is int or actual is float) and (expected is int or expected is float):
		ok = is_equal_approx(float(actual), float(expected))
	check(name, ok, "" if ok else "esperado %s, obtido %s" % [str(expected), str(actual)])


func skip(name: String, reason: String) -> void:
	results.append({"suite": _suite, "name": name, "ok": null, "detail": reason})


func passed() -> int:
	return results.filter(func(r): return r.ok == true).size()


func failed() -> int:
	return results.filter(func(r): return r.ok == false).size()


func skipped() -> int:
	return results.filter(func(r): return r.ok == null).size()
