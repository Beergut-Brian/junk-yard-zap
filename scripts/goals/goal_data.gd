## One goal card (GAME.md "Goal cards"). description is for Hermes and release notes only; the
## card shows `picture` (data/goals/pictures/, baked by scripts/goals/card_art.gd), or a pictogram
## Pictos draws from the condition when it's empty. Vocabulary: docs/contracts.md "Goal conditions".
class_name GoalData
extends Resource

## Append only: the .tres files store these as numbers.
enum Condition {
	OBJECT_SCALE_AT_LEAST,   # subject grown to at least `amount` steps
	OBJECT_HAS_EFFECT,       # subject carries `effect`
	OBJECT_IN_ZONE,          # subject inside `other` (an object like the bathtub, a zone or a card spot)
	GLUED_PAIR,              # subject glued to other (either may be &"any")
	OBJECT_HEIGHT_ABOVE,     # subject higher than `amount` metres
	OBJECT_SPEED_OVER,       # subject faster than `amount` m/s
	OBJECT_SCALE_AT_MOST,    # subject shrunk to at most `amount` steps (negative)
	OBJECT_HEIGHT_BELOW,     # subject lower than `amount` metres
	OBJECT_SPEED_UNDER,      # subject slower than `amount` m/s (resting)
	STACK_HEIGHT,            # `count` resting objects one on another, the top above `amount` metres
	ALL_OF,                  # the same object satisfies every one of `steps`
	SEQUENCE,                # the same object satisfies `steps` in order (needs a GoalMemory)
}

@export var id: StringName = &"goal"
@export_multiline var description := ""
@export var picture: Texture2D
## 1 easy, 2 medium, 3 dad.
@export_range(1, 3) var band := 1
## Order inside the band (low first); ties go by id.
@export var rank := 0
@export var condition: Condition = Condition.OBJECT_HAS_EFFECT
## ObjectData id ("cow", "chicken") or &"any".
@export var subject: StringName = &"any"
@export var other: StringName = &""
@export var effect: StringName = &""
@export var amount := 0.0
## How many different objects must hold it (STACK_HEIGHT: how many in the stack).
@export var count := 1
## ALL_OF / SEQUENCE parts. A step's own subject is ignored: the card's subject is the object.
@export var steps: Array[GoalData] = []
## Also holds when anything glued to the subject satisfies it (the cow-car raft).
@export var group := false
## The subject's last gun touch was inside this zone or spot ("from the barn loft").
@export var touched_in: StringName = &""
## In a SEQUENCE: no gun touched the subject since the previous step (chain reactions).
@export var untouched := false
## Objects that glow softly while the card is the top card, so he can find them.
@export var hint_objects: Array[StringName] = []
