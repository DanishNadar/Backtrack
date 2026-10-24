# Backtrack — The Ragebaiter's Guide to the Void

A 2D labyrinth game about patterns, memory and ragebait. A faded, glowing butterfly (a 67-year-old recovering from a coma) navigates a new maze of their own brain every night to recover a core memory.

## Running

Requires **Godot 4.3+** (built and tested on 4.7). Open `project.godot` in the Godot editor and press F5, or:

```
godot --path .
```

## Controls

| Key | Action |
|---|---|
| Arrows / WASD | Move |
| Space | Take the restricted shortcut (only when offered) |
| Enter / Space | Continue after a memory |

## MVP mechanics

- **Brain look**: the floor is a dark purple gradient and the walls are wobbly pink "brain folds".
- **Colour code**: Purple = Puzzle (the maze), Green = Go (the exit), Red = Restricted (the cheat shortcut), Blue = Ragebait Road.
- **Fog of war**: you only see straight down the corridors from where you stand. The start (lavender ring) and the goal (green light) are always visible. Paths you've walked are not remembered.
- **Ragebait Road**: one cell on the east edge opens onto a blue road with a green light at the far end. The road never ends and the light never gets closer, while hints keep telling you you're almost there. You can't turn around, so only a backtrack gets you out.
- **No turning back**: you can't reverse into the cell you just left. At a dead end you have to wait for the backtrack.
- **Backtrack**: every 8–15 s you're thrown back a random distance along the path you walked. There's a 10% chance it sends you to the start.
- **Restricted shortcut**: when you're sent to the start, a red restricted tile opens for 5 s. Taking it drops you about 80% of the way to the goal, but costs line strength.
- **Line strength**: starts at 25%. +15% for each honest night, −30% for each shortcut used. At 0% you fade away (game over).
- **Core memories**: reaching the goal shows that night's memory text, then the next, larger maze begins.

Tuning constants are at the top of `scripts/main.gd` and `scripts/game_state.gd`.

## Layout

- `scenes/main.tscn`: main scene (maze node + HUD/overlay UI)
- `scripts/main.gd`: gameplay, fog, backtrack, shortcut, drawing
- `scripts/maze_generator.gd`: maze generation (recursive backtracker + loops) and BFS solver
- `scripts/game_state.gd`: autoload with strength, night counter and memory texts
