extends State
class_name PlayerIdle

@export var animator : AnimationPlayer

func Enter():
	animator.play("Idle")
	pass
	
func Update(_delta : float):
	if(Input.get_vector("MoveLeft", "MoveRight", "MoveUp", "MoveDown").normalized()):
		state_transition.emit(self, "Moving")
	# 左クリック（ジャンプボタン）：ふつうモード＝ジャンプ（十字キー入っていてもジャンプ）、カクカク＝小ダッシュ＋炎
	if Input.is_action_just_pressed("Punch"):
		var p = get_tree().get_first_node_in_group("Player") as PlayerMain
		if p and p.use_grid_movement:
			state_transition.emit(self, "FireDash")
		else:
			state_transition.emit(self, "Jump")
	# 攻撃は J（パンチ）K（キック）キー
	if Input.is_action_just_pressed("AttackPunch") or Input.is_action_just_pressed("AttackKick"):
		state_transition.emit(self, "Attacking")
