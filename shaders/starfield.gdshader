shader_type canvas_item;

uniform vec2 resolution = vec2(4096.0,4096.0);
uniform vec2 uv_offset = vec2(0.,0.);
uniform sampler2D noise_texture_star_strength: filter_nearest, repeat_enable;
uniform sampler2D noise_texture_star_color: filter_nearest, repeat_enable;
uniform float density: hint_range(1.0, 100.0, 0.1) = 20.0;
uniform float speed_x: hint_range(-100.0, 100.0, 0.1) = 0.0;
uniform float speed_y: hint_range(-100.0, 100.0, 0.1) = 0.0;
uniform float layers: hint_range(1.0, 10.0, 1.0) = 5.0;
uniform float color_shift_strength: hint_range(0.0, 1.0) = 0.1;
uniform float sample_rounder: hint_range(0.0, 10000.0) = 0.1;
void fragment() {
	vec2 uv = UV + uv_offset;
	vec2 speed = TIME * vec2(speed_x, speed_y) * .01;
	uv.x *= resolution.x / resolution.y;

	// Calculate star brightness
	float stars = 0.0;
	for (float i = 0.0; i < layers; i += 1.0){
		float shift = i * 0.2; 
		float brightness = 1.0 - i * 0.2;
		vec2 sample_coordinate = round((uv + shift + speed * (1.0 - i * 0.1)) * sample_rounder) / sample_rounder;
		float sampled_noise = texture(noise_texture_star_strength, sample_coordinate).r;
		stars += step(0.2, pow(sampled_noise, density)) * brightness;
	}

	// Add red and blue color shift
	vec3 star_color = vec3(stars);
	if (0. < stars) {
		float color_correction = texture(noise_texture_star_color, uv).r * 2. - 1.;
		star_color.r += min(0., color_correction) * color_shift_strength;
		star_color.g -= abs(color_correction) * color_shift_strength;
		star_color.b -= max(0., color_correction) * color_shift_strength;
	}
	
	COLOR = vec4(star_color, stars);
}
