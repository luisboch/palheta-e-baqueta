// Feixe visível de um refletor: um cone somando luz, mais forte perto da lâmpada e no meio.
// Mais barato que neblina volumétrica, que o Deck não aguentaria com a cena desenhada duas vezes.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

instance uniform vec3 beam_color : source_color = vec3(1.0);
uniform float strength = 0.3;

void fragment() {
	// UV.y vai de 0 (lâmpada) a 1 (chão) no CylinderMesh.
	float fade = 1.0 - UV.y * 0.85;
	// As bordas do cone, vistas de lado, quase somem: dá volume sem um contorno duro.
	float core = abs(dot(NORMAL, VIEW));
	ALBEDO = beam_color * strength * fade * core;
}
