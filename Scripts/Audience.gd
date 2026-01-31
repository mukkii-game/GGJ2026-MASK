extends Node2D
## グリッドモード時は観客の顔を青くする（モードがわかりやすいように）

const COLOR_NORMAL := Color(1, 1, 1, 1)
const COLOR_GRID := Color(0.45, 0.65, 1.0, 1)  # 青っぽく

func _process(_delta: float) -> void:
	var mod: Color = COLOR_GRID if GameManager.use_grid_mode else COLOR_NORMAL
	var left := get_node_or_null("Left") as CanvasItem
	var right := get_node_or_null("Right") as CanvasItem
	if left:
		left.modulate = mod
	if right:
		right.modulate = mod
