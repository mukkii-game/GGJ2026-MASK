extends Sprite2D

@export var value: int = 5

#Movement
var time_passed: float = 0.0
var initial_position: Vector2 = Vector2.ZERO
@export var amplitude: float = 3.0
@export var frequency: float = 4.0

func _ready():
	initial_position = position

func _process(_delta):
	body_hover(_delta)

#Gently bob up and down with 'amplitude' where 'frequency' is speed
func body_hover(delta):
	time_passed += delta
	var new_y = initial_position.y + amplitude * sin(frequency * time_passed)
	position.y = new_y

#Get picked up by our player
func _on_area_2d_body_entered(body):
	if body.is_in_group("Player"):
		GameManager.add_money(value)
		AudioManager.play_sound(AudioManager.COIN_PICK, 0, -10)
		queue_free()

