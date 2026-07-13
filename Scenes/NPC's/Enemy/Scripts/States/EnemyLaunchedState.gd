extends State
class_name enemy_launched_state

## マット内の着地範囲（確実にマット内に収める）
const MAT_LEFT := 350.0
const MAT_RIGHT := 930.0
const MAT_TOP := 106.0
const MAT_BOTTOM := 614.0
## ロープからの反発ジャンプ（放物線移動）の持続時間（秒）
const LAUNCH_DURATION := 1.2
## ジャンプ弧の見た目の高さ（ピクセル）
const LAUNCH_HEIGHT := 150.0

var body: CharacterBody2D
var enemy_main: CharacterBase
var body_shape: CollisionShape2D
var sprite_node: Node2D
## 飛翔前の collision_layer を退避（Exit で復元）
var _saved_collision_layer: int = 1
## ジャンプ開始からの経過時間
var launch_time: float = 0.0
## 開始位置と目標位置
var start_pos: Vector2
var target_pos: Vector2

func Enter() -> void:
	body = get_parent().get_parent() as CharacterBody2D
	enemy_main = body as CharacterBase
	if not body or not enemy_main:
		state_transition.emit(self, "enemy_idle_state")
		return
	
	# ロープの振動音（PLAYER_ATTACK_SWINGを使用）
	AudioManager.play_sound(AudioManager.PLAYER_ATTACK_SWING, 0, -6)
	
	body.velocity = Vector2.ZERO
	launch_time = 0.0
	
	# 開始位置を記録
	start_pos = body.global_position
	
	# 目標位置：反対側のマットのランダムな位置
	target_pos = _calculate_opposite_position(start_pos)
	
	# 当たり判定なし + ロープの壁をすり抜ける（一変向中は他キャラと当たらない）
	_saved_collision_layer = body.collision_layer
	body.collision_layer = 0
	body_shape = body.get_node_or_null("BodyCollider") as CollisionShape2D
	if body_shape:
		body_shape.disabled = true
	body.z_index = 100
	# コリジョンマスクを1に変更（layer 2のロープ外の壁をすり抜ける）
	body.collision_mask = 1
	sprite_node = enemy_main.sprite if enemy_main else body.get_node_or_null("AnimatedSprite2D")
	
	# Enter時に自分の移動・回転Tweenだけをkillしてリセット（他ノードのTweenは巻き込まない）
	enemy_main.kill_motion_tweens()
	if sprite_node and is_instance_valid(sprite_node):
		# scaleは一切触らない！rotationとpositionだけリセット
		sprite_node.rotation = 0.0
		sprite_node.position = Vector2.ZERO
	
	# スプライト高速回転
	if sprite_node and is_instance_valid(sprite_node):
		var tween := sprite_node.create_tween()
		tween.tween_property(sprite_node, "rotation", TAU * 2.0, LAUNCH_DURATION)  # 2回転
		enemy_main.register_motion_tween(tween)

func Exit() -> void:
	if not body:
		return
	body.collision_layer = _saved_collision_layer
	if body_shape and is_instance_valid(body_shape):
		body_shape.disabled = false
	body.z_index = 0
	# コリジョンマスクを元に戻す（3 = layer 1 + layer 2）
	body.collision_mask = 3
	# 自分の移動・回転Tweenだけをkillしてリセット
	if enemy_main and is_instance_valid(enemy_main):
		enemy_main.kill_motion_tweens()
	if sprite_node and is_instance_valid(sprite_node):
		sprite_node.position = Vector2.ZERO
		sprite_node.rotation = 0.0
		# scaleは一切触らない！

func Update(delta: float) -> void:
	if not body or not enemy_main:
		return
	if GameManager.enemies_frozen:
		body.velocity = Vector2.ZERO
		body.move_and_slide()
		return
	
	# 放物線移動：開始位置から目標位置まで
	launch_time += delta
	var t: float = launch_time / LAUNCH_DURATION
	
	if t >= 1.0:
		# 着地（演出なし）
		body.global_position = target_pos
		if sprite_node and is_instance_valid(sprite_node):
			sprite_node.position.y = 0.0
			sprite_node.rotation = 0.0
		state_transition.emit(self, "enemy_idle_state")
		return
	
	# 水平位置：線形補間
	var horizontal_pos := start_pos.lerp(target_pos, t)
	body.global_position = horizontal_pos
	
	# ジャンプ弧の見た目（Yオフセット）
	var jump_offset: float = 4.0 * LAUNCH_HEIGHT * t * (1.0 - t)
	if sprite_node and is_instance_valid(sprite_node):
		sprite_node.position.y = -jump_offset
	
	body.velocity = Vector2.ZERO


## マット中央付近のランダムな位置を計算（半分くらいの距離をジャンプ）
func _calculate_opposite_position(current_pos: Vector2) -> Vector2:
	var mat_center_x := (MAT_LEFT + MAT_RIGHT) / 2.0
	var mat_center_y := (MAT_TOP + MAT_BOTTOM) / 2.0
	
	# マット中央付近にランダムに配置（中央から±100pxくらい）
	var opposite_x := mat_center_x + randf_range(-100, 100)
	var opposite_y := mat_center_y + randf_range(-100, 100)
	
	return Vector2(opposite_x, opposite_y)
