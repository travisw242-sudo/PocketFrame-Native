shader_type canvas_item;
uniform vec4 base_color : source_color;
uniform vec4 accent_color : source_color;
uniform sampler2D artwork : source_color, filter_linear;
uniform int design=0;
#include "res://scripts/shell_patterns.gdshaderinc"
void fragment() {
    vec2 p=abs(UV-.5)-vec2(.46,.40);
    float rounded=length(max(p,vec2(0)))+min(max(p.x,p.y),0.0)-.04;
    vec3 paint=design<2?texture(artwork,UV).rgb:shell_pattern(UV,design,base_color.rgb,accent_color.rgb);
    COLOR=vec4(paint,1.0-smoothstep(0,.009,rounded));
}
