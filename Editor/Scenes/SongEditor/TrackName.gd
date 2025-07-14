extends Button

func _ready() -> void:
	%DeleteConfirm.confirmed.connect(queue_free)

func set_instrument(icon: Texture, instrument_name: String) -> void:
	icon = icon
	text = instrument_name
	if instrument_name.length() > 20:
		text = instrument_name.substr(0, 17) + "..."
