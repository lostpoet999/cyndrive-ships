extends CollisionPolygon2D

const node_name_to_replace = "collision_shape"
@onready var parent_node: BattleCharacter = get_parent()

func _ready() -> void:
	if parent_node.has_node(node_name_to_replace):
		var n = parent_node.get_node(node_name_to_replace)
		n.queue_free()
		self.name = node_name_to_replace
	else: push_error("Expected to replace sibling node named '" + node_name_to_replace + "'")
