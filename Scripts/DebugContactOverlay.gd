extends Node2D
## 体当たりデバッグ用：当たり判定の枠・接触時は別色・頭上の移動方向矢印を表示する（PC-88風正方形）

## プレイヤーと同一の接触半幅（PlayerMain.BODY_CONTACT_HALF＝40、1辺80の正方形、scale 1.25考慮）
const CONTACT_HALF := 40.0
## 通常時の枠色（薄い緑）
const COLOR_NORMAL := Color(0.2, 1.0, 0.3, 0.6)
## 接触中の枠色（目立つオレンジ）
const COLOR_TOUCHING := Color(1.0, 0.4, 0.0, 0.9)
## 矢印の長さ
const ARROW_LENGTH := 28.0
## 矢印の頭のサイズ
const ARROW_HEAD := 12.0
## 頭上のオフセット（Y上方向）
const HEAD_OFFSET := -48.0

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var player := get_tree().get_first_node_in_group("Player") as Node2D
	if not player:
		return
	var bodies: Array[Node2D] = []
	bodies.append(player)
	for node in get_tree().get_nodes_in_group("Enemy"):
		var n := node as Node2D
		if is_instance_valid(n) and n is CharacterBody2D:
			var cb := n as CharacterBase
			if not cb.is_dead:
				bodies.append(n)
	# 誰が誰と接触しているか
	var touching: Dictionary = {} # index -> true if this body is in contact with any other
	for i in bodies.size():
		touching[i] = false
	for i in bodies.size():
		for j in bodies.size():
			if i >= j:
				continue
			var a: Node2D = bodies[i]
			var b: Node2D = bodies[j]
			var pa := a.global_position
			var pb := b.global_position
			if absf(pa.x - pb.x) <= 2.0 * CONTACT_HALF and absf(pa.y - pb.y) <= 2.0 * CONTACT_HALF:
				touching[i] = true
				touching[j] = true
	# 描画（正方形コリジョン）
	for i in bodies.size():
		var body: Node2D = bodies[i]
		var pos: Vector2 = to_local(body.global_position)
		var col: Color = COLOR_TOUCHING if touching[i] else COLOR_NORMAL
		var h := CONTACT_HALF
		var rect := Rect2(pos.x - h, pos.y - h, 2.0 * h, 2.0 * h)
		draw_rect(rect, col, false)
		# 接触時だけ頭上に移動方向の矢印
		if touching[i] and body is CharacterBody2D:
			var vel: Vector2 = (body as CharacterBody2D).velocity
			var head_pos := pos + Vector2(0, HEAD_OFFSET)
			if vel.length_squared() > 1.0:
				var dir := vel.normalized()
				var tip := head_pos + dir * ARROW_LENGTH
				draw_line(head_pos, tip, Color(1, 1, 0, 1))
				# 矢印の頭（三角）
				var perp := Vector2(-dir.y, dir.x)
				var back := tip - dir * ARROW_HEAD
				var arrow_head_points: PackedVector2Array = [tip, back + perp * 6, back - perp * 6]
				draw_polygon(arrow_head_points, [Color(1, 1, 0, 1)])
			else:
				# 止まっているときは小さい丸
				draw_arc(head_pos, 4.0, 0.0, TAU, 12, Color(0.8, 0.8, 0, 1))
