// Piso da arena: placas metálicas com juntas, grade fina e linhas neon.
// Tudo procedural (sem texturas) — leve e nítido em qualquer resolução.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.15, 0.17, 0.21);
uniform vec3 color_left : source_color = vec3(0.13, 0.83, 0.93);
uniform vec3 color_right : source_color = vec3(1.0, 0.23, 0.31);
uniform float line_strength = 1.0;
uniform float arena_limit = 6.6;
uniform float lane_half_width = 1.4;

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 cell = floor(p / 2.0);
	float plate = hash(cell);
	vec2 f = fract(p / 2.0);
	float d = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float seam = 1.0 - smoothstep(0.0, 0.012, d);

	vec2 g = abs(fract(p * 2.0) - 0.5);
	float fine = smoothstep(0.485, 0.5, max(g.x, g.y));

	float side = smoothstep(-2.5, 2.5, p.x);
	vec3 neon = mix(color_left, color_right, side);

	float in_lane_x = step(abs(p.x), arena_limit);
	float lane = (1.0 - smoothstep(0.0, 0.03, abs(abs(p.y) - lane_half_width))) * in_lane_x;
	float edge = (1.0 - smoothstep(0.0, 0.05, abs(abs(p.x) - arena_limit))) * step(abs(p.y), lane_half_width + 0.6);
	float center = (1.0 - smoothstep(0.0, 0.025, abs(p.x))) * step(abs(p.y), lane_half_width);
	float fade = exp(-abs(p.y) * 0.25) * exp(-abs(p.x) * 0.06);

	ALBEDO = base_color * (0.7 + plate * 0.55) * (1.0 - seam * 0.7);
	METALLIC = 0.88;
	ROUGHNESS = 0.14 + plate * 0.2 + seam * 0.5;
	SPECULAR = 0.6;
	EMISSION = neon * (lane * 2.2 + edge * 3.0 + center * 0.7) * line_strength
		+ neon * fine * 0.06 * fade;
}
