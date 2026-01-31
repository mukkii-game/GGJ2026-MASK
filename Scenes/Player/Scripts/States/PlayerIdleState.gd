extends State
class_name PlayerIdle

@export var animator : AnimationPlayer

func Enter():
	animator.play("Idle")

func Update(_delta : float):
	if Input.get_vector("MoveLeft", "MoveRight", "MoveUp", "MoveDown").normalized():
		state_transition.emit(self, "Moving")
	# 左クリック：方向キーあり＝ダッシュ（0.5秒3倍速・連打で延長）、なし＝ジャンプ
	if Input.is_action_just_pressed("Punch"):
		var input_dir = Input.get_vector("MoveLeft", "MoveRight", "MoveUp", "MoveDown").normalized()
		var p = get_tree().get_first_node_in_group("Player") as PlayerMain
		if input_dir.length() > 0 and p:
			p.dash_timer = p.DASH_DURATION
			state_transition.emit(self, "Moving")
		else:
			state_transition.emit(self, "Jump")
	# 攻撃は J（パンチ）K（キック）キー
	if Input.is_action_just_pressed("AttackPunch") or Input.is_action_just_pressed("AttackKick"):
		state_transition.emit(self, "Attacking")
