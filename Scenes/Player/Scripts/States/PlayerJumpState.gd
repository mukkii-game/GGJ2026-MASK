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
## 空中頭突き（確定仕様P7）: 走行中ジャンプで発動。走行方向へ高速で飛び、命中した敵を吹き飛ばしダウン。
## 強い（Angry）敵にも通る唯一の直接技（ダウンで強化解除）。KOならそのまま場外へ
const HEADBUTT_SPEED := 420.0
const HEADBUTT_DURATION := 0.5
const HEADBUTT_DAMAGE := 20
## ダウン（寝）敵へのプレス（確定仕様P6）: 着地で大ダメージ。KOなら場外へ吹っ飛ぶ
const PRESS_DAMAGE := 30

var player: CharacterBody2D
var player_main: PlayerMain
var body_shape: CollisionShape2D
var sprite_node: Node2D
var jump_time: float = 0.0
var jump_duration: float = JUMP_DURATION_NORMAL
## 空中頭突きモード（走行中ジャンプ）
var is_headbutt := false
var headbutt_dir := Vector2.ZERO
var _headbutt_hit_done := false

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
	# 空中頭突き判定: 走行中ジャンプ（Walk/ロープ走行から pending_headbutt_dir が渡される）
	is_headbutt = false
	headbutt_dir = Vector2.ZERO
	_headbutt_hit_done = false
	if player_main.pending_headbutt_dir != Vector2.ZERO:
		is_headbutt = true
		headbutt_dir = player_main.pending_headbutt_dir.normalized()
		player_main.pending_headbutt_dir = Vector2.ZERO
		jump_duration = HEADBUTT_DURATION
		player_main.rope_bounce_running = false
		AudioManager.play_sound(AudioManager.PLAYER_ATTACK_SWING, 0, 2)
		# 頭から突っ込む見た目（進行方向へ倒す）
		if sprite_node and is_instance_valid(sprite_node):
			sprite_node.rotation = headbutt_dir.angle() - PI / 2.0
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
	var move: Vector2
	if is_headbutt:
		# 頭突き中は入力無視・走行方向へ一直線
		move = headbutt_dir * HEADBUTT_SPEED * delta
	else:
		var mv_left := "MoveLeft" if not player_main.is_player_two else "Move2Left"
		var mv_right := "MoveRight" if not player_main.is_player_two else "Move2Right"
		var mv_up := "MoveUp" if not player_main.is_player_two else "Move2Up"
		var mv_down := "MoveDown" if not player_main.is_player_two else "Move2Down"
		var input_dir := Input.get_vector(mv_left, mv_right, mv_up, mv_down).normalized()
		move = input_dir * WALK_SPEED_JUMP * delta
	var p := player.global_position + move
	p.x = clampf(p.x, player_main.MAT_LEFT, player_main.MAT_RIGHT)
	p.y = clampf(p.y, player_main.MAT_TOP, player_main.MAT_BOTTOM)
	player.global_position = p
	player.velocity = Vector2.ZERO
	jump_time += delta
	var t: float = jump_time / jump_duration
	var jump_offset: float = 0.0
	var visual_height: float = JUMP_VISUAL_HEIGHT * (0.45 if is_headbutt else 1.0)
	if t < 1.0:
		jump_offset = 4.0 * visual_height * t * (1.0 - t)
	if sprite_node and is_instance_valid(sprite_node):
		sprite_node.position.y = -jump_offset
	# 頭突きの命中判定（飛んでいる間、最初の1体に命中）
	if is_headbutt and not _headbutt_hit_done:
		_check_headbutt_hit()
		if _headbutt_hit_done:
			return
	if jump_time >= jump_duration:
		if sprite_node and is_instance_valid(sprite_node):
			sprite_node.position.y = 0.0
		_land()
		return

func _check_headbutt_hit() -> void:
	var half := player_main.BODY_CONTACT_HALF
	for node in get_tree().get_nodes_in_group("Enemy"):
		var enemy = node as CharacterBase
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if enemy is EnemyMain:
			var em0 := enemy as EnemyMain
			if em0.is_ring_in_effect_only() or em0.is_rope_launched() or em0.is_in_down_state() or em0._aerial_knockback_animating or em0.is_perched:
				continue
		if absf(player.global_position.x - enemy.global_position.x) <= 2.0 * half and absf(player.global_position.y - enemy.global_position.y) <= 2.0 * half:
			_headbutt_hit(enemy)
			return

func _headbutt_hit(enemy: CharacterBase) -> void:
	_headbutt_hit_done = true
	var em := enemy as EnemyMain
	AudioManager.play_sound(AudioManager.BLOODY_HIT, 0, 5)
	AudioManager.play_sound(AudioManager.PLAYER_ATTACK_HIT, 0, 2)
	if player_main.has_method("flash_aerial_hit"):
		player_main.flash_aerial_hit(enemy)
	# ロープ走行停止はダメージより先に（QTE発火でスキップされないように。カウンター経路と同順序）
	if em:
		em.stop_rope_run()
	enemy._take_damage(HEADBUTT_DAMAGE)
	if enemy.hit_particles:
		enemy.hit_particles.amount = 50
		enemy.hit_particles.lifetime = 0.8
		enemy.hit_particles.emitting = true
	if em:
		if enemy.is_dead:
			em.fly_out_visual(headbutt_dir)
		elif enemy.health > 0:
			GameManager.show_callout(enemy, "ヘッドバット！", Color(1.0, 0.6, 0.2, 1.0))
			em.blast_to_down(headbutt_dir)
	if GameManager.training_mode:
		GameManager.body_contact_type_text = "空中頭突き！"
		GameManager.body_contact_type_timer = 1.5
	# 命中したらその場で着地（着地ダメージは重複させない）
	_land(true)

func _land(skip_damage: bool = false) -> void:
	if skip_damage:
		state_transition.emit(self, "Idle")
		return
	var land_pos := player.global_position
	var half := player_main.BODY_CONTACT_HALF
	for node in get_tree().get_nodes_in_group("Enemy"):
		var enemy = node as CharacterBase
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if enemy is EnemyMain and ((enemy as EnemyMain).is_ring_in_effect_only() or (enemy as EnemyMain).is_perched):
			continue
		if absf(land_pos.x - enemy.global_position.x) <= 2.0 * half and absf(land_pos.y - enemy.global_position.y) <= 2.0 * half:
			var em := enemy as EnemyMain
			if em and em.is_in_down_state():
				# ダウン敵へのプレス（P6）: 大ダメージ。KOなら場外へ吹っ飛ぶ
				AudioManager.play_sound(AudioManager.BLOODY_HIT, 0, 5)
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
					GameManager.show_callout(enemy, "ボディプレス！", Color(0.9, 0.5, 1.0, 1.0))
					em.down_remaining = maxf(em.down_remaining, 1.2)
				if GameManager.training_mode:
					GameManager.body_contact_type_text = "ボディプレス！"
					GameManager.body_contact_type_timer = 1.5
				continue
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
