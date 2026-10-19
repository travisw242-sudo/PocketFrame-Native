shader_type spatial;
uniform vec4 tint : source_color = vec4(0.5,0.4,0.3,1.0);
uniform int surface_kind = 0;
varying vec3 location;
void vertex() { location = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
float noise(vec3 p) { return fract(sin(dot(p,vec3(12.9898,78.233,43.12)))*43758.5453); }
void fragment() {
    float grain = 0.0;
    if (surface_kind == 0) {
        grain = sin(location.z*310.0 + sin(location.x*8.0)*3.0)*0.025;
        grain += sin(location.z*1100.0+location.x*12.0)*0.012;
    } else if (surface_kind == 1) {
        grain = noise(floor(location*500.0))*0.018;
    } else {
        grain = sin(location.x*1800.0)*sin(location.z*1800.0)*0.025;
    }
    ALBEDO = tint.rgb*(1.0+grain);
    ROUGHNESS = surface_kind == 0 ? 0.64 : 0.9;
}
