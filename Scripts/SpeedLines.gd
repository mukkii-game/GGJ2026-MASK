extends Node2D
## 走り中に表示する高架線風スピードライン（速度感アップ）

const LINE_COLOR := Color(1.0, 0.98, 0.85, 0.5)
const LINE_WIDTH := 2.0
const LINE_LENGTH := 28.0
const LINE_SPACING := 8.0
const LINE_COUNT := 5
const TILT := 0.15  # 線の傾き（ラジアン）

var _player_main: PlayerMain

func _ready() -> void:
	_player_main = get_parent() as PlayerMain
	visible = false
	z_index = -3

func _process(_delta: float) -> void:
	if not _player_main:
		return
	visible = _player_main.is_run_dashing
	if visible and _player_main.run_dash_direction.length_squared() > 0.01:
		# 進行方向の逆を向く（線は後方に流れる＝高架線風）
		var dir := _player_main.run_dash_direction.normalized()
		rotation = dir.angle() + PI
		queue_redraw()

func _draw() -> void:
	# 高架線風：水平に近い複数本の線（キャラ背後側に伸ばす）
	var base_dir := Vector2.RIGHT.rotated(rotation)
	var perp := Vector2(-base_dir.y, base_dir.x)
	for i in LINE_COUNT:
		var offset_y := (float(i) - LINE_COUNT * 0.5) * LINE_SPACING
		var start_p := perp * offset_y
		var end_p := start_p + base_dir * (LINE_LENGTH + i * 3.0)
		draw_line(start_p, end_p, LINE_COLOR, LINE_WIDTH)

