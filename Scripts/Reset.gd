extends Node
## ゲームオーバー画面。コンティニュー / タイトルに戻る / 終了する を移動キーで選択。

var _buttons: Array[Button] = []
var _selected_index := 0

func _ready() -> void:
	var list = get_node_or_null("Control/Panel/VBox/OptionsList")
	if list:
		for c in list.get_children():
			if c is Button:
				_buttons.append(c as Button)
	if _buttons.size() >= 1:
		_buttons[0].pressed.connect(_on_continue)
	if _buttons.size() >= 2:
		_buttons[1].pressed.connect(_on_title)
	if _buttons.size() >= 3:
		_buttons[2].pressed.connect(_on_quit)
	_highlight_selection()

func _input(event: InputEvent) -> void:
	var vp := get_viewport()
	if _buttons.is_empty():
		return
	# ESC = 終了する
	if event.is_action_pressed("Escape") or (event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE):
		_on_quit()
		if vp:
			vp.set_input_as_handled()
		return
	# 上下で選択
	var go_up := event.is_action_pressed("MoveUp") or event.is_action_pressed("Move2Up")
	var go_down := event.is_action_pressed("MoveDown") or event.is_action_pressed("Move2Down")
	if go_up:
		_selected_index = (_selected_index - 1 + _buttons.size()) % _buttons.size()
		_highlight_selection()
		if vp:
			vp.set_input_as_handled()
		return
	if go_down:
		_selected_index = (_selected_index + 1) % _buttons.size()
		_highlight_selection()
		if vp:
			vp.set_input_as_handled()
		return
	# 決定
	if event.is_action_pressed("Enter") or event.is_action_pressed("ui_accept") or event.is_action_pressed("Punch") or event.is_action_pressed("Kick") or event.is_action_pressed("Punch2") or event.is_action_pressed("Kick2"):
		_activate_selected()
		if vp:
			vp.set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_activate_selected()
		if vp:
			vp.set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		_activate_selected()
		if vp:
			vp.set_input_as_handled()

func _highlight_selection() -> void:
	for i in _buttons.size():
		var btn: Button = _buttons[i]
		if i == _selected_index:
			btn.add_theme_color_override("font_color", Color(1, 0.9, 0.2, 1))
			btn.grab_focus()
		else:
			btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))

func _activate_selected() -> void:
	if _selected_index < 0 or _selected_index >= _buttons.size():
		return
	_buttons[_selected_index].emit_signal("pressed")

func _on_continue() -> void:
	GameManager.load_same_level()

func _on_title() -> void:
	GameManager.load_title()

func _on_quit() -> void:
	get_tree().quit()
