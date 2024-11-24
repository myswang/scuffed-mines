# scuffed-mines

A really bad implementation of Minesweeper in Lua

![scuffed mines](screenshot.png)

## Quick Start

Install the [LÖVE](https://love2d.org/) game framework.

Then go to the project root, and run

```
$ love .
```

to start the game.

## Controls

**Mouse:**

 - Left click: R
 - Right click: Flag a tile.
 - Middle click: Perform a "chord" where a revealed tile with the correct number of flags has all hidden tiles revealed.

**Keyboard:**

 - Enter: Start a new game (you can also click on the smiley face at the top)
 - Escape: Exit the game

 ## Game Configuration

The game consists of a single file, `main.lua`. You can easily modify the behaviour of the game by simply changing the variables at the top of this file.

For example, you can modify the overall difficulty of the game through the `tiles_y`, `tiles_x`, and `num_mines` parameters. Some [recommended values](https://en.wikipedia.org/wiki/Minesweeper_(video_game)) for these are listed below:

| Difficulty   | tiles_y | tiles_x | num_mines |
|--------------|---------|---------|-----------|
| Beginner     | 9       | 9       | 10        |
| Intermediate | 16      | 16      | 40        |
| Expert       | 16      | 30      | 99        |

You can also modify the window/tile scaling through the `tile_size` parameter.