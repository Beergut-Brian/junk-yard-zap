# Voice fixture (tests only)

`catchphrase.ogg` and `cheer.ogg` are copies of Zorp's synced voice files
(`openjar-characters` `v0.5.0`, `characters/zorp/voice/lib/catchphrase_big.ogg` and
`characters/zorp/voice/cheer.ogg`; Open Jar Games, in-house, see `assets/CREDITS.md`). The test
roster `roster_voice.json` points its made-up characters at them, so the chooser voice tests never
depend on the real roster's contents.

`join.ogg` and `swap_in.ogg` (added by jyz-gap-close-2) are copies of Zorp's synced
`characters/zorp/voice/join.ogg` and `swap_in.ogg` (`openjar-characters` `v0.5.3`; Open Jar Games,
generated with ElevenLabs, see `assets/CREDITS.md`), for the drop-in hello and solo swap tests.
