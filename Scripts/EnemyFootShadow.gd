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
	var parent := get_parent() as CharacterBase
	var is_downed: bool = parent != null and parent.has_method("is_in_down_state") and parent.is_in_down_state()

	# 横長楕円の影を描画（黒、半透明）
	# ダウン中は倒れた身体に合わせて影を横長にして接地感を出す
	var shadow_width := 44.0 if is_downed else 33.0
	var shadow_height := 14.0 if is_downed else 11.0
	var y_offset := 24.0 if is_downed else 28.0
	
	# 楕円を描画（複数の円を横に並べて楕円に見せる）
	for i in range(-int(shadow_width), int(shadow_width) + 1, 2):
		var x := float(i)
		var height_at_x := shadow_height * sqrt(max(0.0, 1.0 - (x * x) / (shadow_width * shadow_width)))
		if height_at_x > 0.5:
			draw_circle(Vector2(x, y_offset), height_at_x * 0.5, Color(0, 0, 0, 0.5))
