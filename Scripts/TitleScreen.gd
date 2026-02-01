extends Control
## タイトル画面。「スタート」（本番）と「テスト」（簡単）の2つのモード。
## 表示時に「ゴドー！」声をエコーでやまびこ＋フェードアウト。スタート/テスト押下で決定音。

var _godou_players: Array[AudioStreamPlayer] = []

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
	
	# タイトル表示時：「ゴドー！」声をエコーでやまびこ＋フェードアウト
	_play_godou_voice()

## 「ゴドー！」声：メイン＋エコー2回を遅延再生し、全員フェードアウト
func _play_godou_voice() -> void:
	var path_ogg := "res://Art/Audio/godou.ogg"
	var path_wav := "res://Art/Audio/godou.wav"
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
	
	# エコー1: 0.35秒後に小さめで再生
	var echo1 := AudioStreamPlayer.new()
	echo1.volume_db = -5.0
	echo1.stream = stream
	add_child(echo1)
	_godou_players.append(echo1)
	get_tree().create_timer(0.35).timeout.connect(func() -> void:
		if is_instance_valid(echo1):
			echo1.play()
	)
	
	# エコー2: 0.7秒後にさらに小さく再生
	var echo2 := AudioStreamPlayer.new()
	echo2.volume_db = -11.0
	echo2.stream = stream
	add_child(echo2)
	_godou_players.append(echo2)
	get_tree().create_timer(0.7).timeout.connect(func() -> void:
		if is_instance_valid(echo2):
			echo2.play()
	)
	
	# エコーが全部鳴り始めてから約2秒かけてフェードアウト
	get_tree().create_timer(0.85).timeout.connect(func() -> void:
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

## 本番バランスでスタート
func _on_start_pressed() -> void:
	_play_decision_sound()
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
