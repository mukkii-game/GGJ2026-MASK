extends CharacterBase
class_name PlayerMain

@onready var fsm = $FSM as FiniteStateMachine
@onready var cam = $Camera2D
const DEATH_SCREEN = preload("res://Scenes/Misc/DeathScreen.tscn")

## マット内の移動範囲（赤ロープ32pxの内側、プレイヤー半径16pxのマージン）
const MAT_LEFT := 48
const MAT_RIGHT := 1232
const MAT_TOP := 48
const MAT_BOTTOM := 672
## カメラ固定位置（スクロールなし＝画面中心をこの座標に）
const CAM_CENTER := Vector2(640, 360)

## false=滑らか（初期） / true=カクカク。Gキーでトグル
var use_grid_movement := false

func _ready():
	super()
	if cam:
		cam.position_smoothing_enabled = false

func _process(_delta):
	super(_delta)
	if Input.is_action_just_pressed("ToggleGridMove"):
		use_grid_movement = not use_grid_movement
	# カメラ固定：マット外を見せない（スクロールなし）
	if cam:
		cam.global_position = CAM_CENTER
	# マット外には出さない
	var p := global_position
	global_position = Vector2(clampf(p.x, MAT_LEFT, MAT_RIGHT), clampf(p.y, MAT_TOP, MAT_BOTTOM))

func _die():
	super() #calls _die() on base-class CharacterBase
	
	fsm.force_change_state("Die")
	var death_scene = DEATH_SCREEN.instantiate()
	add_child(death_scene)
