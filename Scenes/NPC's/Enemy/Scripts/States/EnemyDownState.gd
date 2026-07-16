extends State
class_name enemy_down_state

## ダウン（寝）状態：確定仕様v1.0
## - 横倒れ（スプライト90度回転）＋赤めの色で「寝ている」表現
## - down_remaining（EnemyMain）を減算し、0で起き上がり → 2秒だけ弱り（起き上がりの隙）
## - ダウン中はプレスとの追撃対象（無敵ではない）。体当たり接触からは除外（PlayerMain側でスキップ）

@export var animator: AnimationPlayer
var body: EnemyMain

func Enter() -> void:
	body = get_parent().get_parent() as EnemyMain
	if not body:
		return
	if animator:
		animator.play("Idle")
	body.velocity = Vector2.ZERO
	# 横倒れ＋赤フラッシュのまま（ダメージ表現）
	if body.sprite:
		body.sprite.modulate = Color(1.4, 0.4, 0.4, 1.0)
		body.sprite.rotation_degrees = 90.0

func Exit() -> void:
	if body and body.sprite and is_instance_valid(body.sprite):
		body.sprite.modulate = Color.WHITE
		body.sprite.rotation_degrees = 0.0

func Update(delta: float) -> void:
	if not body:
		return
	body.down_remaining -= delta
	if body.down_remaining <= 0.0:
		body.down_remaining = 0.0
		# 起き上がりの隙＝短い弱り（確定仕様: WAKEUP_WEAK_SEC）
		body.set_weak_for(body.WAKEUP_WEAK_SEC)
		state_transition.emit(self, "enemy_idle_state")
