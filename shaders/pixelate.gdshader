shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform int pixel_size = 3;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 resolution = 1.0 / SCREEN_PIXEL_SIZE;

    // Calculate pixelated coordinates
    vec2 pixelated_uv = floor(uv * resolution / float(pixel_size)) * float(pixel_size) / resolution;

    // Sample the screen texture at pixelated coordinates
    vec4 color = texture(screen_texture, pixelated_uv);

    COLOR = color;
}
