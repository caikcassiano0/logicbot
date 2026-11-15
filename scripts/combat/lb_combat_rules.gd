class_name LBCombatRules
extends RefCounted
## Todas as regras numéricas do combate em um só lugar.
## Para balancear o jogo, altere SOMENTE este arquivo (e as descrições em
## LBRobotAPI, que o aluno lê no jogo).

const TICK_RATE := 60
const DT := 1.0 / TICK_RATE

const ROUND_TIME := 60.0
const TURNO_DURACAO := 5.0    ## luta por turnos: a cada 5 s a luta pausa para os dois reprogramarem
const MAX_VIDA := 200
const MAX_ENERGIA := 100.0
const ENERGIA_INICIAL := 20.0
const ENERGIA_REGEN_POR_SEG := 6.0
const ENERGIA_AO_ACERTAR := 10.0
const ENERGIA_AO_BLOQUEAR := 5.0

const ARENA_LIMITE := 6.0      ## robôs ficam entre -6 m e +6 m
const DISTANCIA_MINIMA := 0.9  ## robôs não atravessam um ao outro
const DISTANCIA_PERTO := 1.7   ## sensor inimigo_perto
const POSICAO_INICIAL := 2.5   ## começam a 5 m de distância

const REDUCAO_DEFESA := 0.75
const REDUCAO_DEFESA_ESPECIAL := 0.5
const ATORDOAMENTO := 0.3      ## tempo travado depois de levar um golpe em cheio
const EMPURRAO_ESPECIAL := 1.2
const DURACAO_FALHA := 0.35    ## tempo perdido ao tentar ação sem energia
const DESEQUILIBRIO_BLOQUEIO := 0.25  ## golpe bloqueado: atacante demora mais para se recuperar
const ATORDOAMENTO_CORTE := 0.2      ## 2.0: quem tem o golpe forte cortado por um jab perde o ritmo
const DESEQUILIBRIO_ESQUIVA := 0.35   ## 2.0: golpe FORTE que o outro esquivou deixa o atacante aberto

## dur = duração total; hit_at = momento do impacto; inv = janela intocável;
## air = janela no ar; speed = metros/s (positivo = em direção ao inimigo).
const ACOES := {
	"atacar": {"dur": 0.42, "hit_at": 0.18, "alcance": 1.7, "dano": 7, "custo": 0.0, "tipo": "golpe"},
	"golpe_especial": {"dur": 0.85, "hit_at": 0.45, "alcance": 2.8, "dano": 20, "custo": 50.0, "tipo": "especial"},
	"defender": {"dur": 0.55, "custo": 0.0},
	"avancar": {"dur": 0.3, "speed": 4.0, "custo": 0.0},
	"recuar": {"dur": 0.3, "speed": -3.5, "custo": 0.0},
	"esquivar": {"dur": 0.45, "inv_de": 0.04, "inv_ate": 0.32, "speed": -2.6, "custo": 8.0},
	"pular": {"dur": 0.6, "ar_de": 0.08, "ar_ate": 0.5, "altura": 1.3, "custo": 10.0},
	"aguardar": {"dur": 0.25, "custo": 0.0},

	# ---------------- BOXE (2.0) ----------------
	# Golpes: altura "alto" (cabeça) ou "baixo" (corpo); trajeto "reto", "curvo" ou "sobe" (uppercut).
	# Mão da frente = mais rápida e fraca; mão de trás = mais lenta e forte.
	"jab": {"dur": 0.40, "hit_at": 0.16, "alcance": 1.8, "dano": 4, "custo": 0.0, "tipo": "golpe", "altura": "alto", "trajeto": "reto", "folego": 4.0},
	"direto": {"dur": 0.60, "hit_at": 0.28, "alcance": 1.9, "dano": 9, "custo": 0.0, "tipo": "golpe", "altura": "alto", "trajeto": "reto", "folego": 5.0},
	"cruzado_frente": {"dur": 0.55, "hit_at": 0.26, "alcance": 1.7, "dano": 10, "custo": 0.0, "tipo": "golpe", "altura": "alto", "trajeto": "curvo", "folego": 5.0},
	"cruzado_tras": {"dur": 0.70, "hit_at": 0.34, "alcance": 1.7, "dano": 13, "custo": 0.0, "tipo": "golpe", "altura": "alto", "trajeto": "curvo", "folego": 7.0},
	"uppercut_frente": {"dur": 0.60, "hit_at": 0.30, "alcance": 1.4, "dano": 12, "custo": 0.0, "tipo": "golpe", "altura": "alto", "trajeto": "sobe", "folego": 6.0},
	"uppercut_tras": {"dur": 0.75, "hit_at": 0.38, "alcance": 1.4, "dano": 16, "custo": 0.0, "tipo": "golpe", "altura": "alto", "trajeto": "sobe", "folego": 8.0},
	"jab_corpo": {"dur": 0.42, "hit_at": 0.17, "alcance": 1.7, "dano": 4, "custo": 0.0, "tipo": "golpe", "altura": "baixo", "trajeto": "reto", "folego": 4.0},
	"direto_corpo": {"dur": 0.62, "hit_at": 0.29, "alcance": 1.8, "dano": 9, "custo": 0.0, "tipo": "golpe", "altura": "baixo", "trajeto": "reto", "folego": 5.0},
	"gancho_figado": {"dur": 0.65, "hit_at": 0.32, "alcance": 1.7, "dano": 11, "custo": 0.0, "tipo": "golpe", "altura": "baixo", "trajeto": "curvo", "folego": 6.0},
	"overhand": {"dur": 0.85, "hit_at": 0.45, "alcance": 1.9, "dano": 17, "custo": 20.0, "tipo": "golpe", "altura": "alto", "trajeto": "curvo", "folego": 9.0},
	# Defesas: bloqueio protege só a sua altura; esquivas têm uma janela em que o golpe passa.
	"bloqueio_alto": {"dur": 0.55, "custo": 0.0, "protege": "alto"},
	"bloqueio_baixo": {"dur": 0.55, "custo": 0.0, "protege": "baixo"},
	"esquivar_esquerda": {"dur": 0.45, "inv_de": 0.05, "inv_ate": 0.35, "custo": 6.0, "evita": ["alto:reto"]},
	"esquivar_direita": {"dur": 0.45, "inv_de": 0.05, "inv_ate": 0.35, "custo": 6.0, "evita": ["alto:reto"]},
	"abaixar": {"dur": 0.50, "inv_de": 0.06, "inv_ate": 0.40, "custo": 6.0, "evita": ["alto:reto", "alto:curvo"], "punido_por": "sobe"},
	"recuar_tronco": {"dur": 0.55, "inv_de": 0.05, "inv_ate": 0.40, "custo": 0.0, "evita_alcance_ate": 1.7, "evita_altura": "alto"},
	"passo_lado": {"dur": 0.50, "inv_de": 0.10, "inv_ate": 0.45, "custo": 0.0, "evita": ["alto:reto", "baixo:reto"]},
}

const ACOES_DE_ATAQUE: Array[String] = ["atacar", "golpe_especial", "jab", "direto", "cruzado_frente", "cruzado_tras",
	"uppercut_frente", "uppercut_tras", "jab_corpo", "direto_corpo", "gancho_figado", "overhand"]
const ACOES_DE_DEFESA: Array[String] = ["defender", "esquivar", "pular", "bloqueio_alto", "bloqueio_baixo",
	"esquivar_esquerda", "esquivar_direita", "abaixar", "recuar_tronco", "passo_lado"]
const BONUS_UPPERCUT_ABAIXADO := 1.3   ## uppercut em quem está abaixado: +30% de dano
const REDUCAO_ALTA_CONTRA_UPPERCUT := 0.25  ## uppercut sobe pelo meio da guarda alta: ela segura só 25%

# ---------------- FÔLEGO E PARTES DO CORPO (2.0, só golpes de boxe) ----------------
const FOLEGO_MAX := 100.0
const FOLEGO_REGEN := 5.0             ## por segundo, normalmente
const FOLEGO_REGEN_DEFESA := 12.0     ## por segundo bloqueando, esquivando, recuando ou aguardando
const FOLEGO_POR_DANO_CABECA := 0.7   ## fôlego perdido por ponto de dano na cabeça
const FOLEGO_POR_DANO_CORPO := 1.6    ## golpe no corpo "tira o ar": perde mais fôlego
const FOLEGO_POR_BLOQUEIO := 0.5      ## por ponto de dano do golpe bloqueado
const FOLEGO_CANSADO := 25.0          ## abaixo disto o robô está cansado
const LENTIDAO_CANSADO := 1.2         ## cansado: ações de boxe 20% mais lentas
const GOLPE_PESADO := 10              ## golpe "forte": interrompe/atordoa e derruba quem está sem fôlego
const PARTE_POR_DANO := 2.0           ## integridade perdida pela parte atingida, por ponto de dano
const PARTE_POR_BLOQUEIO := 1.0       ## braços perdem isto por ponto de dano bloqueado
const PARTE_FRACA := 40.0             ## abaixo disto a parte está avariada
const DANO_BRACOS_FRACOS := 0.8       ## braços avariados: socos com 80% do dano
const REDUCAO_BRACOS_FRACOS := 0.6    ## braços avariados: a guarda segura só 60%
const ATORDOAMENTO_CABECA_FRACA := 1.6  ## cabeça avariada: atordoamento 60% maior
const REGEN_CORPO_FRACO := 0.5        ## corpo avariado: fôlego volta pela metade
