extends State
class_name enemy_wander_state

## ランダム移動の範囲半径（ピクセル）
@export var wander_radius := 100.0
@export var move_speed := 50.0
const STEP_SIZE := 32
var _step_cooldown: float:
	get: return STEP_SIZE / move_speed

@export var animator : AnimationPlayer
@onready var body = get_parent().get_parent() as CharacterBody2D

var _start_pos := Vector2.ZERO
var _target := Vector2.ZERO
var _has_target := false
var _step_timer := 0.0

func Enter():
	animator.play("Chasing")
	_start_pos = body.global_position
	_pick_new_target()
	_step_timer = 0.0

func _pick_new_target():
	var angle = randf() * TAU
	var r = randf() * wander_radius
	_target = _start_pos + Vector2(cos(angle), sin(angle)) * r
	_has_target = true

func Update(delta: float):
	if not _has_target:
		return
	var to_target: Vector2 = _target - body.global_position
	if to_target.length() < 8.0:
		_has_target = false
		state_transition.emit(self, "enemy_idle_state")
		return
	# 敵の動きはカクカク/通常に依存せず常にスムーズ
	body.velocity = to_target.normalized() * move_speed
	body.move_and_slide()
