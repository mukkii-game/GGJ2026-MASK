extends State
class_name PlayerWalking

## グリッドごとワープ：1ステップのピクセル数（半キャラ＝32）
const STEP_SIZE := 32
## 1ステップごとの間隔（秒）。小さくすると速く動く
@export var step_cooldown := 0.12
## ロープ跳ね返り後の待ち時間（秒）
const ROPE_BOUNCE_DELAY := 0.5
## 自動走行時は通常の何倍速か
const AUTO_RUN_SPEED_MULT := 3.0

@export var movespeed := int(2800)
@export var dash_max := int(2000)
var dashspeed := float(400)
var can_dash := bool(false)
var dash_direction := Vector2(0,0)
var step_timer := 0.0
## 左クリック自動走行：向き。ZEROで解除
var auto_run_direction := Vector2.ZERO
var auto_run_bounce_timer := 0.0

var player : CharacterBody2D
var player_main : PlayerMain
@export var animator : AnimationPlayer

func Enter():
	player = get_tree().get_first_node_in_group("Player")
	player_main = player as PlayerMain
	animator.play("Walk")
	if player_main and player_main.start_auto_run:
		player_main.start_auto_run = false
		var sprite = player_main.sprite
		auto_run_direction = Vector2.RIGHT if (sprite and sprite.scale.x >= 0) else Vector2.LEFT

func Update(delta : float):
	step_timer -= delta
	var input_dir = Input.get_vector("MoveLeft", "MoveRight", "MoveUp", "MoveDown").normalized()
	# 左クリック（ジャンプボタン）＋方向キーでダッシュ延長（連打で速度維持）
	if Input.is_action_just_pressed("Punch") and player_main and input_dir.length() > 0:
		player_main.dash_timer = player_main.DASH_DURATION
	# 移動キーを入れると自動走行解除
	if input_dir.length() > 0 and auto_run_direction != Vector2.ZERO:
		auto_run_direction = Vector2.ZERO
	# 左クリックで自動走行開始（Moving 中に押した場合・方向なしのとき）
	if Input.is_action_just_pressed("Punch") and auto_run_direction == Vector2.ZERO and dashspeed <= 0 and input_dir.length() <= 0:
		var sprite = player_main.sprite if player_main else null
		auto_run_direction = Vector2.RIGHT if (sprite and sprite.scale.x >= 0) else Vector2.LEFT
	if Input.is_action_just_pressed("Dash") and can_dash:
		start_dash(input_dir if input_dir.length() > 0 else auto_run_direction)
	elif Input.is_action_just_pressed("AttackPunch") or Input.is_action_just_pressed("AttackKick"):
		Transition("Attacking")
	else:
		Move(input_dir, delta)
	LessenDash(delta)

func Move(input_dir : Vector2, delta : float):
	if dash_direction != Vector2.ZERO and dash_direction != input_dir:
		dash_direction = Vector2.ZERO
		dashspeed = 0

	if dashspeed > 0:
		player.velocity = input_dir * movespeed + dash_direction * dashspeed
		player.move_and_slide()
		if input_dir.length() <= 0 and auto_run_direction == Vector2.ZERO:
			Transition("Idle")
		return

	# 自動走行：跳ね返り待ち中
	if auto_run_bounce_timer > 0:
		auto_run_bounce_timer -= delta
		player.velocity = Vector2.ZERO
		if auto_run_bounce_timer <= 0:
			auto_run_direction = -auto_run_direction
			# 少しだけロープから離す
			player.global_position += auto_run_direction * 4
		return

	# 自動走行中（3倍速）
	if auto_run_direction != Vector2.ZERO:
		if player_main:
			player_main.is_auto_running = true
		player.velocity = auto_run_direction * (movespeed * AUTO_RUN_SPEED_MULT)
		player.move_and_slide()
		var nc = player.get_slide_collision_count()
		for i in nc:
			var col = player.get_slide_collision(i)
			if not col:
				continue
			var collider = col.get_collider()
			if collider and collider.is_in_group("Rope"):
				player.velocity = Vector2.ZERO
				player.global_position -= auto_run_direction * 4
				auto_run_bounce_timer = ROPE_BOUNCE_DELAY
				AudioManager.play_sound(AudioManager.PLAYER_ATTACK_SWING, 0.1, 2)
				# ロープを揺らす
				var side := _rope_wall_to_side(collider)
				var arena = player.get_parent().get_node_or_null("ArenaMat")
				if arena and arena.has_method("sway_rope"):
					arena.sway_rope(side)
				break
			else:
				# ロープ以外（敵など）に当たったら解除
				auto_run_direction = Vector2.ZERO
				if player_main:
					player_main.is_auto_running = false
				Transition("Idle")
				return
		return

	if player_main:
		player_main.is_auto_running = false
	# 通常時（ダッシュ中は3倍速）
	if input_dir.length() > 0:
		var effective_speed := movespeed
		if player_main and player_main.dash_timer > 0:
			effective_speed = int(movespeed * player_main.DASH_SPEED_MULT)
			player_main.dash_timer -= delta
		player.velocity = input_dir
		var use_grid: bool = player_main.use_grid_movement if player_main else false
		if use_grid:
			if step_timer <= 0:
				var step := Vector2(
					STEP_SIZE * sign(input_dir.x) if absf(input_dir.x) > 0.1 else 0,
					STEP_SIZE * sign(input_dir.y) if absf(input_dir.y) > 0.1 else 0
				)
				if step != Vector2.ZERO and not player.test_move(player.global_transform, step):
					player.global_position += step
				step_timer = step_cooldown
		else:
			player.velocity = input_dir * effective_speed
			player.move_and_slide()
	else:
		player.velocity = Vector2.ZERO
		Transition("Idle")

func start_dash(input_dir : Vector2):
	AudioManager.play_sound(AudioManager.PLAYER_ATTACK_SWING, 0.3, -1)
	dash_direction = input_dir.normalized()
	dashspeed = dash_max
	animator.play("Dash")
	can_dash = false

func LessenDash(delta : float):
	#Higher multiplier values makes the dash shorter
	var multiplier : float = 4.0
	var timemultiplier : float = 4.1
	
	#slow down the dash over time, both as a fraction of dashspeed and also time
	#While clamping it between 0 and dash_max
	dashspeed -= (dashspeed * multiplier * delta) + (delta * timemultiplier)
	dashspeed = clamp(dashspeed, 0, dash_max)
	
	if(dashspeed <= 0):
		can_dash = true
		dash_direction = Vector2.ZERO
		
	if(animator.current_animation == "Dash"):
		await animator.animation_finished
		animator.play("Walk")

# 壁ノード名からロープ揺れ用の側名を返す
func _rope_wall_to_side(collider: Node) -> StringName:
	var n := collider.name
	if n == "WallLeft": return &"left"
	if n == "WallRight": return &"right"
	if n == "WallTop": return &"top"
	if n == "WallBottom": return &"bottom"
	return &""

#We cannot allow a transition before the dash is complete and the animation has stopped playing
func Transition(newstate : String):
	if(dashspeed <= 0):
		state_transition.emit(self, newstate)
