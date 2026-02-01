extends Area2D
## 四隅のコーナーポスト。触れただけで大ジャンプ自動発動（通常ジャンプの長い版・回転あり）。

## 円柱状ポストの上面（半径22の円の天頂。中心が(0,-22)なので天頂は-44）
const POST_TOP_OFFSET := -44.0

func get_top_position() -> Vector2:
	return global_position + Vector2(0, POST_TOP_OFFSET)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	# 四隅どれも同じ処理。見た目はリング上にはみ出るが当たり判定なしで問題ない
	if body.has_method("trigger_corner_post_jump"):
		body.trigger_corner_post_jump()

func _on_body_exited(_body: Node2D) -> void:
	pass
