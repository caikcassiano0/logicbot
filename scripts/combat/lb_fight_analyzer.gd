class_name LBFightAnalyzer
extends RefCounted
## Gera o FEEDBACK EDUCATIVO depois da luta.
##
## Cada sugestão aponta um comportamento observado, o conceito de programação
## relacionado e um exemplo de código. Nunca altera o código do aluno.

const MAX_SUGESTOES := 4


## Retorna uma lista de {"titulo", "texto", "conceito", "exemplo"}.
static func analisar(sim: LBCombatSim, jogador: int = 0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var f := sim.lutadores[jogador]
	var o := sim.lutadores[1 - jogador]
	var s: Dictionary = f.stats
	var venceu := sim.vencedor == jogador

	if f.programa_travado and f.erro_programa:
		out.append({
			"titulo": "O programa parou durante a luta",
			"texto": "Na linha %d: %s %s" % [f.erro_programa.line, f.erro_programa.message, f.erro_programa.hint],
			"conceito": "Depuração",
			"exemplo": "",
		})

	if s.falhas_sem_energia > 0:
		out.append({
			"titulo": "Golpe especial sem energia",
			"texto": "Seu robô tentou usar uma habilidade %d vez(es) sem ter energia suficiente e ficou parado, vulnerável. Verifique a energia antes de usar o golpe especial." % s.falhas_sem_energia,
			"conceito": "Operadores relacionais (>=)",
			"exemplo": "se energia >= 50 entao\n   golpe_especial()\nfimse",
		})

	if s.golpes_no_vazio >= 3:
		out.append({
			"titulo": "Ataques no vazio",
			"texto": "%d golpes foram dados longe demais do inimigo. Ataque só quando ele estiver ao alcance; caso contrário, aproxime-se." % s.golpes_no_vazio,
			"conceito": "Condicional SE / SENÃO",
			"exemplo": "se inimigo_perto entao\n   jab()\nsenao\n   avancar()\nfimse",
		})

	var acoes: Dictionary = s.acoes
	var defendeu := 0
	for nome in LBCombatRules.ACOES_DE_DEFESA:
		defendeu += int(acoes.get(nome, 0))
	if s.golpes_recebidos_em_cheio >= 4 and defendeu == 0:
		out.append({
			"titulo": "Nenhuma defesa",
			"texto": "Seu robô levou %d golpes em cheio e nunca se defendeu. Os sensores inimigo_atacando_alto e inimigo_atacando_baixo dizem para onde vai o golpe que ele está preparando." % s.golpes_recebidos_em_cheio,
			"conceito": "Tomada de decisão com sensores",
			"exemplo": "se inimigo_atacando_alto entao\n   bloqueio_alto()\nfimse",
		})

	if s.ataques_com_vida_baixa >= 3 and not venceu:
		out.append({
			"titulo": "Ataque com pouca vida",
			"texto": "Seu robô continuou atacando %d vezes mesmo com menos de 60 de vida. Experimente uma estratégia mais cuidadosa quando a vida estiver baixa." % s.ataques_com_vida_baixa,
			"conceito": "Operadores lógicos (E)",
			"exemplo": "se vida < 60 e inimigo_atacando entao\n   bloqueio_alto()\nfimse",
		})

	if sim.motivo_fim == "tempo" and s.dano_causado < 60:
		out.append({
			"titulo": "Pouca agressividade",
			"texto": "A luta acabou por tempo e seu robô causou só %d de dano. Garanta que ele se aproxime e ataque." % s.dano_causado,
			"conceito": "Sequência de instruções",
			"exemplo": "avancar()\njab()",
		})

	# Depuração: condições que nunca mudaram de resultado
	if f.vm:
		var linhas: Array = f.vm.condition_stats.keys()
		linhas.sort()
		for linha in linhas:
			var st: Dictionary = f.vm.condition_stats[linha]
			if st.kind != "se":
				continue
			if st.v == 0 and st.f >= 5:
				out.append({
					"titulo": "Condição que nunca foi verdadeira (linha %d)" % linha,
					"texto": "O SE da linha %d foi testado %d vezes e o resultado foi sempre FALSO, então o bloco dentro dele nunca rodou. Confira se a comparação faz sentido." % [linha, st.f],
					"conceito": "Depuração de condições",
					"exemplo": "",
				})
				break

	if venceu and out.is_empty():
		var eff := 0.0
		if s.ataques > 0:
			eff = 100.0 * s.acertos / s.ataques
		out.append({
			"titulo": "Estratégia vencedora!",
			"texto": "Seu robô acertou %d de %d ataques (%.0f%%). Desafio: tente vencer usando menos linhas, ou enfrente um oponente mais difícil." % [s.acertos, s.ataques, eff],
			"conceito": "Otimização",
			"exemplo": "",
		})
	elif out.is_empty():
		out.append({
			"titulo": "Observe o inimigo",
			"texto": "Leia o código do %s na aba ao lado. Descubra quando ele ataca e quando defende, e crie condições que aproveitem isso." % o.nome,
			"conceito": "Análise de algoritmos",
			"exemplo": "",
		})

	if out.size() > MAX_SUGESTOES:
		out.resize(MAX_SUGESTOES)
	return out
