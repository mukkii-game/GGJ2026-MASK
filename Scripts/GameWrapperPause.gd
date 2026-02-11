extends Control
## ゲーム中のESCでポーズ。メニューは縦4択（バトルに戻る / ステージ開始から / タイトルから / やめる）。
## ポーズ中も入力を受け取るため PROCESS_MODE_ALWAYS を使用。

var _pause_layer: CanvasLayer
var _panel: PanelContainer
var _buttons: Array[Button] = []
var _selected_index := 0  # 0=バトルに戻る 1=ステージ開始から 2=タイトルから 3=やめる

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_build_pause_ui()

func _build_pause_ui() -> void:
	_pause_layer = CanvasLayer.new()
	_pause_layer.name = "PauseLayer"
	_pause_layer.layer = 100
	_pause_layer.process_mode = PROCESS_MODE_ALWAYS
	add_child(_pause_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_layer.add_child(root)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.offset_left = -180
	_panel.offset_top = 120
	_panel.offset_right = 180
	_panel.offset_bottom = 420
	_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = Color(0.5, 0.5, 0.6, 1)
	_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var label := Label.new()
	label.text = "ポーズ"
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	var titles := ["バトルに戻る", "ステージ開始から", "タイトルから", "やめる"]
	for i in titles.size():
		var btn := Button.new()
		btn.text = titles[i]
		btn.add_theme_font_size_override("font_size", 24)
		btn.pressed.connect(_on_option_pressed.bind(i))
		_buttons.append(btn)
		vbox.add_child(btn)

func _input(event: InputEvent) -> void:
	_try_handle_pause_input(event)

func _unhandled_input(event: InputEvent) -> void:
	# SubViewport側で消費されていてもESCはここで受け取る
	_try_handle_pause_input(event)

func _try_handle_pause_input(event: InputEvent) -> void:
	var vp := get_viewport()
	var is_esc := event.is_action_pressed("Escape") or (event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE)

	if not get_tree().paused:
		if is_esc:
			_open_pause()
			if vp:
				vp.set_input_as_handled()
		return

	# ポーズ中
	if is_esc:
		# ポーズメニューでESC = やめる
		_on_quit()
		if vp:
			vp.set_input_as_handled()
		return
	var go_up := event.is_action_pressed("MoveUp") or event.is_action_pressed("Move2Up")
	var go_down := event.is_action_pressed("MoveDown") or event.is_action_pressed("Move2Down")
	if go_up:
		_selected_index = (_selected_index - 1 + _buttons.size()) % _buttons.size()
		_highlight_buttons()
		if vp:
			vp.set_input_as_handled()
		return
	if go_down:
		_selected_index = (_selected_index + 1) % _buttons.size()
		_highlight_buttons()
		if vp:
			vp.set_input_as_handled()
		return
	if event.is_action_pressed("Enter") or event.is_action_pressed("ui_accept") or event.is_action_pressed("Punch") or event.is_action_pressed("Kick") or event.is_action_pressed("Punch2") or event.is_action_pressed("Kick2"):
		_on_option_pressed(_selected_index)
		if vp:
			vp.set_input_as_handled()

func _open_pause() -> void:
	get_tree().paused = true
	_selected_index = 0
	_panel.visible = true
	_highlight_buttons()
	if _buttons.size() > 0:
		_buttons[0].grab_focus()

func _highlight_buttons() -> void:
	for i in _buttons.size():
		var btn: Button = _buttons[i]
		if i == _selected_index:
			btn.add_theme_color_override("font_color", Color(1, 0.9, 0.2, 1))
			btn.grab_focus()
		else:
			btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))

func _on_option_pressed(index: int) -> void:
	get_tree().paused = false
	_panel.visible = false
	match index:
		0:
			pass  # バトルに戻る（何もしない）
		1:
			GameManager.load_same_level()
		2:
			GameManager.load_title()
		3:
			_on_quit()

func _on_quit() -> void:
	get_tree().paused = false
	_panel.visible = false
	get_tree().quit()
