shader_type canvas_item;

uniform float glow_intensity : hint_range(0.1, 5.0) = 2.0;
uniform float glow_speed : hint_range(0.1, 3.0) = 1.0;
uniform float radial_glow : hint_range(1.0, 10.0) = 3.0;
uniform vec4 glow_color : source_color = vec4(0.2, 1.0, 0.3, 1.0);
uniform float wave_count : hint_range(1, 10) = 3.;
uniform float wave_spacing : hint_range(0.1, 0.5) = 0.2;
uniform float pixel_size : hint_range(1.0, 20.0) = 4.0;

void fragment() {
	vec2 uv = UV - 0.5;
	uv = floor(uv * (1.0 / pixel_size) * 100.0) / (100.0 / pixel_size);
	float dist = length(uv);

	float glow = 0.0;    
	for (float i = 0.; i < wave_count; i+= 1.) {
		float wave_offset = i * wave_spacing;
		float wave_time = -TIME * glow_speed + wave_offset;
		float wave_pos = fract(wave_time) * 1.5;
		float wave_dist = abs(dist - wave_pos);
		float wave_intensity = exp(-wave_dist * 15.0);
		wave_intensity *= 1.0 - smoothstep(0.0, 1.2, wave_pos);
		glow += wave_intensity;
	}
    glow += exp(-dist * (10. - radial_glow)) * glow_intensity;
	COLOR = glow_color;
    COLOR.a = glow * glow_color.a * smoothstep(0.6, 0.0, dist);
}