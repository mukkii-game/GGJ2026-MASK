extends Area2D
## 四隅のコーナーポスト（Phase A: プレイヤー用は廃止。見た目のみ残す）

@onready var visual = get_node_or_null("Visual") as Polygon2D

func _ready() -> void:
	monitoring = false
	monitorable = false
	if visual:
		visual.color = Color(0.35, 0.35, 0.35, 0.6)

func _on_body_entered(_body: Node2D) -> void:
	pass

func _on_body_exited(_body: Node2D) -> void:
	pass
