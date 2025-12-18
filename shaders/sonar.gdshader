shader_type canvas_item;

const float PI_DOUBLE = PI * 2.;

uniform sampler2D screen_texture : hint_screen_texture;
uniform sampler2D greeble_noise;
uniform vec2 noise_offset = vec2(0, 0);

uniform float aspect_ratio = 1.777777778; //1920./ 1080.;
uniform float sonar_angle : hint_range(0.0, 6.28318530718) = 0.0;
uniform float sonar_width_percent = 0.1;
uniform float sonar_sharpness = 5.;
uniform float center_blindspot = 0.2;
uniform float sonar_ring_length = 1.3;
uniform float sonar_blindspot_ring : hint_range(0.0, 1.0) = 0.9;
uniform float sonar_display_strength : hint_range(0.0, 1.0) = 0.1;
uniform vec4 sonar_color : source_color = vec4(0.0, 1.0, 0.5, 1.0);

uniform float health : hint_range(0.0, 1.0) = 0.5;
uniform float health_range : hint_range(0.0, 6.28318530718) = 0.5;
uniform float health_angle : hint_range(0.0, 6.28318530718) = 0.5;
uniform float health_ring_width : hint_range(0.0, 1.0) = 0.9;
uniform float health_ring_core_width : hint_range(0.0, 0.1) = 0.1;
uniform float greeble_strength : hint_range(0., 0.1) = 0.001;
uniform float pixel_size = 1.;

// Provides the distance of the given pixel to the given angle within a circular sweep
float pixel_distance_to_angle(vec2 uv, float angle_rad) {
  float pixel_angle = atan(uv.y, uv.x) + PI;
  if (pixel_angle > PI_DOUBLE) {
    pixel_angle -= PI_DOUBLE;
  } else if (pixel_angle < -PI_DOUBLE) {
    pixel_angle += PI_DOUBLE;
  }
  float angle_diff = abs(angle_rad - pixel_angle);
  if (angle_diff > PI) {
    angle_diff = PI_DOUBLE - angle_diff;
  }
  return angle_diff;
}

void fragment() {
  vec2 uv = (UV - 0.5) * vec2(aspect_ratio, 1.);
  vec2 greebled_uv = (
    uv
    + (
      texture(
        greeble_noise,
        round((UV + noise_offset) * pixel_size) / pixel_size
      ).r - 0.5
    ) * greeble_strength
  );
  greebled_uv = round(greebled_uv * pixel_size) / pixel_size; // Create pixellized greeble noise

  // Decide how far the pixel is from the center
  float pixel_center_distance = length(uv);
  float greebled_pixel_center_distance = length(greebled_uv);

  // Display user interface
  vec4 result_color = vec4(0., 0., 0., 0.);
  float health_angle_diff = pixel_distance_to_angle(greebled_uv, health_angle);
  if (
    (
      pixel_center_distance < center_blindspot * sonar_blindspot_ring
      && greebled_pixel_center_distance < center_blindspot * sonar_blindspot_ring
      && (greebled_pixel_center_distance >= center_blindspot * (1. - health_ring_width))
    )
    && health_angle_diff < health_range
  ) {
    // Health display
    health_angle_diff /= max(health, 0.001);
    result_color.r = pow(health_range / max(health_angle_diff, 0.001), 10.);
    result_color.a = min(
      result_color.r,
      smoothstep(
        health_ring_core_width, 0.0015,
        abs(greebled_pixel_center_distance - center_blindspot * (1. - health_ring_width))
      ) * 0.75
    );
  } else if (pixel_center_distance >= center_blindspot * sonar_blindspot_ring) {
    // Sonar display
    float sonar_angle_width = sonar_width_percent * PI_DOUBLE;
    float angle_diff = pixel_distance_to_angle(uv, sonar_angle + PI);
    float sonar_arc_alpha = 0.;
    if (pixel_center_distance < center_blindspot) {
      sonar_angle_width *= sonar_ring_length;
    }
    if (angle_diff >= 0.0 && angle_diff <= sonar_angle_width) {
      sonar_arc_alpha = smoothstep(sonar_angle_width, 0.0, angle_diff);
      if (pixel_center_distance > center_blindspot)
        sonar_arc_alpha = pow(sonar_arc_alpha, sonar_sharpness);
    }
    float sonar_alpha_value = sonar_arc_alpha * sonar_display_strength;
    if (sonar_alpha_value >= result_color.a) {
      result_color = vec4(sonar_color.rgb, sonar_alpha_value);
    }
  }

  // Set the output color
  COLOR = result_color;
}
