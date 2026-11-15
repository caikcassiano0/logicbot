extends Node
## Autoload "Progress": guarda o progresso do aluno em user://progresso.json.
## Tudo fica no computador do aluno — nenhum dado é enviado para lugar algum.

signal changed

const PATH := "user://progresso.json"
const CATEGORIA_NOME := {
	"sintaxe": "escrita dos comandos (sintaxe)", "variavel": "variáveis", "tipo": "tipos de dados",
	"condicional": "condições SE/SENAO", "operador": "operadores", "laco": "laços de repetição",
	"comando": "comandos do robô", "execucao": "erros durante a execução",
}

var data := LBProgressData.new()


func _ready() -> void:
	load_progress()


func load_progress() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		data.from_dict(parsed)


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data.to_dict(), "\t"))
	changed.emit()


func reset_all() -> void:
	data = LBProgressData.new()
	save()
