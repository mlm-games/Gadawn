## A wrapper to make AudioStreamPlayers conform to the Instrument interface.
class_name AudioInstrumentWrapper
extends Instrument

var active_players: Dictionary = {} # Track active players by event reference
var player_pool: Array[AudioStreamPlayer] = []
var pool_size: int = 18 #TODO: Dynamically increase like nanobot's survival

func _ready():
	# Create a pool of players for polyphony
	for i in range(pool_size):
		var player = AudioStreamPlayer.new()
		player.name = "AudioPlayer_" + str(i)
		add_child(player)
		player.finished.connect(_on_player_finished.bind(player))
		player_pool.append(player)

func play_event(event: TrackEvent):
	if event is AudioClipEvent and event.audio_stream:
		# Find an available player
		var player = _get_available_player()
		if not player:
			push_warning("No available audio players for clip")
			return
		
		active_players[event] = player
		player.stream = event.audio_stream
		player.volume_db = event.volume_db
		player.play()

func stop_event(event: TrackEvent):
	if event is AudioClipEvent and active_players.has(event):
		var player = active_players[event]
		player.stop()
		active_players.erase(event)

func set_volume(volume_db: float):
	for player in player_pool:
		player.volume_db = volume_db
	
func all_notes_off():
	for player in player_pool:
		player.stop()
	active_players.clear()

func _get_available_player() -> AudioStreamPlayer:
	for player in player_pool:
		if not player.playing:
			return player
	# If all are playing, return the first one (will cut it off)
	return player_pool[0]

func _on_player_finished(player: AudioStreamPlayer):
	# Remove from active players
	var keys_to_remove = []
	for event in active_players:
		if active_players[event] == player:
			keys_to_remove.append(event)
	for key in keys_to_remove:
		active_players.erase(key)
