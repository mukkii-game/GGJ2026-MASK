extends State
class_name enemy_patrol_state

## 往復の距離（ピクセル）
@export var patrol_distance := 80.0
## 左右=true, 上下=false
@export var axis_horizontal := true
@export var move_speed := 60.0
## この秒数でIdleに戻る（0で無制限）
@export var patrol_duration := 4.0

@export var animator : AnimationPlayer
@onready var body = get_parent().get_parent() as CharacterBody2D

var _start_pos := Vector2.ZERO
var _dir := 1.0
var _timer := 0.0

func _use_horizontal() -> bool:
	if body is EnemyMain:
		return not (body as EnemyMain).patrol_vertical
	return axis_horizontal

func Enter():
	animator.play("Chasing")
	_start_pos = body.global_position
	_dir = 1.0
	_timer = patrol_duration

func Update(delta: float):
	if GameManager.enemies_frozen:
		body.velocity = Vector2.ZERO
		body.move_and_slide()
		return
	if body.knockback_stun_remaining > 0:
		body.velocity = Vector2.ZERO
		body.move_and_slide()
		return
	# 上下/左右ループの場合はIdleに戻らない（patrol_duration 無視）
	var is_loop := body is EnemyMain and ((body as EnemyMain).behavior_type == EnemyMain.Behavior.VerticalLoop or (body as EnemyMain).behavior_type == EnemyMain.Behavior.HorizontalLoop)
	if not is_loop and patrol_duration > 0.0:
		_timer -= delta
		if _timer <= 0.0:
			state_transition.emit(self, "enemy_idle_state")
			return

	var use_h := _use_horizontal()
	var offset: Vector2
	if use_h:
		offset = Vector2((body.global_position - _start_pos).x, 0)
	else:
		offset = Vector2(0, (body.global_position - _start_pos).y)

	var len = offset.x if use_h else offset.y
	if len >= patrol_distance:
		_dir = -1.0
	elif len <= -patrol_distance:
		_dir = 1.0

	if use_h:
		body.velocity = Vector2(_dir * move_speed, 0)
	else:
		body.velocity = Vector2(0, _dir * move_speed)
	body.move_and_slide()
