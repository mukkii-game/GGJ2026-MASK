extends Control
## タイトル画面。「スタート」（本番）と「テスト」（簡単）の2つのモード。
## 表示時に「ゴドーだ　待たせたな！」をかっこいい男声で再生＋フェードアウト。スタート押下でシュヴァーンジングル。

var _godou_players: Array[AudioStreamPlayer] = []
var _menu_visible := false

func _ready() -> void:
	# ボタンのシグナル接続（ButtonsContainer の子なのでフルパスで取得）
	var start_btn = get_node_or_null("ButtonsContainer/StartButton")
	if start_btn:
		start_btn.pressed.connect(_on_start_pressed)
	
	var test_btn = get_node_or_null("ButtonsContainer/TestButton")
	if test_btn:
		test_btn.pressed.connect(_on_test_pressed)
	
	# タイトル表示時：「ゴドーだ　待たせたな！」をかっこいい男声で再生＋フェードアウト
	_play_godou_voice()
	# 3秒後にスタート・テスト・操作説明を表示
	get_tree().create_timer(3.0).timeout.connect(_show_menu)

func _input(_event: InputEvent) -> void:
	# 3秒待つまでメニューは出さない（スキップなし）
	pass

func _show_menu() -> void:
	if _menu_visible:
		return
	_menu_visible = true
	# スタート・テスト・操作説明（ボタン左の小さめ文字）を同時に表示
	var buttons = get_node_or_null("ButtonsContainer")
	if buttons:
		buttons.visible = true

## 「ゴドーだ　待たせたな！」声：かっこいい男声（godou_da_matasetana.ogg 優先、なければ godou.ogg）で再生しフェードアウト
func _play_godou_voice() -> void:
	var path_ogg := "res://Art/Audio/godou_da_matasetana.ogg"
	var path_wav := "res://Art/Audio/godou_da_matasetana.wav"
	if not ResourceLoader.exists(path_ogg):
		path_ogg = "res://Art/Audio/godou.ogg"
	if not ResourceLoader.exists(path_wav):
		path_wav = "res://Art/Audio/godou.wav"
	var stream: AudioStream = null
	if ResourceLoader.exists(path_ogg):
		stream = load(path_ogg) as AudioStream
	elif ResourceLoader.exists(path_wav):
		stream = load(path_wav) as AudioStream
	if stream == null:
		return
	
	var main := AudioStreamPlayer.new()
	main.volume_db = 0.0
	main.stream = stream
	add_child(main)
	_godou_players.append(main)
	main.play()
	
	# 約2秒かけてフェードアウト
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		var tween := create_tween()
		tween.set_parallel(true)
		for p in _godou_players:
			if is_instance_valid(p):
				tween.tween_property(p, "volume_db", -50.0, 2.0)
		tween.tween_callback(func() -> void:
			for p in _godou_players:
				if is_instance_valid(p):
					p.stop()
		)
	)

func _play_decision_sound() -> void:
	var path_ogg := "res://Art/Audio/Effects/decision.ogg"
	var path_wav := "res://Art/Audio/Effects/decision.wav"
	var stream: AudioStream = null
	if ResourceLoader.exists(path_ogg):
		stream = load(path_ogg) as AudioStream
	elif ResourceLoader.exists(path_wav):
		stream = load(path_wav) as AudioStream
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

## スタート押下時：シュヴァーンとしたかっこいいジングル（start_jingle.ogg 等）
func _play_start_jingle() -> void:
	var path_ogg := "res://Art/Audio/Effects/start_jingle.ogg"
	var path_wav := "res://Art/Audio/Effects/start_jingle.wav"
	var stream: AudioStream = null
	if ResourceLoader.exists(path_ogg):
		stream = load(path_ogg) as AudioStream
	elif ResourceLoader.exists(path_wav):
		stream = load(path_wav) as AudioStream
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

## 本番バランスでスタート
func _on_start_pressed() -> void:
	_play_start_jingle()
	GameManager.test_mode = false
	_start_game()

## テストバランスでスタート
func _on_test_pressed() -> void:
	_play_decision_sound()
	GameManager.test_mode = true
	_start_game()

func _start_game() -> void:
	# ステージ1登場画面へ
	get_tree().change_scene_to_file("res://Scenes/UI/StageIntro.tscn")
