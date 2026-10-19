shader_type spatial;
uniform vec4 base_color : source_color;
uniform vec4 accent_color : source_color;
uniform sampler2D artwork : source_color, filter_linear_mipmap_anisotropic;
uniform int design = 0;
uniform vec2 panel_size=vec2(.157,.088);
uniform float center_z=0.0;
varying vec3 panel_position;
varying vec3 panel_normal;
#include "res://scripts/shell_patterns.gdshaderinc"
void vertex() { panel_position=VERTEX;panel_normal=NORMAL; }
void fragment() {
    vec2 uv=vec2(panel_position.x/panel_size.x+.5,(panel_position.z-center_z)/panel_size.y+.5);
    vec3 paint=design<2?texture(artwork,uv).rgb:shell_pattern(uv,design,base_color.rgb,accent_color.rgb);
    ALBEDO=mix(base_color.rgb,paint,smoothstep(.7,.98,-panel_normal.y));
    METALLIC=.15;ROUGHNESS=.32;CLEARCOAT=.35;
}
