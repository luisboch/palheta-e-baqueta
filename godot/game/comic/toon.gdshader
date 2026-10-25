// Sombreado de quadrinho dos modelos (art/build_models.py): luz cheia, uma faixa de sombra e
// retícula (pontos de impressão) na passagem entre as duas. Luz de refletor com borda dura, como
// num desenho. O contorno de tinta não é daqui: é um pós-processamento (ink.gdshader).
shader_type spatial;
render_mode specular_disabled;

uniform vec3 albedo : source_color = vec3(1.0);
uniform vec3 emission : source_color = vec3(0.0);
// Acima disto (cosseno entre a normal e a luz) a face recebe a luz toda.
uniform float lit_threshold = 0.35;
// Quanto da luz chega na sombra: nem preto, nem chapado.
uniform float shade = 0.4;
// Lado da célula da retícula, em pixels de tela.
uniform float dot_size = 6.0;
// Brilho duro nas facetas (o globo espelhado): 0 desliga.
uniform float sparkle = 0.0;

void fragment() {
	ALBEDO = albedo;
	EMISSION = emission;
	ROUGHNESS = 1.0;
}

// 1 dentro do ponto da retícula. `coverage` (0 a 1) é o tamanho do ponto.
float halftone(vec2 frag, float coverage) {
	// Grade a 45°, como na impressão de quadrinhos.
	vec2 p = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * frag / dot_size;
	return step(length(fract(p) - 0.5) * 1.4142, coverage);
}

void light() {
	// Fora do cone ou do alcance da luz, nada: a borda da luz fica dura.
	float reach = step(0.05, ATTENUATION);
	float ndl = dot(NORMAL, LIGHT);
	float tone = shade;
	if (ndl > lit_threshold) {
		tone = 1.0;
	} else if (ndl > 0.0) {
		tone = mix(1.0, shade, halftone(FRAGCOORD.xy, 1.0 - ndl / lit_threshold));
	}
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * tone * reach;
	if (sparkle > 0.0) {
		float glint = step(0.96, dot(reflect(-LIGHT, NORMAL), VIEW));
		SPECULAR_LIGHT += LIGHT_COLOR * glint * sparkle * reach;
	}
}
