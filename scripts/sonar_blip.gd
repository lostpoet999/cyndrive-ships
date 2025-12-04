class_name SonarBlip extends Node2D

@onready var pip = $blip
var parent: Node2D = null
var target: Node2D = null
var parent_offset: int = 0
var color: Color = Color.WHITE

# call after instantiating the scene
func init(p_parent: Node2D, p_parent_offset: int, p_target: Node2D, p_color: Color) -> void:
	parent = p_parent
	target = p_target
	parent_offset = p_parent_offset
	color = p_color
	parent.add_child(self)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pip.modulate = color
	pip.offset = Vector2(0,-parent_offset)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	look_at(target.global_position)
	
	
#
#var screen_center = get_viewport_rect().size / 2.
#var direction = relative_pos.normalized();
#var sprite = Sprite2D.new()
#sprite.texture = preload("res://textures/sonar_blip.png")
#sprite.set_position(screen_center + direction * radius)
#sprite.set_rotation(direction.angle() + PI/2.)
#sprite.modulate = modulate_color
#$"..".add_child(sprite)	
#
## make sprite disappear
#var tween = create_tween()
#tween.tween_property(sprite, "modulate", Color(1.,1.,1.,0.), 0.9)
#tween.tween_callback(erase_node.bind(sprite))
