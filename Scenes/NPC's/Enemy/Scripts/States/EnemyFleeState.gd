extends State
class_name EnemyFleeState

## ステージ2ボス「マスクメロンナ」専用：プレイヤーから逃げる

@export var move_speed := 600.0
@export var flee_distance := 200.0  # プレイヤーがこの距離内に入ったら逃げる

var owner_node: EnemyMain

func Enter():
	owner_node = owner as EnemyMain
	if owner_node and owner_node.sprite:
		owner_node.sprite.play("walk")

func Update(_delta: float):
	if not owner_node or owner_node.is_dead:
		return
	
	# プレイヤーを探す
	var player: CharacterBase = _find_player()
	if not player:
		# プレイヤーが見つからない場合は待機
		if owner_node.fsm:
			owner_node.fsm.change_state(self, "enemy_idle_state")
		return
	
	# プレイヤーがジャンプ中は停止（きょろきょろアニメーション）
	if "is_jumping" in player and player.is_jumping:
		owner_node.velocity = Vector2.ZERO
		if owner_node.sprite:
			owner_node.sprite.play("idle")
		return
	
	# プレイヤーとの距離を計算
	var to_player := player.global_position - owner_node.global_position
	var distance := to_player.length()
	
	# 逃走距離より近い場合、逃げる
	if distance < flee_distance:
		# プレイヤーから離れる方向に逃げる
		var flee_dir := -to_player.normalized()
		owner_node.velocity = flee_dir * move_speed
		
		# スプライトの向きを設定
		if owner_node.sprite:
			owner_node.sprite.play("walk")
			if flee_dir.x < 0:
				owner_node.sprite.flip_h = true
			elif flee_dir.x > 0:
				owner_node.sprite.flip_h = false
	else:
		# 十分離れたら待機
		owner_node.velocity = Vector2.ZERO
		if owner_node.sprite:
			owner_node.sprite.play("idle")
	
	# 速度を適用
	if owner_node.velocity.length() > 0:
		owner_node.move_and_slide()

func Exit():
	if owner_node:
		owner_node.velocity = Vector2.ZERO

func _find_player() -> CharacterBase:
	var players := get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		return players[0] as CharacterBase
	return null
