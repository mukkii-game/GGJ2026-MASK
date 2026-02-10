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
	if(Input.get_vector(mv_left, mv_right, mv_up, mv_down).normalized()):
		state_transition.emit(self, "Moving")
	# Nボタン / 左クリック：ふつうモード＝自動走行開始、カクカク＝炎ダッシュ（押し続け）
	var jump_action := "Punch"
	if player_main and player_main.is_player_two:
		jump_action = "Punch2"
	if Input.is_action_just_pressed(jump_action):
		var p := player_main
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
	var atk_punch := "AttackPunch"
	var atk_kick := "AttackKick"
	# 2Pはマウス左右クリックで攻撃ステートへ
	if player_main and player_main.is_player_two:
		atk_punch = "Punch2"
		atk_kick = "Kick2"
	if Input.is_action_just_pressed(atk_punch) or Input.is_action_just_pressed(atk_kick):
		state_transition.emit(self, "Attacking")
