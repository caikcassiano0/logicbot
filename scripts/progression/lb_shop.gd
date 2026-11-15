class_name LBShop
extends RefCounted
## LOJA (2.0): peças e danças compradas com as moedas (LBCoins).
## Tudo é VISUAL: comprar peças não deixa o robô mais forte — quem vence é o algoritmo.

const CATEGORIAS := ["ombreiras", "luvas", "capacete", "nucleo", "acabamento", "danca"]
const NOMES_CATEGORIA := {
	"ombreiras": "OMBREIRAS", "luvas": "LUVAS", "capacete": "CAPACETE", "nucleo": "NÚCLEO DO PEITO",
	"acabamento": "ACABAMENTO", "danca": "DANÇA DA VITÓRIA",
}
## Categorias com "nenhum" (dá para tirar a peça)
const OPCIONAIS := ["ombreiras", "luvas", "capacete", "nucleo"]
## O que vem equipado de fábrica
const PADRAO := {"acabamento": "padrao", "danca": "danca_hiphop_3"}

const ITENS := [
	{"id": "ombro_titan", "cat": "ombreiras", "nome": "Titan", "preco": 120, "desc": "Ombreiras facetadas, iguais à armadura do robô."},
	{"id": "ombro_espinho", "cat": "ombreiras", "nome": "Espinho", "preco": 180, "desc": "Ombreiras com espinhos de metal."},
	{"id": "ombro_escudo", "cat": "ombreiras", "nome": "Escudo", "preco": 220, "desc": "Placas largas de proteção."},
	{"id": "luva_pesada", "cat": "luvas", "nome": "Pesadas", "preco": 120, "desc": "Luvas de metal grossas."},
	{"id": "luva_plasma", "cat": "luvas", "nome": "Plasma", "preco": 200, "desc": "Luvas que brilham na cor do seu robô."},
	{"id": "cap_crista", "cat": "capacete", "nome": "Crista", "preco": 90, "desc": "Uma barbatana no alto da cabeça."},
	{"id": "cap_antenas", "cat": "capacete", "nome": "Antenas", "preco": 110, "desc": "Duas antenas com pontas de luz."},
	{"id": "cap_chifres", "cat": "capacete", "nome": "Chifres", "preco": 150, "desc": "Chifres de touro mecânico."},
	{"id": "nucleo_hex", "cat": "nucleo", "nome": "Hex", "preco": 80, "desc": "Núcleo hexagonal que brilha no peito."},
	{"id": "nucleo_reator", "cat": "nucleo", "nome": "Reator", "preco": 160, "desc": "Reator com anel de energia."},
	{"id": "padrao", "cat": "acabamento", "nome": "Padrão", "preco": 0, "desc": "Metal acetinado de fábrica."},
	{"id": "fosco", "cat": "acabamento", "nome": "Fosco", "preco": 60, "desc": "Pintura sem brilho, estilo militar."},
	{"id": "cromado", "cat": "acabamento", "nome": "Cromado", "preco": 100, "desc": "Metal espelhado."},
	{"id": "carbono", "cat": "acabamento", "nome": "Carbono", "preco": 140, "desc": "Placas escuras de fibra de carbono."},
	{"id": "danca_hiphop_3", "cat": "danca", "nome": "Hip Hop 3", "preco": 0, "desc": "A dança grátis."},
	{"id": "danca_maraschino", "cat": "danca", "nome": "Passinho", "preco": 120, "desc": "Passinho curto e animado."},
	{"id": "danca_hiphop_1", "cat": "danca", "nome": "Hip Hop 1", "preco": 150, "desc": "Hip hop longo."},
	{"id": "danca_hiphop_2", "cat": "danca", "nome": "Hip Hop 2", "preco": 150, "desc": "Hip hop com giros."},
	{"id": "danca_house", "cat": "danca", "nome": "House", "preco": 200, "desc": "Dança house."},
	{"id": "danca_swing", "cat": "danca", "nome": "Swing", "preco": 200, "desc": "Swing dos anos 40."},
	{"id": "danca_soul", "cat": "danca", "nome": "Soul Spin", "preco": 250, "desc": "Giros do northern soul."},
]


static func item(id: String) -> Dictionary:
	for it in ITENS:
		if it.id == id:
			return it
	return {}


static func itens_da(cat: String) -> Array:
	return ITENS.filter(func(it): return it.cat == cat)


static func tem(data: LBProgressData, id: String) -> bool:
	var it := item(id)
	return not it.is_empty() and (int(it.preco) == 0 or data.compradas.has(id))


## Compra (se tiver moedas). Devolve true se comprou.
static func comprar(data: LBProgressData, id: String) -> bool:
	var it := item(id)
	if it.is_empty() or tem(data, id) or data.moedas < int(it.preco):
		return false
	data.moedas -= int(it.preco)
	data.compradas[id] = true
	return true


static func equipar(data: LBProgressData, id: String) -> bool:
	var it := item(id)
	if it.is_empty() or not tem(data, id):
		return false
	data.equipado[it.cat] = id
	return true


static func tirar(data: LBProgressData, cat: String) -> void:
	if cat in OPCIONAIS:
		data.equipado.erase(cat)


## O que está equipado em cada categoria (só itens que a pessoa realmente tem).
static func equipados(data: LBProgressData) -> Dictionary:
	var r := PADRAO.duplicate()
	for cat in data.equipado:
		var id := String(data.equipado[cat])
		if tem(data, id) and item(id).cat == cat:
			r[cat] = id
	return r
