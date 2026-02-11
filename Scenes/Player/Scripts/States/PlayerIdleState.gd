extends State
class_name PlayerIdle

@export var animator : AnimationPlayer

var player_main: PlayerMain

func Enter():
	animator.play("Idle")
	# 自分が所属するプレイヤーをキャッシュ
	var body = get_parent().get_parent()
	player_main = body as PlayerMain
	
func Update(_delta : float):
	var mv_left := "MoveLeft"
	var mv_right := "MoveRight"
	var mv_up := "MoveUp"
	var mv_down := "MoveDown"
	if player_main and player_main.is_player_two:
		mv_left = "Move2Left"
		mv_right = "Move2Right"
		mv_up = "Move2Up"
		mv_down = "Move2Down"
	if Input.get_vector(mv_left, mv_right, mv_up, mv_down).length() > 0.1:
		state_transition.emit(self, "Moving")
	# Mボタン＝ジャンプ（2PはJump2＝右クリック）
	var jump_action := "Jump"
	if player_main and player_main.is_player_two:
		jump_action = "Jump2"
	if Input.is_action_just_pressed(jump_action):
		state_transition.emit(self, "Jump")
	# Nボタン＝走る（向いている方向に自動走行開始）
	if Input.is_action_just_pressed("Dash"):
		var p := player_main
		if p:
			p.start_auto_run = true
			state_transition.emit(self, "Moving")
	# 攻撃はパンチ/キック
	var atk_punch := "AttackPunch"
	var atk_kick := "AttackKick"
	# 2Pはマウス左右クリックで攻撃ステートへ
	if player_main and player_main.is_player_two:
		atk_punch = "Punch2"
		atk_kick = "Kick2"
	if Input.is_action_just_pressed(atk_punch) or Input.is_action_just_pressed(atk_kick):
		state_transition.emit(self, "Attacking")
