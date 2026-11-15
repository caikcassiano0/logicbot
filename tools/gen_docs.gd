extends SceneTree
## Gera documentation/SOLUCOES_PROFESSOR.md a partir dos dados da campanha.
##   godot --headless --path . --script res://tools/gen_docs.gd


func _initialize() -> void:
	var t := "# Soluções de referência (para o professor — contém spoilers)\n\n"
	t += "Gerado por `tools/gen_docs.gd` a partir de `scripts/ai/lb_campaign.gd`. Cada solução é verificada\n"
	t += "automaticamente em `tests/test_progression.gd`: ela vence o inimigo **e** cumpre os requisitos da fase.\n"
	t += "Há várias soluções possíveis — incentive o aluno a chegar na dele.\n\n"
	for i in LBCampaign.count():
		var f: Dictionary = LBCampaign.FASES[i]
		var b := LBCampaign.bot_of(f)
		t += "## Fase %d — %s\n\n" % [i + 1, f.titulo]
		t += "- **Conceito:** %s\n- **Inimigo:** %s — %s\n- **Objetivo:** %s\n" % [f.conceito, b.nome, b.descricao, f.objetivo]
		var req := LBCampaign.requirements_text(f)
		if req != "":
			t += "- **%s**\n" % req
		t += "\n```\n%s```\n\n" % f.solucao
	t += "## Treino livre\n\n- **TREINO-01:** o programa inicial já vence.\n- **SENTINELA:** ler a altura dos golpes (bloqueio alto/baixo), cuidar do fôlego e usar o direto (ideia das fases 3 e 4).\n- **VÓRTEX:** golpes que não deixam ele respirar (o direto já resolve; mas esse mesmo programa perde para a SENTINELA).\n- **BRUTUS e MAESTRO:** têm várias táticas e trocam a cada turno (veja a aba Inimigo nas pausas). A solução da fase 4 vence os dois.\n"
	var fa := FileAccess.open("res://documentation/SOLUCOES_PROFESSOR.md", FileAccess.WRITE)
	fa.store_string(t)
	print("SOLUCOES_PROFESSOR.md gerado com %d fases" % LBCampaign.count())
	quit()
