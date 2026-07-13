extends State
class_name EnemyFleeState

## ステージ2ボス「マスクメロンナ」専用：スピーディに距離を取る。被弾で超高速離脱。ジャンプ中は鈍足。

@export var move_speed: float = 440.0
@export var flee_distance: float = 220.0  # プレイヤーがこの距離内に入ったら逃げる
@export var super_flee_speed: float = 1400.0  # 被弾後の超高速

var owner_node: EnemyMain

func Enter():
	owner_node = owner as EnemyMain
	if owner_node and owner_node.sprite:
		owner_node.sprite.play("walk")

func Update(_delta: float):
	if not owner_node or owner_node.is_dead:
		return
	
	var player: CharacterBase = _find_player()
	if not player:
		if owner_node.fsm:
			owner_node.fsm.change_state(self, "enemy_idle_state")
		return
	
	if "is_jumping" in player and player.is_jumping:
		owner_node.velocity = Vector2.ZERO
		if owner_node.sprite:
			owner_node.sprite.play("idle")
		return
	
	var to_player := player.global_position - owner_node.global_position
	var distance := to_player.length()
	
	# 逃走ボスは怒りで加速させない（追いつけなくなるため）。弱りの減速だけ適用
	var speed := move_speed * minf(1.0, owner_node.state_speed_mult())
	if owner_node.super_flee_remaining > 0.0:
		speed = super_flee_speed
	
	if distance < flee_distance:
		var flee_dir := -to_player.normalized()
		owner_node.velocity = flee_dir * speed
		if owner_node.sprite:
			owner_node.sprite.play("walk")
			owner_node.sprite.flip_h = flee_dir.x < 0
	else:
		owner_node.velocity = Vector2.ZERO
		if owner_node.sprite:
			owner_node.sprite.play("idle")
	
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
