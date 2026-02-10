extends Node2D
signal finished(result: String) # "perfect" "good" "miss" "timeout"

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var result_label: Label = $ResultLabel

var active: bool = false
var resolved: bool = false

# タイミング調整用（各ステージごとにInspectorから変更可能）
@export_group("Timing")
@export var t_target: float = 0.5        # 重なりの中心（0〜1）
@export var perfect_window: float = 0.03 # PERFECT 判定の幅（厳しめ）
@export var good_window: float = 0.08    # GOOD 判定の幅（ゆるめ）

# 結果テキスト（各ステージで差し替え可能）
@export_group("Texts")
@export var text_perfect := "PERFECT"
@export var text_good := "GOOD"
@export var text_miss := "MISS"
@export var text_timeout := "TIME OUT"

# 使用するアニメーション名（ステージごとに差し替え可能）
# デフォルトでは qte_main_2.tscn に合わせて SUCCESS / FAIL を使う
@export_group("Animations")
@export var anim_in_name := "qte_in"
@export var anim_loop_name := "qte_loop"
@export var anim_perfect_name := "qte_success"
@export var anim_good_name := "qte_success"
@export var anim_miss_name := "qte_fail"
@export var anim_timeout_name := "qte_fail"

func start_qte():
	visible = true
	resolved = false
	active = false
	result_label.text = ""
	_play_anim(anim_in_name)

func qte_begin():
	active = true
	_play_anim(anim_loop_name)

func _unhandled_input(event):
	if not active or resolved:
		return
	if event.is_action_pressed("ui_accept"):
		_judge_and_finish()

func _judge_and_finish():
	resolved = true
	active = false

	var dur := anim.current_animation_length
	var pos := anim.current_animation_position
	var t := 0.0
	if dur > 0.0:
		t = clamp(pos / dur, 0.0, 1.0)

	var d := abs(t - t_target)

	if d <= perfect_window:
		_show_result(text_perfect)
		finished.emit("perfect")
		_play_anim(anim_perfect_name)
	elif d <= good_window:
		_show_result(text_good)
		finished.emit("good")
		_play_anim(anim_good_name)
	else:
		_show_result(text_miss)
		finished.emit("miss")
		_play_anim(anim_miss_name)

func qte_timeout():
	if resolved:
		return
	resolved = true
	active = false
	_show_result(text_timeout)
	finished.emit("timeout")
	_play_anim(anim_timeout_name)

func _show_result(text: String):
	result_label.text = text

func _play_anim(name: String) -> void:
	if name == "":
		return
	if anim.has_animation(name):
		anim.play(name)

func cleanup():
	visible = false
