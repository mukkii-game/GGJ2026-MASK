extends State
class_name PlayerFireDash

## Phase A で廃止。誤遷移時は即 Idle へ戻す。

func Enter() -> void:
	state_transition.emit(self, "Idle")

func Update(_delta: float) -> void:
	state_transition.emit(self, "Idle")
