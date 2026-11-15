# Ferramentas de desenvolvimento (não fazem parte do jogo)

| Cena | Uso |
|---|---|
| `smoke_test.tscn` | teste de fumaça (APAGA o progresso salvo): `godot --headless --path . --fixed-fps 60 res://tools/smoke_test.tscn` |
| `screenshot.tscn` | captura do menu e da batalha (`LB_OUT=pasta`) |
| `preview_capture.tscn` | capturas de momentos de uma luta |
| `preview_video.tscn` | grava uma luta: `godot --path . --write-movie saida.avi --fixed-fps 30 res://tools/preview_video.tscn` |
| `screenshot_etapa3.tscn` | captura do menu da campanha e de uma fase |
| `gen_docs.gd` | regera o gabarito do professor: `godot --headless --path . --script res://tools/gen_docs.gd` |
| `preview_video.tscn` (2.0) | `LB_FASE=f8_omega LB_BOT=maestro` escolhe o código (solução da fase) e o bot; luta em turnos |
| `vitrine_pecas.tscn` | fotos de 3 robôs com as peças da loja (`OUT=pasta`) |
| `eval_receitas.gd` | receitas simples x BRUTUS/MAESTRO/ÔMEGA (equilíbrio): `--script res://tools/eval_receitas.gd` |
| `eval_campanha.gd` | cada fase: a solução vence? o código inicial perde? |
| `mixamo_extrair.gd.txt` | como o robô e as animações do Mixamo viraram `assets/robo/` |
