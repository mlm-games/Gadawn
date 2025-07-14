extends Node
class_name Instrument

var bus_idx: int
var instrument_name: String
#TODO: Make a Constants enum with instrument names?
func _init(p_instrument_name: String = ""):
	instrument_name = p_instrument_name
	
	# Each instrument needs to output audio to this bus
	bus_idx = AudioServer.bus_count
	AudioServer.add_bus(bus_idx)

func get_new_player() -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	
	# Defaults go here
	player.bus = AudioServer.get_bus_name(bus_idx)
	add_child(player)
	return player

func play_note(note: Note):
	pass

func stop_note(note: Note):
	pass
