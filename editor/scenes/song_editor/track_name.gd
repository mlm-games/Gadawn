extends Button

func _ready() -> void:
	%DeleteConfirm.confirmed.connect(queue_free)

func set_instrument(icon_texture: Texture, instrument_name: String) -> void:
	self.icon = icon_texture
	text = instrument_name
	if instrument_name.length() > 20:
		text = instrument_name.substr(0, 17) + "..."
