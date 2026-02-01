extends AudioStreamPlayer
## BGMを指定位置から再生するスクリプト

@export var start_offset: float = 0.0

func _ready() -> void:
	# _readyはシーン読み込み時に早すぎる可能性があるので、1フレーム待つ
	await get_tree().process_frame
	if stream and not playing:
		play(start_offset)
		print("BGM started: ", stream.resource_path if stream else "no stream")
