// Contorno só das silhuetas, para a partida (ink.gdshaderinc). Sem a textura de normais: com
// 2 jogadores a cena é desenhada duas vezes, e o passe a mais das normais derrubava os quadros
// (60 → 47 FPS numa Iris Xe). De quebra, a pista fica com menos traços para ler.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

#include "res://game/comic/ink.gdshaderinc"
