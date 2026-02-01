extends Sprite2D
## 死亡時にマスク（顔）部分が飛んでいって消える演出

var velocity := Vector2.ZERO
var gravity := 800.0
var rotation_speed := 5.0
var initial_scale := 1.0
var target_scale := 5.0
var scale_duration := 0.5

func _ready() -> void:
	# ランダムな方向に飛ぶ
	velocity = Vector2(randf_range(-300, 300), randf_range(-600, -400))
	rotation_speed = randf_range(-10, 10)
	# 5倍に拡大するアニメーション
	initial_scale = scale.x
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(target_scale, target_scale), scale_duration)

func _process(delta: float) -> void:
	velocity.y += gravity * delta
	global_position += velocity * delta
	rotation += rotation_speed * delta
	
	# 画面外に出たら削除
	if global_position.y > 800:
		queue_free()
