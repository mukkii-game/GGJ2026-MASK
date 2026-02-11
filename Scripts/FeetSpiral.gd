extends Node2D
## 走り中に足元で回る昔の漫画風うずまき演出

const ROTATE_SPEED := 8.0  # 回転速度（rad/秒）
const SPIRAL_RADIUS := 10.0
const SPIRAL_COLOR := Color(1.0, 0.95, 0.7, 0.65)

var _player_main: PlayerMain

func _ready() -> void:
	_player_main = get_parent() as PlayerMain
	visible = false
	z_index = -2

func _process(delta: float) -> void:
	if not _player_main:
		return
	visible = _player_main.is_run_dashing
	if visible:
		rotation += delta * ROTATE_SPEED

func _draw() -> void:
	# 昔の漫画風：3本の弧でうずまきっぽく
	var n := 3
	for i in n:
		var start_angle := (float(i) / n) * TAU
		var end_angle := start_angle + TAU * 0.7
		draw_arc(Vector2.ZERO, SPIRAL_RADIUS, start_angle, end_angle, 12, SPIRAL_COLOR, 2.0)
