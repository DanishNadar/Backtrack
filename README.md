# Backtrack — The Ragebaiter's Guide to the Void

A 2D labyrinth game about patterns, memory and ragebait. Demen, a faded, glowing butterfly (a 67-year-old recovering from a coma), flies through a hand-drawn map of their own brain every night to recover a core memory.

## Running

Requires **Godot 4.3+** (built and tested on 4.7). Open `project.godot` in the Godot editor and press F5, or:

```
godot --path .
```

## Controls

| Key | Action |
|---|---|
| Enter / click | Start the game from the title screen |
| Arrows / WASD | Fly |
| Enter / Space | Continue after a memory |

## The map

Levels are drawn as images (`public/maps/*.png`). The game reads the walls straight from the pixels, and only what is drawn on the map exists; the map edges are solid:

| On the map | Meaning |
|---|---|
| Purple ground | Path |
| Pink bars | Walls that can't be crossed |
| Grey bars | Secret walls (see below) |
| Green square | Start |
| Yellow square | End |
| Red "67" / crab tumors | Landmarks; they glow red so you can orient yourself |
| Bell tumor | Starts the Simon Says minigame |

Start, end and landmark positions for each map are listed in `MAPS` at the top of `scripts/map_level.gd`. To add a map, drop the PNG in `public/maps/` and add an entry there. Nights beyond the number of maps cycle back through them.

## Mechanics

- **Darkness**: only what's in Demen's line of sight is lit. Everything else is black. Tumor glows and open secret walls only appear once you can see them. The start square stays visible.
- **End beacon**: the yellow end always shows, glows and sends out pulsing rings, and a yellow arrow beside Demen always points toward it.
- **Sounds**: flying into a wall plays the error sound. Taking damage (secret wall, wrong Simon Says note) plays the hurt sound. Every press on the Simon Says board plays the powerup sound.
- **Simon Says**: touching the bell tumor pauses the night. The black board plays 5 cells; repeat them on the pink board (click, or Q W E / A S D / Z X C). Each wrong attempt costs 5% line strength (shown on the board) and replays the sequence. Finishing gives +5%.
- **Backtrack**: every 8–15 s you're thrown back a random distance along the trail you actually flew. 30% of backtracks send you all the way to the start.
- **Secret walls**: grey bars block you normally. After a backtrack sends you to the start, they glow red and become passable until the next backtrack. Each pass through costs 10% line strength.
- **Line strength**: starts at 25%. +15% for a night finished without using secret walls. At 0% Demen fades away (game over).
- **Story**: told in Star Wars-style text crawls (Enter skips) and stick-figure hospital cutscenes (Enter advances). Prologue crawl -> awakening cutscene -> "The Memory Game" crawl -> 5 nights, each ending in a core-memory crawl -> finale crawl and cutscene (his name, tears, then the doctor and daughter turn into butterflies) -> back to the title. Fading away plays the "Faded Away" crawl instead. All story text is in `scripts/story.gd`.

Tuning constants are at the top of `scripts/main.gd`, `scripts/map_level.gd` and `scripts/game_state.gd`.

## Layout

- `scenes/main.tscn`: main scene (camera, HUD and overlay UI)
- `scripts/main.gd`: gameplay, darkness, backtrack, secret walls, drawing
- `scripts/map_level.gd`: map definitions, reads walls from the image, collision and line of sight
- `scripts/simon_says.gd`: the Simon Says minigame
- `scripts/story.gd`: all story text, in the order it's told
- `scripts/crawl.gd` + `crawl.gdshader`: the Star Wars-style text crawl
- `scripts/cutscene.gd`: stick-figure hospital cutscenes (placeholders for character art)
- `scripts/game_state.gd`: autoload with line strength and the night counter
- `public/`: art (maps, Demen, tumors, start/end, Simon Says, sounds)
