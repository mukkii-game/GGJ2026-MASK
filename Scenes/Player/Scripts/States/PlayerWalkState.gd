extends State
class_name PlayerWalking

## グリッドごとワープ：1ステップのピクセル数（半キャラ＝32）
const STEP_SIZE := 32
## 1ステップごとの間隔（秒）。小さくすると速く動く
@export var step_cooldown: float = 0.08
## ロープ跳ね返り後の待ち時間（秒）
const ROPE_BOUNCE_DELAY := 0.5
## 走り（N）時は通常の何倍速か（ちょっとだけ早い）
const AUTO_RUN_SPEED_MULT := 1.3

@export var movespeed: int = 480
## 走り（N）の速度（ちょっとだけ早い）。ロープで跳ね返る
@export var dash_max: int = 640
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
	# 自分の親（FSMの親）がぶら下がっているプレイヤー本体を取得
	player = get_parent().get_parent() as CharacterBody2D
	player_main = player as PlayerMain
	animator.play("Walk")

func Exit():
	if player_main:
		player_main.is_run_dashing = false
		if player_main.sprite:
			player_main.sprite.rotation = 0.0
	if player_main and player_main.start_auto_run:
		player_main.start_auto_run = false
		var sprite = player_main.sprite
		auto_run_direction = Vector2.RIGHT if (sprite and sprite.scale.x >= 0) else Vector2.LEFT
		# 自動走行フラグ（風エフェクト用）
		player_main.is_auto_running = true

func Update(delta : float):
	step_timer -= delta
	auto_run_bounce_timer -= delta
	var mv_left := "MoveLeft"
	var mv_right := "MoveRight"
	var mv_up := "MoveUp"
	var mv_down := "MoveDown"
	var jump_action := "Jump"
	if player_main and player_main.is_player_two:
		mv_left = "Move2Left"
		mv_right = "Move2Right"
		mv_up = "Move2Up"
		mv_down = "Move2Down"
		jump_action = "Jump2"
	var input_dir = Input.get_vector(mv_left, mv_right, mv_up, mv_down).normalized()
	# Mボタン＝ジャンプ
	if Input.is_action_just_pressed(jump_action):
		state_transition.emit(self, "Jump")
		return
	# Nボタン＝走る（押すとダッシュ開始。方向がなければ向いている方向へ自動走行）
	if Input.is_action_just_pressed("Dash") and player_main:
		if can_dash:
			start_dash(input_dir if input_dir.length() > 0 else (auto_run_direction if auto_run_direction != Vector2.ZERO else (Vector2.RIGHT if (player_main.sprite and player_main.sprite.scale.x >= 0) else Vector2.LEFT)))
		elif auto_run_direction == Vector2.ZERO and dashspeed <= 0 and input_dir.length() <= 0:
			player_main.start_auto_run = true
			state_transition.emit(self, "Moving")
		return
	# 移動キーを入れると自動走行解除
	if input_dir.length() > 0 and auto_run_direction != Vector2.ZERO:
		auto_run_direction = Vector2.ZERO
		if player_main:
			player_main.is_auto_running = false
	# 自動走行中フラグ更新（風エフェクト用）
	if player_main:
		player_main.is_auto_running = auto_run_direction != Vector2.ZERO
	if Input.is_action_just_pressed("AttackPunch") or Input.is_action_just_pressed("AttackKick"):
		Transition("Attacking")
	else:
		Move(input_dir, delta)
	LessenDash(delta)
	
func Move(input_dir : Vector2, delta : float):
	#Suddenly turning mid dash
	if(dash_direction != Vector2.ZERO and dash_direction != input_dir):
		dash_direction = Vector2.ZERO
		dashspeed = 0

	# ロープバウンス自動移動中は、ここでは一切動かさない（PlayerMain 側で処理）
	if player_main and player_main.rope_bounce_running:
		player.velocity = Vector2.ZERO
		return

	# ダッシュ中は従来どおり速度移動（壁は move_and_slide が止める）
	if dashspeed > 0:
		player_main.is_run_dashing = true
		# 前傾回転（昔の漫画風・進行方向に少し傾ける）
		if player_main.sprite:
			var lean := -0.14  # 前傾（ラジアン）
			player_main.sprite.rotation = lean if dash_direction.x >= 0 else -lean
		player.velocity = input_dir * movespeed + dash_direction * dashspeed
		player.move_and_slide()
		if input_dir.length() <= 0:
			Transition("Idle")
		return
	else:
		player_main.is_run_dashing = false
		if player_main.sprite:
			player_main.sprite.rotation = 0.0

	# 自動走行中：方向入力がなく auto_run_direction が有効なあいだ走り続ける
	if auto_run_direction != Vector2.ZERO and input_dir.length() <= 0:
		var run_speed := float(movespeed) * AUTO_RUN_SPEED_MULT
		player.velocity = auto_run_direction.normalized() * run_speed
		player.move_and_slide()
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
	
	if dashspeed <= 0:
		can_dash = true
		dash_direction = Vector2.ZERO
		if player_main:
			player_main.is_run_dashing = false
			if player_main.sprite:
				player_main.sprite.rotation = 0.0

	if(animator.current_animation == "Dash"):
		await animator.animation_finished
		animator.play("Walk")

#We cannot allow a transition before the dash is complete and the animation has stopped playing
func Transition(newstate : String):
	if(dashspeed <= 0):
		state_transition.emit(self, newstate)

