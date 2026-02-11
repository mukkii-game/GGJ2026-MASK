extends Control
## モード選択画面。1P・2P・テストの3つ。移動キーと決定ボタンで選択（1P/2Pどちらの操作でも可）。

var _menu_visible := true
var _selected_index: int = 0
var _mode_buttons: Array[Button] = []

func _ready() -> void:
	# 1P / 2P / テスト の3ボタンを取得（シーンで同じ名前のノードにしておく）
	var container = get_node_or_null("ButtonsContainer")
	if container:
		container.visible = true
		# 子のうち Button だけ順に取得（OperationLabel, Spacer は除く）
		for c in container.get_children():
			if c is Button:
				_mode_buttons.append(c as Button)
	if _mode_buttons.size() >= 1:
		_mode_buttons[0].pressed.connect(_on_1p_pressed)
	if _mode_buttons.size() >= 2:
		_mode_buttons[1].pressed.connect(_on_2p_pressed)
	if _mode_buttons.size() >= 3:
		_mode_buttons[2].pressed.connect(_on_test_pressed)
	var op_panel = get_node_or_null("OperationPanel")
	if op_panel:
		op_panel.visible = true
	_highlight_selection()

func _input(event: InputEvent) -> void:
	if not _menu_visible or _mode_buttons.is_empty():
		return
	var vp := get_viewport()
	# 1P: WASD or 矢印相当 / 2P: 矢印キーで上下移動
	var go_up := event.is_action_pressed("MoveUp") or event.is_action_pressed("Move2Up")
	var go_down := event.is_action_pressed("MoveDown") or event.is_action_pressed("Move2Down")
	if go_up:
		_selected_index = (_selected_index - 1 + _mode_buttons.size()) % _mode_buttons.size()
		_highlight_selection()
		if vp:
			vp.set_input_as_handled()
	if go_down:
		_selected_index = (_selected_index + 1) % _mode_buttons.size()
		_highlight_selection()
		if vp:
			vp.set_input_as_handled()
	# 決定: Enter / N(Punch) / M(Kick) / マウス左(Punch2) / マウス右(Kick2)
	var confirm := event.is_action_pressed("Enter") or event.is_action_pressed("Punch") or event.is_action_pressed("Kick") or event.is_action_pressed("Punch2") or event.is_action_pressed("Kick2")
	if confirm:
		_activate_selected()
		if vp:
			vp.set_input_as_handled()

func _highlight_selection() -> void:
	if _selected_index >= 0 and _selected_index < _mode_buttons.size():
		_mode_buttons[_selected_index].grab_focus()

func _activate_selected() -> void:
	if _selected_index < 0 or _selected_index >= _mode_buttons.size():
		return
	_mode_buttons[_selected_index].emit_signal("pressed")

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

## 1Pモード
func _on_1p_pressed() -> void:
	_play_start_jingle()
	GameManager.test_mode = false
	GameManager.two_player_mode = false
	_start_game()

## 2Pモード（2Pは矢印＋マウス左右。1Pキャラのマスクを赤く表示）
func _on_2p_pressed() -> void:
	_play_start_jingle()
	GameManager.test_mode = false
	GameManager.two_player_mode = true
	_start_game()

## テストモード
func _on_test_pressed() -> void:
	_play_decision_sound()
	GameManager.test_mode = true
	GameManager.two_player_mode = false
	_start_game()

func _start_game() -> void:
	# ステージ1登場画面へ
	get_tree().change_scene_to_file("res://Scenes/UI/StageIntro.tscn")
