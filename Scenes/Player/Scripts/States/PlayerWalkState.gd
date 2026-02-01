extends State
class_name PlayerWalking

## グリッドごとワープ：1ステップのピクセル数（半キャラ＝32）
const STEP_SIZE := 32
## 1ステップごとの間隔（秒）。小さくすると速く動く
@export var step_cooldown := 0.08
## ロープ跳ね返り後の待ち時間（秒）
const ROPE_BOUNCE_DELAY := 0.5
## 自動走行時は通常の何倍速か
const AUTO_RUN_SPEED_MULT := 3.0

@export var movespeed := int(480)
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
	auto_run_bounce_timer -= delta
	var input_dir = Input.get_vector("MoveLeft", "MoveRight", "MoveUp", "MoveDown").normalized()
	# 左クリック（ジャンプボタン）：ふつうモード＝ジャンプ、カクカク＝小ダッシュ＋炎（ダッシュ中でも即遷移）
	if Input.is_action_just_pressed("Punch") and player_main:
		if player_main.use_grid_movement:
			state_transition.emit(self, "FireDash")
		else:
			state_transition.emit(self, "Jump")
		return
	# 移動キーを入れると自動走行解除
	if input_dir.length() > 0 and auto_run_direction != Vector2.ZERO:
		auto_run_direction = Vector2.ZERO
	# 左クリックで自動走行開始（Moving 中に押した場合・方向なしのとき）
	if Input.is_action_just_pressed("Punch") and auto_run_direction == Vector2.ZERO and dashspeed <= 0 and input_dir.length() <= 0:
		player_main.start_auto_run = true
		state_transition.emit(self, "Moving")
		return
	if Input.is_action_just_pressed("Dash") and can_dash:
		start_dash(input_dir if input_dir.length() > 0 else auto_run_direction)
	elif Input.is_action_just_pressed("AttackPunch") or Input.is_action_just_pressed("AttackKick"):
		Transition("Attacking")
	else:
		Move(input_dir, delta)
	LessenDash(delta)
	
func Move(input_dir : Vector2, delta : float):
	#Suddenly turning mid dash
	if(dash_direction != Vector2.ZERO and dash_direction != input_dir):
		dash_direction = Vector2.ZERO
		dashspeed = 0

	# ダッシュ中は従来どおり速度移動（壁は move_and_slide が止める）
	if dashspeed > 0:
		player.velocity = input_dir * movespeed + dash_direction * dashspeed
		player.move_and_slide()
		if input_dir.length() <= 0:
			Transition("Idle")
		return

	# 通常時：グリッドONなら32pxワープ、OFFなら滑らか移動（狭い道用）
	if input_dir.length() > 0:
		var use_grid: bool = (player as PlayerMain).use_grid_movement if player is PlayerMain else false
		if use_grid:
			# グリッドモード：velocityを設定して向きを変える（実際の移動はワープ）
			player.velocity = input_dir * movespeed
			if step_timer <= 0:
				var step := Vector2(
					STEP_SIZE * sign(input_dir.x) if absf(input_dir.x) > 0.1 else 0,
					STEP_SIZE * sign(input_dir.y) if absf(input_dir.y) > 0.1 else 0
				)
				if step != Vector2.ZERO and not player.test_move(player.global_transform, step):
					player.global_position += step
				step_timer = step_cooldown
		else:
			player.velocity = input_dir * movespeed
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

#We cannot allow a transition before the dash is complete and the animation has stopped playing
func Transition(newstate : String):
	if(dashspeed <= 0):
		state_transition.emit(self, newstate)
