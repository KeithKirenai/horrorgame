shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

uniform float noise_rate : hint_range(1.0, 60.0) = 12.0;
uniform float jitter_amount : hint_range(0.0, 0.1) = 0.005;
uniform float luma_flicker : hint_range(0.0, 0.5) = 0.05;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.15;
uniform float static_intensity : hint_range(0.0, 1.0) = 0.08;

uniform float dither_spread : hint_range(0.0, 0.1) = 0.03;
uniform bool use_dithering = true;

// Safe RGB to YUV
vec3 rgb2yuv(vec3 rgb) {
	float y = 0.299 * rgb.r + 0.587 * rgb.g + 0.114 * rgb.b;
	float u = -0.14713 * rgb.r - 0.28886 * rgb.g + 0.436 * rgb.b;
	float v = 0.615 * rgb.r - 0.51499 * rgb.g - 0.10001 * rgb.b;
	return vec3(y, u, v);
}

vec3 yuv2rgb(vec3 yuv) {
	float r = yuv.x + 1.13983 * yuv.z;
	float g = yuv.x - 0.39465 * yuv.y - 0.58060 * yuv.z;
	float b = yuv.x + 2.03211 * yuv.y;
	return vec3(r, g, b);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float snapped_time = floor(TIME * noise_rate) / noise_rate;
	vec2 uv = SCREEN_UV;
	
	// Analog Horizontal Jitter (VHS tracking distortion)
	float jitter = hash(vec2(snapped_time, floor(uv.y * 100.0))) - 0.5;
	// Create random band tracking lines
	float band = step(0.98, hash(vec2(snapped_time * 5.0, uv.y * 2.0)));
	uv.x += jitter * jitter_amount * band;
	
	// Sample texture
	vec3 col = texture(screen_tex, uv).rgb;
	vec3 yuv = rgb2yuv(col);
	
	// Analog Luminance Flicker
	float noise_val = hash(uv + vec2(snapped_time));
	yuv.x += (noise_val - 0.5) * luma_flicker;
	
	// Analog Static / Noise Grain
	float grain = hash(uv * snapped_time) - 0.5;
	yuv.x += grain * static_intensity;
	
	// Scanlines
	float scanline = sin(SCREEN_UV.y * 300.0 * PI) * 0.5 + 0.5;
	yuv.x -= scanline * scanline_intensity * 0.15;
	
	vec3 final_color = yuv2rgb(yuv);
	
	if (use_dithering) {
		// 4x4 Bayer Dithering Matrix representation
		int x = int(FRAGCOORD.x) % 4;
		int y = int(FRAGCOORD.y) % 4;
		int index = y * 4 + x;
		float threshold = 0.0;
		if (index == 0) threshold = 0.0/16.0;
		else if (index == 1) threshold = 8.0/16.0;
		else if (index == 2) threshold = 2.0/16.0;
		else if (index == 3) threshold = 10.0/16.0;
		else if (index == 4) threshold = 12.0/16.0;
		else if (index == 5) threshold = 4.0/16.0;
		else if (index == 6) threshold = 14.0/16.0;
		else if (index == 7) threshold = 6.0/16.0;
		else if (index == 8) threshold = 3.0/16.0;
		else if (index == 9) threshold = 11.0/16.0;
		else if (index == 10) threshold = 1.0/16.0;
		else if (index == 11) threshold = 9.0/16.0;
		else if (index == 12) threshold = 15.0/16.0;
		else if (index == 13) threshold = 7.0/16.0;
		else if (index == 14) threshold = 13.0/16.0;
		else if (index == 15) threshold = 5.0/16.0;
		
		final_color += (threshold - 0.5) * dither_spread;
		
		// PSX 15-bit color depth (5-5-5 or 5-6-5 bits per channel)
		final_color.r = floor(final_color.r * 31.0 + 0.5) / 31.0;
		final_color.g = floor(final_color.g * 63.0 + 0.5) / 63.0;
		final_color.b = floor(final_color.b * 31.0 + 0.5) / 31.0;
	}
	
	COLOR = vec4(final_color, 1.0);
}
