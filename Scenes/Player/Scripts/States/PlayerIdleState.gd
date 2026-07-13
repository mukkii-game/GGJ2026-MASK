extends State
class_name PlayerIdle

@export var animator : AnimationPlayer

var player_main: PlayerMain

func Enter():
	animator.play("Idle")
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
	if player_main and player_main.wants_jump():
		state_transition.emit(self, "Jump")
	# Nボタン（2Pは左クリック）＝自動走行（SPEC B.5.1）
	var dash_action := "Dash"
	if player_main and player_main.is_player_two:
		dash_action = "Punch2"
	if Input.is_action_just_pressed(dash_action) and player_main:
		player_main.start_auto_run = true
		state_transition.emit(self, "Moving")
