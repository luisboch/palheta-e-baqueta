// Fundo de quadrinho atrás do cenário dos menus: raios de "explosão" girando devagar, retícula
// crescendo para as bordas e um centro claro que pulsa no tempo. As cores mudam a cada tela.
shader_type canvas_item;

uniform vec3 color_a : source_color = vec3(1.0, 0.82, 0.25);
uniform vec3 color_b : source_color = vec3(1.0, 0.55, 0.26);
uniform vec3 dots : source_color = vec3(0.9, 0.22, 0.27);
// Centro dos raios (UV da tela): um pouco acima do meio, onde fica o horizonte.
uniform vec2 center = vec2(0.5, 0.38);
uniform float rays = 14.0;
uniform float spin = 0.0;  // rad; o script gira
uniform float pulse = 0.0;  // 0 a 1, na batida
uniform float aspect = 1.6;
uniform float dot_size = 10.0;

void fragment() {
	vec2 p = (UV - center) * vec2(aspect, 1.0);
	float r = length(p);
	float angle = atan(p.y, p.x) + spin;
	float ray = step(0.5, fract(angle / TAU * rays));
	vec3 color = mix(color_a, color_b, ray);
	vec2 grid = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * FRAGCOORD.xy / dot_size;
	float coverage = smoothstep(0.3, 1.2, r) * 0.85;
	float dot_mask = step(length(fract(grid) - 0.5) * 1.4142, coverage);
	color = mix(color, dots, dot_mask * 0.8);
	float glow = smoothstep(0.2 + pulse * 0.06, 0.0, r);
	color = mix(color, vec3(1.0, 0.97, 0.88), glow);
	COLOR = vec4(color, 1.0);
}
