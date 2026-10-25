// O telão do palco com a capa da música, impressa como quadrinho: retícula de tinta nas partes
// escuras, uma varredura leve e um clarão quando a capa troca. Sem capa, listras na cor do palco.
shader_type spatial;
render_mode unshaded;

uniform sampler2D cover : source_color, filter_linear_mipmap;
uniform bool has_cover = false;
uniform vec3 tint : source_color = vec3(0.48, 0.17, 0.75);
uniform float flash = 0.0;  // 1 logo depois de trocar, até 0
uniform float dot_size = 5.0;

void fragment() {
	vec3 color;
	if (has_cover) {
		color = texture(cover, UV).rgb;
	} else {
		float stripe = step(0.5, fract((UV.x + UV.y) * 8.0));
		color = mix(tint, tint * 0.6, stripe);
	}
	float luminance = dot(color, vec3(0.299, 0.587, 0.114));
	vec2 grid = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * FRAGCOORD.xy / dot_size;
	float ink_dot = step(length(fract(grid) - 0.5) * 1.4142, (1.0 - luminance) * 0.6);
	color = mix(color, color * 0.3, ink_dot * 0.5);
	color *= 0.94 + 0.06 * sin(FRAGCOORD.y * 1.3 - TIME * 5.0);
	ALBEDO = mix(color, vec3(1.0), flash);
}
