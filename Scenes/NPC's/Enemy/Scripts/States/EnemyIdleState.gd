extends State
class_name enemy_idle_state

## 次の行動（Patrol/Wander）に移るまでの待ち時間（秒）
@export var idle_duration := 1.5

@export var animator : AnimationPlayer
var _timer := 0.0
@onready var enemy: EnemyMain = get_parent().get_parent()

func Enter():
	animator.play("Idle")
	_timer = idle_duration

func Update(delta: float):
	# Chase/Charge タイプは Idle のまま（検知で Chase/Charge に遷移）
	if enemy and (enemy.behavior_type == EnemyMain.Behavior.Chase or enemy.behavior_type == EnemyMain.Behavior.Charge):
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = idle_duration
		if randf() < 0.5:
			state_transition.emit(self, "enemy_patrol_state")
		else:
			state_transition.emit(self, "enemy_wander_state")
