# The Binding of Nexys

### Version 0.2.0

#### Matt Hennes and Tyler Heucke

## Controls

- WASD for movement
- Arrow keys for shooting

## Changelog

### Version 0.2.0
- Added support for seven segment display
- Enemies spawn randomly

### Version 0.1.4
- Register usage is now consistant and easier to understand

### Version 0.1.3
- Fixed bullet drawing
- Fixed inability to move right
- Added a single, randomly moving enemy
- Shooting the enemy kills it

### Version 0.1.2
- Implemented consistent indentation style

### Version 0.1.1
- Fixed spacing and replaced tab characters with spaces

### Version 0.1.0
- Refactored to store player location in r30 and r31
- Added draw_player subroutine
- Added a bullet location stored in r28 and r29
- Added a bullet travel direction stored in r27
- Added constants for bullet travel directions: up = 0x00, right = 0x01,
	up = 0x02, left = 0x03
- Refactored the shoot subroutines to use the new bullet representation
- Re-wrote the main subroutine to call move_bullet and draw_bullet
	subroutines (need to implement them)
- Implemented move_bullet subroutine
- Replaced SHOT_COLOR constants with one BULLET_COLOR constant
- Implemented draw_bullet subroutine
- Added a delay_loop subroutine and a call to it in main
- Added delay constant for the time of the delay
- Added comments to things and normalized spacings

## Registers (yanked from source)
```nasm
;--------------------------------------------------------------------------
;- Register Usage
;--------------------------------------------------------------------------
;- Game
;- R00: Player X
;- R01: Player Y
;- R02: Direction
;- R03: Projectile X
;- R04: Projectile Y
;- R05: Random Number
;- R06: Enemy1 X
;- R07: Enemy1 Y
;- R08: Enemy2 X
;- R09: Enemy2 Y
;- R10: Enemy3 X
;- R11: Enemy3 Y
;-
;- Unused
;- R12
;- R13
;- R14
;- R15
;- R16
;- R17
;-
;- Input
;- R18: Key Pressed
;- 
;- Drawing
;- R19: Temporary Color
;- R20: Temporary X
;- R21: Temporary Y
;- R22: draw_line Ending Tracker
;- R23: draw_background Row Tracker
;- R24: draw_dot X
;- R25: draw_dot Y 
;-
;- Timing
;- R26: Enemy Movement Delay
;- R27: Inner Delay
;- R28: Middle Delay
;- R29: Outer Delay
;-
;- Hardware
;- R30: Key-up Info Flag
;- R31: PS2 Reset
;--------------------------------------------------------------------------
```
