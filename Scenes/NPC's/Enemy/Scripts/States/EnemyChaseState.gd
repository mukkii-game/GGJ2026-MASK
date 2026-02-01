extends State
class_name enemy_chase_state

## プレイヤーに向かう時間（秒）
@export var chase_duration := 3.0
@export var attack_range := float(50)
@export var move_speed := float(80)

@export var animator : AnimationPlayer
@onready var body = $"../.."

var _chase_timer := 0.0

func Enter():
	animator.play("Chasing")
	_chase_timer = chase_duration

func Update(delta: float):
	if GameManager.enemies_frozen:
		body.velocity = Vector2.ZERO
		body.move_and_slide()
		return
	if body.knockback_stun_remaining > 0:
		body.velocity = Vector2.ZERO
		body.move_and_slide()
		return
	_chase_timer -= delta
	if _chase_timer <= 0.0:
		state_transition.emit(self, "enemy_idle_state")
		return

	var player = get_tree().get_first_node_in_group("Player") as CharacterBody2D
	if not player:
		state_transition.emit(self, "enemy_idle_state")
		return
	var chase_direction = player.global_position - body.global_position

	if chase_direction.length() <= attack_range:
		state_transition.emit(self, "enemy_attack_state")
		return

	body.velocity = chase_direction.normalized() * move_speed
	body.move_and_slide()
