shader_type canvas_item;

const float PI_DOUBLE = PI * 2.;

uniform sampler2D screen_texture : hint_screen_texture;
uniform float aspect_ratio = 1.777777778; //1920./ 1080.;
uniform float angle = 0.0;
uniform float sonar_width_percent = 0.1;
uniform float sonar_sharpness = 5.;
uniform float center_blindspot = 0.2;
uniform float sonar_ring_length = 1.3;
uniform float sonar_blindspot_ring: hint_range(0.0, 1.0) = 0.9;
uniform float sonar_display_strength: hint_range(0.0, 1.0) = 0.1;
uniform vec4 sonar_color : source_color = vec4(0.0, 1.0, 0.5, 1.0);

void fragment() {
	vec2 uv = UV - 0.5;
	uv.x *= aspect_ratio;
	
	// Decide how far the pixel is from the center
	float sonar_angle_width = sonar_width_percent * PI_DOUBLE;
	float pixel_center_distance = length(uv);
	if (pixel_center_distance < center_blindspot){
		sonar_angle_width *= sonar_ring_length;
	}
	if (pixel_center_distance < center_blindspot * sonar_blindspot_ring){
		discard;
	}

	// Decide how far away is the current pixel from the start of the sonar sweep
	float sonar_angle = mod(angle + PI, PI_DOUBLE);
	float pixel_angle = atan(uv.y, uv.x) + PI;
	if (sonar_angle > PI) {
		sonar_angle -= PI_DOUBLE;
	} else if (pixel_angle < -PI) {
		sonar_angle += PI_DOUBLE;
	}
	if (pixel_angle > PI) {
		pixel_angle -= PI_DOUBLE;
	} else if (pixel_angle < -PI) {
		pixel_angle += PI_DOUBLE;
	}
	float angle_diff = abs(sonar_angle - pixel_angle);
	float sonar_arc_alpha = 0.;
	if (angle_diff >= 0.0 && angle_diff <= sonar_angle_width) {
		sonar_arc_alpha = smoothstep(sonar_angle_width, 0.0, angle_diff);
		if (pixel_center_distance > center_blindspot)
			sonar_arc_alpha = pow(sonar_arc_alpha, sonar_sharpness);
	}
	COLOR = vec4(sonar_color.rgb, sonar_arc_alpha * sonar_display_strength);
}