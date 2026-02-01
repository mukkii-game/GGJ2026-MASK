extends Node2D
## デバッグ用：体当たり判定の正方形を表示

var player: PlayerMain

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player") as PlayerMain
	# デフォルトで非表示
	visible = false

func _process(_delta: float) -> void:
	if not visible or not player:
		return
	queue_redraw()

func _draw() -> void:
	if not player:
		return
	# プレイヤーの体当たり判定を描画
	var half := player.BODY_CONTACT_HALF
	draw_rect(Rect2(player.global_position - Vector2(half, half), Vector2(half * 2, half * 2)), Color(1, 0, 0, 0.3))
	
	# 敵の体当たり判定を描画
	for node in get_tree().get_nodes_in_group("Enemy"):
		var enemy = node as CharacterBase
		if is_instance_valid(enemy) and not enemy.is_dead:
			draw_rect(Rect2(enemy.global_position - Vector2(half, half), Vector2(half * 2, half * 2)), Color(0, 1, 0, 0.3))
