class_name Wave extends Node2D

var data: PackedByteArray = PackedByteArray([]):
	set(val): set_data(val)
var zero: Color = Color.BLACK:
	set(val): set_zero(val)
var wave_color: Color = Color.GREEN_YELLOW:
	set(val): set_wave(val)

func _init(audio: AudioStreamWAV):
	data = audio.data
	queue_redraw()

func set_data(value: PackedByteArray):
	data = value
	queue_redraw()

func set_zero(value: Color):
	zero = value
	queue_redraw()

func set_wave(value: Color):
	wave_color = value
	queue_redraw()

func sign_extend(value, bits):
	var sign_bit = 1 << (bits - 1)
	return (value & (sign_bit - 1)) - (value & sign_bit)


func _draw():
	var start = Vector2(0, 0)
	draw_line(Vector2.ZERO, Vector2(5000, 0), zero, 5)
	for i in data.size():
		var end = Vector2(start.x + (10 * i / float(data.size())), sign_extend(-data[i], 8))
		draw_line(start, end, wave_color, 2)
		start = end
