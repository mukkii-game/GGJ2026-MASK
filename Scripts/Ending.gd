extends Control
## エンディング画面。「ボタンを押して終了」→ 任意入力でタイトルへ。

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	set_process_input(true)
	# endding_pic.png を表示
	var godot_face = get_node_or_null("GodotMask")
	if godot_face and godot_face.texture == null:
		var pic_path := "res://Art/Sprites/endding_pic.png"
		if ResourceLoader.exists(pic_path):
			godot_face.texture = load(pic_path) as Texture2D
	
	AudioManager.play_ending_bgm()
	
	# ボタン押下で終了
	var btn = get_node_or_null("TwoColumn/TextColumn/ExitButton")
	if btn:
		btn.pressed.connect(_back_to_title)

func _input(event: InputEvent) -> void:
	var vp := get_viewport()
	# なんか入力で終了（キー・マウス・ジョイパッドなど）
	if event is InputEventKey and event.pressed:
		_back_to_title()
		if vp:
			vp.set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_back_to_title()
		if vp:
			vp.set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		_back_to_title()
		if vp:
			vp.set_input_as_handled()

func _back_to_title() -> void:
	AudioManager.stop_bgm()
	GameManager.load_title()
