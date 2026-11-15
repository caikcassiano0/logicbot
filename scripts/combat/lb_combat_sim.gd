class_name LBCombatSim
extends RefCounted
## SIMULAÇÃO DO COMBATE — lógica pura, 60 passos por segundo, sem gráficos.
##
## A cada passo ([method step]):
##   1. o cronômetro anda e a energia recarrega;
##   2. as ações em andamento avançam (movimento, pulo...);
##   3. golpes que chegaram no momento do impacto são resolvidos — para os DOIS
##      robôs ao mesmo tempo, usando o mesmo estado (ninguém leva vantagem por
##      ser processado primeiro);
##   4. verifica nocaute ou fim do tempo;
##   5. cada robô livre "pensa": lê os sensores e pede a próxima ação ao seu
##      programa (LBVM). O inimigo usa EXATAMENTE o mesmo sistema que o jogador.
##
## Não há números aleatórios: o mesmo par de programas sempre produz a mesma
## luta. Assim o aluno consegue entender (e reproduzir) o que aconteceu.
##
## Cada passo devolve uma lista de EVENTOS ("acerto", "bloqueio", "esquiva"...)
## que a parte visual usa para desenhar faíscas, números de dano etc.
##
## LUTA POR TURNOS ([member turnos] = true): a cada R.TURNO_DURACAO segundos a
## simulação PAUSA (evento "fim_turno") e só continua com [method proximo_turno],
## que pode trocar o programa de cada robô. Pausar não altera nada no estado:
## sem trocar os programas, a luta por turnos termina igual à luta contínua.

const R = preload("res://scripts/combat/lb_combat_rules.gd")

var lutadores: Array[LBFighter] = []
var tempo_restante: float = R.ROUND_TIME
var terminou := false
var vencedor := -1          ## 0 = jogador, 1 = inimigo, 2 = empate
var motivo_fim := ""        ## "nocaute" ou "tempo"
var passos := 0

var turnos := false          ## true = luta por turnos de R.TURNO_DURACAO segundos
var turno := 1               ## turno atual (começa em 1)
var turno_t := 0.0           ## tempo decorrido no turno atual
var aguardando_turno := false  ## pausado esperando os programas do próximo turno
var cerebro: LBEnemyBrain = null  ## 2.0: inimigo com várias táticas (troca a cada turno)
var ultima_troca := ""          ## tática que o inimigo passou a usar no último proximo_turno()


func setup(vm_jogador: LBVM, vm_inimigo: LBVM, nome_jogador: String = "TITAN-A", nome_inimigo: String = "INIMIGO") -> void:
	var a := LBFighter.new(nome_jogador, 1, vm_jogador)
	var b := LBFighter.new(nome_inimigo, -1, vm_inimigo)
	a.x = -R.POSICAO_INICIAL
	b.x = R.POSICAO_INICIAL
	if vm_jogador:
		vm_jogador.reset()
	if vm_inimigo:
		vm_inimigo.reset()
	lutadores = [a, b]
	tempo_restante = R.ROUND_TIME
	terminou = false
	vencedor = -1
	motivo_fim = ""
	passos = 0
	turno = 1
	turno_t = 0.0
	aguardando_turno = false


## Quantos turnos a luta tem no máximo (60 s / 5 s = 12).
func total_turnos() -> int:
	return int(ceil(R.ROUND_TIME / R.TURNO_DURACAO - 0.001))


## Inimigo com cérebro: começa com a tática preferida do bot.
func usar_cerebro(c: LBEnemyBrain) -> void:
	cerebro = c
	cerebro.atual = cerebro.primeira()
	cerebro.historico = [cerebro.atual]
	lutadores[1].vm = cerebro.vm_de(cerebro.atual)
	lutadores[1].vm.reset()


## Começa o próximo turno. Um programa novo (não nulo) substitui o antigo e
## recomeça do início; null mantém o programa que já estava rodando.
## Com cérebro, o inimigo escolhe a tática do turno olhando o turno que acabou.
func proximo_turno(vm_jogador: LBVM = null, vm_inimigo: LBVM = null) -> void:
	if not aguardando_turno:
		return
	ultima_troca = ""
	if cerebro != null and vm_inimigo == null:
		var id := cerebro.escolher(self)
		cerebro.historico.append(id)
		if id != cerebro.atual:
			cerebro.atual = id
			vm_inimigo = cerebro.vm_de(id)
			ultima_troca = id
	for f in lutadores:
		f.acoes_turno = {}
	for i in 2:
		var vm: LBVM = vm_jogador if i == 0 else vm_inimigo
		if vm != null:
			vm.reset()
			lutadores[i].vm = vm
			lutadores[i].programa_travado = false
			lutadores[i].erro_programa = null
	turno += 1
	turno_t = 0.0
	aguardando_turno = false


func distancia() -> float:
	return absf(lutadores[1].x - lutadores[0].x)


## Roda a luta inteira de uma vez (usado nos testes e em simulações rápidas).
func run_to_end(max_steps: int = 100000) -> void:
	var i := 0
	while not terminou and i < max_steps:
		if aguardando_turno:
			proximo_turno()   # nos testes, continua com os mesmos programas
		step()
		i += 1


func step() -> Array[Dictionary]:
	var eventos: Array[Dictionary] = []
	if terminou or aguardando_turno:
		return eventos
	passos += 1
	tempo_restante = maxf(0.0, tempo_restante - R.DT)

	# 1-2. recarga e avanço das ações
	var golpes: Array[int] = []
	for i in 2:
		var f := lutadores[i]
		var o := lutadores[1 - i]
		if f.nocauteado:
			continue
		f.energia = minf(R.MAX_ENERGIA, f.energia + R.ENERGIA_REGEN_POR_SEG * R.DT)
		# fôlego volta mais rápido quando o robô se protege ou respira; corpo avariado atrapalha
		var calmo := f.acao == "" or f.acao in R.ACOES_DE_DEFESA or f.acao == "recuar" or f.acao == "aguardar"
		var regen := (R.FOLEGO_REGEN_DEFESA if calmo else R.FOLEGO_REGEN) * (R.REGEN_CORPO_FRACO if f.corpo < R.PARTE_FRACA else 1.0)
		f.folego = minf(R.FOLEGO_MAX, f.folego + regen * R.DT)
		if f.atordoado > 0.0:
			f.atordoado = maxf(0.0, f.atordoado - R.DT)
			continue
		if f.acao == "":
			continue
		f.acao_t += R.DT
		var d := f.def()
		if d.has("speed"):
			_mover(f, o, float(d.speed) * f.lado * R.DT)
		if d.has("hit_at") and not f.golpe_resolvido and f.acao_t >= d.hit_at:
			f.golpe_resolvido = true
			golpes.append(i)
		if f.acao_t >= f.acao_dur:
			eventos.append({"tipo": "fim_acao", "lutador": i, "acao": f.acao})
			f.acao = ""

	# 3. resolve os golpes dos dois lados com o mesmo estado, depois aplica
	var resultados: Array[Dictionary] = []
	for i in golpes:
		resultados.append(_resolver_golpe(i))
	for r in resultados:
		_aplicar_golpe(r, eventos)

	# 4. fim da luta
	var ko_a := lutadores[0].vida <= 0 or lutadores[0].nocaute_folego
	var ko_b := lutadores[1].vida <= 0 or lutadores[1].nocaute_folego
	if ko_a or ko_b:
		terminou = true
		motivo_fim = "nocaute"
		vencedor = 2 if (ko_a and ko_b) else (1 if ko_a else 0)
	elif tempo_restante <= 0.0:
		terminou = true
		motivo_fim = "tempo"
		var va := lutadores[0].vida
		var vb := lutadores[1].vida
		vencedor = 0 if va > vb else (1 if vb > va else 2)
	if terminou:
		for i in 2:
			if lutadores[i].vida <= 0 or lutadores[i].nocaute_folego:
				lutadores[i].nocauteado = true
				lutadores[i].acao = ""
		eventos.append({"tipo": "fim_luta", "vencedor": vencedor, "motivo": motivo_fim})
		return eventos

	# 5. decisões — os dois robôs leem os sensores ANTES de qualquer um agir
	var sensores := [_sensores(0), _sensores(1)]
	for i in 2:
		var f := lutadores[i]
		if f.esta_livre():
			_decidir(i, sensores[i], eventos)

	# 6. luta por turnos: fim do turno → pausa até proximo_turno()
	if turnos:
		turno_t += R.DT
		if turno_t >= R.TURNO_DURACAO - 0.0001:
			aguardando_turno = true
			eventos.append({"tipo": "fim_turno", "turno": turno})
	return eventos


func _mover(f: LBFighter, o: LBFighter, dx: float) -> void:
	var nx := clampf(f.x + dx, -R.ARENA_LIMITE, R.ARENA_LIMITE)
	# não atravessa o inimigo
	if f.lado > 0:
		nx = minf(nx, o.x - R.DISTANCIA_MINIMA)
	else:
		nx = maxf(nx, o.x + R.DISTANCIA_MINIMA)
	f.x = nx


func _sensores(i: int) -> Dictionary:
	var f := lutadores[i]
	var o := lutadores[1 - i]
	var dist := distancia()
	return {
		"vida": f.vida,
		"energia": f.energia_int(),
		"vida_inimigo": o.vida,
		"energia_inimigo": o.energia_int(),
		"distancia_inimigo": snappedf(dist, 0.1),
		"inimigo_perto": dist <= R.DISTANCIA_PERTO + 0.001,
		"inimigo_atacando": o.preparando_golpe(),
		"inimigo_defendendo": o.defendendo(),
		"inimigo_atacando_alto": o.preparando_golpe() and o.def().get("altura", "alto") == "alto",
		"inimigo_atacando_baixo": o.preparando_golpe() and o.def().get("altura", "") == "baixo",
		"inimigo_bloqueando_alto": o.acao == "bloqueio_alto" or o.acao == "defender",
		"inimigo_bloqueando_baixo": o.acao == "bloqueio_baixo" or o.acao == "defender",
		"folego": int(floor(f.folego)),
		"folego_inimigo": int(floor(o.folego)),
		"cabeca": int(floor(f.cabeca)),
		"corpo": int(floor(f.corpo)),
		"bracos": int(floor(f.bracos)),
		"cabeca_inimigo": int(floor(o.cabeca)),
		"corpo_inimigo": int(floor(o.corpo)),
		"bracos_inimigo": int(floor(o.bracos)),
		"defesa_ativa": f.ultima_acao == "defender",
		"tempo_restante": int(ceil(tempo_restante)),
	}


func _decidir(i: int, sensores: Dictionary, eventos: Array[Dictionary]) -> void:
	var f := lutadores[i]
	if f.vm == null or f.programa_travado:
		_iniciar(f, i, "aguardar", 0, eventos, true)
		return
	var r := f.vm.next_action(sensores)
	match r.type:
		"action":
			_iniciar(f, i, r.name, r.line, eventos, false)
		"fim":
			# O programa chegou ao fim sem pedir ação: o robô espera um instante
			# e o programa recomeça do início na próxima decisão.
			_iniciar(f, i, "aguardar", 0, eventos, true)
		"erro":
			f.programa_travado = true
			f.erro_programa = r.diagnostic
			f.stats.erros_programa = int(f.stats.get("erros_programa", 0)) + 1
			eventos.append({"tipo": "erro_programa", "lutador": i, "diagnostico": r.diagnostic})
			_iniciar(f, i, "aguardar", 0, eventos, true)


func _iniciar(f: LBFighter, i: int, nome: String, linha: int, eventos: Array[Dictionary], implicita: bool) -> void:
	var d: Dictionary = R.ACOES[nome]
	var custo: float = d.custo
	f.acao_linha = linha
	f.acao_t = 0.0
	f.golpe_resolvido = false
	if f.energia + 0.0001 < custo:
		f.acao = "falha"
		f.acao_dur = R.DURACAO_FALHA
		f.stats.falhas_sem_energia += 1
		eventos.append({"tipo": "sem_energia", "lutador": i, "acao": nome, "linha": linha})
		return
	f.energia -= custo
	f.stats.energia_gasta += int(custo)
	f.acao = nome
	f.acao_dur = d.dur
	if LBFighter.eh_boxe(nome):
		f.folego = maxf(0.0, f.folego - float(d.get("folego", 0.0)))
		if f.cansado():
			f.acao_dur *= R.LENTIDAO_CANSADO
	if not implicita:
		f.ultima_acao = nome
		f.acoes_turno[nome] = int(f.acoes_turno.get(nome, 0)) + 1
		f.stats.acoes[nome] = int(f.stats.acoes.get(nome, 0)) + 1
	if nome in R.ACOES_DE_ATAQUE:
		f.stats.ataques += 1
		if f.vida < 60:
			f.stats.ataques_com_vida_baixa += 1
	if nome in R.ACOES_DE_DEFESA:
		f.stats.defesas += 1
	eventos.append({"tipo": "inicio_acao", "lutador": i, "acao": nome, "linha": linha, "implicita": implicita})


func _resolver_golpe(i: int) -> Dictionary:
	var a := lutadores[i]
	var t := lutadores[1 - i]
	var d := a.def()
	var r := {"atacante": i, "acao": a.acao, "resultado": "", "dano": 0}
	if distancia() > float(d.alcance) + 0.001:
		r.resultado = "errou"
	elif t.intocavel() or t.evita(d):
		r.resultado = "esquiva"
	elif d.tipo == "golpe" and t.no_ar():
		r.resultado = "esquiva"
	elif t.defendendo() and t.reducao_contra(d) > 0.0:
		r.resultado = "bloqueio"
		r.dano = int(round(float(d.dano) * (1.0 - t.reducao_contra(d))))
	else:
		r.resultado = "acerto"
		r.dano = int(d.dano)
		if d.has("altura") and a.bracos < R.PARTE_FRACA:
			r.dano = int(round(float(d.dano) * R.DANO_BRACOS_FRACOS))
		# uppercut em quem se abaixou: entra em cheio no queixo
		if d.get("trajeto", "") == "sobe" and t.def().get("punido_por", "") == "sobe":
			r.dano = int(round(float(d.dano) * R.BONUS_UPPERCUT_ABAIXADO))
			r.punido = true
	return r


func _aplicar_golpe(r: Dictionary, eventos: Array[Dictionary]) -> void:
	var i: int = r.atacante
	var a := lutadores[i]
	var t := lutadores[1 - i]
	var especial: bool = r.acao == "golpe_especial"
	if especial:
		a.stats.especiais_ok += 1
	match r.resultado:
		"errou":
			a.stats.golpes_no_vazio += 1
		"esquiva":
			t.stats.esquivas_ok += 1
			# 2.0: golpe forte de boxe que passa no vazio desequilibra quem bateu
			if a.acao != "" and LBFighter.eh_boxe(a.acao) and int(a.def().get("dano", 0)) >= R.GOLPE_PESADO:
				a.acao_dur += R.DESEQUILIBRIO_ESQUIVA
		"bloqueio":
			t.stats.defesas_ok += 1
			a.stats.golpes_bloqueados_pelo_inimigo += 1
			t.energia = minf(R.MAX_ENERGIA, t.energia + R.ENERGIA_AO_BLOQUEAR)
			# quem bate na guarda fica desequilibrado: abre espaço para o contra-ataque
			if a.acao != "":
				a.acao_dur += R.DESEQUILIBRIO_BLOQUEIO
		"acerto":
			a.stats.acertos += 1
			t.stats.golpes_recebidos_em_cheio += 1
			a.energia = minf(R.MAX_ENERGIA, a.energia + R.ENERGIA_AO_ACERTAR)
			# golpe em cheio interrompe o que o alvo estava fazendo
			# (2.0: golpes de boxe LEVES, como o jab, não interrompem — os dois socos entram)
			var leve: bool = a.def().has("altura") and int(r.dano) < R.GOLPE_PESADO
			if not leve:
				t.acao = ""
				t.atordoado = R.ATORDOAMENTO
			elif not a.cansado() and t.preparando_golpe() and int(t.def().get("dano", 0)) >= R.GOLPE_PESADO:
				# golpe leve no rosto "corta" o golpe forte que o alvo ainda estava preparando
				# (só com fôlego: soco cansado não tem força para isso)
				t.acao = ""
				t.atordoado = maxf(t.atordoado, R.ATORDOAMENTO_CORTE)
				eventos.append({"tipo": "cortou", "atacante": i, "alvo": 1 - i, "acao": r.acao})
			if not leve and a.def().get("altura", "") == "alto" and t.cabeca < R.PARTE_FRACA:
				t.atordoado *= R.ATORDOAMENTO_CABECA_FRACA
			if especial:
				_mover(t, a, -R.EMPURRAO_ESPECIAL * t.lado)
	_aplicar_boxe(r, a, t, eventos)
	if r.dano > 0:
		var antes := t.vida
		t.vida = clampi(t.vida - int(r.dano), 0, R.MAX_VIDA)
		var real_dano := antes - t.vida
		a.stats.dano_causado += real_dano
		t.stats.dano_recebido += real_dano
	eventos.append({"tipo": r.resultado, "atacante": i, "alvo": 1 - i, "acao": r.acao, "dano": r.dano})


## 2.0 — fôlego e partes do corpo (só para golpes de boxe, que têm "altura").
func _aplicar_boxe(r: Dictionary, a: LBFighter, t: LBFighter, eventos: Array[Dictionary]) -> void:
	var d: Dictionary = R.ACOES.get(r.acao, {})
	if not d.has("altura"):
		return
	var cheio := float(d.dano)
	match r.resultado:
		"acerto":
			var no_corpo: bool = d.altura == "baixo"
			t.folego = maxf(0.0, t.folego - float(r.dano) * (R.FOLEGO_POR_DANO_CORPO if no_corpo else R.FOLEGO_POR_DANO_CABECA))
			if no_corpo:
				t.corpo = maxf(0.0, t.corpo - float(r.dano) * R.PARTE_POR_DANO)
			else:
				t.cabeca = maxf(0.0, t.cabeca - float(r.dano) * R.PARTE_POR_DANO)
				# sem fôlego, um golpe forte na cabeça derruba
				if t.folego <= 0.0 and r.dano >= R.GOLPE_PESADO and t.vida - int(r.dano) > 0:
					t.nocaute_folego = true
					eventos.append({"tipo": "nocaute_folego", "atacante": r.atacante, "alvo": 1 - int(r.atacante), "acao": r.acao})
		"bloqueio":
			t.bracos = maxf(0.0, t.bracos - cheio * R.PARTE_POR_BLOQUEIO)
			t.folego = maxf(0.0, t.folego - cheio * R.FOLEGO_POR_BLOQUEIO)
