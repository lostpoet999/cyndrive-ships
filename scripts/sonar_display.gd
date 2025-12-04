extends ColorRect

const SONAR_BLIP_SCENE = preload("res://scenes/sonar_blip.tscn")

func set_display_visibility(yesno):
	set_visible(yesno)

func set_display_rotation(rot): 
	get_material().set_shader_parameter("angle", rot)

func erase_node(node):
	node.queue_free()

func add_display_object(parent: Node2D, parent_offset: int, target: Node2D, p_color: Color):
	var sonar_blip = SONAR_BLIP_SCENE.instantiate()
	sonar_blip.init(parent, parent_offset, target, p_color)
