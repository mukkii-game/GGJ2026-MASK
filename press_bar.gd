extends Area2D

@export var bar_speed: float = 300.0
@export var start_x: float = 100.0
@export var end_x: float = 600.0
@export var break_distance: float = 12.0
@export var press_fixed_x: float = 400.0  # Pressの位置（Inspectorで調整）

var bar_pos: float = 0.0

func _ready():
	global_position.x = start_x
	print("Press_Bar移動開始! Press位置:", press_fixed_x)

func _process(delta):
	bar_pos += bar_speed * delta
	global_position.x = start_x + bar_pos
	
	# 固定Press位置との距離チェック
	var distance = abs(press_fixed_x - global_position.x)
	if distance <= break_distance:
		print("💥 BREAK! Bar:", snapped(global_position.x, 0.1), 
			  " Press:", press_fixed_x, "距離:", snapped(distance, 0.1))
		get_tree().paused = true
		return
	
	if bar_pos >= end_x:
		print("Bar時間切れ")
		get_tree().paused = true
