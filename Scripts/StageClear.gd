extends Control
## ステージクリア画面。倒したボスの顔を表示。
## S2〜S4: 右上にモザイク＋「〇〇のマスクを剥いだ！」
## S1: モザイクなし。文言は画面下部に表示。

var _can_advance := false

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	set_process_input(true)
	# クリア画面は一旦無音（専用曲は後日用意）。戦闘BGMを止める
	AudioManager.stop_bgm()
	# ステージ番号表示
	var stage_label = get_node_or_null("FaceCover/TextPanel/VBox/StageNumber")
	if stage_label:
		stage_label.text = "STAGE " + str(GameManager.current_stage) + " CLEAR!"
	
	# ボス顔画像（ステージごと: iron_mask_title1〜4 を背景に使用）
	var texture_path := "res://Art/Sprites/iron_mask_title%d.png" % clampi(GameManager.current_stage, 1, 4)
	var tex: Texture2D = null
	if ResourceLoader.exists(texture_path):
		tex = load(texture_path) as Texture2D
	var boss_face = get_node_or_null("BossFace")
	if boss_face and tex:
		boss_face.texture = tex
	var blur_rect = get_node_or_null("FaceCover/BlurMosaicRect")
	if blur_rect and tex:
		blur_rect.texture = tex
	
	var boss_name := _get_boss_name(GameManager.current_stage)
	var peel_text := boss_name + "のマスクを剥いだ！"
	var message_label = get_node_or_null("FaceCover/TextPanel/VBox/Message") as Label
	
	if GameManager.current_stage == 1:
		# ザコ面: モザイク不要。文言は画面下部
		if blur_rect:
			blur_rect.visible = false
		if message_label:
			message_label.visible = false
		_add_bottom_peel_label(peel_text)
	else:
		if message_label:
			message_label.visible = true
			message_label.text = peel_text
	
	# 1秒間は進めない
	get_tree().create_timer(1.0).timeout.connect(_on_advance_allowed)

func _add_bottom_peel_label(text: String) -> void:
	var label := Label.new()
	label.name = "BottomPeelMessage"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 6)
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_left = 24.0
	label.offset_right = -24.0
	label.offset_top = -110.0
	label.offset_bottom = -36.0
	add_child(label)

func _on_advance_allowed() -> void:
	_can_advance = true

func _input(event: InputEvent) -> void:
	_try_advance(event)

func _unhandled_input(event: InputEvent) -> void:
	# フォーカスで消費されていても未処理ならここで受け取る
	_try_advance(event)

func _try_advance(event: InputEvent) -> void:
	if not _can_advance:
		return
	var advance := false
	if event is InputEventKey and event.pressed and not event.echo:
		advance = true
	elif event is InputEventMouseButton and event.pressed:
		advance = true
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		advance = true
	if advance:
		_next_stage()
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()

func _get_boss_name(stage: int) -> String:
	match stage:
		1: return "雑魚マスク軍団"
		2: return "マスクメロンナちゃん"
		3: return "うに帝仮面"
		4: return "異論マスク"
		_: return "マスク"

func _next_stage() -> void:
	# 次のステージへ
	GameManager.load_next_stage()
