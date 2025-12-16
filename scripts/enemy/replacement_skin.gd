extends Sprite2D

const node_name_to_replace = "skin"
@onready var parent_node: BattleCharacter = get_parent()

func _ready() -> void:
	if parent_node.has_node(node_name_to_replace):
		var n = parent_node.get_node(node_name_to_replace)
		_update_self(n)
		n.queue_free()
		self.name = node_name_to_replace
	else: push_error("Expected to replace sibling node named '" + node_name_to_replace + "'")
		
func _update_self(node_replacing: Sprite2D):
	$accent.self_modulate = Color.YELLOW
	$stripe.self_modulate = Color.BLUE_VIOLET
	self.material = node_replacing.material.duplicate()
	self.material.set_shader_parameter("team_color", parent_node.color)
	
