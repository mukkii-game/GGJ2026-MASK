extends Node2D

@onready var player_point = $PlayerPoint
@onready var target_zone = $TargetZone
@onready var result_label = $ResultLabel
@onready var anim: AnimationPlayer = $QTEAnimationPlayer
@onready var hit_hip: AudioStreamPlayer2D = $hit_hip

var speed = 500.0
var is_active = false
var is_overlapping = false # これが「接触中か」を判定するフラグ

var player_start_pos: Vector2


func _ready():
	# PlayerPointの開始位置を記録
	player_start_pos = player_point.position

	# 接触イベント（シグナル）の接続
	target_zone.area_entered.connect(_on_area_entered)
	target_zone.area_exited.connect(_on_area_exited)
	result_label.text = ""

	# シーン開始と同時に毎回スタート（PlayerPoint開始とアニメ開始を同期）
	start_qte()


func start_qte():
	# PlayerPointを開始位置に戻す
	player_point.position = player_start_pos

	# 状態リセット
	is_overlapping = false
	result_label.text = ""

	# QTEを有効化（_processが動き出す）
	is_active = true

	# アニメも同時に先頭から再生
	anim.play("attack")   # ←アニメ名が違う場合はここを修正
	anim.seek(0.0, true)  # 念のため0秒から即反映


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

	# ★ 成功音を鳴らす
	hit_hip.play()

	anim.stop()
	result_label.text = "SUCCESS!"
	exit_sequence()



func fail_game():
	is_active = false
	anim.stop()
	result_label.text = "FAIL..."
	exit_sequence()


func exit_sequence():
	# 2秒待ってからプログラムを終了
	await get_tree().create_timer(2.0).timeout
	get_tree().quit()
