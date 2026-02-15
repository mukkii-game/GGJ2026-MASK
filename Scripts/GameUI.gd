extends Control

@export var money_label : Label

var _training_contact_label: Label

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

func _process(delta: float) -> void:
	money_label.text = "Coins: " + "%d" % GameManager.money
	if GameManager.training_mode and _training_contact_label:
		GameManager.body_contact_type_timer -= delta
		if GameManager.body_contact_type_timer > 0:
			_training_contact_label.visible = true
			_training_contact_label.text = GameManager.body_contact_type_text
		else:
			_training_contact_label.visible = false
