extends Control

@export var money_label : Label

var _training_contact_label: Label
## ステージ1・本番プレイ限定：生存敵数の表示（クリア条件不透明対策のKI対応）
var _stage1_enemy_label: Label
## ステージ1・本番プレイ限定：正面衝突の誤学習防止ヒント（一度だけ表示）
var _stage1_hint_label: Label
## 既存の pixelized_label 系フォント（m3x6）を流用しつつ、背景色に依存せず読めるよう縁取りを付けたHUD用設定
var _hud_label_settings: LabelSettings

func _ready() -> void:
	if GameManager.training_mode:
		_training_contact_label = Label.new()
		_training_contact_label.name = "TrainingContactLabel"
		_training_contact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_training_contact_label.anchor_left = 0.5
		_training_contact_label.anchor_right = 0.5
		_training_contact_label.anchor_top = 0.0
		_training_contact_label.offset_left = -80
		_training_contact_label.offset_right = 80
		_training_contact_label.offset_top = 60
		_training_contact_label.offset_bottom = 90
		add_child(_training_contact_label)
		return

	if GameManager.current_stage == 1:
		_hud_label_settings = LabelSettings.new()
		_hud_label_settings.font = load("res://Art/Fonts/m3x6.ttf")
		_hud_label_settings.font_size = 20
		_hud_label_settings.outline_size = 3
		_hud_label_settings.outline_color = Color(0, 0, 0, 1)

		# 残り敵数HUD（画面右上・体力バー等の既存UIと重ならない位置）
		_stage1_enemy_label = Label.new()
		_stage1_enemy_label.name = "Stage1EnemyLabel"
		_stage1_enemy_label.label_settings = _hud_label_settings
		_stage1_enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_stage1_enemy_label.offset_left = 820.0
		_stage1_enemy_label.offset_top = 8.0
		_stage1_enemy_label.offset_right = 1270.0
		_stage1_enemy_label.offset_bottom = 56.0
		_stage1_enemy_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		add_child(_stage1_enemy_label)

		# 誤学習防止ヒント（1プレイにつき一度だけ、画面上部中央に3.5秒表示）
		_stage1_hint_label = Label.new()
		_stage1_hint_label.name = "Stage1HintLabel"
		_stage1_hint_label.label_settings = _hud_label_settings
		_stage1_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_stage1_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_stage1_hint_label.offset_left = 140.0
		_stage1_hint_label.offset_top = 40.0
		_stage1_hint_label.offset_right = 1140.0
		_stage1_hint_label.offset_bottom = 90.0
		_stage1_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_stage1_hint_label.visible = false
		add_child(_stage1_hint_label)

func _process(delta: float) -> void:
	money_label.text = "Coins: " + "%d" % GameManager.money
	if GameManager.training_mode and _training_contact_label:
		GameManager.body_contact_type_timer -= delta
		if GameManager.body_contact_type_timer > 0:
			_training_contact_label.visible = true
			_training_contact_label.text = GameManager.body_contact_type_text
		else:
			_training_contact_label.visible = false

	if _stage1_enemy_label:
		var alive: int = GameManager.stage1_alive_enemy_count
		var cap: int = GameManager.stage1_max_concurrent_enemy_count
		# 初期スポーン完了前（cap未設定=0）は非表示（「敵0体・全滅でクリア」という誤解を防ぐ）
		_stage1_enemy_label.visible = cap > 0
		# 増援は無限湧き（場の同時出現数の上限のみ固定）なので「残り総数」ではなく
		# 「今何体いるか」＋「全滅した瞬間にクリア」という正直な表現にする
		_stage1_enemy_label.text = "敵 %d体（最大%d体・全滅でクリア）" % [alive, cap]

	if _stage1_hint_label:
		GameManager.front_collision_hint_timer -= delta
		if GameManager.front_collision_hint_timer > 0:
			_stage1_hint_label.visible = true
			_stage1_hint_label.text = GameManager.front_collision_hint_text
		else:
			_stage1_hint_label.visible = false
