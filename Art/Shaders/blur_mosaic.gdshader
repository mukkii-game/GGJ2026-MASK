shader_type canvas_item;

// 画面右上1/4用。テクスチャの右上1/4をサンプルしてモザイク（右側の人物の顔に掛ける）
uniform float mosaic_block_size : hint_range(1.0, 32.0) = 4.0;
uniform float blur_radius : hint_range(0.0, 0.05) = 0.008;

void fragment() {
	// このノードは画面右上1/4。テクスチャの右上1/4をマッピング（右側の人物の顔）
	vec2 quarter_uv = vec2(0.5 + UV.x * 0.5, UV.y * 0.5);
	
	// 控えめなモザイク（元の顔が想像できる程度）
	float blocks = 30.0 / mosaic_block_size;
	vec2 block_uv = floor(quarter_uv * blocks) / blocks + 0.5 / blocks;
	
	vec4 sum = vec4(0.0);
	float samples = 0.0;
	float r = blur_radius;
	for (float x = -2.0; x <= 2.0; x += 1.0) {
		for (float y = -2.0; y <= 2.0; y += 1.0) {
			vec2 off = vec2(x, y) * r;
			sum += texture(TEXTURE, block_uv + off);
			samples += 1.0;
		}
	}
	COLOR = sum / samples;
}
