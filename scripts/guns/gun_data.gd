## One gun on the belt (GAME.md "The guns"). Data, so adding gun 8 is a Content lane job:
## data/guns/<id>.tres. The Zapper reads kind and params; the wheel draws icon (or a pictogram of
## the kind when icon is empty).
class_name GunData
extends Resource

enum Kind { SIZE, GRAB, BOUNCY, BALLOON, FREEZE, GLUE, MAGNET }

@export var id: StringName = &"gun"
@export var kind: Kind = Kind.BOUNCY
## SIZE: {"repeat": s between steps while held}. GRAB: {"reach": m, "throw_speed": m/s}.
@export var params: Dictionary = {}
## Belt-wheel picture. Empty: GunIcon draws a pictogram of the kind.
@export var icon: Texture2D
@export var beam_color := Color.WHITE
## Played on every zap that lands (zap_<id>).
@export var cue: StringName = &""
## Not drawn any more: the junk-built guns (scripts/art/gun_art.gd) take the beam colour.
@export var body_color := Color(0.6, 0.6, 0.6)


func zap_cue() -> String:
	return String(cue) if cue != &"" else "zap_%s" % id


## The EffectStack id this gun toggles (Effects.zap); SIZE and GRAB are driven by the Zapper.
func effect_id() -> StringName:
	match kind:
		Kind.BOUNCY: return &"bouncy"
		Kind.BALLOON: return &"balloon"
		Kind.FREEZE: return &"freeze"
		Kind.MAGNET: return &"magnet"
		Kind.GLUE: return &"glue"
		Kind.GRAB: return &"grab"
	return &"size"


func param(key: String, default):
	return params.get(key, default)
