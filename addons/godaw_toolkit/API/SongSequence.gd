class_name SongSequence extends Resource

#Tempo in bpm
@export var tracks: Array = []
@export var tempo: int = 0
@export var master_pitch: int = 1
@export var master_volume: int = linear_to_db(0.5):
	set(val): set_volume(val)

func set_volume(val: int):
	master_volume = linear_to_db(val)

func add_track(val: Track):
	tracks.append(val)
