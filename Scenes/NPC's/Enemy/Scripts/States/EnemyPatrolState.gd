extends State
class_name enemy_patrol_state

## 往復の距離（ピクセル）
@export var patrol_distance: float = 80.0
## 左右=true, 上下=false
@export var axis_horizontal: bool = true
@export var move_speed: float = 60.0
## この秒数でIdleに戻る（0で無制限）
@export var patrol_duration: float = 4.0

@export var animator : AnimationPlayer
@onready var body = get_parent().get_parent() as CharacterBody2D

var _start_pos := Vector2.ZERO
var _dir := 1.0
var _timer := 0.0

func _use_horizontal() -> bool:
	if body is EnemyMain:
		return not (body as EnemyMain).patrol_vertical
	return axis_horizontal

func _get_patrol_distance() -> float:
	if body is EnemyMain and (body as EnemyMain).patrol_distance_override > 0.0:
		return (body as EnemyMain).patrol_distance_override
	return patrol_distance

func _get_patrol_speed() -> float:
	if body is EnemyMain and (body as EnemyMain).patrol_speed_override > 0.0:
		return (body as EnemyMain).patrol_speed_override
	return move_speed

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
	# プレイヤーが範囲内なら接近・攻撃（チェース）へ
	if body is EnemyMain and (body as EnemyMain).player_in_range:
		state_transition.emit(self, "enemy_chase_state")
		return
	# 上下/左右ループの場合はIdleに戻らない（patrol_duration 無視）
	var is_loop := body is EnemyMain and ((body as EnemyMain).behavior_type == EnemyMain.Behavior.VerticalLoop or (body as EnemyMain).behavior_type == EnemyMain.Behavior.HorizontalLoop)
	if not is_loop and patrol_duration > 0.0:
		_timer -= delta
		if _timer <= 0.0:
			state_transition.emit(self, "enemy_idle_state")
			return

	var use_h := _use_horizontal()
	var dist := _get_patrol_distance()
	var spd := _get_patrol_speed()
	# ロープ間往復：マット端の手前で反転（端に張り付かないようマージンを使う）
	const ROPE_MARGIN := 32.0
	if body is EnemyMain:
		var en := body as EnemyMain
		if use_h:
			if body.global_position.x >= EnemyMain.MAT_RIGHT - ROPE_MARGIN and _dir > 0:
				_dir = -1.0
			elif body.global_position.x <= EnemyMain.MAT_LEFT + ROPE_MARGIN and _dir < 0:
				_dir = 1.0
		else:
			if body.global_position.y >= EnemyMain.MAT_BOTTOM - ROPE_MARGIN and _dir > 0:
				_dir = -1.0
			elif body.global_position.y <= EnemyMain.MAT_TOP + ROPE_MARGIN and _dir < 0:
				_dir = 1.0
	else:
		var offset: Vector2
		if use_h:
			offset = Vector2((body.global_position - _start_pos).x, 0)
		else:
			offset = Vector2(0, (body.global_position - _start_pos).y)
		var len = offset.x if use_h else offset.y
		if len >= dist:
			_dir = -1.0
		elif len <= -dist:
			_dir = 1.0

	if body is EnemyMain:
		spd *= (body as EnemyMain).state_speed_mult()
	if use_h:
		body.velocity = Vector2(_dir * spd, 0)
	else:
		body.velocity = Vector2(0, _dir * spd)
	body.move_and_slide()
