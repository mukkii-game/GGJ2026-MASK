extends Node2D
## 観客1人：普通の男女の頭と肩（目なし）。2パターン・2フレーム繰り返しアニメ。

@export var type_index: int = 0  ## 0=男 1=女（色の違い）
@export var head_radius_x: float = 14.0
@export var head_radius_y: float = 16.0
@export var shoulder_width: float = 28.0
@export var shoulder_height: float = 12.0

var _anim_time: float = 0.0
const ANIM_PERIOD := 0.4

const COLOR_MALE_HEAD := Color(1.05, 0.92, 0.85, 1)
const COLOR_MALE_SHOULDER := Color(0.35, 0.45, 0.6, 1)
const COLOR_FEMALE_HEAD := Color(1.0, 0.88, 0.9, 1)
const COLOR_FEMALE_SHOULDER := Color(0.6, 0.4, 0.5, 1)

func _process(delta: float) -> void:
	_anim_time += delta
	if _anim_time >= ANIM_PERIOD * 2.0:
		_anim_time = fmod(_anim_time, ANIM_PERIOD * 2.0)
	queue_redraw()

func _draw() -> void:
	var head_color: Color = COLOR_MALE_HEAD if type_index == 0 else COLOR_FEMALE_HEAD
	var shoulder_color: Color = COLOR_MALE_SHOULDER if type_index == 0 else COLOR_FEMALE_SHOULDER
	# 2フレームアニメ：わずかに上下
	var frame: int = 1 if fmod(_anim_time, ANIM_PERIOD * 2.0) >= ANIM_PERIOD else 0
	var bounce: float = 2.0 if frame == 1 else 0.0
	# 肩（下の四角）
	draw_rect(Rect2(-shoulder_width / 2, bounce + 4, shoulder_width, shoulder_height), shoulder_color)
	# 頭（楕円）
	var head_points: PackedVector2Array = []
	var n := 24
	for i in n:
		var a := i * TAU / float(n)
		head_points.append(Vector2(head_radius_x * cos(a), bounce + head_radius_y * sin(a)))
	draw_polygon(head_points, [head_color])
