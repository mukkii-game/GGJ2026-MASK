extends State
class_name PlayerWalking

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
## 左クリック自動走行：向き。ZEROで解除
var auto_run_direction := Vector2.ZERO
var auto_run_bounce_timer := 0.0

var player : CharacterBody2D
var player_main : PlayerMain
@export var animator : AnimationPlayer

func Enter():
	player = get_parent().get_parent() as CharacterBody2D
	player_main = player as PlayerMain
	animator.play("Walk")

func Exit():
	if player_main:
		player_main.is_run_dashing = false
		player_main.run_dash_direction = Vector2.ZERO
	if player_main and player_main.start_auto_run:
		player_main.start_auto_run = false
		var sprite = player_main.sprite
		auto_run_direction = Vector2.RIGHT if (sprite and sprite.scale.x >= 0) else Vector2.LEFT
		player_main.is_auto_running = true

func Update(delta : float):
	auto_run_bounce_timer -= delta
	var mv_left := "MoveLeft"
	var mv_right := "MoveRight"
	var mv_up := "MoveUp"
	var mv_down := "MoveDown"
	if player_main and player_main.is_player_two:
		mv_left = "Move2Left"
		mv_right = "Move2Right"
		mv_up = "Move2Up"
		mv_down = "Move2Down"
	var input_dir = Input.get_vector(mv_left, mv_right, mv_up, mv_down).normalized()
	if player_main and player_main.wants_jump():
		player_main.pending_headbutt_dir = Vector2.ZERO
		state_transition.emit(self, "Jump")
		return
	# Nボタン（2Pは左クリック）＝走る
	var dash_action := "Dash"
	if player_main and player_main.is_player_two:
		dash_action = "Punch2"
	if Input.is_action_just_pressed(dash_action) and player_main:
		if can_dash:
			start_dash(input_dir if input_dir.length() > 0 else (auto_run_direction if auto_run_direction != Vector2.ZERO else (Vector2.RIGHT if (player_main.sprite and player_main.sprite.scale.x >= 0) else Vector2.LEFT)))
		elif auto_run_direction == Vector2.ZERO and dashspeed <= 0 and input_dir.length() <= 0:
			player_main.start_auto_run = true
			state_transition.emit(self, "Moving")
		return
	if input_dir.length() > 0 and auto_run_direction != Vector2.ZERO:
		auto_run_direction = Vector2.ZERO
		if player_main:
			player_main.is_auto_running = false
	if player_main:
		player_main.is_auto_running = auto_run_direction != Vector2.ZERO
	Move(input_dir, delta)
	LessenDash(delta)
	
func Move(input_dir : Vector2, delta : float):
	if(dash_direction != Vector2.ZERO and dash_direction != input_dir):
		dash_direction = Vector2.ZERO
		dashspeed = 0

	if player_main and player_main.rope_bounce_running:
		player.velocity = Vector2.ZERO
		return

	if dashspeed > 0:
		player_main.is_run_dashing = true
		player_main.run_dash_direction = dash_direction
		var speed_mult: float = player_main.power_bait_speed_mult if player_main else 1.0
		player.velocity = input_dir * (float(movespeed) * speed_mult) + dash_direction * dashspeed
		player.move_and_slide()
		if input_dir.length() <= 0:
			Transition("Idle")
		return
	else:
		player_main.is_run_dashing = false

	if auto_run_direction != Vector2.ZERO and input_dir.length() <= 0:
		var speed_mult: float = player_main.power_bait_speed_mult if player_main else 1.0
		var run_speed := float(movespeed) * AUTO_RUN_SPEED_MULT * speed_mult
		player.velocity = auto_run_direction.normalized() * run_speed
		player.move_and_slide()
		return

	if input_dir.length() > 0:
		var speed_mult: float = player_main.power_bait_speed_mult if player_main else 1.0
		player.velocity = input_dir * (float(movespeed) * speed_mult)
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
	var multiplier : float = 4.0
	var timemultiplier : float = 4.1
	dashspeed -= (dashspeed * multiplier * delta) + (delta * timemultiplier)
	dashspeed = clamp(dashspeed, 0, dash_max)
	if dashspeed <= 0:
		can_dash = true
		dash_direction = Vector2.ZERO
		if player_main:
			player_main.is_run_dashing = false
			player_main.run_dash_direction = Vector2.ZERO

	if(animator.current_animation == "Dash"):
		await animator.animation_finished
		animator.play("Walk")

func Transition(newstate : String):
	if(dashspeed <= 0):
		state_transition.emit(self, newstate)
