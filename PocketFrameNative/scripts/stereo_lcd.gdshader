shader_type spatial;
render_mode unshaded;
uniform sampler2D lcd_image : source_color, filter_linear, repeat_disable;
uniform bool stereo_image = false;
uniform bool swap_eyes = false;
void fragment() {
    vec2 coord = UV;
    vec2 image_size = vec2(textureSize(lcd_image, 0));
    vec2 lower_bound = 0.5 / image_size;
    vec2 upper_bound = vec2(1.0) - lower_bound;
    if (stereo_image) {
        bool right_eye = VIEW_INDEX == VIEW_RIGHT;
        if (swap_eyes) right_eye = !right_eye;
        coord.x = coord.x * 0.5 + (right_eye ? 0.5 : 0.0);
        // Every filter tap must stay inside its own eye, including at the seam.
        lower_bound.x = (right_eye ? 0.5 : 0.0) + 0.5 / image_size.x;
        upper_bound.x = (right_eye ? 1.0 : 0.5) - 0.5 / image_size.x;
    }
    vec2 dx = dFdx(coord);
    vec2 dy = dFdy(coord);
    float footprint = max(length(dx * image_size), length(dy * image_size));
    vec3 center = textureLod(lcd_image, clamp(coord, lower_bound, upper_bound), 0.0).rgb;
    vec3 filtered = center;
    if (footprint > 1.0) {
        // Integrate the tilted/distant headset pixel footprint on the GPU.
        // No per-frame CPU mip generation or stereo-atlas mip seam mixing.
        float limit = min(1.0, 16.0 / max(footprint, 1.0));
        dx *= limit;
        dy *= limit;
        filtered = vec3(0.0);
        for (int y = 0; y < 4; y++) {
            for (int x = 0; x < 4; x++) {
                vec2 offset = dx * ((float(x) + 0.5) / 4.0 - 0.5)
                            + dy * ((float(y) + 0.5) / 4.0 - 0.5);
                filtered += textureLod(lcd_image, clamp(coord + offset, lower_bound, upper_bound), 0.0).rgb;
            }
        }
        filtered *= 1.0 / 16.0;
    }
    // Fade smoothly into minification filtering, avoiding a visible distance pop.
    ALBEDO = mix(center, filtered, smoothstep(1.0, 2.0, footprint));
}
