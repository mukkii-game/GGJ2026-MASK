extends Control
signal finished(result: String) # "perfect" "good" "miss" "timeout"

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var result_label: Label = $ResultLabel

var active := false
var resolved := false

# 調整用
var t_target := 0.5        # 重なりの中心（0〜1）
var perfect_window := 0.03 # 厳しめ
var good_window := 0.08    # ゆるめ

func start_qte():
	visible = true
	resolved = false
	active = false
	result_label.text = ""
	anim.play("qte_in")

func qte_begin():
	active = true
	anim.play("qte_loop")

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
		_show_result("PERFECT")
		finished.emit("perfect")
		anim.play("qte_perfect")
	elif d <= good_window:
		_show_result("GOOD")
		finished.emit("good")
		anim.play("qte_good")
	else:
		_show_result("MISS")
		finished.emit("miss")
		anim.play("qte_miss")

func qte_timeout():
	if resolved:
		return
	resolved = true
	active = false
	_show_result("TIME OUT")
	finished.emit("timeout")
	anim.play("qte_miss")

func _show_result(text: String):
	result_label.text = text

func cleanup():
	visible = false
