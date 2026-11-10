## One goal card (GAME.md "Goal cards"). description is for Hermes and release notes only; the
## card shows `picture`, or a pictogram CardPicture draws from the condition when it's empty.
class_name GoalData
extends Resource

enum Condition {
	OBJECT_SCALE_AT_LEAST,   # subject grown to at least `amount` steps
	OBJECT_HAS_EFFECT,       # subject carries `effect`
	OBJECT_IN_ZONE,          # subject inside `other` (an object like the bathtub, or a zone name)
	GLUED_PAIR,              # subject glued to other (either may be &"any")
	OBJECT_HEIGHT_ABOVE,     # subject higher than `amount` metres
	OBJECT_SPEED_OVER,       # subject faster than `amount` m/s
}

@export var id: StringName = &"goal"
@export_multiline var description := ""
@export var picture: Texture2D
## 1 easy, 2 medium, 3 dad.
@export_range(1, 3) var band := 1
@export var condition: Condition = Condition.OBJECT_HAS_EFFECT
## ObjectData id ("cow", "chicken") or &"any".
@export var subject: StringName = &"any"
@export var other: StringName = &""
@export var effect: StringName = &""
@export var amount := 0.0
## Objects that glow softly while the card is the top card, so he can find them.
@export var hint_objects: Array[StringName] = []
