shader_type canvas_item;

uniform vec4 block_color_a : source_color = vec4(0.22, 0.22, 0.28, 0.95);
uniform vec4 block_color_b : source_color = vec4(0.18, 0.18, 0.24, 0.95);
uniform float block_size : hint_range(8.0, 64.0) = 24.0;

void fragment() {
	vec2 block_uv = floor(UV * 30.0);
	float checker = mod(block_uv.x + block_uv.y, 2.0);
	COLOR = mix(block_color_a, block_color_b, checker);
}
