extends Control
func _draw() -> void:
	for p in [Vector2(4,0),Vector2(0,4)]:
		draw_line(-p,p,Color(0,0,0,.65),3)
		draw_line(-p,p,Color(.88,.88,.80,.76),1)
