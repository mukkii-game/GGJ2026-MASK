extends State
class_name enemy_down_state

## ダウン状態：動かず攻撃せず、赤フラッシュのまま（移行条件は後でアルゴリズムで与える）

@export var animator: AnimationPlayer
var body: EnemyMain

func Enter() -> void:
	body = get_parent().get_parent() as EnemyMain
	if not body:
		return
	if animator:
		animator.play("Idle")
	# 赤フラッシュのまま（ダメージ表現）
	if body.sprite:
		body.sprite.modulate = Color(1.4, 0.4, 0.4, 1.0)

func Exit() -> void:
	if body and body.sprite and is_instance_valid(body.sprite):
		body.sprite.modulate = Color.WHITE

func Update(_delta: float) -> void:
	# 何もしない（動かない・攻撃しない）
	pass
