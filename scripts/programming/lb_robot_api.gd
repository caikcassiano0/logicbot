class_name LBRobotAPI
extends RefCounted
## O "contrato" entre o programa do aluno e o robô.
##
## Só o que está listado aqui pode ser usado no código do jogador.
## Isto é uma camada de SEGURANÇA: o programa nunca acessa nada do jogo
## além destes comandos (ações) e sensores (variáveis somente leitura).
##
## Os números das descrições seguem LBCombatRules (scripts/combat/lb_combat_rules.gd).

## Comandos de ação. Cada um ocupa o robô por um tempo; enquanto a ação
## acontece, o programa fica pausado naquela linha.
const ACTIONS := {
	"atacar": {
		"resumo": "Soco rápido.",
		"desc": "Soco rápido (0,42 s). Causa 7 de dano se o inimigo estiver a até 1,7 m. Acertar dá +10 de energia.",
	},
	"defender": {
		"resumo": "Ergue a guarda.",
		"desc": "Ergue a guarda por 0,55 s. Reduz 75% do dano de socos e 50% do golpe especial. Bloquear dá +5 de energia.",
	},
	"avancar": {
		"resumo": "Anda em direção ao inimigo.",
		"desc": "Anda cerca de 1,2 m em direção ao inimigo (0,3 s).",
	},
	"recuar": {
		"resumo": "Anda para trás.",
		"desc": "Anda cerca de 1 m para longe do inimigo (0,3 s).",
	},
	"esquivar": {
		"resumo": "Desvia de qualquer golpe.",
		"desc": "Inclina o corpo para trás (0,45 s). Fica intocável durante quase toda a esquiva. Custa 8 de energia.",
	},
	"pular": {
		"resumo": "Salta e evita socos.",
		"desc": "Salta (0,6 s). No ar, os socos passam por baixo, mas o golpe especial ainda acerta. Custa 10 de energia.",
	},
	"golpe_especial": {
		"resumo": "Disparo de energia (precisa de 50).",
		"desc": "Disparo de plasma (0,85 s) com alcance de 2,8 m e 20 de dano. Custa 50 de energia; sem energia suficiente o robô falha e perde tempo.",
	},
	"aguardar": {
		"resumo": "Espera um instante.",
		"desc": "Não faz nada por 0,25 s. Útil para observar o inimigo.",
	},

	# ---------------- BOXE (2.0) ----------------
	"jab": {"resumo": "1 · soco reto rápido da mão da frente.", "golpe": true,
		"desc": "Golpe nº 1. Soco reto e rápido na cabeça (0,40 s): 4 de dano até 1,8 m. Esquivas para os lados desviam dele."},
	"direto": {"resumo": "2 · soco reto forte da mão de trás.", "golpe": true,
		"desc": "Golpe nº 2. Soco reto na cabeça com o peso do corpo (0,60 s): 9 de dano até 1,9 m — o mais longo. Esquivas para os lados desviam dele."},
	"cruzado_frente": {"resumo": "3 · gancho curto da mão da frente.", "golpe": true,
		"desc": "Golpe nº 3. Soco curvo na lateral da cabeça (0,55 s): 10 de dano até 1,7 m. Vem de lado: esquivar para os lados NÃO funciona; abaixe ou recue o tronco."},
	"cruzado_tras": {"resumo": "4 · gancho forte da mão de trás.", "golpe": true,
		"desc": "Golpe nº 4. Soco curvo e pesado na cabeça (0,70 s): 13 de dano até 1,7 m. Mesmas defesas do nº 3."},
	"uppercut_frente": {"resumo": "5 · soco de baixo para cima (frente).", "golpe": true,
		"desc": "Golpe nº 5. Sobe até o queixo (0,60 s): 12 de dano até 1,4 m (bem de perto). Passa pelo meio da guarda alta (ela segura só 25%) e pega quem se abaixa com +30%."},
	"uppercut_tras": {"resumo": "6 · soco de baixo para cima (trás).", "golpe": true,
		"desc": "Golpe nº 6. O uppercut mais forte (0,75 s): 16 de dano até 1,4 m. Passa pelo meio da guarda alta e pega quem se abaixa com +30%."},
	"jab_corpo": {"resumo": "Jab na linha da cintura.", "golpe": true,
		"desc": "Jab no corpo (0,42 s): 4 de dano até 1,7 m. Passa por baixo do bloqueio alto; só o bloqueio baixo segura."},
	"direto_corpo": {"resumo": "Direto no estômago.", "golpe": true,
		"desc": "Direto no corpo (0,62 s): 9 de dano até 1,8 m. Passa por baixo do bloqueio alto."},
	"gancho_figado": {"resumo": "Gancho nas costelas.", "golpe": true,
		"desc": "Gancho no fígado (0,65 s): 11 de dano até 1,7 m. Golpe baixo e curvo: só o bloqueio baixo segura."},
	"overhand": {"resumo": "Soco longo por cima da guarda.", "golpe": true,
		"desc": "Overhand (0,85 s): 17 de dano até 1,9 m, vindo por cima. Custa 20 de energia e é lento: fácil de ver chegando."},
	"bloqueio_alto": {"resumo": "Guarda alta: protege a cabeça.",
		"desc": "Protege a cabeça por 0,55 s: reduz 75% dos golpes altos (só 25% do uppercut, que sobe pelo meio). Golpes no corpo passam inteiros."},
	"bloqueio_baixo": {"resumo": "Guarda baixa: protege o corpo.",
		"desc": "Protege o corpo por 0,55 s: reduz 75% dos golpes baixos. Golpes na cabeça passam inteiros."},
	"esquivar_esquerda": {"resumo": "Tira a cabeça da linha (esquerda).",
		"desc": "Desvia de golpes RETOS na cabeça (jab, direto) por 0,45 s. Não funciona contra ganchos. Custa 6 de energia."},
	"esquivar_direita": {"resumo": "Tira a cabeça da linha (direita).",
		"desc": "Igual à esquiva para a esquerda, para o outro lado. Custa 6 de energia."},
	"abaixar": {"resumo": "Pêndulo: abaixa sob o golpe.",
		"desc": "Abaixa por 0,50 s e desvia de golpes altos retos e curvos. Mas o UPPERCUT pega com +30% de dano. Custa 6 de energia."},
	"recuar_tronco": {"resumo": "Inclina o tronco para trás.",
		"desc": "Afasta a cabeça por 0,55 s: desvia de golpes altos curtos (ganchos e uppercuts, até 1,7 m). Jab e direto ainda alcançam."},
	"passo_lado": {"resumo": "Sai da linha com um passo lateral.",
		"desc": "Passo para o lado (0,50 s): sai da linha dos golpes RETOS, na cabeça ou no corpo. Não custa energia."},
}

## Comandos da versão 1.x: continuam funcionando (códigos antigos não quebram),
## mas não aparecem mais na Referência — o boxe (2.0) usa jab, direto, bloqueios...
const ANTIGOS: Array[String] = ["atacar", "defender", "esquivar", "pular"]

## Golpes que começam bloqueados e são liberados ao concluir uma fase da campanha.
## (comando -> id da fase que libera). O que não está aqui está sempre liberado.
const LIBERA_NA_FASE := {
	"cruzado_frente": "f2_se_senao", "cruzado_tras": "f2_se_senao", "abaixar": "f2_se_senao",
	"uppercut_frente": "f4_senao_se", "uppercut_tras": "f4_senao_se", "recuar_tronco": "f4_senao_se",
	"jab_corpo": "f5_variaveis", "direto_corpo": "f5_variaveis", "gancho_figado": "f5_variaveis", "passo_lado": "f5_variaveis",
	"overhand": "f7a_enquanto",
}

## Comandos bloqueados AGORA (comando -> mensagem). Vazio = tudo liberado
## (padrão nos testes). A tela de batalha preenche conforme o progresso do aluno.
static var bloqueados := {}


## Calcula os bloqueios a partir de uma função que diz se uma fase foi concluída.
static func bloqueios_para(fase_concluida: Callable) -> Dictionary:
	var b := {}
	for cmd in LIBERA_NA_FASE:
		var fid: String = LIBERA_NA_FASE[cmd]
		if not fase_concluida.call(fid):
			var idx := LBCampaign.index_of(fid)
			b[cmd] = "Conclua a fase %d da campanha (%s) para liberar %s()." % [idx + 1, LBCampaign.FASES[idx].titulo, cmd]
	return b

## Sensores: variáveis que o robô atualiza sozinho. O aluno só pode LER.
const SENSORS := {
	"vida": {"tipo": "inteiro", "desc": "Sua vida, de 0 a 200."},
	"energia": {"tipo": "inteiro", "desc": "Sua energia, de 0 a 100. Recarrega 6 por segundo e ao acertar golpes."},
	"vida_inimigo": {"tipo": "inteiro", "desc": "A vida do inimigo, de 0 a 200."},
	"energia_inimigo": {"tipo": "inteiro", "desc": "A energia do inimigo, de 0 a 100."},
	"distancia_inimigo": {"tipo": "real", "desc": "Distância até o inimigo, em metros (ex: 2.5)."},
	"inimigo_perto": {"tipo": "logico", "desc": "verdadeiro se o inimigo está ao alcance do soco (até 1,7 m)."},
	"inimigo_atacando": {"tipo": "logico", "desc": "verdadeiro se o inimigo está preparando um golpe agora."},
	"inimigo_defendendo": {"tipo": "logico", "desc": "verdadeiro se o inimigo está com a guarda erguida."},
	"defesa_ativa": {"tipo": "logico", "desc": "verdadeiro se a última ação do seu robô foi defender()."},
	"tempo_restante": {"tipo": "inteiro", "desc": "Segundos que faltam para o fim da luta."},
	"inimigo_atacando_alto": {"tipo": "logico", "desc": "verdadeiro se o inimigo está preparando um golpe na CABEÇA."},
	"inimigo_atacando_baixo": {"tipo": "logico", "desc": "verdadeiro se o inimigo está preparando um golpe no CORPO."},
	"inimigo_bloqueando_alto": {"tipo": "logico", "desc": "verdadeiro se a guarda do inimigo protege a cabeça agora."},
	"inimigo_bloqueando_baixo": {"tipo": "logico", "desc": "verdadeiro se a guarda do inimigo protege o corpo agora."},
	"folego": {"tipo": "inteiro", "desc": "Seu fôlego, de 0 a 100. Golpes de boxe gastam; volta mais rápido bloqueando, esquivando, recuando ou aguardando. Abaixo de 25 o robô fica lento; em 0, um golpe forte (dano 10 ou mais) na cabeça derruba."},
	"folego_inimigo": {"tipo": "inteiro", "desc": "O fôlego do inimigo, de 0 a 100. Inimigo cansado é mais lento e pode ser derrubado."},
	"cabeca": {"tipo": "inteiro", "desc": "Integridade da sua cabeça (0 a 100). Abaixo de 40, você fica atordoado por mais tempo."},
	"corpo": {"tipo": "inteiro", "desc": "Integridade do seu corpo (0 a 100). Abaixo de 40, seu fôlego volta pela metade."},
	"bracos": {"tipo": "inteiro", "desc": "Integridade dos seus braços (0 a 100). Gastam ao bloquear; abaixo de 40, seus socos e sua guarda enfraquecem."},
	"cabeca_inimigo": {"tipo": "inteiro", "desc": "Integridade da cabeça do inimigo (0 a 100)."},
	"corpo_inimigo": {"tipo": "inteiro", "desc": "Integridade do corpo do inimigo (0 a 100)."},
	"bracos_inimigo": {"tipo": "inteiro", "desc": "Integridade dos braços do inimigo (0 a 100)."},
}


static func is_action(name: String) -> bool:
	return ACTIONS.has(name)


static func is_sensor(name: String) -> bool:
	return SENSORS.has(name)


static func sensor_type(name: String) -> String:
	return SENSORS[name].tipo if SENSORS.has(name) else ""


## Sugere o nome mais parecido (para mensagens do tipo "você quis dizer...?").
static func closest_name(name: String, candidates: Array) -> String:
	var best := ""
	var best_score := 0.0
	for c in candidates:
		var score := name.similarity(String(c))
		if score > best_score:
			best_score = score
			best = c
	return best if best_score >= 0.5 else ""
