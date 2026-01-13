extends CanvasLayer
@onready var panel = $PanelContainer
func _ready() -> void:
	if FeatureFlags.is_enabled('dialogue'):
		self.visible = true
	else: 
		self.visible = false
