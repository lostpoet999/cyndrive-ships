extends ColorRect

const SONAR_BLIP_SCENE = preload("res://scenes/sonar_blip.tscn")

@export_range(0., 1.,) var sonar_width: float = 0.0075
@export_range(-1., 5.,) var sonar_edge_open: float = -0.5
@export_range(-1., 5.,) var sonar_edge_close: float = 5.
@export var open_time = 0.4
@export var close_time = 0.2
func set_display_visibility(yes: bool) -> void:
	if yes:
		create_tween().tween_method(
			func(w) : get_material().set_shader_parameter("sonar_width_percent", w),
			0., sonar_width, open_time
		)
		create_tween().tween_method(
			func(e) : get_material().set_shader_parameter("sonar_sharpness", e),
			0., sonar_edge_open, open_time
		)
	else:
		create_tween().tween_method(
			func(w) : get_material().set_shader_parameter("sonar_width_percent", w),
			sonar_width, 0., open_time
		)
		create_tween().tween_method(
			func(e) : get_material().set_shader_parameter("sonar_sharpness", e),
			sonar_edge_close, 0., open_time
		)
	
func set_display_rotation(rot: float) -> void: 
	get_material().set_shader_parameter("angle", rot)

func add_display_object(parent: Node2D, parent_offset: int, target: Node2D, p_color: Color) -> Node2D:
	if not visible:
		return null
	var sonar_blip = SONAR_BLIP_SCENE.instantiate()
	sonar_blip.init(parent, parent_offset, target, p_color)
	return sonar_blip
