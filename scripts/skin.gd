extends Node2D

var skins_material : ShaderMaterial
func set_burn_percentage(percentage: float) -> void:
	skins_material.set_shader_parameter("burn_percentage", percentage)

func set_team_color(color: Color) -> void:
	skins_material.set_shader_parameter("team_color", color)

func set_skins_material(mat: ShaderMaterial) -> void:
	skins_material = mat
	for c in get_children():
		c.material = mat

func init_skin(skin_layers: Array[BattleShipSkin], team_color: Color) -> void:
	# Remove placeholders
	for c in get_children():
		c.queue_free()

	# Add a Sprite for each layer of skin
	skins_material = preload("res://resources/implode_effect.tres").duplicate()
	for layer in skin_layers.size():
		var layer_image = Sprite2D.new()
		layer_image.set_texture(skin_layers[layer].texture)
		layer_image.material = skins_material
		layer_image.material.set_shader_parameter("team_color", team_color)
		layer_image.scale = skin_layers[layer].scale
		layer_image.set_rotation(skin_layers[layer].rotation)
		layer_image.z_index = skin_layers[layer].z_index
		add_child(layer_image)
