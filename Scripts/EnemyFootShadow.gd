extends Node2D
## 敵の足元に表示される横長楕円の影。これが本体位置。

func _ready() -> void:
	z_index = -5

func _process(_delta: float) -> void:
	# 影は常に親（敵）の位置に追従（本体＝影の位置）
	var parent = get_parent()
	if parent:
		global_position = parent.global_position
	queue_redraw()

func _draw() -> void:
	# 横長楕円の影を描画（黒、半透明）適度なサイズ
	var shadow_width := 33.0  # 横幅（元の2/3）
	var shadow_height := 11.0  # 縦幅（元の2/3）
	var y_offset := 28.0  # キャラの1/4くらい下
	
	# 楕円を描画（複数の円を横に並べて楕円に見せる）
	for i in range(-int(shadow_width), int(shadow_width) + 1, 2):
		var x := float(i)
		var height_at_x := shadow_height * sqrt(max(0.0, 1.0 - (x * x) / (shadow_width * shadow_width)))
		if height_at_x > 0.5:
			draw_circle(Vector2(x, y_offset), height_at_x * 0.5, Color(0, 0, 0, 0.5))
