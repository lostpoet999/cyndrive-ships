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
	## make sprite disappear
	var tween = create_tween()
	tween.tween_property(pip, "modulate", Color(1.,1.,1.,0.), 0.9)
	tween.finished.connect(queue_free)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	look_at(target.global_position)
