extends Node2D
## アリーナマット：
## - カクカクモード時にマット色を変更
## - ロープヒット時にロープを外側に「たわませる」演出を行う

@onready var mat_rect: ColorRect = get_node_or_null("MatBackground/MatColor")
@onready var rope_left: ColorRect = get_node_or_null("RopeFrameBack/RopeLeft")
@onready var rope_right: ColorRect = get_node_or_null("RopeFrameBack/RopeRight")

const ROPE_BEND_OFFSET := 8.0
const ROPE_BEND_TIME_OUT := 0.06
const ROPE_BEND_TIME_BACK := 0.10

var _left_orig_left: float
var _left_orig_right: float
var _right_orig_left: float
var _right_orig_right: float
var _left_tween: Tween
var _right_tween: Tween

func _ready() -> void:
	if rope_left:
		_left_orig_left = rope_left.offset_left
		_left_orig_right = rope_left.offset_right
	if rope_right:
		_right_orig_left = rope_right.offset_left
		_right_orig_right = rope_right.offset_right

func _process(_delta: float) -> void:
	if mat_rect:
		# カクカクモード時：マットを黒に近いグレーに
		if GameManager.use_grid_mode:
			mat_rect.color = Color(0.15, 0.15, 0.15, 1.0)  # 黒に近いグレー
		else:
			mat_rect.color = Color.WHITE

## プレイヤーがロープにヒットしたときに呼ぶ。side: "left" / "right"
func bend_rope(side: String) -> void:
	if side == "left":
		_bend_left()
	elif side == "right":
		_bend_right()

func _bend_left() -> void:
	if not rope_left:
		return
	if _left_tween and _left_tween.is_valid():
		_left_tween.kill()
	rope_left.offset_left = _left_orig_left
	rope_left.offset_right = _left_orig_right
	var out := -ROPE_BEND_OFFSET  # 左外側へ
	var t := create_tween()
	_left_tween = t
	t.tween_property(rope_left, "offset_left", _left_orig_left + out, ROPE_BEND_TIME_OUT)
	t.parallel().tween_property(rope_left, "offset_right", _left_orig_right + out, ROPE_BEND_TIME_OUT)
	t.tween_property(rope_left, "offset_left", _left_orig_left, ROPE_BEND_TIME_BACK)
	t.parallel().tween_property(rope_left, "offset_right", _left_orig_right, ROPE_BEND_TIME_BACK)

func _bend_right() -> void:
	if not rope_right:
		return
	if _right_tween and _right_tween.is_valid():
		_right_tween.kill()
	rope_right.offset_left = _right_orig_left
	rope_right.offset_right = _right_orig_right
	var out := ROPE_BEND_OFFSET  # 右外側へ
	var t := create_tween()
	_right_tween = t
	t.tween_property(rope_right, "offset_left", _right_orig_left + out, ROPE_BEND_TIME_OUT)
	t.parallel().tween_property(rope_right, "offset_right", _right_orig_right + out, ROPE_BEND_TIME_OUT)
	t.tween_property(rope_right, "offset_left", _right_orig_left, ROPE_BEND_TIME_BACK)
	t.parallel().tween_property(rope_right, "offset_right", _right_orig_right, ROPE_BEND_TIME_BACK)
