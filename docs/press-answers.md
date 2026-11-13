# Every press answers: Junk Yard Zap menus

Kaden's standing rule 5: every press answers; a press that does nothing says so. The template fixed its
menu kit on `feature/template-press-answers-1` (commit `9d99f29`, its `docs/press-answers.md`). This game
adopted it on `feature/press-answers-adopt-1`, merged file by file into this game's own kit (which has
its own D-pad code, Start-to-ready (PF-5), five pause rows, a Restore old yard row in Settings and the
New yard / Restore question card).

`MenuInput.read()` now also reports `other` (the player) and `button` ("x", "y", "lb", "rb", "lt", "rt",
"l3", "r3", "select", "start") for a button the menus never use. `MenuInput.refuse(item, button)` plays
the refusal and wobbles the focused item.

**The refusal sound here is `nope`** (`nope_1/2.ogg`, the zapper's refused press), not the template's
`honk`: this game has no `honk.ogg`, and `test_launch_ready.gd` holds every menu cue to a designed file,
so the template's synth stand-in is left out of `UiSound` here.

**SILENT** = no sound and no visual.

## Before (dev @ 42491b1)

| Input | Lobby (start menu) | Pause list | Settings (lobby or pause) | Leave the game? | New yard / Restore question |
| --- | --- | --- | --- | --- | --- |
| A | ready / hold to start; New yard, Settings, Door: open | press the bar | step / toggle; Restore: ask | Stay or Leave | hold: fill the ring |
| B | un-ready; off Play: back to Play; **not ready, on Play: SILENT** | resume | close | Stay | keep the yard |
| X, Y, LB, RB, LT, RT, L3, R3 | **SILENT** | **SILENT** | **SILENT** | **SILENT** | **SILENT** |
| Up / down | move | move | row | move | **SILENT** |
| Left / right | chooser swap; nobody free: head-shake; **ready / counting / other podium in solo: SILENT** | **SILENT** | step the row; **on Restore old yard: SILENT** | move | **SILENT** |
| Start | ready (PF-5), then start; **ready and waiting for the other, or counting: SILENT** | resume (Game) | in pause: resume; **in the lobby: SILENT** | in pause: resume; **in the lobby: SILENT** | **SILENT** |
| Select | solo: switch podium; **not solo: SILENT** | **SILENT** | **SILENT** | **SILENT** | **SILENT** |
| Select + Start held | solo toggle (Players) | same | same | same | same |

## After

| Input | Lobby (start menu) | Pause list | Settings | Leave the game? | New yard / Restore question |
| --- | --- | --- | --- | --- | --- |
| X, Y, LB, RB, LT, RT, L3, R3 | refuse | refuse | refuse (Restore row too) | refuse | refuse, the card shakes |
| Up / down | unchanged | unchanged | unchanged | unchanged | refuse, the card shakes |
| Left / right | chooser unchanged; locked podium: refuse | step the list (right = down); past the end: refuse | unchanged; Restore row: refuse | unchanged | refuse, the card shakes |
| Start | ready / start unchanged; nothing to do (waiting, counting): refuse | resume (unchanged) | in pause: resume; in the lobby: refuse | in pause: resume; in the lobby: refuse | refuse, the card shakes |
| Select | solo: switch (unchanged); else refuse | refuse | refuse | refuse | refuse, the card shakes |
| B | un-ready / back to Play (unchanged); not ready on Play: refuse | resume (unchanged) | close (unchanged) | Stay (unchanged) | keep the yard (unchanged) |

Nothing else changes on a refusal: no focus move, no state, no setting, no pick, no backup, and the
question card keeps its ring and stays open.

Details (as the template):
- A trigger counts once per pull (past 0.6, re-armed under 0.3).
- A press that joins a pad is the join, never also a refusal.
- A button already held when a menu opens is not a press.
- Select with Start held (or Start with Select held) is the solo hold, never refused.
- Once the lobby's wipe has started, refusals are skipped (the screen is covered).
- In play (not a menu) nothing here changes: X, Y, LT, RT and the stick clicks in play are R-05's open
  gameplay question.
