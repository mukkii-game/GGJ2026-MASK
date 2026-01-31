extends State
class_name enemy_launched_state

## マット内の着地範囲（PlayerMain と同じ）
const MAT_LEFT := 296.0
const MAT_RIGHT := 984.0
const MAT_TOP := 48.0
const MAT_BOTTOM := 704.0
## 初速（上方向）
const LAUNCH_VY := -380.0
## 横方向の初速範囲
const LAUNCH_VX_MIN := -120.0
const LAUNCH_VX_MAX := 120.0
## 重力
const GRAVITY := 600.0

@onready var body = get_parent().get_parent() as CharacterBody2D
var _body_shape: CollisionShape2D
var _ground_y: float = 0.0

func Enter() -> void:
	if not body:
		state_transition.emit(self, "enemy_idle_state")
		return
	_ground_y = body.global_position.y
	body.velocity = Vector2(randf_range(LAUNCH_VX_MIN, LAUNCH_VX_MAX), LAUNCH_VY)
	_body_shape = body.get_node_or_null("BodyCollider") as CollisionShape2D
	if _body_shape:
		_body_shape.disabled = true
	body.z_index = 80

func Exit() -> void:
	if body and is_instance_valid(body):
		if _body_shape and is_instance_valid(_body_shape):
			_body_shape.disabled = false
		body.z_index = 0

func Update(delta: float) -> void:
	if not body:
		return
	body.velocity.y += GRAVITY * delta
	body.move_and_slide()
	if body.velocity.y >= 0 and body.global_position.y >= _ground_y:
		# 画面内のどこかに着地（Exit でコリジョン・z_index を戻す）
		body.global_position = Vector2(
			randf_range(MAT_LEFT, MAT_RIGHT),
			randf_range(MAT_TOP, MAT_BOTTOM)
		)
		body.velocity = Vector2.ZERO
		state_transition.emit(self, "enemy_idle_state")
