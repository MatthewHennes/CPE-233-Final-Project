# The Binding of Nexys

### Version 0.1.2

#### Matt Hennes and Tyler Heucke

## Changelog

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

### Version 0.1.1
- Fixed spacing and replaced tab characters with spaces

### Version 0.1.2
- Implemented consistent indentation style
