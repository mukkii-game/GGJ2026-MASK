extends State
class_name PlayerRopeLaunched

## ロープからの反発ジャンプ（放物線移動）の持続時間（秒）
const LAUNCH_DURATION := 1.2
## ジャンプ弧の見た目の高さ（ピクセル）
const LAUNCH_HEIGHT := 150.0

var player: CharacterBody2D
var player_main: PlayerMain
var body_shape: CollisionShape2D
var sprite_node: Node2D
## ジャンプ開始からの経過時間
var launch_time: float = 0.0
## 開始位置と目標位置
var start_pos: Vector2
var target_pos: Vector2

func Enter() -> void:
	player = get_parent().get_parent() as CharacterBody2D
	player_main = player as PlayerMain
	if not player or not player_main:
		return
	
	# ダメージなしのロープ弾き＝かわいいぽよーん
	AudioManager.play_sound(AudioManager.POYO_BOUNCE, 0, 0)
	GameManager.show_callout(player, "ロープ飛ばし！", Color(0.55, 0.85, 1.0, 1.0))
	
	player_main.is_jumping = true
	player.velocity = Vector2.ZERO
	player.rotation = 0.0
	launch_time = 0.0
	
	# 開始位置を記録
	start_pos = player.global_position
	
	# 目標位置：反対側のマットのランダムな位置
	target_pos = _calculate_opposite_position(start_pos)
	
	# 当たり判定なし（敵はすり抜ける）+ ロープの壁をすり抜ける
	body_shape = player.get_node_or_null("BodyCollisionShape") as CollisionShape2D
	if body_shape:
		body_shape.disabled = true
	player.z_index = 100
	# コリジョンマスクを1に変更（layer 2のロープ外の壁をすり抜ける）
	player.collision_mask = 1
	sprite_node = player_main.sprite if player_main else player.get_node_or_null("AnimatedSprite2D")
	
	# Enter時に自分の移動・回転Tweenだけをkillしてリセット（他ノードのTweenは巻き込まない）
	player_main.kill_motion_tweens()
	if sprite_node and is_instance_valid(sprite_node):
		# scaleは一切触らない！rotationとpositionだけリセット
		sprite_node.rotation = 0.0
		sprite_node.position = Vector2.ZERO
	
	# スプライト高速回転
	if sprite_node:
		var tween := sprite_node.create_tween()
		tween.tween_property(sprite_node, "rotation", TAU * 2.0, LAUNCH_DURATION)  # 2回転
		player_main.register_motion_tween(tween)

func Exit() -> void:
	if not player:
		return
	player_main.is_jumping = false
	if body_shape and is_instance_valid(body_shape):
		body_shape.disabled = false
	player.z_index = 0
	player.rotation = 0.0
	# コリジョンマスクを元に戻す（1 = layer 1 のみ・ロープ外の壁は無効のまま）
	player.collision_mask = 1
	# 自分の移動・回転Tweenだけをkillしてリセット
	player_main.kill_motion_tweens()
	if sprite_node and is_instance_valid(sprite_node):
		sprite_node.position = Vector2.ZERO
		sprite_node.rotation = 0.0
		# scaleは一切触らない！

func Update(delta: float) -> void:
	if not player or not player_main:
		return
	
	# 放物線移動：開始位置から目標位置まで
	launch_time += delta
	var t: float = launch_time / LAUNCH_DURATION
	
	if t >= 1.0:
		# 着地（演出なし）
		player.global_position = target_pos
		if sprite_node and is_instance_valid(sprite_node):
			sprite_node.position.y = 0.0
			sprite_node.rotation = 0.0
		state_transition.emit(self, "Idle")
		return
	
	# 水平位置：線形補間
	var horizontal_pos := start_pos.lerp(target_pos, t)
	player.global_position = horizontal_pos
	
	# ジャンプ弧の見た目（Yオフセット）
	var jump_offset: float = 4.0 * LAUNCH_HEIGHT * t * (1.0 - t)
	if sprite_node and is_instance_valid(sprite_node):
		sprite_node.position.y = -jump_offset
	
	player.velocity = Vector2.ZERO


## マット中央付近のランダムな位置を計算（半分くらいの距離をジャンプ）
func _calculate_opposite_position(current_pos: Vector2) -> Vector2:
	# マット中央付近にランダムに配置（確実にマット内に収める）
	var opposite_x := randf_range(350.0, 930.0)
	var opposite_y := randf_range(138.0, 614.0)
	
	return Vector2(opposite_x, opposite_y)
