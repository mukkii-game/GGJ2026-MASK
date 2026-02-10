extends State
class_name PlayerJump

## ジャンプ中の実座標移動＝歩きの速度（ピクセル/秒）
const WALK_SPEED_JUMP := 280.0
## 通常ジャンプの持続時間（秒）
const JUMP_DURATION_NORMAL := 0.85
## コーナーポストジャンプの持続時間（秒）
const JUMP_DURATION_POST := 1.7
## ジャンプ弧の見た目の高さ（ピクセル）
const JUMP_VISUAL_HEIGHT := 100.0
## 着地時に敵に与えるダメージ倍率（体当たりの2倍）
const LAND_DAMAGE_MULT := 2
## 着地時ノックバック量（キャラ1人分＝80、scale 1.25考慮）
const LAND_KNOCKBACK := 60.0
## ポストから降りるジャンプ時の回転（1回転の秒数）
const POST_JUMP_ROTATION_DURATION := 1.0

var player: CharacterBody2D
var player_main: PlayerMain
var body_shape: CollisionShape2D
var sprite_node: Node2D
## ジャンプ開始からの経過時間
var jump_time: float = 0.0
## 今回のジャンプの持続時間
var jump_duration: float = JUMP_DURATION_NORMAL

func Enter() -> void:
	player = get_parent().get_parent() as CharacterBody2D
	player_main = player as PlayerMain
	if not player or not player_main:
		return
	# AudioManager.play_sound(AudioManager.PLAYER_ATTACK_SWING, 0, -4)  # ジャンプ音（JUMP定数がないのでコメントアウト）
	player_main.is_jumping = true
	player.velocity = Vector2.ZERO
	player.rotation = 0.0
	# 通常ジャンプとコーナーポストジャンプは同じ処理。時間だけ違う
	jump_time = 0.0
	# sprite_nodeを先に取得
	sprite_node = player_main.sprite if player_main else player.get_node_or_null("AnimatedSprite2D")
	
	# Enter時に必ず既存のtweenをすべてkillしてリセット
	if sprite_node and is_instance_valid(sprite_node):
		# 既存のすべてのtweenを強制終了
		var tree := sprite_node.get_tree()
		if tree:
			for tween in tree.get_processed_tweens():
				if tween.is_valid():
					tween.kill()
		# scaleは一切触らない！rotationとpositionだけリセット
		sprite_node.rotation = 0.0
		sprite_node.position = Vector2.ZERO
	
	if player_main.on_corner_post:
		player_main.leave_post_2x_jump = true
		player_main.on_corner_post = false
		jump_duration = JUMP_DURATION_POST
		# スプライト高速回転（影は動かない、スプライトのみ回転）6回転
		if sprite_node and is_instance_valid(sprite_node):
			# 既存のすべてのtweenを強制終了してから新規作成
			var tree := sprite_node.get_tree()
			if tree:
				for tween_old in tree.get_processed_tweens():
					if tween_old.is_valid():
						tween_old.kill()
			var tween := sprite_node.create_tween()
			tween.set_parallel(false)
			tween.tween_property(sprite_node, "rotation", TAU * 6.0, JUMP_DURATION_POST)  # 6回転（2倍速）
		# 「ギュルるる」音を立て続けて（PLAYER_ATTACK_SWINGを連続で）
		_play_spin_sounds()
	else:
		jump_duration = JUMP_DURATION_NORMAL
	# 当たり判定なし（敵はすり抜ける）+ ロープの壁をすり抜ける
	body_shape = player.get_node_or_null("BodyCollisionShape") as CollisionShape2D
	if body_shape:
		body_shape.disabled = true
	player.z_index = 100
	# コリジョンマスクを1に変更（layer 2のロープ外の壁をすり抜ける）
	player.collision_mask = 1

func Exit() -> void:
	if not player:
		return
	player_main.is_jumping = false
	player_main._just_landed_frame = true
	if body_shape and is_instance_valid(body_shape):
		body_shape.disabled = false
	player.z_index = 0
	player.rotation = 0.0
	# コリジョンマスクを元に戻す（1 = layer 1 のみ・ロープ外の壁は無効のまま）
	player.collision_mask = 1
	if sprite_node and is_instance_valid(sprite_node):
		# すべてのtweenを強制終了
		var tree := sprite_node.get_tree()
		if tree:
			for tween in tree.get_processed_tweens():
				if tween.is_valid():
					tween.kill()
		sprite_node.position = Vector2.ZERO  # 完全にリセット
		sprite_node.rotation = 0.0  # スプライトの回転もリセット
		# scaleは一切触らない！

func Update(delta: float) -> void:
	if not player or not player_main:
		return
	# 実座標：歩きの速度で移動。ロープは超えられない（クランプのみ）
	var input_dir := Input.get_vector("MoveLeft", "MoveRight", "MoveUp", "MoveDown").normalized()
	if player_main.use_grid_movement:
		input_dir = Vector2.ZERO
	var move := input_dir * WALK_SPEED_JUMP * delta
	var p := player.global_position + move
	p.x = clampf(p.x, player_main.MAT_LEFT, player_main.MAT_RIGHT)
	p.y = clampf(p.y, player_main.MAT_TOP, player_main.MAT_BOTTOM)
	player.global_position = p
	player.velocity = Vector2.ZERO
	# ジャンプ弧の見た目（Yオフセット）
	jump_time += delta
	var t: float = jump_time / jump_duration
	var jump_offset: float = 0.0
	if t < 1.0:
		jump_offset = 4.0 * JUMP_VISUAL_HEIGHT * t * (1.0 - t)
	if sprite_node and is_instance_valid(sprite_node):
		sprite_node.position.y = -jump_offset
	# 着地：時間で終了
	if jump_time >= jump_duration:
		if sprite_node and is_instance_valid(sprite_node):
			sprite_node.position.y = 0.0
		_land()
		return

func _land() -> void:
	var land_pos := player.global_position
	var half := player_main.BODY_CONTACT_HALF
	var damage_mult: float = LAND_DAMAGE_MULT
	if player_main.leave_post_2x_jump:
		player_main.leave_post_2x_jump = false
		damage_mult = LAND_DAMAGE_MULT * 2.0
	for node in get_tree().get_nodes_in_group("Enemy"):
		var enemy = node as CharacterBase
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if absf(land_pos.x - enemy.global_position.x) <= 2.0 * half and absf(land_pos.y - enemy.global_position.y) <= 2.0 * half:
			var to_enemy: Vector2 = (enemy.global_position - land_pos).normalized()
			enemy._take_damage(int(player_main.BODY_DAMAGE_DEALT * damage_mult))
			# 敵を押し飛ばす方向は「敵から離れる方向」（to_enemyの方向）
			var knock: Vector2 = _axis_knockback(to_enemy, LAND_KNOCKBACK)
			enemy.global_position += knock
	state_transition.emit(self, "Idle")

func _axis_knockback(to_enemy: Vector2, amount: float) -> Vector2:
	if absf(to_enemy.x) >= absf(to_enemy.y):
		return Vector2(signf(to_enemy.x) * amount, 0.0)
	return Vector2(0.0, signf(to_enemy.y) * amount)

## コーナーポストジャンプ中に「ギュルるる」音を立て続けて再生
func _play_spin_sounds() -> void:
	# ジャンプ中に5回音を鳴らす
	for i in range(5):
		await get_tree().create_timer(i * 0.3).timeout
		AudioManager.play_sound(AudioManager.PLAYER_ATTACK_SWING, 0, -2 - i)
