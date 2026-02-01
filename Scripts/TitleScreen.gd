extends Control
## タイトル画面。「スタート」（本番）と「テスト」（簡単）の2つのモード。

func _ready() -> void:
	# Point_pic.pngを使用（マスクのアイコン）
	var tex_rect = get_node_or_null("MaskIcon")
	if tex_rect:
		var path := "res://Art/Sprites/Point_pic.png"
		if ResourceLoader.exists(path):
			tex_rect.texture = load(path) as Texture2D
	
	# ボタンのシグナル接続
	var start_btn = get_node_or_null("StartButton")
	if start_btn:
		start_btn.pressed.connect(_on_start_pressed)
	
	var test_btn = get_node_or_null("TestButton")
	if test_btn:
		test_btn.pressed.connect(_on_test_pressed)

## 本番バランスでスタート
func _on_start_pressed() -> void:
	GameManager.test_mode = false
	_start_game()

## テストバランスでスタート
func _on_test_pressed() -> void:
	GameManager.test_mode = true
	_start_game()

func _start_game() -> void:
	# ステージ1登場画面へ
	get_tree().change_scene_to_file("res://Scenes/UI/StageIntro.tscn")
