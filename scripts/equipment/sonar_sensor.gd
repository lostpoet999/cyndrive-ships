extends ShapeCast2D

@export var rotation_speed: float = 0.005
@export var blip_radius: float = 100.

@onready var display_node: ColorRect = get_node("/root/battle/GUI/sonar_display")

var direct_control: bool = false
var blips: Dictionary = {}

func set_manual_rotation(rad: float) -> void:
	direct_control = true
	set_global_rotation(rad)

func _process(_delta: float) -> void:
	if !direct_control: set_global_rotation(get_global_rotation() + rotation_speed)
	display_node.set_display_rotation(get_global_rotation())
	
func _physics_process(_delta: float) -> void:
	force_shapecast_update()
	for i in range(get_collision_count()):
		var collider = get_collider(i)
		#prevent re-firing on each tick while colliding remains true
		if not blips.has(collider.get_instance_id()) or null == blips[collider.get_instance_id()]:
			blips[collider.get_instance_id()] = add_blip(collider) 
			continue
		blips[collider.get_instance_id()].reinvigorate()

func add_blip(collider: Object) -> Node2D:
	if collider.has_node("team"):
		var coll_color = collider.get_node("team").color
		if collider.get_node("team").team_id == 0: # team zero is the player!
			coll_color = Color.LIME
		return display_node.add_display_object(self, blip_radius, collider, coll_color)
	else:
		return display_node.add_display_object(self, blip_radius, collider, Color.WEB_GRAY)
