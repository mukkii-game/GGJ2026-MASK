extends Node2D
## キャラの頭上に表示されるHPバー

@onready var character = get_parent() as CharacterBase
const BAR_WIDTH := 48.0
const BAR_HEIGHT := 18.0  # 3倍の太さ
const Y_OFFSET := -51.0  # 頭の上（5ピクセルさらに上に）

func _ready() -> void:
	z_index = 0  # キャラと同じプライオリティ

func _process(_delta: float) -> void:
	if not character:
		return
	# キャラクタのスプライトがジャンプ中に上にオフセットされている場合、HPバーも追従
	var sprite_offset := Vector2.ZERO
	if character.sprite and is_instance_valid(character.sprite):
		sprite_offset = character.sprite.position
	# HPバーをスプライトと同じオフセットに配置
	position = sprite_offset
	queue_redraw()

func _draw() -> void:
	if not character or character.is_dead:
		return
	
	var hp_percent := clampf(float(character.health) / float(character.max_health), 0.0, 1.0)
	
	# 背景（黒）
	draw_rect(Rect2(-BAR_WIDTH / 2, Y_OFFSET, BAR_WIDTH, BAR_HEIGHT), Color(0, 0, 0, 0.8))
	
	# HPゲージ色
	# - 50%超: 緑
	# - 50%以下: 黄
	# - 30%以下: 朱⇄白 点滅
	var bar_color: Color
	if hp_percent <= 0.3:
		var blink_on := int(Time.get_ticks_msec() / 150) % 2 == 0
		bar_color = Color(0.9, 0.25, 0.12, 1.0) if blink_on else Color.WHITE
	elif hp_percent <= 0.5:
		bar_color = Color(1.0, 0.9, 0.25, 1.0)
	else:
		bar_color = Color(0.2, 1.0, 0.35, 1.0)
	
	var current_width := BAR_WIDTH * hp_percent
	if current_width > 0:
		draw_rect(Rect2(-BAR_WIDTH / 2, Y_OFFSET, current_width, BAR_HEIGHT), bar_color)
	
	# 枠線（白）
	draw_rect(Rect2(-BAR_WIDTH / 2, Y_OFFSET, BAR_WIDTH, BAR_HEIGHT), Color.WHITE, false, 1.0)
