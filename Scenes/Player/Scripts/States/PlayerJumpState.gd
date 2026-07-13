extends State
class_name PlayerJump

## ジャンプ中の実座標移動＝歩きの速度（ピクセル/秒）
const WALK_SPEED_JUMP := 280.0
## 通常ジャンプの持続時間（秒）
const JUMP_DURATION_NORMAL := 0.85
## ジャンプ弧の見た目の高さ（ピクセル）
const JUMP_VISUAL_HEIGHT := 100.0
## 着地時に敵に与えるダメージ倍率（体当たりの2倍）
const LAND_DAMAGE_MULT := 2
## 着地時ノックバック量（キャラ64に合わせて60）
const LAND_KNOCKBACK := 60.0

var player: CharacterBody2D
var player_main: PlayerMain
var body_shape: CollisionShape2D
var sprite_node: Node2D
var jump_time: float = 0.0
var jump_duration: float = JUMP_DURATION_NORMAL

func Enter() -> void:
	player = get_parent().get_parent() as CharacterBody2D
	player_main = player as PlayerMain
	if not player or not player_main:
		return
	player_main.is_jumping = true
	player.velocity = Vector2.ZERO
	player.rotation = 0.0
	jump_time = 0.0
	jump_duration = JUMP_DURATION_NORMAL
	sprite_node = player_main.sprite if player_main else player.get_node_or_null("AnimatedSprite2D")
	player_main.kill_motion_tweens()
	if sprite_node and is_instance_valid(sprite_node):
		sprite_node.rotation = 0.0
		sprite_node.position = Vector2.ZERO
	body_shape = player.get_node_or_null("BodyCollisionShape") as CollisionShape2D
	if body_shape:
		body_shape.disabled = true
	player.z_index = 100
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
	player.collision_mask = 3
	player_main.kill_motion_tweens()
	if sprite_node and is_instance_valid(sprite_node):
		sprite_node.position = Vector2.ZERO
		sprite_node.rotation = 0.0

func Update(delta: float) -> void:
	if not player or not player_main:
		return
	var mv_left := "MoveLeft" if not player_main.is_player_two else "Move2Left"
	var mv_right := "MoveRight" if not player_main.is_player_two else "Move2Right"
	var mv_up := "MoveUp" if not player_main.is_player_two else "Move2Up"
	var mv_down := "MoveDown" if not player_main.is_player_two else "Move2Down"
	var input_dir := Input.get_vector(mv_left, mv_right, mv_up, mv_down).normalized()
	var move := input_dir * WALK_SPEED_JUMP * delta
	var p := player.global_position + move
	p.x = clampf(p.x, player_main.MAT_LEFT, player_main.MAT_RIGHT)
	p.y = clampf(p.y, player_main.MAT_TOP, player_main.MAT_BOTTOM)
	player.global_position = p
	player.velocity = Vector2.ZERO
	jump_time += delta
	var t: float = jump_time / jump_duration
	var jump_offset: float = 0.0
	if t < 1.0:
		jump_offset = 4.0 * JUMP_VISUAL_HEIGHT * t * (1.0 - t)
	if sprite_node and is_instance_valid(sprite_node):
		sprite_node.position.y = -jump_offset
	if jump_time >= jump_duration:
		if sprite_node and is_instance_valid(sprite_node):
			sprite_node.position.y = 0.0
		_land()
		return

func _land() -> void:
	var land_pos := player.global_position
	var half := player_main.BODY_CONTACT_HALF
	for node in get_tree().get_nodes_in_group("Enemy"):
		var enemy = node as CharacterBase
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if enemy is EnemyMain and (enemy as EnemyMain).is_ring_in_effect_only():
			continue
		if absf(land_pos.x - enemy.global_position.x) <= 2.0 * half and absf(land_pos.y - enemy.global_position.y) <= 2.0 * half:
			enemy._take_damage(int(player_main.BODY_DAMAGE_DEALT * LAND_DAMAGE_MULT))
			if enemy.has_method("notify_stepped_on"):
				enemy.notify_stepped_on()
			if player_main.has_method("flash_aerial_hit"):
				player_main.flash_aerial_hit(enemy)
			if enemy.has_method("trigger_aerial_knockback"):
				enemy.trigger_aerial_knockback()
			else:
				var to_enemy: Vector2 = (enemy.global_position - land_pos).normalized()
				var knock: Vector2 = _axis_knockback(to_enemy, LAND_KNOCKBACK)
				enemy.global_position += knock
	state_transition.emit(self, "Idle")

func _axis_knockback(to_enemy: Vector2, amount: float) -> Vector2:
	if absf(to_enemy.x) >= absf(to_enemy.y):
		return Vector2(signf(to_enemy.x) * amount, 0.0)
	return Vector2(0.0, signf(to_enemy.y) * amount)
