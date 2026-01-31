extends Node2D

@onready var player_point = $PlayerPoint
@onready var target_zone = $TargetZone
@onready var result_label = $ResultLabel

var speed = 500.0
var is_active = true
var is_overlapping = false # これが「接触中か」を判定するフラグ

func _ready():
	# 接触イベント（シグナル）の接続
	target_zone.area_entered.connect(_on_area_entered)
	target_zone.area_exited.connect(_on_area_exited)
	result_label.text = ""

func _process(delta):
	if not is_active:
		return

	# ポイントを右へ移動
	player_point.position.x += speed * delta

	# スペースキー（ui_accept）が押された瞬間の判定
	if Input.is_action_just_pressed("ui_accept"):
		if is_overlapping:
			success_game()
		else:
			fail_game()

	# 画面の右端（ビューポートのサイズ）を超えたら失敗
	if player_point.position.x > get_viewport_rect().size.x:
		fail_game()

# エリアに入った時に呼ばれる
func _on_area_entered(_area):
	is_overlapping = true

# エリアから出た時に呼ばれる
func _on_area_exited(_area):
	is_overlapping = false

func success_game():
	is_active = false
	result_label.text = "SUCCESS!"
	exit_sequence()

func fail_game():
	is_active = false
	result_label.text = "FAIL..."
	exit_sequence()

func exit_sequence():
	# 2秒待ってからプログラムを終了
	await get_tree().create_timer(2.0).timeout
	get_tree().quit()
