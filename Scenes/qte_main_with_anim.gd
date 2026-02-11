extends Node2D
## QTEコア。成功/失敗でシグナルを発行。ゲーム内では親が add_child して start_qte() を呼ぶ。

signal qte_succeeded
signal qte_failed

@onready var player_point = $PlayerPoint
@onready var run_sprite: Sprite2D = $PlayerPoint/CollisionShape2D/sprite
@onready var target_zone = $TargetZone
@onready var result_label = $ResultLabel
@onready var anim: AnimationPlayer = $QTEAnimationPlayer
@onready var hit_hip: AudioStreamPlayer2D = $hit_hip

var speed = 500.0
var is_active = false
var is_overlapping = false # これが「接触中か」を判定するフラグ
## QTE右走り用2パターン（m_man_g_l1 / m_man_g_l2）
var _tex_l1: Texture2D
var _tex_l2: Texture2D
var _pattern_timer := 0.0
const PATTERN_INTERVAL := 0.12

var player_start_pos: Vector2
## 親がスタートを制御する場合は true（ゲーム内ボス撃破QTE用）
var wait_for_start: bool = false


func _ready():
	# PlayerPointの開始位置を記録
	player_start_pos = player_point.position
	# 右走り用2パターン読み込み（m_man_g_l1 / m_man_g_l2）
	if ResourceLoader.exists("res://Art/Sprites/m_man_g_l1.png"):
		_tex_l1 = load("res://Art/Sprites/m_man_g_l1.png") as Texture2D
	if ResourceLoader.exists("res://Art/Sprites/m_man_g_l2.png"):
		_tex_l2 = load("res://Art/Sprites/m_man_g_l2.png") as Texture2D
	if not _tex_l2:
		_tex_l2 = _tex_l1

	# 接触イベント（シグナル）の接続
	target_zone.area_entered.connect(_on_area_entered)
	target_zone.area_exited.connect(_on_area_exited)
	result_label.text = ""

	# 単体実行時は即スタート、ゲーム内から呼ばれた場合は start_qte() を待つ
	if not wait_for_start:
		start_qte()


func start_qte():
	# PlayerPointを開始位置に戻す
	player_point.position = player_start_pos
	if run_sprite and _tex_l1:
		run_sprite.texture = _tex_l1

	# 状態リセット
	_pattern_timer = 0.0
	is_overlapping = false
	result_label.text = ""
	result_label.remove_theme_font_size_override("font_size")
	result_label.remove_theme_color_override("font_color")
	result_label.remove_theme_color_override("font_outline_color")
	result_label.remove_theme_constant_override("outline_size")

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

	# 右走り2パターンアニメ（l1/l2切り替え）
	_pattern_timer += delta
	if _pattern_timer >= PATTERN_INTERVAL:
		_pattern_timer = 0.0
		if run_sprite and _tex_l1 and _tex_l2:
			run_sprite.texture = _tex_l2 if run_sprite.texture == _tex_l1 else _tex_l1

	# いずれかのボタンが押された瞬間の判定（スペース・パンチ・キック・Enterなど）
	var qte_pressed := (
		Input.is_action_just_pressed("ui_accept") or
		Input.is_action_just_pressed("Punch") or
		Input.is_action_just_pressed("Kick") or
		Input.is_action_just_pressed("Dash") or
		Input.is_action_just_pressed("Enter")
	)
	if qte_pressed:
		if is_overlapping:
			success_game()
		else:
			fail_game()

	# 画面の右端（ビューポートのサイズ）を超えたら失敗
	if player_point.position.x > get_viewport_rect().size.x:
		fail_game()


# エリアに入った時に呼ばれる
func _on_area_entered(area):
	if area == player_point:
		is_overlapping = true


# エリアから出た時に呼ばれる
func _on_area_exited(area):
	if area == player_point:
		is_overlapping = false


func success_game():
	is_active = false
	if hit_hip:
		hit_hip.play()
	anim.stop()
	_show_result("SUCCESS!", true)
	qte_succeeded.emit()
	exit_sequence()


func fail_game():
	is_active = false
	anim.stop()
	_show_result("FAIL...", false)
	qte_failed.emit()
	exit_sequence()


func _show_result(text: String, is_success: bool) -> void:
	result_label.text = text
	# バーンと出す：でかい赤くて太い文字
	result_label.add_theme_font_size_override("font_size", 120)
	result_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15, 1.0))
	result_label.add_theme_color_override("font_outline_color", Color(0.4, 0.0, 0.0, 1.0))
	result_label.add_theme_constant_override("outline_size", 12)


func exit_sequence():
	# 2秒待ってから閉じる（ゲーム内の場合は親が remove_child するまで表示）
	await get_tree().create_timer(2.0).timeout
	# ゲーム内から呼ばれた場合は quit しない
	if not wait_for_start:
		get_tree().quit()
	else:
		queue_free()
