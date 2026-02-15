extends Node2D
## デバッグ用：体当たり判定の正方形を表示。トレーニングモード時は常時表示（線のみ）。

var player: PlayerMain

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player") as PlayerMain
	# トレーニングモードなら常時表示、それ以外は非表示
	visible = GameManager.training_mode

func _process(_delta: float) -> void:
	if GameManager.training_mode:
		visible = true
		if not player:
			player = get_tree().get_first_node_in_group("Player") as PlayerMain
	elif not visible:
		return
	if not player:
		return
	queue_redraw()

func _draw() -> void:
	if not player:
		return
	var half := player.BODY_CONTACT_HALF
	var use_lines := GameManager.training_mode  # トレーニング時は線のみ
	var line_width := 2.0
	
	for node in get_tree().get_nodes_in_group("Enemy"):
		var enemy = node as CharacterBase
		if is_instance_valid(enemy) and not enemy.is_dead:
			var pos := to_local(enemy.global_position)
			var r := Rect2(pos - Vector2(half, half), Vector2(half * 2, half * 2))
			if use_lines:
				_draw_rect_outline(r, Color(0, 1, 0, 1), line_width)
			else:
				draw_rect(r, Color(0, 1, 0, 0.3))
	
	var p_pos := to_local(player.global_position)
	var pr := Rect2(p_pos - Vector2(half, half), Vector2(half * 2, half * 2))
	if use_lines:
		_draw_rect_outline(pr, Color(1, 0, 0, 1), line_width)
	else:
		draw_rect(pr, Color(1, 0, 0, 0.3))

func _draw_rect_outline(rect: Rect2, color: Color, width: float) -> void:
	var w := width
	draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), color)
	draw_line(rect.position + Vector2(rect.size.x, 0), rect.position + rect.size, color)
	draw_line(rect.position + rect.size, rect.position + Vector2(0, rect.size.y), color)
	draw_line(rect.position + Vector2(0, rect.size.y), rect.position, color)
