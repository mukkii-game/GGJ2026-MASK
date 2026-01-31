extends Node
## BGMを指定秒数から再生し、ループ時も同じ位置から再生する

@export var start_offset_sec := 11.0
@export var player_node_name := "AudioStreamPlayer"

func _ready() -> void:
	var asp := get_node_or_null(player_node_name) as AudioStreamPlayer
	if not asp:
		return
	asp.play(start_offset_sec)
	asp.finished.connect(_on_finished.bind(asp))

func _on_finished(asp: AudioStreamPlayer) -> void:
	asp.play(start_offset_sec)
