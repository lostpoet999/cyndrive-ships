extends Node2D

var pewpew: bool = false
var pewpew_ready: bool = false
var target_position: Vector2 = Vector2()
func process_input_action(action: Dictionary) -> void:
	if "pewpew" in action:
		target_position = action["pewpew"]
		pewpew = true
		pewpew_ready = false

func _physics_process(_delta):
	if pewpew:
		$beam_line.points[0] = get_global_position()
		$beam_line.points[1] = get_global_position() + (target_position - get_global_position()) * 5000.
		var space_state = get_world_2d().direct_space_state
		var laser_raycast_result = space_state.intersect_ray(PhysicsRayQueryParameters2D.create(
			get_global_position(), $beam_line.points[1]
		))
		if laser_raycast_result.has("collider"):
			$sound.play()
			var victim = laser_raycast_result.collider
			if victim.has_method("accept_damage"):
				victim.accept_damage(1.)
			$beam_line.points[1] = laser_raycast_result.position
		var tween = create_tween()
		tween.tween_property($beam_line, "width", 20, 0.05)
		tween.tween_property($beam_line, "width", 0, 0.07)
		tween.chain()
		pewpew = false
	
