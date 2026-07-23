extends State
class_name PlayerJump

## ジャンプ中の実座標移動＝歩きの速度（ピクセル/秒）
const WALK_SPEED_JUMP := 280.0
## 通常ジャンプの持続時間（秒）
const JUMP_DURATION_NORMAL := 0.85
## ジャンプ弧の見た目の高さ（ピクセル）
const JUMP_VISUAL_HEIGHT := 100.0
## ダウン敵へのフライングボディアタック
const PRESS_DAMAGE := 40
## 非ダウン敵に着地したとき、自分が吹き飛ぶ距離
const FAIL_LAND_KNOCKBACK := 120.0

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
	# 頭突きは廃止（回避＋ダウン追撃に特化）
	player_main.pending_headbutt_dir = Vector2.ZERO
	sprite_node = player_main.sprite if player_main else player.get_node_or_null("AnimatedSprite2D")
	player_main.kill_motion_tweens()
	if sprite_node and is_instance_valid(sprite_node):
		sprite_node.rotation = 0.0
		sprite_node.position = Vector2.ZERO
	body_shape = player.get_node_or_null("BodyCollisionShape") as CollisionShape2D
	if body_shape:
		body_shape.disabled = true
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
	# z_index は CharacterBase.update_draw_priority に任せる

func Update(delta: float) -> void:
	if not player or not player_main:
		return
	var mv_left := "MoveLeft" if not player_main.is_player_two else "Move2Left"
	var mv_right := "MoveRight" if not player_main.is_player_two else "Move2Right"
	var mv_up := "MoveUp" if not player_main.is_player_two else "Move2Up"
	var mv_down := "MoveDown" if not player_main.is_player_two else "Move2Down"
	var input_dir := Input.get_vector(mv_left, mv_right, mv_up, mv_down).normalized()
	var move: Vector2 = input_dir * WALK_SPEED_JUMP * delta
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
		if enemy is EnemyMain and ((enemy as EnemyMain).is_ring_in_effect_only() or (enemy as EnemyMain).is_perched):
			continue
		if absf(land_pos.x - enemy.global_position.x) > 2.0 * half or absf(land_pos.y - enemy.global_position.y) > 2.0 * half:
			continue
		var em := enemy as EnemyMain
		if em and em.is_in_down_state():
			# ボスHP0ダウン中: ジャンプでQTE開始
			if em.is_boss and (em.awaiting_finisher or em.health <= 0):
				AudioManager.play_sound(AudioManager.BLOODY_HIT, 0, -1)
				GameManager.show_callout(enemy, "フィニッシュ！", Color(1.0, 0.85, 0.2, 1.0))
				if player_main.has_method("flash_aerial_hit"):
					player_main.flash_aerial_hit(enemy)
				em.request_finisher_qte()
				if GameManager.training_mode:
					GameManager.body_contact_type_text = "フィニッシュ！"
					GameManager.body_contact_type_timer = 1.5
				state_transition.emit(self, "Idle")
				return
			# フライングボディアタック
			AudioManager.play_sound(AudioManager.BLOODY_HIT, 0, -1)
			enemy._take_damage(PRESS_DAMAGE)
			if player_main.has_method("flash_aerial_hit"):
				player_main.flash_aerial_hit(enemy)
			if enemy.hit_particles:
				enemy.hit_particles.amount = 60
				enemy.hit_particles.lifetime = 1.0
				enemy.hit_particles.emitting = true
			if enemy.is_dead:
				em.fly_out_visual(Vector2(cos(randf() * TAU), sin(randf() * TAU)))
			else:
				GameManager.show_callout(enemy, "フライングボディ！", Color(0.9, 0.5, 1.0, 1.0))
				em.down_remaining = maxf(em.down_remaining, 1.2)
			if GameManager.training_mode:
				GameManager.body_contact_type_text = "フライングボディ！"
				GameManager.body_contact_type_timer = 1.5
			continue
		# 非ダウンへ着地＝自分が吹き飛ぶ（攻撃失敗・ダメージなし）
		AudioManager.play_sound(AudioManager.PLAYER_ATTACK_HIT, 0, 1)
		AudioManager.play_sound(AudioManager.PLAYER_ATTACK_SWING, 0, -1)
		GameManager.show_callout(player, "着地失敗！", Color(1.0, 0.45, 0.3, 1.0))
		var away := _axis_knockback((land_pos - enemy.global_position).normalized(), FAIL_LAND_KNOCKBACK)
		if away == Vector2.ZERO:
			away = Vector2(FAIL_LAND_KNOCKBACK, 0)
		var blow_pos := land_pos + away
		blow_pos.x = clampf(blow_pos.x, player_main.MAT_LEFT, player_main.MAT_RIGHT)
		blow_pos.y = clampf(blow_pos.y, player_main.MAT_TOP, player_main.MAT_BOTTOM)
		player_main.set_invincible_for(0.35)
		var tw := player.create_tween()
		tw.tween_property(player, "global_position", blow_pos, 0.2)
		player_main.register_motion_tween(tw)
		if GameManager.training_mode:
			GameManager.body_contact_type_text = "着地失敗！"
			GameManager.body_contact_type_timer = 1.5
		break
	state_transition.emit(self, "Idle")

func _axis_knockback(to_dir: Vector2, amount: float) -> Vector2:
	if to_dir.length() < 0.01:
		return Vector2.ZERO
	if absf(to_dir.x) >= absf(to_dir.y):
		return Vector2(signf(to_dir.x) * amount, 0.0)
	return Vector2(0.0, signf(to_dir.y) * amount)
