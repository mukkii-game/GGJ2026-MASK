extends State
class_name enemy_ring_in_state

## 右端か左端から走る速度で入場。ロープの少し手前で大きくジャンプして狙った位置に着地
const MAT_LEFT := 296.0
const MAT_RIGHT := 984.0
const MAT_TOP := 106.0
const MAT_BOTTOM := 614.0
## 普通の走り程度の速度
const RING_IN_RUN_SPEED := 180.0
## ロープの少し手前でジャンプ開始（マット端より外側の距離）
const ROPE_MARGIN := 55.0
## ジャンプは少し遅め（着地まで時間多め）
const RING_JUMP_DURATION := 1.35
const RING_JUMP_HEIGHT := 140.0

var body: CharacterBody2D
var enemy_main: EnemyMain
var body_shape: CollisionShape2D
var sprite_node: Node2D
var _saved_collision_layer: int = 1

enum Phase { Run, Jump }
var phase: Phase = Phase.Run
var jump_time: float = 0.0
var jump_start: Vector2
var jump_target: Vector2
## true＝右端から（左へ走る）、false＝左端から（右へ走る）
var _from_right: bool = true

func Enter() -> void:
	body = get_parent().get_parent() as CharacterBody2D
	enemy_main = body as EnemyMain
	if not body or not enemy_main:
		state_transition.emit(self, "enemy_idle_state")
		return
	body_shape = body.get_node_or_null("BodyCollider") as CollisionShape2D
	sprite_node = enemy_main.sprite if enemy_main else body.get_node_or_null("AnimatedSprite2D")
	# 着地するまで当たり判定なし（演出のみ・敵として認識しない）
	_saved_collision_layer = body.collision_layer
	body.collision_layer = 0
	if body_shape:
		body_shape.disabled = true
	body.collision_mask = 1
	body.z_index = 100
	phase = Phase.Run
	jump_time = 0.0
	var center_x := (MAT_LEFT + MAT_RIGHT) * 0.5
	_from_right = body.global_position.x > center_x
	jump_target = enemy_main.ring_in_landing_pos
	if jump_target == Vector2.ZERO:
		jump_target = Vector2(center_x, (MAT_TOP + MAT_BOTTOM) * 0.5)
	if enemy_main and enemy_main.sprite:
		enemy_main.sprite.animation = "Walk"

func Exit() -> void:
	# リングに降り立ったので敵として認識（当たり判定を復帰）
	body.collision_layer = _saved_collision_layer
	if body_shape and is_instance_valid(body_shape):
		body_shape.disabled = false
	body.collision_mask = 3
	body.z_index = 0
	if sprite_node and is_instance_valid(sprite_node):
		sprite_node.position.y = 0.0

func Update(delta: float) -> void:
	if not body or not enemy_main:
		return
	if GameManager.enemies_frozen:
		body.velocity = Vector2.ZERO
		body.move_and_slide()
		return

	if phase == Phase.Run:
		# ロープの少し手前で止まって大きくジャンプ開始
		if _from_right:
			if body.global_position.x <= MAT_RIGHT + ROPE_MARGIN:
				_start_jump()
				return
			body.velocity = Vector2(-RING_IN_RUN_SPEED, 0.0)
		else:
			if body.global_position.x >= MAT_LEFT - ROPE_MARGIN:
				_start_jump()
				return
			body.velocity = Vector2(RING_IN_RUN_SPEED, 0.0)
		body.move_and_slide()
		return

	# Phase.Jump: 放物線で狙った位置①に着地
	jump_time += delta
	var t: float = jump_time / RING_JUMP_DURATION
	if t >= 1.0:
		body.global_position = jump_target
		if sprite_node:
			sprite_node.position.y = 0.0
		state_transition.emit(self, "enemy_idle_state")
		return
	var horizontal_pos := jump_start.lerp(jump_target, t)
	body.global_position = horizontal_pos
	var jump_offset: float = 4.0 * RING_JUMP_HEIGHT * t * (1.0 - t)
	if sprite_node and is_instance_valid(sprite_node):
		sprite_node.position.y = -jump_offset
	body.velocity = Vector2.ZERO

func _start_jump() -> void:
	phase = Phase.Jump
	jump_start = body.global_position
	jump_time = 0.0
	body.velocity = Vector2.ZERO
	# 当たり判定はEnterで既に無効のまま
	body.collision_mask = 1
	body.z_index = 100
