extends State
class_name enemy_bounce_state

## 一方向に走る速度
@export var move_speed: float = 120.0
## ロープ跳ね返り後の待ち時間（秒）
const ROPE_BOUNCE_DELAY := 0.5
const STEP_SIZE := 32
var _step_cooldown: float:
	get: return STEP_SIZE / move_speed

@export var animator : AnimationPlayer
@onready var body = get_parent().get_parent() as CharacterBody2D

var _direction := Vector2.RIGHT
var _bounce_timer := 0.0
var _step_timer := 0.0

func Enter():
	animator.play("Chasing")
	_direction = Vector2.RIGHT if randf() > 0.5 else Vector2.LEFT
	_bounce_timer = 0.0
	_step_timer = 0.0

func Update(delta: float):
	if GameManager.enemies_frozen:
		body.velocity = Vector2.ZERO
		body.move_and_slide()
		return
	if body.knockback_stun_remaining > 0:
		body.velocity = Vector2.ZERO
		body.move_and_slide()
		return
	if _bounce_timer > 0:
		_bounce_timer -= delta
		body.velocity = Vector2.ZERO
		if _bounce_timer <= 0:
			_direction = -_direction
			body.global_position += _direction * 4
		return

	# 敵の動きはカクカク/通常に依存せず常にスムーズ
	body.velocity = _direction * move_speed
	body.move_and_slide()
	var nc = body.get_slide_collision_count()
	for i in nc:
		var col = body.get_slide_collision(i)
		if not col:
			continue
		var collider = col.get_collider()
		if collider and collider.is_in_group("Rope"):
			body.velocity = Vector2.ZERO
			body.global_position -= _direction * 4
			_bounce_timer = ROPE_BOUNCE_DELAY
			AudioManager.play_sound(AudioManager.PLAYER_ATTACK_SWING, 0.1, 2)
			break
