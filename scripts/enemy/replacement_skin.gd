extends Sprite2D

const node_name_to_replace: String = "skin"

@onready var parent_node: Node = get_parent()

var replace_skin = true
func _ready() -> void:
	if not replace_skin: return
	if parent_node.has_node(node_name_to_replace):
		var n = parent_node.get_node(node_name_to_replace)
		_update_self(n)
		n.replace_by(self)
		n.queue_free()
		# queue_free needs some time to be applied so the rename needs to be delayed
		get_tree().create_timer(1.).connect("timeout", func(): self.name = node_name_to_replace)
	else: push_error("Expected to replace sibling node named '" + node_name_to_replace + "'")
		
func _update_self(node_replacing: Sprite2D):
	$accent.self_modulate = Color.YELLOW
	$stripe.self_modulate = Color.BLUE_VIOLET
	self.material = node_replacing.material
	self.material.set_shader_parameter("team_color", parent_node.color)
	
