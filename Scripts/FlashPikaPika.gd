extends Node2D
class_name FlashPikaPika
## 白エフェクト画像を一定間隔で点滅させてピカピカ表示し、指定秒後に消す

const TOGGLE_INTERVAL := 0.08
const TOTAL_DURATION := 1.0

var _sprite: Sprite2D
var _elapsed: float = 0.0

func setup(texture: Texture2D) -> void:
	z_index = 50
	_sprite = Sprite2D.new()
	_sprite.z_index = 50
	_sprite.texture = texture
	_sprite.visible = true
	add_child(_sprite)

func start() -> void:
	_elapsed = 0.0
	set_process(true)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= TOTAL_DURATION:
		queue_free()
		return
	var toggle_count := int(_elapsed / TOGGLE_INTERVAL)
	var want_visible := (toggle_count % 2) == 0
	if _sprite and _sprite.visible != want_visible:
		_sprite.visible = want_visible
