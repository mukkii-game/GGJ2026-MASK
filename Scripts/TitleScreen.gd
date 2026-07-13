extends Control
## モード選択画面。1P・2P・テストの3つ。移動キーと決定ボタンで選択（1P/2Pどちらの操作でも可）。
## ESCで「タイトルに戻りますか？ はい/いいえ」を表示。はい=終了・いいえ=閉じる。ダイアログでESC=終了。

var _menu_visible := true
var _selected_index: int = 0
var _mode_buttons: Array[Button] = []
var _style_normal: StyleBoxFlat
var _style_selected: StyleBoxFlat
var _confirm_panel: Control
var _btn_yes: Button
var _btn_no: Button
var _confirm_visible := false
var _confirm_index := 0  # 0=はい 1=いいえ

func _ready() -> void:
	AudioManager.play_battle_bgm()
	# 選択中ボタン用スタイル（目立つ色）
	_style_selected = StyleBoxFlat.new()
	_style_selected.bg_color = Color(0.95, 0.75, 0.15, 1)
	_style_selected.set_corner_radius_all(8)
	_style_selected.set_content_margin_all(6)
	_style_selected.content_margin_left = 16
	_style_selected.content_margin_right = 16
	_style_selected.border_width_left = 3
	_style_selected.border_width_top = 3
	_style_selected.border_width_right = 3
	_style_selected.border_width_bottom = 3
	_style_selected.border_color = Color(1, 1, 0.6, 1)
	# 通常スタイル（ボタンから取得するので後で設定）
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color(0.15, 0.35, 0.75, 1)
	_style_normal.set_corner_radius_all(8)
	_style_normal.set_content_margin_all(6)
	_style_normal.content_margin_left = 16
	_style_normal.content_margin_right = 16

	# 1P / 2P / テスト の3ボタンを取得（シーンで同じ名前のノードにしておく）
	var container = get_node_or_null("ButtonsContainer")
	if container:
		container.visible = true
		for c in container.get_children():
			if c is Button:
				_mode_buttons.append(c as Button)
	if _mode_buttons.size() >= 1:
		_mode_buttons[0].pressed.connect(_on_1p_pressed)
	if _mode_buttons.size() >= 2:
		_mode_buttons[1].pressed.connect(_on_2p_pressed)
	if _mode_buttons.size() >= 3:
		_mode_buttons[2].pressed.connect(_on_test_pressed)
	if _mode_buttons.size() >= 4:
		_mode_buttons[3].pressed.connect(_on_training_pressed)
	if _mode_buttons.size() >= 5:
		_mode_buttons[4].pressed.connect(_on_stage_pressed.bind(1))
	if _mode_buttons.size() >= 6:
		_mode_buttons[5].pressed.connect(_on_stage_pressed.bind(2))
	if _mode_buttons.size() >= 7:
		_mode_buttons[6].pressed.connect(_on_stage_pressed.bind(3))
	if _mode_buttons.size() >= 8:
		_mode_buttons[7].pressed.connect(_on_stage_pressed.bind(4))
	if _mode_buttons.size() >= 9:
		_mode_buttons[8].pressed.connect(_on_ending_pressed)

	# ESC確認パネル（暗い背景・最前面に表示）
	_confirm_panel = get_node_or_null("ConfirmReturnPanel")
	if _confirm_panel:
		_confirm_panel.visible = false
		_confirm_panel.z_index = 200
		# 描画順を最後にする（兄弟の後に描画）
		_confirm_panel.set_as_top_level(false)
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
		panel_style.set_corner_radius_all(12)
		panel_style.set_border_width_all(2)
		panel_style.border_color = Color(0.5, 0.5, 0.6, 1)
		if _confirm_panel is PanelContainer:
			(_confirm_panel as PanelContainer).add_theme_stylebox_override("panel", panel_style)
		_btn_yes = _confirm_panel.get_node_or_null("MarginContainer/VBox/ButtonsRow/BtnYes")
		_btn_no = _confirm_panel.get_node_or_null("MarginContainer/VBox/ButtonsRow/BtnNo")
		if _btn_yes:
			_btn_yes.pressed.connect(_on_confirm_yes)
		if _btn_no:
			_btn_no.pressed.connect(_on_confirm_no)

	var op_panel = get_node_or_null("OperationPanel")
	if op_panel:
		op_panel.visible = true
	_highlight_selection()

func _unhandled_key_input(event: InputEvent) -> void:
	# 子Controlが消費しなかったESCをここで受け取る（フォーカスがボタンにあると_inputで取れないことがある）
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			if _confirm_visible:
				get_tree().quit()
				get_viewport().set_input_as_handled()
			else:
				_show_confirm_return()
				get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	var vp := get_viewport()
	# ESC: 最優先で受け取る（アクション＋キー直接の両方）
	var is_esc := event.is_action_pressed("Escape") or event.is_action_pressed("ui_cancel")
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			is_esc = true
	if is_esc:
		if _confirm_visible:
			get_tree().quit()
			if vp:
				vp.set_input_as_handled()
			return
		_show_confirm_return()
		if vp:
			vp.set_input_as_handled()
		return

	if _confirm_visible:
		# ダイアログ中: 上下で はい/いいえ、Enter で決定
		var go_up := event.is_action_pressed("MoveUp") or event.is_action_pressed("Move2Up")
		var go_down := event.is_action_pressed("MoveDown") or event.is_action_pressed("Move2Down")
		if go_up or go_down:
			_confirm_index = 1 - _confirm_index
			_highlight_confirm()
			if vp:
				vp.set_input_as_handled()
			return
		if event.is_action_pressed("Enter") or event.is_action_pressed("ui_accept") or event.is_action_pressed("Punch") or event.is_action_pressed("Kick") or event.is_action_pressed("Punch2") or event.is_action_pressed("Kick2"):
			if _confirm_index == 0:
				_on_confirm_yes()
			else:
				_on_confirm_no()
			if vp:
				vp.set_input_as_handled()
		return

	if not _menu_visible or _mode_buttons.is_empty():
		return
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
	for i in _mode_buttons.size():
		var btn: Button = _mode_buttons[i]
		if i == _selected_index:
			btn.add_theme_stylebox_override("normal", _style_selected)
			btn.add_theme_stylebox_override("hover", _style_selected)
			btn.add_theme_stylebox_override("pressed", _style_selected)
			btn.add_theme_font_size_override("font_size", 32)
			btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1))
			btn.grab_focus()
		else:
			btn.add_theme_stylebox_override("normal", _style_normal)
			btn.add_theme_stylebox_override("hover", _style_normal)
			btn.add_theme_stylebox_override("pressed", _style_normal)
			btn.add_theme_font_size_override("font_size", 28)
			btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))

func _show_confirm_return() -> void:
	_confirm_visible = true
	_confirm_index = 0
	if _confirm_panel:
		_confirm_panel.visible = true
		_confirm_panel.z_index = 200
		# 前面に出すため一度末尾に移動
		var p := _confirm_panel.get_parent()
		if p:
			p.move_child(_confirm_panel, -1)
	_highlight_confirm()

func _highlight_confirm() -> void:
	if _btn_yes and _btn_no:
		if _confirm_index == 0:
			_btn_yes.grab_focus()
			_btn_yes.add_theme_color_override("font_color", Color(1, 0.9, 0.2, 1))
			_btn_no.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
		else:
			_btn_no.grab_focus()
			_btn_yes.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
			_btn_no.add_theme_color_override("font_color", Color(1, 0.9, 0.2, 1))

func _on_confirm_yes() -> void:
	_confirm_visible = false
	if _confirm_panel:
		_confirm_panel.visible = false
	get_tree().quit()

func _on_confirm_no() -> void:
	_confirm_visible = false
	if _confirm_panel:
		_confirm_panel.visible = false
	_highlight_selection()

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

## トレーニングモード（中央に動かず攻撃しない敵・倒したら復活）
func _on_training_pressed() -> void:
	_play_decision_sound()
	GameManager.test_mode = true
	GameManager.two_player_mode = false
	GameManager.training_mode = true
	GameManager.current_stage = 1
	_start_game()

func _start_game() -> void:
	# ステージ1登場画面へ
	get_tree().change_scene_to_file("res://Scenes/UI/StageIntro.tscn")

## ステージ1〜4直接選択（テスト用）
func _on_stage_pressed(stage_num: int) -> void:
	_play_decision_sound()
	GameManager.test_mode = true
	GameManager.two_player_mode = false
	GameManager.current_stage = stage_num
	get_tree().change_scene_to_file("res://Scenes/UI/StageIntro.tscn")

## エンディングへ直接
func _on_ending_pressed() -> void:
	_play_decision_sound()
	get_tree().change_scene_to_file("res://Scenes/UI/Ending.tscn")
