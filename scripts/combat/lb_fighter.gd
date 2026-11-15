class_name LBFighter
extends RefCounted
## Estado de UM lutador durante a luta (somente dados, nada gráfico).
## A parte visual (LBRobotVisual) apenas LÊ este estado para se desenhar.

const R = preload("res://scripts/combat/lb_combat_rules.gd")

var nome := "ROBÔ"
var lado := 1            ## +1 = olha para a direita (jogador), -1 = olha para a esquerda
var x := 0.0
var vida: int = R.MAX_VIDA
var energia: float = R.ENERGIA_INICIAL
var folego: float = R.FOLEGO_MAX   ## 2.0: cansaço (golpes de boxe)
var cabeca := 100.0                ## 2.0: integridade das partes (0 a 100)
var corpo := 100.0
var bracos := 100.0
var nocaute_folego := false        ## derrubado por golpe forte sem fôlego

var acao := ""           ## ação atual ("" = livre para decidir)
var acao_t := 0.0        ## tempo decorrido da ação atual
var acao_dur := 0.0
var acao_linha := 0      ## linha do código que pediu a ação
var golpe_resolvido := false
var atordoado := 0.0
var nocauteado := false
var ultima_acao := ""

var vm: LBVM = null
var programa_travado := false
var erro_programa: LBDiagnostic = null

var stats := {}
var acoes_turno := {}   ## 2.0: ações pedidas no turno atual (o cérebro do inimigo lê as do jogador)


func _init(p_nome: String = "ROBÔ", p_lado: int = 1, p_vm: LBVM = null) -> void:
	nome = p_nome
	lado = p_lado
	vm = p_vm
	reset_stats()


func reset_stats() -> void:
	stats = {
		"dano_causado": 0, "dano_recebido": 0,
		"ataques": 0, "acertos": 0, "golpes_no_vazio": 0, "golpes_bloqueados_pelo_inimigo": 0,
		"defesas": 0, "defesas_ok": 0, "esquivas_ok": 0,
		"energia_gasta": 0, "especiais_ok": 0, "falhas_sem_energia": 0,
		"ataques_com_vida_baixa": 0, "golpes_recebidos_em_cheio": 0, "erros_programa": 0,
		"acoes": {},
	}


func esta_livre() -> bool:
	return acao == "" and atordoado <= 0.0 and not nocauteado


func def() -> Dictionary:
	return R.ACOES.get(acao, {})


## Preparando um golpe (antes do impacto) — é o que o sensor inimigo_atacando enxerga.
func preparando_golpe() -> bool:
	if not (acao in R.ACOES_DE_ATAQUE):
		return false
	return acao_t < def().hit_at


func intocavel() -> bool:
	if acao != "esquivar":
		return false
	var d := def()
	return acao_t >= d.inv_de and acao_t <= d.inv_ate


func no_ar() -> bool:
	if acao != "pular":
		return false
	var d := def()
	return acao_t >= d.ar_de and acao_t <= d.ar_ate


func defendendo() -> bool:
	return acao == "defender" or acao == "bloqueio_alto" or acao == "bloqueio_baixo"


## Quanto do dano a guarda segura contra este golpe (0 = nada).
## defender() protege tudo; bloqueio_alto/baixo só a sua altura.
func reducao_contra(golpe: Dictionary) -> float:
	if acao == "defender":
		return R.REDUCAO_DEFESA_ESPECIAL if golpe.get("tipo", "") == "especial" else R.REDUCAO_DEFESA
	var d := def()
	# golpes antigos sem "altura" (atacar, golpe_especial) contam como golpes na cabeça
	if d.has("protege") and d.protege == golpe.get("altura", "alto"):
		if golpe.get("tipo", "") == "especial":
			return R.REDUCAO_DEFESA_ESPECIAL
		if golpe.get("trajeto", "") == "sobe" and d.protege == "alto":
			return R.REDUCAO_ALTA_CONTRA_UPPERCUT
		return R.REDUCAO_BRACOS_FRACOS if bracos < R.PARTE_FRACA else R.REDUCAO_DEFESA
	return 0.0


## As esquivas novas (2.0) desviam só de certos golpes, durante a janela.
func evita(golpe: Dictionary) -> bool:
	var d := def()
	if not d.has("inv_de") or acao == "esquivar":
		return false
	if acao_t < d.inv_de or acao_t > d.inv_ate:
		return false
	if golpe.get("tipo", "") == "especial":
		return false   # o golpe especial (plasma) não é desviado pelas esquivas de boxe
	# o soco antigo atacar() conta como golpe reto na cabeça
	var altura: String = golpe.get("altura", "alto")
	var trajeto: String = golpe.get("trajeto", "reto")
	if d.has("evita") and ("%s:%s" % [altura, trajeto]) in d.evita:
		return true
	if d.has("evita_alcance_ate") and altura == d.evita_altura and float(golpe.alcance) <= float(d.evita_alcance_ate):
		return true
	return false


## Altura do pulo (para a parte visual), 0 quando no chão.
func altura_pulo() -> float:
	if acao != "pular":
		return 0.0
	var p := clampf(acao_t / acao_dur, 0.0, 1.0)
	return sin(p * PI) * float(def().altura)


func progresso() -> float:
	return clampf(acao_t / acao_dur, 0.0, 1.0) if acao_dur > 0.0 else 0.0


func cansado() -> bool:
	return folego < R.FOLEGO_CANSADO


## Ação "de boxe" (2.0): só elas usam fôlego e partes do corpo.
static func eh_boxe(nome: String) -> bool:
	var d: Dictionary = R.ACOES.get(nome, {})
	return d.has("altura") or d.has("protege") or d.has("evita") or d.has("evita_alcance_ate")


func energia_int() -> int:
	return int(floor(energia))
