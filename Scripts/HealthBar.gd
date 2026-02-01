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
	
	# HPゲージ：緑と朱（赤）の混合で表現
	# hp_percent が高い = 緑が多い
	# hp_percent が低い = 朱（赤）が多い
	var green_amount := hp_percent
	var red_amount := 1.0 - hp_percent
	var bar_color := Color(0.9 * red_amount, 0.8 * green_amount, 0.0, 1.0)
	
	var current_width := BAR_WIDTH * hp_percent
	if current_width > 0:
		draw_rect(Rect2(-BAR_WIDTH / 2, Y_OFFSET, current_width, BAR_HEIGHT), bar_color)
	
	# 枠線（白）
	draw_rect(Rect2(-BAR_WIDTH / 2, Y_OFFSET, BAR_WIDTH, BAR_HEIGHT), Color.WHITE, false, 1.0)
