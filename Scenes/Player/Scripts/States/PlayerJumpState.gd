extends State
class_name PlayerJump

## ジャンプ初速（高さ2倍：v^2=2gh で h≈128 → v≈395）
@export var jump_initial_speed := 395.0
## 落下重力
@export var gravity := 600.0
## 着地時に敵に与えるダメージ倍率（体当たりの2倍）
const LAND_DAMAGE_MULT := 2
## 着地時ノックバック量（キャラ1人分＝64）
const LAND_KNOCKBACK := 64.0

var player: CharacterBody2D
var player_main: PlayerMain
var body_shape: CollisionShape2D
var jump_start_y: float = 0.0

func Enter() -> void:
	player = get_parent().get_parent() as CharacterBody2D
	player_main = player as PlayerMain
	if not player or not player_main:
		return
	AudioManager.play_sound(AudioManager.JUMP, 0, -4)
	player_main.is_jumping = true
	jump_start_y = player.global_position.y
	# 固定の初速で一度だけ上昇（押し続けで無限上昇しない）
	player.velocity = Vector2(0, -jump_initial_speed)
	# 当たり判定なし
	body_shape = player.get_node_or_null("BodyCollisionShape") as CollisionShape2D
	if body_shape:
		body_shape.disabled = true
	# 表示プライオリティ一番上
	player.z_index = 100
	# 足元の影は着地点に固定（プレイヤーが動かない限りそのまま。着地で通常の足元に戻る）
	var shadow = player.get_node_or_null("FootShadow")
	if shadow:
		if "ground_y" in shadow:
			shadow.ground_y = jump_start_y
		if "ground_x" in shadow:
			shadow.ground_x = player.global_position.x

func Exit() -> void:
	if not player:
		return
	player_main.is_jumping = false
	player_main._just_landed_frame = true
	if body_shape and is_instance_valid(body_shape):
		body_shape.disabled = false
	player.z_index = 0
	var shadow = player.get_node_or_null("FootShadow")
	if shadow != null and "ground_y" in shadow:
		shadow.ground_y = INF
	if shadow != null and "ground_x" in shadow:
		shadow.ground_x = INF

func Update(delta: float) -> void:
	if not player or not player_main:
		return
	# 重力で落下（押し続けは無視。固定高さジャンプのみ）
	player.velocity.y += gravity * delta
	# カクカクモード時は横移動なしで縦だけ（ジャンプもカクカク）
	if player_main.use_grid_movement:
		player.velocity.x = 0
	else:
		player.velocity.x = Input.get_axis("MoveLeft", "MoveRight") * player_main.MAT_RIGHT * 0.2
	player.move_and_slide()
	# 着地判定：落下中かつ開始Y以上に戻った
	if player.velocity.y >= 0 and player.global_position.y >= jump_start_y:
		player.global_position.y = jump_start_y
		player.velocity = Vector2.ZERO
		_land()
		return

func _land() -> void:
	# 着地位置に敵がいれば体当たりの2倍ダメージ＋ノックバック（クリーンアップは Exit で行う）
	var land_pos := player.global_position
	for node in get_tree().get_nodes_in_group("Enemy"):
		var enemy = node as CharacterBase
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var d := land_pos.distance_to(enemy.global_position)
		if d < player_main.BODY_CONTACT_RADIUS:
			var to_enemy: Vector2 = (enemy.global_position - land_pos).normalized()
			enemy._take_damage(player_main.BODY_DAMAGE_DEALT * LAND_DAMAGE_MULT)
			var knock: Vector2 = _axis_knockback(to_enemy, LAND_KNOCKBACK)
			enemy.global_position += knock
	state_transition.emit(self, "Idle")

func _axis_knockback(to_enemy: Vector2, amount: float) -> Vector2:
	if absf(to_enemy.x) >= absf(to_enemy.y):
		return Vector2(signf(to_enemy.x) * amount, 0.0)
	return Vector2(0.0, signf(to_enemy.y) * amount)
