extends Control
## エンディング画面。「ボタンを押して終了」→ 任意入力でタイトルへ。

@onready var bgm_player: AudioStreamPlayer = null

func _ready() -> void:
	# 主人公（ゴドーマスク）の絵を表示（m_man_g_l1 / m_man_g_l2 で2コマ切り替え）
	var godot_face = get_node_or_null("GodotMask")
	if godot_face:
		var path_l1 := "res://Art/Sprites/m_man_g_l1.png"
		var path_l2 := "res://Art/Sprites/m_man_g_l2.png"
		var tex_l1: Texture2D = null
		var tex_l2: Texture2D = null
		if ResourceLoader.exists(path_l1):
			tex_l1 = load(path_l1) as Texture2D
			godot_face.texture = tex_l1
		if ResourceLoader.exists(path_l2):
			tex_l2 = load(path_l2) as Texture2D
		if tex_l1 and tex_l2:
			var use_l2 := false
			var tween := create_tween().set_loops()
			tween.tween_interval(0.2)
			tween.tween_callback(func() -> void:
				if is_instance_valid(godot_face):
					godot_face.texture = tex_l2 if use_l2 else tex_l1
					use_l2 = not use_l2
			)
	
	# エンディング曲を再生（なければMainTheme.mp3）
	bgm_player = AudioStreamPlayer.new()
	add_child(bgm_player)
	var ending_path := "res://Art/Audio/Ending.mp3"
	if ResourceLoader.exists(ending_path):
		bgm_player.stream = load(ending_path) as AudioStream
		bgm_player.play()
	elif ResourceLoader.exists("res://Art/Audio/MainTheme.mp3"):
		bgm_player.stream = load("res://Art/Audio/MainTheme.mp3") as AudioStream
		bgm_player.play()
	
	# ボタン押下で終了
	var btn = get_node_or_null("ExitButton")
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
	if bgm_player:
		bgm_player.stop()
	GameManager.load_title()
