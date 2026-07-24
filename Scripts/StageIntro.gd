extends Control
## ステージ登場画面。背景の書き文字を隠さないよう、攻略テキストパネルは出さない。
## 代わりに登場人物の吹き出しで一言（仮文言・あとで差し替え可）。

var _can_advance := false

func _ready() -> void:
	var stage_data := _get_stage_data(GameManager.current_stage)
	
	var stage_label = get_node_or_null("StageNumber")
	if stage_label:
		stage_label.text = "STAGE " + str(GameManager.current_stage)
	
	var boss_label = get_node_or_null("BossName")
	if boss_label:
		boss_label.visible = false
	
	var boss_face = get_node_or_null("BossFace")
	if boss_face and ResourceLoader.exists(stage_data["boss_texture"]):
		boss_face.texture = load(stage_data["boss_texture"]) as Texture2D
	
	var face_sparkle = get_node_or_null("FaceSparkle")
	if face_sparkle:
		face_sparkle.visible = GameManager.current_stage == 4
		if GameManager.current_stage == 4:
			_start_face_sparkle(face_sparkle)
	
	# 攻略テキストパネルはカット（書き文字が見えなくなるため）
	var desc_panel = get_node_or_null("DescriptionPanel")
	if desc_panel:
		desc_panel.visible = false
	
	# 吹き出しで一言
	_setup_speech_bubble(str(stage_data.get("speech", "……！")))
	
	AudioManager.play_intro_bgm(_on_intro_finished)
	get_tree().create_timer(1.0).timeout.connect(_on_advance_allowed)

func _get_stage_data(stage: int) -> Dictionary:
	match stage:
		1:
			return {
				"boss_texture": "res://Art/Sprites/iron_mask_title1.png",
				"speech": "てめえら、まとめてかかってこい！"
			}
		2:
			return {
				"boss_texture": "res://Art/Sprites/iron_mask_title2.png",
				"speech": "メロンパンの魅力を知りな！"
			}
		3:
			return {
				"boss_texture": "res://Art/Sprites/iron_mask_title3.png",
				"speech": "今のアタシは\nバージョン７よ！"
			}
		4:
			return {
				"boss_texture": "res://Art/Sprites/iron_mask_title4.png",
				"speech": "イーロン反論オブジェクション！"
			}
		_:
			return {
				"boss_texture": "res://Art/Sprites/m_man_b_l1.png",
				"speech": "……！"
			}

func _setup_speech_bubble(line: String) -> void:
	var bubble := get_node_or_null("SpeechBubble") as Control
	if bubble == null:
		bubble = PanelContainer.new()
		bubble.name = "SpeechBubble"
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.92)
		style.border_color = Color(0.1, 0.1, 0.1, 1)
		style.set_border_width_all(4)
		style.set_corner_radius_all(16)
		style.content_margin_left = 22
		style.content_margin_right = 22
		style.content_margin_top = 14
		style.content_margin_bottom = 14
		bubble.add_theme_stylebox_override("panel", style)
		# 画面右上（背景の書き文字をできるだけ隠さない）
		bubble.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		bubble.anchor_left = 0.58
		bubble.anchor_right = 0.98
		bubble.anchor_top = 0.04
		bubble.anchor_bottom = 0.22
		bubble.offset_left = 0
		bubble.offset_right = 0
		bubble.offset_top = 0
		bubble.offset_bottom = 0
		add_child(bubble)
		var label := Label.new()
		label.name = "SpeechText"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 36)
		label.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1, 1))
		bubble.add_child(label)
	else:
		# 既存ノードでも位置を右上へ寄せる
		bubble.anchor_left = 0.58
		bubble.anchor_right = 0.98
		bubble.anchor_top = 0.04
		bubble.anchor_bottom = 0.22
		bubble.offset_left = 0
		bubble.offset_right = 0
		bubble.offset_top = 0
		bubble.offset_bottom = 0
	bubble.visible = true
	var speech_label := bubble.get_node_or_null("SpeechText") as Label
	if speech_label:
		speech_label.text = line
	# ぽよんと出す（レイアウト確定後）
	await get_tree().process_frame
	bubble.pivot_offset = bubble.size * 0.5
	bubble.scale = Vector2(0.7, 0.7)
	var tw := create_tween()
	tw.tween_property(bubble, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_advance_allowed() -> void:
	_can_advance = true

## Intro終了時：ゴング1回
func _on_intro_finished() -> void:
	AudioManager.play_gong_once()

func _input(event: InputEvent) -> void:
	if not _can_advance:
		return
	if event is InputEventKey and event.pressed:
		_start_battle()
		var vp = get_viewport()
		if vp:
			vp.set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_start_battle()
		var vp = get_viewport()
		if vp:
			vp.set_input_as_handled()

func _start_face_sparkle(node: Control) -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(node, "modulate", Color(1, 1, 1, 0.35), 0.12)
	tween.tween_property(node, "modulate", Color(1, 1, 1, 1), 0.12)
	tween.tween_property(node, "scale", Vector2(1.2, 1.2), 0.08)
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), 0.08)

func _start_battle() -> void:
	AudioManager.stop_bgm()
	get_tree().change_scene_to_file("res://Scenes/Levels/GameWrapper.tscn")
