extends Node2D
## QTEシーンのスクリプト。StageController から qte_core.tscn 経由で使われる。
## シグナル qte_succeeded / qte_failed を emit し、呼び元が結果を処理する。

signal qte_succeeded
signal qte_failed

@onready var player_point = $PlayerPoint
@onready var target_zone = $TargetZone
@onready var result_label = $ResultLabel

var speed = 500.0
var is_active = false
var is_overlapping = false
## true にしてからstart_qte()で開始（StageControllerが設定する）
@export var wait_for_start: bool = false

func _ready():
	target_zone.area_entered.connect(_on_area_entered)
	target_zone.area_exited.connect(_on_area_exited)
	result_label.text = ""
	if not wait_for_start:
		is_active = true

func start_qte() -> void:
	is_active = true

func _process(delta):
	if not is_active:
		return

	player_point.position.x += speed * delta

	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("QTE_Q"):
		if is_overlapping:
			_on_success()
		else:
			_on_fail()

	if player_point.position.x > get_viewport_rect().size.x:
		_on_fail()

func _on_area_entered(_area):
	is_overlapping = true

func _on_area_exited(_area):
	is_overlapping = false

func _on_success():
	is_active = false
	result_label.text = "SUCCESS!"
	qte_succeeded.emit()
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(self):
		queue_free()

func _on_fail():
	is_active = false
	result_label.text = "FAIL..."
	qte_failed.emit()
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(self):
		queue_free()
