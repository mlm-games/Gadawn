class_name RulerUI
extends Control

var project: Project

func _draw():
	if not project: return
	
	draw_rect(get_rect(), Color(0.15, 0.15, 0.18))
	
	var beat_duration_sec = 60.0 / project.bpm
	var beat_width_px = beat_duration_sec * project.view_zoom
	
	# Determine subdivision level based on zoom
	var subdivisions = 1
	if beat_width_px > 80: subdivisions = 4
	elif beat_width_px > 40: subdivisions = 2
	
	var sub_beat_width_px = beat_width_px / subdivisions
	
	for i in range(int(get_rect().size.x / sub_beat_width_px)):
		var x = i * sub_beat_width_px
		var line_height = 10
		var color = Color(0.5, 0.5, 0.5)
		
		if i % (subdivisions * 4) == 0: # Full measure (4/4)
			line_height = 30
			color = Color(0.9, 0.9, 0.9)
			var measure_num = i / (subdivisions * 4) + 1
			draw_string(get_theme_font("normal", "Label"), Vector2(x + 4, 20), str(measure_num))
		elif i % subdivisions == 0: # Beat
			line_height = 20
			color = Color(0.7, 0.7, 0.7)
			
		draw_line(Vector2(x, 30), Vector2(x, 30 - line_height), color)
