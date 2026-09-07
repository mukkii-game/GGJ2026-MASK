extends Control
## タイトル画面。
## メインメニュー: ゲーム開始 / 面セレクト
## 面セレクトメニュー: S1〜S4、エンディング、タイトルへ戻る（クリア後はタイトルへ戻る）

var _menu_mode := "main"  # "main" または "stage_select"
var _selected_index: int = 0
var _main_buttons: Array[Button] = []
var _stage_buttons: Array[Button] = []

var _style_normal: StyleBoxFlat
var _style_selected: StyleBoxFlat

var _buttons_container: Control
var _stage_select_container: Control

var _confirm_panel: Control
var _btn_yes: Button
var _btn_no: Button
var _confirm_visible := false
var _confirm_index := 0  # 0=はい 1=いいえ

func _ready() -> void:
	AudioManager.play_title_bgm()

	# 選択中ボタンスタイル（黄色ハイライト）
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

	# 通常ボタンスタイル（青色）
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color(0.15, 0.35, 0.75, 1)
	_style_normal.set_corner_radius_all(8)
	_style_normal.set_content_margin_all(6)
	_style_normal.content_margin_left = 16
	_style_normal.content_margin_right = 16

	_buttons_container = get_node_or_null("ButtonsContainer")
	_stage_select_container = get_node_or_null("StageSelectContainer")

	# メインメニューボタン
	var btn_1p := get_node_or_null("ButtonsContainer/Btn1P") as Button
	if btn_1p:
		_main_buttons.append(btn_1p)
		btn_1p.mouse_entered.connect(func() -> void:
			if _menu_mode == "main":
				_selected_index = 0
				_highlight_selection()
		)
		btn_1p.pressed.connect(func() -> void:
			if _menu_mode == "main":
				_selected_index = 0
				_on_1p_pressed()
		)

	var btn_stage_sel := get_node_or_null("ButtonsContainer/BtnStageSelect") as Button
	if btn_stage_sel:
		_main_buttons.append(btn_stage_sel)
		btn_stage_sel.mouse_entered.connect(func() -> void:
			if _menu_mode == "main":
				_selected_index = 1
				_highlight_selection()
		)
		btn_stage_sel.pressed.connect(func() -> void:
			if _menu_mode == "main":
				_selected_index = 1
				_open_stage_select()
		)

	var btn_inv := get_node_or_null("ButtonsContainer/BtnInvincible") as Button
	if btn_inv:
		_main_buttons.append(btn_inv)
		_update_invincible_button_text(btn_inv)
		btn_inv.mouse_entered.connect(func() -> void:
			if _menu_mode == "main":
				_selected_index = 2
				_highlight_selection()
		)
		btn_inv.pressed.connect(func() -> void:
			if _menu_mode == "main":
				_selected_index = 2
				_toggle_invincible()
		)

	# 面セレクトボタン
	var stage_btn_names: Array[String] = [
		"BtnStage1", "BtnStage2", "BtnStage3", "BtnStage4", "BtnEnding", "BtnBack"
	]
	for i in stage_btn_names.size():
		var bname: String = stage_btn_names[i]
		var btn := get_node_or_null("StageSelectContainer/" + bname) as Button
		if btn == null:
			continue
		_stage_buttons.append(btn)
		var s_idx := _stage_buttons.size() - 1
		btn.mouse_entered.connect(func() -> void:
			if _menu_mode == "stage_select":
				_selected_index = s_idx
				_highlight_selection()
		)
		match bname:
			"BtnStage1":
				btn.pressed.connect(func() -> void:
					if _menu_mode == "stage_select":
						_selected_index = s_idx
						_on_stage_pressed(1)
				)
			"BtnStage2":
				btn.pressed.connect(func() -> void:
					if _menu_mode == "stage_select":
						_selected_index = s_idx
						_on_stage_pressed(2)
				)
			"BtnStage3":
				btn.pressed.connect(func() -> void:
					if _menu_mode == "stage_select":
						_selected_index = s_idx
						_on_stage_pressed(3)
				)
			"BtnStage4":
				btn.pressed.connect(func() -> void:
					if _menu_mode == "stage_select":
						_selected_index = s_idx
						_on_stage_pressed(4)
				)
			"BtnEnding":
				btn.pressed.connect(func() -> void:
					if _menu_mode == "stage_select":
						_selected_index = s_idx
						_on_ending_pressed()
				)
			"BtnBack":
				btn.pressed.connect(func() -> void:
					if _menu_mode == "stage_select":
						_close_stage_select()
				)

	# ESC確認パネル
	_confirm_panel = get_node_or_null("ConfirmReturnPanel")
	if _confirm_panel:
		_confirm_panel.visible = false
		_confirm_panel.z_index = 200
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
	_show_main_menu()

func _show_main_menu() -> void:
	_menu_mode = "main"
	if _buttons_container:
		_buttons_container.visible = true
	if _stage_select_container:
		_stage_select_container.visible = false
	_selected_index = 0
	_highlight_selection()

func _open_stage_select() -> void:
	_play_decision_sound()
	_menu_mode = "stage_select"
	if _buttons_container:
		_buttons_container.visible = false
	if _stage_select_container:
		_stage_select_container.visible = true
	_selected_index = 0
	_highlight_selection()

func _close_stage_select() -> void:
	_play_decision_sound()
	_menu_mode = "main"
	if _stage_select_container:
		_stage_select_container.visible = false
	if _buttons_container:
		_buttons_container.visible = true
	_selected_index = 1  # 「面セレクト」にカーソルを戻す
	_highlight_selection()

func _get_active_buttons() -> Array[Button]:
	if _menu_mode == "stage_select":
		return _stage_buttons
	return _main_buttons

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			_handle_esc()
			get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	var vp := get_viewport()
	var is_esc := event.is_action_pressed("Escape") or event.is_action_pressed("ui_cancel")
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			is_esc = true
	if is_esc:
		_handle_esc()
		if vp:
			vp.set_input_as_handled()
		return

	if _confirm_visible:
		if event is InputEventMouseButton:
			return
		var go_up := event.is_action_pressed("MoveUp") or event.is_action_pressed("Move2Up")
		var go_down := event.is_action_pressed("MoveDown") or event.is_action_pressed("Move2Down")
		if go_up or go_down:
			_confirm_index = 1 - _confirm_index
			_highlight_confirm()
			if vp:
				vp.set_input_as_handled()
			return
		if event.is_action_pressed("Enter") or event.is_action_pressed("ui_accept") or event.is_action_pressed("Punch") or event.is_action_pressed("Kick"):
			if _confirm_index == 0:
				_on_confirm_yes()
			else:
				_on_confirm_no()
			if vp:
				vp.set_input_as_handled()
		return

	var btns := _get_active_buttons()
	if btns.is_empty():
		return

	var go_up := event.is_action_pressed("MoveUp") or event.is_action_pressed("Move2Up")
	var go_down := event.is_action_pressed("MoveDown") or event.is_action_pressed("Move2Down")
	if go_up:
		_selected_index = (_selected_index - 1 + btns.size()) % btns.size()
		_highlight_selection()
		if vp:
			vp.set_input_as_handled()
		return
	if go_down:
		_selected_index = (_selected_index + 1) % btns.size()
		_highlight_selection()
		if vp:
			vp.set_input_as_handled()
		return

	if event is InputEventMouseButton:
		return

	var confirm := event.is_action_pressed("Enter") or event.is_action_pressed("ui_accept") or event.is_action_pressed("Punch") or event.is_action_pressed("Kick")
	if confirm:
		_activate_selected()
		if vp:
			vp.set_input_as_handled()

func _handle_esc() -> void:
	if _confirm_visible:
		get_tree().quit()
		return
	if _menu_mode == "stage_select":
		_close_stage_select()
		return
	_show_confirm_return()

func _highlight_selection() -> void:
	var btns := _get_active_buttons()
	for i in btns.size():
		var btn: Button = btns[i]
		if i == _selected_index:
			btn.add_theme_stylebox_override("normal", _style_selected)
			btn.add_theme_stylebox_override("hover", _style_selected)
			btn.add_theme_stylebox_override("pressed", _style_selected)
			btn.add_theme_font_size_override("font_size", 28 if _menu_mode == "main" else 22)
			btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1))
			btn.grab_focus()
		else:
			btn.add_theme_stylebox_override("normal", _style_normal)
			btn.add_theme_stylebox_override("hover", _style_normal)
			btn.add_theme_stylebox_override("pressed", _style_normal)
			btn.add_theme_font_size_override("font_size", 26 if _menu_mode == "main" else 20)
			btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))

func _show_confirm_return() -> void:
	_confirm_visible = true
	_confirm_index = 0
	if _confirm_panel:
		_confirm_panel.visible = true
		_confirm_panel.z_index = 200
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
	var btns := _get_active_buttons()
	if _selected_index < 0 or _selected_index >= btns.size():
		return
	var btn := btns[_selected_index]
	match String(btn.name):
		"Btn1P":
			_on_1p_pressed()
		"BtnStageSelect":
			_open_stage_select()
		"BtnInvincible":
			_toggle_invincible()
		"BtnStage1":
			_on_stage_pressed(1)
		"BtnStage2":
			_on_stage_pressed(2)
		"BtnStage3":
			_on_stage_pressed(3)
		"BtnStage4":
			_on_stage_pressed(4)
		"BtnEnding":
			_on_ending_pressed()
		"BtnBack":
			_close_stage_select()
		_:
			btn.emit_signal("pressed")

func _toggle_invincible() -> void:
	GameManager.player_invincible_mode = !GameManager.player_invincible_mode
	_play_decision_sound()
	var btn_inv := get_node_or_null("ButtonsContainer/BtnInvincible") as Button
	if btn_inv:
		_update_invincible_button_text(btn_inv)
	_highlight_selection()

func _update_invincible_button_text(btn: Button) -> void:
	if GameManager.player_invincible_mode:
		btn.text = "無敵モード: ON (ダメージ無効)"
		btn.modulate = Color(1.3, 1.2, 0.4, 1.0)
	else:
		btn.text = "無敵モード: OFF"
		btn.modulate = Color(1.0, 1.0, 1.0, 1.0)

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

## 1P通常ゲーム開始（S1から通しプレイ）
func _on_1p_pressed() -> void:
	_play_start_jingle()
	GameManager.test_mode = false
	GameManager.two_player_mode = false
	GameManager.training_mode = false
	GameManager.single_stage_mode = false
	GameManager.current_stage = 1
	get_tree().change_scene_to_file("res://Scenes/UI/StageIntro.tscn")

## ステージ1〜4直接選択（クリア後はタイトルへ戻る）
func _on_stage_pressed(stage_num: int) -> void:
	_play_decision_sound()
	GameManager.test_mode = false
	GameManager.two_player_mode = false
	GameManager.training_mode = false
	GameManager.current_stage = clampi(stage_num, 1, 4)
	GameManager.single_stage_mode = true
	get_tree().change_scene_to_file("res://Scenes/UI/StageIntro.tscn")

## エンディング直接選択（閲覧後タイトルへ戻る）
func _on_ending_pressed() -> void:
	_play_decision_sound()
	GameManager.single_stage_mode = true
	get_tree().change_scene_to_file("res://Scenes/UI/Ending.tscn")
