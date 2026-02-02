extends Node
## ゲームオーバー画面。コンティニュー（再挑戦）かタイトルへ戻るかを選べる。

func _ready() -> void:
	var continue_btn = get_node_or_null("Control/Panel/VBox/HBox/ContinueButton")
	if continue_btn:
		continue_btn.pressed.connect(_on_continue)
	var title_btn = get_node_or_null("Control/Panel/VBox/HBox/TitleButton")
	if title_btn:
		title_btn.pressed.connect(_on_title)

func _input(event: InputEvent) -> void:
	var vp := get_viewport()
	if event.is_action_pressed("Escape"):
		_on_title()
		if vp:
			vp.set_input_as_handled()
		return
	# Esc以外：キー・クリック・パッドでコンティニュー（ボタン押下と重複するが load_same_level は冪等に扱う）
	if event is InputEventKey and event.pressed:
		_on_continue()
		if vp:
			vp.set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_on_continue()
		if vp:
			vp.set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		_on_continue()
		if vp:
			vp.set_input_as_handled()

func _on_continue() -> void:
	GameManager.load_same_level()

func _on_title() -> void:
	GameManager.load_title()
