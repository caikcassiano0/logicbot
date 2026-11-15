class_name LBProgressData
extends RefCounted
## Progresso do aluno (dados puros, sem disco — por isso é fácil de testar).
## Quem salva/carrega é o autoload Progress (scripts/core/progress.gd).

var tutorial_concluido := false
var dificuldade := 0                ## 0 Fácil, 1 Médio, 2 Difícil
var fases := {}                     ## id -> {"tentativas", "concluida", "melhor_vida", "dificuldade"}
var erros := {}                     ## categoria do erro -> quantidade
var lutas := 0
var vitorias := 0
var xp := 0
var conquistas := {}                ## id -> true
var treino_vencidos := {}           ## bot_id -> true
var cor := "azul"                   ## personalização escolhida (LBRewards.CORES)
var armadura := "padrao"            ## LBRewards.ARMADURAS (robô clássico 1.x)
var moedas := 0                     ## 2.0: moedas (LBCoins) para a loja
var recordes := {}                  ## 2.0: "fase:id"/"treino:bot" -> melhor nota (0 a 100)
var compradas := {}                 ## 2.0: id do item da loja -> true
var equipado := {}                  ## 2.0: categoria -> id do item (LBShop)


func _fase(id: String) -> Dictionary:
	if not fases.has(id):
		fases[id] = {"tentativas": 0, "concluida": false, "melhor_vida": 0, "dificuldade": -1}
	return fases[id]


func fase_concluida(id: String) -> bool:
	return fases.has(id) and bool(fases[id].concluida)


## Regra: nada da campanha antes do tutorial; cada fase exige a anterior concluída.
func fase_desbloqueada(index: int) -> bool:
	if not tutorial_concluido or index < 0 or index >= LBCampaign.count():
		return false
	return index == 0 or fase_concluida(LBCampaign.FASES[index - 1].id)


func treino_livre_liberado() -> bool:
	return tutorial_concluido


func registrar_tentativa(id: String) -> void:
	_fase(id).tentativas += 1


func concluir_fase(id: String, vida: int) -> void:
	var f := _fase(id)
	f.concluida = true
	f.melhor_vida = maxi(int(f.melhor_vida), vida)
	f.dificuldade = maxi(int(f.dificuldade), dificuldade)


func registrar_erro(categoria: String) -> void:
	erros[categoria] = int(erros.get(categoria, 0)) + 1


func registrar_luta(venceu: bool) -> void:
	lutas += 1
	if venceu:
		vitorias += 1


func fases_concluidas() -> int:
	var n := 0
	for f in LBCampaign.FASES:
		if fase_concluida(f.id):
			n += 1
	return n


## Categorias de erro mais frequentes (para sugerir o que praticar).
func erros_mais_comuns(limite: int = 3) -> Array:
	var lista := []
	for c in erros:
		lista.append([c, erros[c]])
	lista.sort_custom(func(a, b): return a[1] > b[1])
	return lista.slice(0, limite)


func to_dict() -> Dictionary:
	return {"versao": 1, "tutorial_concluido": tutorial_concluido, "dificuldade": dificuldade,
		"fases": fases, "erros": erros, "lutas": lutas, "vitorias": vitorias, "xp": xp,
		"conquistas": conquistas, "treino_vencidos": treino_vencidos, "cor": cor, "armadura": armadura,
		"moedas": moedas, "recordes": recordes, "compradas": compradas, "equipado": equipado}


func from_dict(d: Dictionary) -> void:
	tutorial_concluido = bool(d.get("tutorial_concluido", false))
	dificuldade = clampi(int(d.get("dificuldade", 0)), 0, 2)
	fases = d.get("fases", {})
	erros = d.get("erros", {})
	lutas = int(d.get("lutas", 0))
	vitorias = int(d.get("vitorias", 0))
	xp = maxi(0, int(d.get("xp", 0)))
	conquistas = d.get("conquistas", {})
	treino_vencidos = d.get("treino_vencidos", {})
	cor = String(d.get("cor", "azul"))
	armadura = String(d.get("armadura", "padrao"))
	moedas = maxi(0, int(d.get("moedas", 0)))
	recordes = d.get("recordes", {})
	compradas = d.get("compradas", {})
	equipado = d.get("equipado", {})
