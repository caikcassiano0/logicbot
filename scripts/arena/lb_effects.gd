class_name LBEffects
extends Node3D
## Efeitos visuais de combate: faíscas, flashes, disparo de plasma, números.
## Tudo é puramente cosmético — nada aqui altera o resultado da luta.
## [member particle_scale] reduz a quantidade de partículas em PCs modestos.

var particle_scale := 1.0
var _spark_mat: ParticleProcessMaterial
var _spark_mesh: QuadMesh
var _ring_mesh: TorusMesh
var _bolt_mesh: SphereMesh
var _dmg_font: Font


func _ready() -> void:
	_spark_mesh = QuadMesh.new()
	_spark_mesh.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_spark_mesh.material = m

	_spark_mat = ParticleProcessMaterial.new()
	_spark_mat.direction = Vector3(0, 0.4, 1)
	_spark_mat.spread = 75.0
	_spark_mat.initial_velocity_min = 2.5
	_spark_mat.initial_velocity_max = 7.0
	_spark_mat.gravity = Vector3(0, -9.0, 0)
	_spark_mat.damping_min = 1.0
	_spark_mat.damping_max = 3.0
	_spark_mat.scale_min = 0.6
	_spark_mat.scale_max = 1.6
	var curve := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	curve.curve = c
	_spark_mat.scale_curve = curve

	_ring_mesh = TorusMesh.new()
	_ring_mesh.inner_radius = 0.42
	_ring_mesh.outer_radius = 0.5
	_ring_mesh.rings = 24
	_ring_mesh.ring_segments = 8

	_bolt_mesh = SphereMesh.new()
	_bolt_mesh.radius = 0.16
	_bolt_mesh.height = 0.32
	_dmg_font = LBUITheme.font(LBUITheme.FONT_TITLE, 900)


func _glow_mat(color: Color, energy: float = 6.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func sparks(pos: Vector3, color: Color, amount: int = 40, dir_x: float = 0.0) -> void:
	var n := maxi(4, int(amount * particle_scale))
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.amount = n
	p.lifetime = 0.55
	p.explosiveness = 0.95
	p.draw_pass_1 = _spark_mesh
	var pm: ParticleProcessMaterial = _spark_mat.duplicate()
	pm.direction = Vector3(dir_x, 0.5, 0.35).normalized() if dir_x != 0.0 else Vector3(0, 1, 0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), color.lightened(0.3), Color(color, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	p.position = pos
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	p.emitting = true
	_free_later(p, 1.2)
	_flash_light(pos, color, 6.0, 3.5, 0.18)


## 2.0: estilhaços de metal (golpes fortes) — pedacinhos escuros que caem no ringue.
func metal_chips(pos: Vector3, dir_x: float, amount: int = 10) -> void:
	var n := maxi(3, int(amount * particle_scale))
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.amount = n
	p.lifetime = 0.9
	p.explosiveness = 1.0
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.03, 0.04)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.32, 0.34, 0.38)
	m.metallic = 0.9
	m.roughness = 0.3
	bm.material = m
	p.draw_pass_1 = bm
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(dir_x, 0.8, 0.2).normalized()
	pm.spread = 50.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.5
	pm.gravity = Vector3(0, -12.0, 0)
	pm.angular_velocity_min = -720.0
	pm.angular_velocity_max = 720.0
	pm.scale_min = 0.6
	pm.scale_max = 1.5
	p.process_material = pm
	p.position = pos
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	p.emitting = true
	_free_later(p, 1.6)


## 2.0: onda de choque virada para a câmera (golpe forte / nocaute).
func shockwave(pos: Vector3, color: Color, size: float = 1.0) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _ring_mesh
	var mat := _glow_mat(color, 4.0)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mi.material_override = mat
	mi.position = pos
	mi.rotation = Vector3(PI / 2, 0, 0)
	mi.scale = Vector3.ONE * 0.15 * size
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 1.8 * size, 0.32).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.32)
	tw.chain().tween_callback(mi.queue_free)


func impact_ring(pos: Vector3, color: Color, size: float = 1.0) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _ring_mesh
	var mat := _glow_mat(color, 5.0)
	mi.material_override = mat
	mi.position = pos
	mi.rotation = Vector3(0, 0, PI / 2)
	mi.scale = Vector3.ONE * 0.2 * size
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 1.4 * size, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tw.chain().tween_callback(mi.queue_free)


func block_flash(pos: Vector3, color: Color) -> void:
	impact_ring(pos, color, 1.3)
	sparks(pos, color, 18, 0.0)


func plasma_bolt(from: Vector3, to: Vector3, color: Color, travel: float = 0.14) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _bolt_mesh
	mi.material_override = _glow_mat(color, 9.0)
	mi.position = from
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 6.0
	light.omni_range = 3.0
	mi.add_child(light)
	add_child(mi)
	# rastro
	var trail := GPUParticles3D.new()
	trail.amount = maxi(8, int(48 * particle_scale))
	trail.lifetime = 0.25
	trail.draw_pass_1 = _spark_mesh
	var pm: ParticleProcessMaterial = _spark_mat.duplicate()
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3.ZERO
	pm.spread = 180.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(color.lightened(0.5), 1), Color(color, 0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	trail.process_material = pm
	mi.add_child(trail)
	trail.emitting = true
	var tw := create_tween()
	tw.tween_property(mi, "position", to, travel).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if is_instance_valid(mi):
			mi.visible = false
	)
	_free_later(mi, travel + 0.4)


func muzzle(pos: Vector3, color: Color) -> void:
	impact_ring(pos, color, 0.6)
	_flash_light(pos, color, 5.0, 2.5, 0.12)


func damage_number(pos: Vector3, value: int, color: Color, label_text: String = "") -> void:
	var l := Label3D.new()
	l.text = label_text if label_text != "" else str(value)
	l.font = _dmg_font
	l.font_size = 64 if label_text == "" else 40
	l.pixel_size = 0.005
	l.modulate = color
	l.outline_size = 14
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 20
	l.position = pos
	add_child(l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", pos.y + 0.9, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "scale", Vector3.ONE * 1.15, 0.12)
	tw.tween_property(l, "modulate:a", 0.0, 0.45).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)


func _flash_light(pos: Vector3, color: Color, energy: float, rng: float, dur: float) -> void:
	if particle_scale < 0.5:
		return   # qualidade Baixa: sem luz extra a cada golpe (pesa no celular)
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.position = pos
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur)
	tw.tween_callback(l.queue_free)


func _free_later(n: Node, t: float) -> void:
	get_tree().create_timer(t).timeout.connect(func():
		if is_instance_valid(n):
			n.queue_free()
	)
