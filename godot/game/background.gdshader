// Fundo da partida: anéis que saem do horizonte a cada batida, brilho do horizonte pelos graves,
// raios pelos médios e estrelas pelos agudos. Discreto: as notas precisam continuar legíveis.
shader_type canvas_item;

uniform vec2 horizon = vec2(0.5, 0.37); // ponto de fuga da pista na tela (0-1)
uniform float phase = -1.0; // da batida atual (0-1); -1 antes da primeira
uniform float pulse = 0.0; // 0-2 (downbeat vale o dobro)
uniform float low = 0.0; // graves, médios e agudos (0-1)
uniform float mid = 0.0;
uniform float high = 0.0;
uniform vec3 color_a : source_color = vec3(0.78, 0.49, 1.0); // cor do compasso anterior
uniform vec3 color_b : source_color = vec3(0.18, 0.77, 0.71); // cor do compasso atual
uniform float bar_mix = 1.0; // 0-1 ao longo do compasso
uniform float aspect = 1.6;

const vec3 DEEP = vec3(0.035, 0.035, 0.07);
const vec3 HAZE = vec3(0.09, 0.06, 0.16);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec2 d = (uv - horizon) * vec2(aspect, 1.0);
	float r = length(d);
	vec3 tint = mix(color_a, color_b, smoothstep(0.0, 0.25, bar_mix)); // troca no 1º tempo

	// Céu: escuro em cima, névoa perto do horizonte.
	vec3 col = mix(HAZE, DEEP, smoothstep(0.0, 0.9, abs(uv.y - horizon.y) * 2.2));

	// Horizonte respira com os graves.
	float band = exp(-abs(uv.y - horizon.y) * 14.0);
	col += tint * band * (0.08 + 0.35 * low);

	// Raios em leque a partir do ponto de fuga, girando devagar; força pelos médios.
	float angle = atan(d.y, d.x);
	float rays = pow(0.5 + 0.5 * sin(angle * 14.0 + TIME * 0.15), 6.0);
	col += tint * rays * (0.03 + 0.12 * mid) * smoothstep(1.4, 0.1, r);

	// Anel por batida, saindo do horizonte; some antes da próxima.
	if (phase >= 0.0) {
		float radius = phase * 1.1;
		float ring = exp(-abs(r - radius) * 40.0) * (1.0 - phase);
		col += tint * ring * 0.35 * (0.6 + 0.4 * min(pulse, 2.0));
	}

	// Estrelas que cintilam com os agudos, só no céu.
	vec2 grid = uv * vec2(aspect, 1.0) * 70.0;
	vec2 cell = floor(grid);
	float star = step(0.985, hash(cell)) * smoothstep(0.18, 0.0, length(fract(grid) - 0.5));
	float twinkle = 0.4 + 0.6 * sin(TIME * 3.0 + hash(cell + 7.0) * 6.28);
	col += vec3(star * twinkle * (0.15 + 0.6 * high)) * step(uv.y, horizon.y);

	// Vinheta para o centro ficar mais limpo que as bordas.
	col *= 1.0 - 0.35 * smoothstep(0.5, 1.2, length((uv - vec2(0.5)) * vec2(aspect, 1.0)));
	COLOR = vec4(col, 1.0);
}
