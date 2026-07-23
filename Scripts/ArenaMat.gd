extends Node2D
## アリーナマット：ロープヒット時にロープを外側に「たわませる」演出を行う

@onready var mat_rect: ColorRect = get_node_or_null("MatBackground/MatColor")
@onready var rope_left: ColorRect = get_node_or_null("RopeFrameBack/RopeLeft1")
@onready var rope_right: ColorRect = get_node_or_null("RopeFrameBack/RopeRight1")
@onready var rope_top: ColorRect = get_node_or_null("RopeFrameBack/RopeTop")
@onready var rope_bottom: ColorRect = get_node_or_null("RopeBottom/BottomRect")

const ROPE_BEND_OFFSET := 8.0
const ROPE_BEND_TIME_OUT := 0.06
const ROPE_BEND_TIME_BACK := 0.10

var _left_orig_left: float
var _left_orig_right: float
var _right_orig_left: float
var _right_orig_right: float
var _top_orig_top: float
var _top_orig_bottom: float
var _bottom_orig_top: float
var _bottom_orig_bottom: float
var _left_tween: Tween
var _right_tween: Tween
var _top_tween: Tween
var _bottom_tween: Tween

## 下部ロープはキャラより手前（通常ジャンプ含む）。上部ロープは奥寄り。
const ROPE_BOTTOM_Z := 1800
const ROPE_TOP_Z := 155

func _ready() -> void:
	_setup_rope_draw_layers()
	if rope_left:
		_left_orig_left = rope_left.offset_left
		_left_orig_right = rope_left.offset_right
	if rope_right:
		_right_orig_left = rope_right.offset_left
		_right_orig_right = rope_right.offset_right
	if rope_top:
		_top_orig_top = rope_top.offset_top
		_top_orig_bottom = rope_top.offset_bottom
	if rope_bottom:
		_bottom_orig_top = rope_bottom.offset_top
		_bottom_orig_bottom = rope_bottom.offset_bottom

## ring_bg にロープが焼き付いているため、重ね描きで前後関係を補正する
func _setup_rope_draw_layers() -> void:
	var bottom := get_node_or_null("RopeBottom") as Node2D
	if bottom:
		bottom.visible = true
		bottom.z_as_relative = false
		bottom.z_index = ROPE_BOTTOM_Z
	var frame := get_node_or_null("RopeFrameBack") as Node2D
	if frame:
		frame.visible = true
		frame.z_as_relative = false
		frame.z_index = ROPE_TOP_Z
		# 左右は背景絵のまま。上部3本だけ手前／奥の補正に使う
		for n in ["RopeLeft1", "RopeLeft2", "RopeLeft3", "RopeRight1", "RopeRight2", "RopeRight3"]:
			var side := frame.get_node_or_null(n) as CanvasItem
			if side:
				side.visible = false

func _process(_delta: float) -> void:
	if mat_rect:
		mat_rect.color = Color.WHITE

## プレイヤーがロープにヒットしたときに呼ぶ。side: "left" / "right" / "top" / "bottom"
func bend_rope(side: String) -> void:
	match side:
		"left":
			_bend_horizontal(rope_left, _left_orig_left, _left_orig_right, true, "_left_tween")
		"right":
			_bend_horizontal(rope_right, _right_orig_left, _right_orig_right, false, "_right_tween")
		"top":
			_bend_vertical(rope_top, _top_orig_top, _top_orig_bottom, true, "_top_tween")
		"bottom":
			_bend_vertical(rope_bottom, _bottom_orig_top, _bottom_orig_bottom, false, "_bottom_tween")

func _bend_horizontal(rect: ColorRect, orig_l: float, orig_r: float, is_left: bool, tween_var: String) -> void:
	if not rect:
		return
	var existing: Tween = get(tween_var)
	if existing and existing.is_valid():
		existing.kill()
	rect.offset_left = orig_l
	rect.offset_right = orig_r
	var out := -ROPE_BEND_OFFSET if is_left else ROPE_BEND_OFFSET
	var t := create_tween()
	set(tween_var, t)
	t.tween_property(rect, "offset_left", orig_l + out, ROPE_BEND_TIME_OUT)
	t.parallel().tween_property(rect, "offset_right", orig_r + out, ROPE_BEND_TIME_OUT)
	t.tween_property(rect, "offset_left", orig_l, ROPE_BEND_TIME_BACK)
	t.parallel().tween_property(rect, "offset_right", orig_r, ROPE_BEND_TIME_BACK)

func _bend_vertical(rect: ColorRect, orig_top: float, orig_bottom: float, is_top: bool, tween_var: String) -> void:
	if not rect:
		return
	var existing: Tween = get(tween_var)
	if existing and existing.is_valid():
		existing.kill()
	rect.offset_top = orig_top
	rect.offset_bottom = orig_bottom
	var out := -ROPE_BEND_OFFSET if is_top else ROPE_BEND_OFFSET
	var t := create_tween()
	set(tween_var, t)
	t.tween_property(rect, "offset_top", orig_top + out, ROPE_BEND_TIME_OUT)
	t.parallel().tween_property(rect, "offset_bottom", orig_bottom + out, ROPE_BEND_TIME_OUT)
	t.tween_property(rect, "offset_top", orig_top, ROPE_BEND_TIME_BACK)
	t.parallel().tween_property(rect, "offset_bottom", orig_bottom, ROPE_BEND_TIME_BACK)
