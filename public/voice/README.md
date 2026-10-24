# Voice lines

The game's voice lines, one file per line, named exactly as below. They play automatically; a line without a file just stays silent.

**Formats:** Godot plays `.ogg`, `.wav` and `.mp3`, not `.m4a`. Your `.m4a` recordings are kept here as the originals, and the game plays an `.ogg` copy of each (Vorbis, high quality) under the name below. Re-recording a line: replace its `.m4a`, then convert, e.g. `ffmpeg -i memory_01.m4a -c:a libvorbis -q:a 8 memory_1.ogg`. Recorded names that differ from the game's: `memory_01`…`05` → `memory_1`…`5`, `awakening_08_dream` → `dream`, `prologue` → `title`.

## Naming convention

- **Scrolling text screens** are read by the narrator, title then body, one file each: `title` (the start screen), `dream`, `memory_1` … `memory_5`, `finale`, `faded`.
- **Cutscene lines** are `<scene>_<line number>_<speaker>`: two-digit line numbers, speaker in lowercase, `narrator` when nobody is speaking. Scenes are `awakening` (right after Start) and `ending` (the finale).
- Scrolling text waits for its narration to finish. A cutscene line plays when it appears and stops when the player presses Enter.

## Every file (22)

| # | File | Speaker | Plays |
|---|---|---|---|
| 1 | `title.ogg` | Narrator | Start screen, after the intro video |
| 2 | `awakening_01_narrator.ogg` | Narrator | Awakening cutscene |
| 3 | `awakening_02_narrator.ogg` | Narrator | Awakening cutscene |
| 4 | `awakening_03_doctor.ogg` | Doctor | Awakening cutscene |
| 5 | `awakening_04_demen.ogg` | Demen | Awakening cutscene |
| 6 | `awakening_05_doctor.ogg` | Doctor | Awakening cutscene |
| 7 | `awakening_06_daughter.ogg` | Daughter | Awakening cutscene |
| 8 | `awakening_07_doctor.ogg` | Doctor | Awakening cutscene |
| 9 | `dream.ogg` | Narrator | Before night 1 |
| 10 | `memory_1.ogg` | Narrator | After night 1 |
| 11 | `memory_2.ogg` | Narrator | After night 2 |
| 12 | `memory_3.ogg` | Narrator | After night 3 |
| 13 | `memory_4.ogg` | Narrator | After night 4 |
| 14 | `memory_5.ogg` | Narrator | After night 5 |
| 15 | `finale.ogg` | Narrator | After the last memory |
| 16 | `ending_01_narrator.ogg` | Narrator | Ending cutscene |
| 17 | `ending_02_demen.ogg` | Demen | Ending cutscene |
| 18 | `ending_03_narrator.ogg` | Narrator | Ending cutscene |
| 19 | `ending_04_narrator.ogg` | Narrator | Ending cutscene |
| 20 | `ending_05_narrator.ogg` | Narrator | Ending cutscene |
| 21 | `ending_06_narrator.ogg` | Narrator | Ending cutscene |
| 22 | `faded.ogg` | Narrator | Only if Demen fades away |

## Script

The lines, in the order they play. The wording comes from `scripts/story.gd`; if it changes there, this file needs regenerating.

### Start screen

**`title.ogg`** · Narrator

> BACKTRACK — The Ragebaiter's Guide to the Void

### 1. Awakening (hospital cutscene, right after Start)

**`awakening_01_narrator.ogg`** · Narrator

> 50 years later.

**`awakening_02_narrator.ogg`** · Narrator

> Demen awakens from his coma. He doesn't know who he is, who the people around him are, or where he is.

**`awakening_03_doctor.ogg`** · Doctor

> You've been in a coma for 50 years.

**`awakening_04_demen.ogg`** · Demen

> ...

**`awakening_05_doctor.ogg`** · Doctor

> This is your daughter.

**`awakening_06_daughter.ogg`** · Daughter

> Hi, Dad.

**`awakening_07_doctor.ogg`** · Doctor

> I'm sorry. You have dementia.

### 2. The Memory Game

**`dream.ogg`** · Narrator

> THE MEMORY GAME
>
> That night, after learning he has dementia, Demen falls asleep.
>
> In his dream he is a butterfly, faded and glowing, lost in the maze of his own brain.
>
> Somewhere in the dark are his memories. He must collect them, one night at a time.
>
> But the mind stumbles backward, and every shortcut costs a piece of who he is.

### 3. Core memories (one after each night)

The game adds the player's line strength under each memory on screen; that part isn't voiced.

**`memory_1.ogg`** · Narrator

> CORE MEMORY I — Sunshine
>
> The sun on your face. Every single day, outside, until the streetlights came on.
>
> You were a joyful young soul.

**`memory_2.ogg`** · Narrator

> CORE MEMORY II — The Ball
>
> A ball bouncing down the street. A bunch of young folk, laughing, shouting your name.
>
> You can almost hear it.

**`memory_3.ogg`** · Narrator

> CORE MEMORY III — The Driver
>
> Headlights. A horn. A driver looking at something else.
>
> Then you were flying.

**`memory_4.ogg`** · Narrator

> CORE MEMORY IV — The Well
>
> Cold stone. Black water. Coins glinting in the dark.
>
> You had fallen into a wishing well.

**`memory_5.ogg`** · Narrator

> CORE MEMORY V — The Wish
>
> In agonizing pain, you wished for one thing: a daughter who would never die.
>
> And with the wish came your name.

### 4. Finale

**`finale.ogg`** · Narrator

> 50 YEARS LATER
>
> The dream lasted so long that another 50 years passed by.
>
> Night after night, Demen collected his memories, one pattern at a time, until he remembered who he was.
>
> And then, he woke up.

### 5. Ending (hospital cutscene)

**`ending_01_narrator.ogg`** · Narrator

> Demen wakes up. His daughter is at his side.

**`ending_02_demen.ogg`** · Demen

> My name is Anakin Gilgamesh John-Smith.

**`ending_03_narrator.ogg`** · Narrator

> Everyone in the room breaks into tears.

**`ending_04_narrator.ogg`** · Narrator

> Then the doctor is gone. In his place, a swarm of butterflies.

**`ending_05_narrator.ogg`** · Narrator

> His daughter is gone too. Only butterflies remain.

**`ending_06_narrator.ogg`** · Narrator

> THE END

### Game over

**`faded.ogg`** · Narrator

> FADED AWAY
>
> Demen tried to skip the human connection and the learning process, and faded into irrelevancy.
>
> His daughter pulled the plug.
>
> He was a lost cause.
