extends State
class_name enemy_chase_state

## プレイヤーに向かう時間（秒）（ボスは長めに攻め続ける）
@export var chase_duration: float = 3.0
@export var attack_range: float = 50.0
@export var move_speed: float = 80.0

@export var animator : AnimationPlayer
@onready var body = $"../.."

var _chase_timer := 0.0
## 気合モード風の赤い色
const CHASE_MODULATE := Color(1.18, 0.55, 0.55, 1.0)

func Enter():
	animator.play("Chasing")
	_chase_timer = chase_duration
	# 接近・攻撃時は気合モードのように赤くする
	if body.sprite:
		body.sprite.modulate = CHASE_MODULATE

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
		# プレイヤーがまだ範囲内ならチェースを延長（ボスが攻め続ける）
		if body is EnemyMain and (body as EnemyMain).player_in_range:
			_chase_timer = chase_duration
		else:
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

	var speed_mult: float = (body as EnemyMain).state_speed_mult() if body is EnemyMain else 1.0
	body.velocity = chase_direction.normalized() * move_speed * speed_mult
	body.move_and_slide()

func Exit():
	if body.sprite:
		body.sprite.modulate = Color.WHITE
