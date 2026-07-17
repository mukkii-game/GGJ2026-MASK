extends State
class_name enemy_idle_state

## 次の行動（Patrol/Wander）に移るまでの待ち時間（秒）
@export var idle_duration: float = 1.5

@export var animator : AnimationPlayer
var _timer := 0.0
@onready var enemy = $"../.." as EnemyMain

func Enter():
	animator.play("Idle")
	_timer = idle_duration

func Update(delta: float):
	# 敵全員凍結モード時は動かない
	if GameManager.enemies_frozen:
		return
	# ポスト上待機中はIdleのまま（StageControllerのend_perchで降臨するまで動かない）
	if enemy and enemy.is_perched:
		return
	# プレイヤーが範囲内なら接近・攻撃（チェース）へ
	if enemy and enemy.player_in_range:
		state_transition.emit(self, "enemy_chase_state")
		return
	# 静止タイプは Idle のまま（遷移しない）
	if enemy and enemy.behavior_type == EnemyMain.Behavior.Idle:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = idle_duration
		# 往復とランダムをランダムで切り替え
		if randf() < 0.5:
			state_transition.emit(self, "enemy_patrol_state")
		else:
			state_transition.emit(self, "enemy_wander_state")
