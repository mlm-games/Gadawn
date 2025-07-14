extends Instrument
class_name LiveSynthesisInstrument

var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var mix_rate: float

var t := 0.0

func _init(p_instrument_name: String = "", p_mix_rate: float = 44100.0):
	super(p_instrument_name)
	mix_rate = p_mix_rate

func _ready():
	player = get_new_player()
	var stream = AudioStreamGenerator.new()
	stream.buffer_length = 0.04
	stream.mix_rate = mix_rate
	player.stream = stream

func _process(_delta):
	if player.playing:
		_fill_buffer()

func _fill_buffer():
	var buffer = PackedVector2Array()
	playback = player.get_stream_playback()
	for _i in playback.get_frames_available():
		buffer.append(Vector2.ONE * waveform(t))
		t += 1 / mix_rate

	playback.push_buffer(buffer)

func waveform(_t: float) -> float:
	return 0.0

func play_note(_note: Note):
	_fill_buffer()
	player.play()

func stop_note(_note: Note):
	player.stop()
	await player.finished
	playback.clear_buffer()
