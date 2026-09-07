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
	# 横倒れ＋赤フラッシュ（ダメージ表現）
	# 足元（影・マット）の高さ（+24px）へスプライト位置を下げてマット上に接地させる
	if body.sprite:
		body.sprite.modulate = Color(1.4, 0.4, 0.4, 1.0)
		body.sprite.rotation_degrees = 90.0
		body.sprite.position.y = 24.0

func Exit() -> void:
	if body and body.sprite and is_instance_valid(body.sprite):
		body.sprite.modulate = body.body_tint if "body_tint" in body else Color.WHITE
		body.sprite.rotation_degrees = 0.0
		body.sprite.position.y = 0.0

func Update(delta: float) -> void:
	if not body:
		return
	# QTE中・クリア演出中はダウンのまま静止（起き上がりカウントも止める）
	if GameManager.enemies_frozen:
		return
	# ボスHP0フィニッシュ待ちは起き上がらない（ジャンプまで寝る）
	if body.awaiting_finisher:
		return
	body.down_remaining -= delta
	if body.down_remaining <= 0.0:
		body.down_remaining = 0.0
		var next_state := "enemy_idle_state"
		if body.behavior_type == EnemyMain.Behavior.Flee:
			next_state = "enemy_flee_state"
		elif body.behavior_type in [EnemyMain.Behavior.RandomRange, EnemyMain.Behavior.Yotayota, EnemyMain.Behavior.SineWave, EnemyMain.Behavior.SlowApproach]:
			next_state = "enemy_wander_state"
		elif body.behavior_type in [EnemyMain.Behavior.VerticalLoop, EnemyMain.Behavior.HorizontalLoop]:
			next_state = "enemy_patrol_state"
		state_transition.emit(self, next_state)
