extends State
class_name PlayerIdle

@export var animator : AnimationPlayer

func Enter():
	animator.play("Idle")
	pass
	
func Update(_delta : float):
	if(Input.get_vector("MoveLeft", "MoveRight", "MoveUp", "MoveDown").normalized()):
		state_transition.emit(self, "Moving")
	# Nボタン / 左クリック：ふつうモード＝自動走行開始、カクカク＝炎ダッシュ（押し続け）
	if Input.is_action_just_pressed("Punch"):
		var p = get_tree().get_first_node_in_group("Player") as PlayerMain
		if not p:
			return
		if p.use_grid_movement:
			# グリッド移動中は従来どおり炎ダッシュ
			state_transition.emit(self, "FireDash")
		else:
			# ふつうモード：一回押すと走る（向いている方向に自動走行）
			p.start_auto_run = true
			state_transition.emit(self, "Moving")
	# 攻撃は J（パンチ）K（キック）キー
	if Input.is_action_just_pressed("AttackPunch") or Input.is_action_just_pressed("AttackKick"):
		state_transition.emit(self, "Attacking")
