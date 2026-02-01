extends Node2D
## アリーナマット：カクカクモード時に色を変更

@onready var mat_rect = get_node_or_null("MatBackground/MatColor")

func _process(_delta: float) -> void:
	if not mat_rect:
		return
	# カクカクモード時：マットを黒に近いグレーに
	if GameManager.use_grid_mode:
		mat_rect.color = Color(0.15, 0.15, 0.15, 1.0)  # 黒に近いグレー
	else:
		mat_rect.color = Color.WHITE
