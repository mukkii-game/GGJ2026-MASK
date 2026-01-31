extends Node2D
## ロープ跳ね返り時にロープを少し揺らす。グリッドモード時はマットをグレーに。

const SWAY_PIXELS := 4.0
const SWAY_DURATION := 0.15
const MAT_COLOR_NORMAL := Color(1, 1, 1, 1)
## カクカクモード時はマットをはっきり変える（暗いグレー青）
const MAT_COLOR_GRID := Color(0.4, 0.42, 0.5, 1)
const ROPE_BULGE := 16.0
const PLAYER_RADIUS := 32.0

func _ready() -> void:
	_update_mat_color()

func _process(_delta: float) -> void:
	_update_mat_color()
	_update_rope_bulge()

## 下ロープの基準（プレイヤーが足で触れるように少し上に伸ばしている）
const ROPE_BOTTOM_TOP := 672.0
const ROPE_BOTTOM_BOTTOM := 736.0

func _update_rope_bulge() -> void:
	var player := get_tree().get_first_node_in_group("Player") as Node2D
	var frame := get_node_or_null("RopeFrame") as CanvasLayer
	if not player or not frame:
		return
	var px: float = player.global_position.x
	var py: float = player.global_position.y
	var rope_left := frame.get_node_or_null("RopeLeft") as Control
	var rope_right := frame.get_node_or_null("RopeRight") as Control
	var rope_top := frame.get_node_or_null("RopeTop") as Control
	var rope_bottom := frame.get_node_or_null("RopeBottom") as Control
	# 左ロープ：当たったその先（外側）に膨らむ → offset_left を減らす
	if rope_left:
		rope_left.offset_left = 248.0 - (ROPE_BULGE if px < 280.0 + PLAYER_RADIUS else 0.0)
	# 右ロープ：左と対称に奥側（外側）に膨らむ → offset_right を増やす（手前に膨らまない）
	if rope_right:
		rope_right.offset_left = 1000.0
		rope_right.offset_right = 1032.0 + (ROPE_BULGE if px > 1000.0 - PLAYER_RADIUS else 0.0)
	# 上ロープ：外側（上）に膨らむ。見えるように RopeFrame を手前レイヤーに
	if rope_top:
		rope_top.offset_top = 0.0 - (ROPE_BULGE if py < 32.0 + PLAYER_RADIUS else 0.0)
	# 下ロープ：外側（下）に膨らむ ＋ プレイヤーが視覚的に触れる高さまで伸ばす（offset_top=672, bottom=736）
	if rope_bottom:
		rope_bottom.offset_top = ROPE_BOTTOM_TOP
		rope_bottom.offset_bottom = ROPE_BOTTOM_BOTTOM + (ROPE_BULGE if py > ROPE_BOTTOM_BOTTOM - PLAYER_RADIUS else 0.0)

func _update_mat_color() -> void:
	var white_mat := get_node_or_null("MatBackground/WhiteMat") as ColorRect
	if white_mat:
		white_mat.color = MAT_COLOR_GRID if GameManager.use_grid_mode else MAT_COLOR_NORMAL

## 跳ね返った側を指定してロープを揺らす。side: "left" | "right" | "top" | "bottom"
func sway_rope(side: StringName) -> void:
	var frame := get_node_or_null("RopeFrame") as CanvasLayer
	if not frame:
		return
	var target: Control = null
	var prop: NodePath = NodePath("")
	var base_val: float = 0.0
	match side:
		&"left":
			target = frame.get_node_or_null("RopeLeft") as Control
			prop = NodePath("offset_left")
			base_val = 248.0
		&"right":
			target = frame.get_node_or_null("RopeRight") as Control
			prop = NodePath("offset_left")
			base_val = 1000.0
		&"top":
			target = frame.get_node_or_null("RopeTop") as Control
			prop = NodePath("offset_top")
			base_val = 0.0
		&"bottom":
			target = frame.get_node_or_null("RopeBottom") as Control
			prop = NodePath("offset_top")
			base_val = ROPE_BOTTOM_TOP
		_:
			return
	if not target:
		return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(target, prop, base_val + SWAY_PIXELS, SWAY_DURATION * 0.5)
	tween.tween_property(target, prop, base_val, SWAY_DURATION * 0.5)
