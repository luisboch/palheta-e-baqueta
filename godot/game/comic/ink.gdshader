// Contorno completo, para os menus: silhuetas e arestas vivas (ink.gdshaderinc). A textura de
// normais custa um passe a mais da cena e exige o Forward+.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

#define INK_NORMALS
#include "res://game/comic/ink.gdshaderinc"
