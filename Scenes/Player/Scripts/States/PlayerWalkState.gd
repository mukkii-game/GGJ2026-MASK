extends State
class_name PlayerWalking

## グリッドごとワープ：1ステップのピクセル数（半キャラ＝16）
const STEP_SIZE := 16
## 1ステップごとの間隔（秒）。小さくすると速く動く
@export var step_cooldown := 0.12

@export var movespeed := int(350)
@export var dash_max := int(500)
var dashspeed := float(100)
var can_dash := bool(false)
var dash_direction := Vector2(0,0)
var step_timer := 0.0

var player : CharacterBody2D
@export var animator : AnimationPlayer

func Enter():
	player = get_tree().get_first_node_in_group("Player")
	animator.play("Walk")

func Update(delta : float):
	step_timer -= delta
	var input_dir = Input.get_vector("MoveLeft", "MoveRight", "MoveUp", "MoveDown").normalized()
	Move(input_dir, delta)
	LessenDash(delta)

	if(Input.is_action_just_pressed("Dash") && can_dash):
		start_dash(input_dir)
		
	if Input.is_action_just_pressed("Punch") or Input.is_action_just_pressed("Kick"):
		Transition("Attacking")
	
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

	# 通常時：グリッドONなら16pxワープ、OFFなら滑らか移動（狭い道用）
	if input_dir.length() > 0:
		player.velocity = input_dir
		var use_grid: bool = (player as PlayerMain).use_grid_movement if player is PlayerMain else false
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
