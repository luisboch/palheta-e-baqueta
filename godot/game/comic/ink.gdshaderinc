// Contorno de tinta de quadrinho na tela inteira (incluído por ink.gdshader e
// ink_silhouette.gdshader): traço onde a profundidade salta (a silhueta) e, com INK_NORMALS,
// onde a normal muda de repente (as arestas vivas dos modelos). Fica num quad diante da câmera.
// Um passe só para a cena toda, em vez de um casco invertido por objeto, que abre buracos nas
// quinas das caixas.
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
#ifdef INK_NORMALS
uniform sampler2D normal_texture : hint_normal_roughness_texture, filter_nearest;
#endif
uniform vec3 ink : source_color = vec3(0.07, 0.07, 0.09);
// Distância (px) dos vizinhos comparados: a grossura do traço.
uniform float thickness = 1.5;
// Salto de profundidade que vira traço, relativo à distância (longe precisa de salto maior).
uniform float depth_threshold = 0.06;
#ifdef INK_NORMALS
// 1 - cosseno entre normais vizinhas que vira traço.
uniform float normal_threshold = 0.45;
#endif

void vertex() {
	// QuadMesh 2×2: cobre a tela inteira, no plano de perto.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float linear_depth(vec2 uv, mat4 inv_projection) {
	float depth = texture(depth_texture, uv).r;
	vec4 view = inv_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
	return -view.z / view.w;
}

#ifdef INK_NORMALS
vec3 view_normal(vec2 uv) {
	return texture(normal_texture, uv).xyz * 2.0 - 1.0;
}
#endif

void fragment() {
	vec2 step_px = thickness / VIEWPORT_SIZE;
	float center = linear_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
#ifdef INK_NORMALS
	vec3 normal = view_normal(SCREEN_UV);
#endif
	float depth_jump = 0.0;
	float bend = 0.0;
	vec2 around[4] = {vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0)};
	for (int i = 0; i < 4; i++) {
		vec2 uv = SCREEN_UV + around[i] * step_px;
		depth_jump = max(depth_jump, linear_depth(uv, INV_PROJECTION_MATRIX) - center);
#ifdef INK_NORMALS
		bend = max(bend, 1.0 - dot(normal, view_normal(uv)));
#endif
	}
	// Só o lado de perto da borda pinta: o traço não engorda para dentro do céu.
	float edge = step(depth_threshold * center, depth_jump);
#ifdef INK_NORMALS
	edge = max(edge, step(normal_threshold, bend));
#endif
	ALBEDO = ink;
	ALPHA = edge;
}
