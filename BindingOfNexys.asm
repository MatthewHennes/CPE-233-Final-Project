;--------------------------------------------------------------------------
;- The Binding of Nexys
;- Programmers: Matt Hennes & Tyler Heucke
;- Creation Date: 11/20/14
;-
;- Version:     0.3.2
;- Description: A Binding of Isaac clone running on the RAT CPU
;--------------------------------------------------------------------------

;--------------------------------------------------------------------------
;- Port Constants
;--------------------------------------------------------------------------
.EQU SWITCH_PORT = 0x20 ; port for switches      INPUT
.EQU RAND_PORT   = 0x50 ; port for random number INPUT
.EQU BTN_PORT    = 0x21 ; port for buttons       INPUT
.EQU KEYBOARD    = 0x25 ; port for keyoard       INPUT
.EQU VGA_HADD    = 0x90 ; port for vga x         OUTPUT
.EQU VGA_LADD    = 0x91 ; port for vga y         OUTPUT
.EQU VGA_COLOR   = 0x92 ; port for vga color     OUTPUT
.EQU LEDS        = 0x40 ; port for LEDs          OUTPUT
.EQU SSEG        = 0x81 ; port for display       OUTPUT

;-- Keyboard Stuff -------------------------------------------------------
.EQU PS2_KEY_CODE = 0x44 ; Port for Key Code (data)
.EQU PS2_STATUS   = 0x45 ; Port for status
.EQU PS2_CONTROL  = 0x46 ; Ready for data control
.EQU int_flag     = 0x01 ; interrupt data from keyboard
.EQU KEY_UP       = 0xF0 ; Key release data
;--------------------------------------------------------------------------

;--------------------------------------------------------------------------
;- Game Constants
;--------------------------------------------------------------------------
.EQU DELAY                  = 0xBB ; Delay timer

.EQU BG_COLOR               = 0x00 ; Black
.EQU WALL_COLOR             = 0xFF ; White
.EQU ENEMY_COLOR            = 0xE0 ; Red
.EQU PLAYER_COLOR           = 0x1C ; Green

.EQU DIRECTION_UP           = 0x00
.EQU DIRECTION_RIGHT        = 0x01
.EQU DIRECTION_DOWN         = 0x02
.EQU DIRECTION_LEFT         = 0x03
.EQU DIRECTION_NONE         = 0x04

.EQU BULLET_COLOR           = 0x03 ; Blue

.EQU NUM_LIVES              = 0x03
.EQU STARTING_SCORE         = 0x00
;--------------------------------------------------------------------------

;--------------------------------------------------------------------------
;- Keyboard Constants
;--------------------------------------------------------------------------
.EQU KEY_W                  = 0x1D
.EQU KEY_A                  = 0x1C
.EQU KEY_S                  = 0x1B
.EQU KEY_D                  = 0x23

.EQU ARROW_UP               = 0x75
.EQU ARROW_DOWN             = 0x72
.EQU ARROW_LEFT             = 0x6B
.EQU ARROW_RIGHT            = 0x74

.EQU KEY_UP                 = 0xF0 ; key release data
;--------------------------------------------------------------------------

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
;-
;- Game
;- R15: Level
;- R16: Lives
;- R17: Score
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

;--------------------------------------------------------------------------
;- Program Start
;--------------------------------------------------------------------------
.CSEG
.ORG        0x01

init:
    MOV   R30,    0x00      ; clear key-up flag
    MOV   R15,    0x01      ; start on level one
    MOV   R16,    NUM_LIVES ; Store number of lives
    MOV   R17,    STARTING_SCORE
    CALL  draw_background   ; draw using default color
    CALL  draw_walls        ; 4 lines around edge of screen
    MOV   R00,    0x14      ; Starting player x-coord = 20
    MOV   R01,    0x0F      ; Starting player y-coord = 15
    CALL  draw_player       ; draw green hero
    MOV   R06,    0xFE      ; set enemy spawn
    MOV   R07,    0xFE      ; set enemy spawn
    CALL  draw_enemy        ; draw first enemy
    SEI                     ; set interrupt to receive key presses

main:
    CALL  move_bullet       ; update the bullet's location
    CALL  draw_bullet       ; draw the bullet
    CALL  detect_hits       ; check if bullet hit enemy
    CMP   R26, 0x00         ; enemy monster delay check
    BRNE  no_move           ; branch if still counting down
    CALL  move_enemy        ; otherwise move monster 
    MOV   R26, 0x30         ; and reset counter
no_move:
    SUB   R26, 0x01         ; subtract one from delay
    CALL  draw_player       ; draw the player
    CALL  draw_enemy        ; draw the enemy
    CALL  delay_loop        ; create a delay between in-game "ticks"
    OUT   R17, SSEG         ; output score
    BRN   main              ; repeat main subroutine

;--------------------------------------------------------------
; Interrup Service Routine - Handles Interrupts from keyboard
;--------------------------------------------------------------
; Tweaked Registers; R18,R31,R30
;--------------------------------------------------------------
isr:
    CMP   R30, int_flag        ; check key-up flag
    BRNE  continue
    MOV   R30, 0x00            ; clear key-up flag
    BRN   reset_ps2_register

continue:
    IN    R18, PS2_KEY_CODE     ; get keycode data

check_w:
    CMP   R18,KEY_W             ; was 'w' pressed?
    BRNE  check_a
    CALL  move_up
    BRN   reset_ps2_register

check_a:
    CMP   R18,KEY_A             ; was 'a' pressed?
    BRNE  check_s
    CALL  move_left
    BRN   reset_ps2_register

check_s:
    CMP   R18,KEY_S             ; was 's' pressed?
    BRNE  check_d
    CALL  move_down
    BRN   reset_ps2_register

check_d:
    CMP   R18,KEY_D             ; was 'd' pressed?
    BRNE  check_up
    CALL  move_right
    BRN   reset_ps2_register

check_up:
    CMP   R18,ARROW_UP         ; was 'up' pressed?
    BRNE  check_down
    CALL  shoot_up
    BRN   reset_ps2_register

check_down:
    CMP   R18,ARROW_DOWN     ; was 'down' pressed?
    BRNE  check_left
    CALL  shoot_down
    BRN   reset_ps2_register

check_left:
    CMP   R18,ARROW_LEFT     ; was 'left' pressed?
    BRNE  check_right
    CALL  shoot_left
    BRN   reset_ps2_register

check_right:
    CMP   R18,ARROW_RIGHT   ; was 'right' pressed?
    BRNE  key_up_check
    CALL  shoot_right
    BRN   reset_ps2_register

key_up_check:
    CMP   R18,KEY_UP            ; look for key-up code
    BREQ  set_skip_flag        ; branch if found
    BRN   reset_ps2_register


set_skip_flag:
    ADD   R30, KEY_UP            ; indicate key-up found
    BRN   reset_ps2_register

reset_skip_flag:
   MOV   R30, 0x00           ; indicate key-up handles
   BRN   reset_ps2_register
;-------------------------------------------------------------------

;-------------------------------------------------------------------
; reset PS2 register which allow it to send more interrupts
;-------------------------------------------------------------------
reset_ps2_register:
    MOV    R31, 0x01
    OUT    R31, PS2_CONTROL
    MOV    R31, 0x00
    OUT    R31, PS2_CONTROL
    RETIE
;-------------------------------------------------------------------

;-------------------------------------------------------------------
; do something meaningful when particular keys are pressed
;-------------------------------------------------------------------
move_up:
    CMP  R01,    0x01   ; Check if player is already at the edge of the screen
    BREQ move_up_end    ; If so, do not move the player
    MOV  R19,    BG_COLOR  ; Set draw-color to the background color
    MOV  R20,     R00    ; Set draw-x-coord to the player's old location
    MOV  R21,     R01    ; Set draw-y-coord to the player's old location
    CALL draw_dot     ; Fill in the player's old location with the background color
    SUB  R01,    0x01   ; Move the player up
    CALL draw_player    ; Draw the player in the new location
move_up_end:
    RET

move_left:
    CMP  R00,    0x01   ; Check if player is already at the edge of the screen
    BREQ move_left_end  ; If so, do not move the player
    MOV  R19,    BG_COLOR  ; Set draw-color to the background color
    MOV  R20,     R00    ; Set draw-x-coord to the player's old location
    MOV  R21,     R01    ; Set draw-y-coord to the player's old location
    CALL draw_dot     ; Fill in the player's old location with the background color
    SUB  R00,    0x01   ; Move the player left
    CALL draw_player    ; Draw the player in the new location
move_left_end:
    RET

move_down:
    CMP  R01,    0x1C   ; Check if player is already at the edge of the screen
    BREQ move_down_end  ; If so, do not move the player
    MOV  R19,    BG_COLOR  ; Set draw-color to the background color
    MOV  R20,     R00    ; Set draw-x-coord to the player's old location
    MOV  R21,     R01    ; Set draw-y-coord to the player's old location
    CALL draw_dot     ; Fill in the player's old location with the background color
    ADD  R01,    0x01   ; Move the player down
    CALL draw_player    ; Draw the player in the new location
move_down_end:
    RET

move_right:
    CMP  R00,    0x26    ; Check if player is already at the edge of the screen
    BREQ move_right_end ; If so, do not move the player
    MOV  R19,   BG_COLOR ; Set draw-color to the background color
    MOV  R20,     R00    ; Set draw-x-coord to the player's old location
    MOV  R21,     R01    ; Set draw-y-coord to the player's old location
    CALL draw_dot     ; Fill in the player's old location with the background color
    ADD  R00,    0x01    ; Move the player right
    CALL draw_player    ; Draw th player in the new location
move_right_end:
    RET

shoot_up:
    MOV  R02,   DIRECTION_UP   ; Set the bullet direction to up
    MOV  R03,   R00           ; Set the bullet x-coord to the player x-coord
    MOV  R04,   R01           ; Set the bullet y-coord to the player y-coord
    RET

shoot_right:
    MOV  R02,   DIRECTION_RIGHT  ; Set the bullet direction to up
    MOV  R03,   R00           ; Set the bullet x-coord to the player x-coord
    MOV  R04,   R01           ; Set the bullet y-coord to the player y-coord
    RET

shoot_down:
    MOV  R02,   DIRECTION_DOWN   ; Set the bullet direction to down
    MOV  R03,   R00           ; Set the bullet x-coord to the player x-coord
    MOV  R04,   R01           ; Set the bullet y-coord to the player y-coord
    RET

shoot_left:
    MOV  R02,   DIRECTION_LEFT   ; Set the bullet direction to left
    MOV  R03,   R00           ; Set the bullet x-coord to the player x-coord
    MOV  R04,   R01           ; Set the bullet y-coord to the player y-coord
    RET
;--------------------------------------------------------------------

;--------------------------------------------------------------------
;- Subroutine: move_bullet
;-
;- Moves the bullet to the next location based on its move direction
;-
;- Parameters:
;-  R02 = bullet direction of motion
;-  R03 = bullet x-coordinate
;-  R04 = bullet y-coordinate
;-
;- Tweaked registers: R03, R04
;--------------------------------------------------------------------
move_bullet:
    CALL  check_walls           ; Check if bullet has hit wall
    CMP   R02,  DIRECTION_NONE  ; Check if bullet did hit wall
    BREQ  bullet_stop           ; Only move bullet if still moving
    MOV   R19,  BG_COLOR        ; Paint old location with floor color
    MOV   R20,  R03             ; Paint old location
    MOV   R21,  R04             ; Paint old location
    CALL  draw_dot              ; Paint!
    CMP   R02,  DIRECTION_UP    ; Check if the bullet was fired upwards
    BREQ  bullet_move_up        ; Move it appropriately
    CMP   R02,  DIRECTION_RIGHT ; Check if the bullet was fired to the right
    BREQ  bullet_move_right     ; Move it appropriately
    CMP   R02,  DIRECTION_DOWN  ; Check if the bullet was fired downwards
    BREQ  bullet_move_down      ; Move it appropriately
    CMP   R02,  DIRECTION_LEFT  ; Check if the bullet was fired to the left
    BREQ  bullet_move_left      ; Move it appropriately
bullet_stop:
    MOV   R03,  0xFF            ; Move bullet off screen if stopped
    MOV   R04,  0xFF            ; Off screen
    RET
bullet_move_up:
    SUB   R04,  0x01         ; Move the bullet up
    RET
bullet_move_right:
    ADD   R03,  0x01         ; Move the bullet to the right
    RET
bullet_move_down:
    ADD   R04,  0x01         ; Move the bullet downwards
    RET
bullet_move_left:
    SUB   R03,  0x01         ; Move the bullet to the left
    RET
;--------------------------------------------------------------------

;--------------------------------------------------------------------
;-  Subroutine: check_walls
;- 
;-  Stops bullet from moving through walls
;--------------------------------------------------------------------
check_walls:
    CMP   R03,  0x00              ; Check left wall
    BREQ  stop_bullet
    CMP   R03,  0x27              ; Right wall
    BREQ  stop_bullet 
    CMP   R04,  0x00              ; Top wall
    BREQ  stop_bullet
    CMP   R04,  0x1D              ; Bottom wall
    BREQ  stop_bullet
    RET
stop_bullet:
    MOV   R02,  DIRECTION_NONE    ; Set direction to none
    RET
;-------------------------------------------------------------------

;--------------------------------------------------------------------
;-  Subroutine: draw_horizontal_line
;-
;-  Draws a horizontal line from (R20,R21) to (R22,R21) using color in R19.
;-   This subroutine works by consecutive calls to drawdot, meaning
;-   that a horizontal line is nothing more than a bunch of dots.
;-
;-  Parameters:
;-   R20  = starting x-coordinate
;-   R21  = y-coordinate
;-   R22  = ending x-coordinate
;-   R19  = color used for line
;-
;- Tweaked registers: R20,R22
;--------------------------------------------------------------------
draw_horizontal_line:
    ADD    R22,  0x01          ; go from R20 to R22 inclusive

draw_horiz1:
    CALL   draw_dot            ; draw tile
    ADD    R20,  0x01          ; increment column (X) count
    CMP    R20,  R22           ; see if there are more columns
    BRNE   draw_horiz1         ; branch if more columns
    RET
;--------------------------------------------------------------------


;---------------------------------------------------------------------
;-  Subroutine: draw_vertical_line
;-
;-  Draws a horizontal line from (R20,R21) to (R20,R22) using color in R19.
;-   This subroutine works by consecutive calls to drawdot, meaning
;-   that a vertical line is nothing more than a bunch of dots.
;-
;-  Parameters:
;-   R20  = x-coordinate
;-   R21  = starting y-coordinate
;-   R22  = ending y-coordinate
;-   R19  = color used for line
;-
;- Tweaked registers: R21,R22
;--------------------------------------------------------------------
draw_vertical_line:
    ADD    R22,  0x01         ; go from R21 to R22 inclusive

draw_vert1:
    CALL   draw_dot           ; draw tile
    ADD    R21,  0x01         ; increment row (y) count
    CMP    R21,  R22          ; see if there are more rows
    BRNE   draw_vert1         ; branch if more rows
    RET
;--------------------------------------------------------------------

;---------------------------------------------------------------------
;-  Subroutine: draw_background
;-
;-  Fills the 30x40 grid with one color using successive calls to
;-  draw_horizontal_line subroutine.
;-
;-  Tweaked registers: R28,R21,R20,R22
;----------------------------------------------------------------------
draw_background:
    MOV   R19,  BG_COLOR              ; use default color
    MOV   R23,  0x00                  ; R28 keeps track of rows
start:
    MOV   R21,  R23                   ; load current row count
    MOV   R20,  0x00                  ; restart x coordinates
    MOV   R22,  0x27                  ; ending coordinate
    CALL  draw_horizontal_line        ; draw a complete line
    ADD   R23,  0x01                  ; increment row count
    CMP   R23,  0x1E                  ; see if more rows to draw
    BRNE  start                       ; branch to draw more rows
    RET
;---------------------------------------------------------------------

;---------------------------------------------------------------------
;-  Subroutine: draw_walls
;-
;-  Fills the edges of the 30x40 grid with one color using successive calls to
;-  draw_horizontal_line subroutine.
;-
;-  Tweaked registers: R22
;----------------------------------------------------------------------
draw_walls:
    MOV   R19,  WALL_COLOR           ; use wall color

    MOV   R21,  0x00                 ; restart y position
    MOV   R20,  0x00                 ; restart x position
    MOV   R22,  0x28                 ; ending x position
    CALL  draw_horizontal_line       ; draw a complete line

    MOV   R21,  0x1D                 ; restart y position
    MOV   R20,  0x00                 ; restart x position
    MOV   R22,  0x28                 ; ending x position
    CALL  draw_horizontal_line       ; draw a complete line

    MOV   R21,  0x00                 ; restart y position
    MOV   R20,  0x00                 ; restart x position
    MOV   R22,  0x1E                 ; ending y position
    CALL  draw_vertical_line         ; draw a complete line

    MOV   R21,  0x00                 ; restart y position
    MOV   R20,  0x27                 ; restart x position
    MOV   R22,  0x1E                 ; ending y position
    CALL  draw_vertical_line         ; draw a complete line

    RET
;---------------------------------------------------------------------

;---------------------------------------------------------------------
;- Subrountine: draw_dot
;-
;- This subroutine draws a dot on the display the given coordinates:
;-
;- (X,Y) = (R20,R21)  with a color stored in R19
;-
;- Tweaked registers: R25,R24
;---------------------------------------------------------------------
draw_dot:
    MOV   R25,  R21         ; copy Y coordinate
    MOV   R24,  R20         ; copy X coordinate

    AND   R24,  0x3F        ; make sure top 2 bits cleared
    AND   R25,  0x1F        ; make sure top 3 bits cleared

    ;--- you need bottom two bits of R25 into top two bits of R24
    LSR   R25               ; shift LSB into carry
    BRCC  bit7              ; no carry, jump to next bit
    OR    R24,  0x40        ; there was a carry, set bit
    CLC                     ; freshen bit, do one more left shift

bit7:
    LSR   R25               ; shift LSB into carry
    BRCC  dd_out            ; no carry, jump to output
    OR    R24,  0x80        ; set bit if needed

dd_out:
    OUT   R24,  VGA_LADD    ; write low 8 address bits to register
    OUT   R25,  VGA_HADD    ; write hi 3 address bits to register
    OUT   R19,  VGA_COLOR   ; write data to frame buffer
    RET
; --------------------------------------------------------------------

;--------------------------------------------------------------------
;- Subroutine: detect_hits
;- 
;- Detects all hits occuring
;- 
;- Player = R00, R01
;- Bullet = R03, R04
;- Enemy1 = R06, R07
;---------------------------------------------------------------------
detect_hits:
    CMP  R03,  R06          ; Check if bullet x = enemy x
    BRNE no_hit_enemy
    CMP  R04,  R07          ; Check if bullet y = enemy y
    BRNE no_hit_enemy
    ADD  R17,  0x01         ; Score one point for hit
    MOV  R06,  0xFE         ; Move enemy off screen to respawn
    MOV  R07,  0xFE         ; Move enemy off screen
    
level_two:
    CMP  R17,  0x05         ; Level 2 after 4 kills
    BRNE level_three     
    ADD  R15,  0x01         ; Level up!

level_three:
    CMP  R17,  0x0A         ; Level 3 after 9 kills
    BRNE no_hit_enemy 
    ADD  R15,  0x01         ; Level up!

no_hit_enemy:
    CMP  R00,  R06          ; Check if player x = enemy x
    BRNE no_hit_player
    CMP  R01,  R07          ; Check if player y = enemy y
    BRNE no_hit_player
    CMP  R16,  0x00         ; Check if out of lives
    BREQ game_over
    SUB  R16,  0x01         ; Subtract 1 life for death
    MOV  R00,  0x14         ; Respawn player x
    MOV  R01,  0x0F         ; Respawn player y
    CLI
    CALL delay_loop         ; Respawn delay
    SEI
    RET

no_hit_player:
    RET

game_over:
    CLI
    OUT  R17,  SSEG
    BRN  game_over
;---------------------------------------------------------------------

;---------------------------------------------------------------------
;- Subroutine: draw_player
;-
;- This subroutine draws the player on the display at the correct coordinates.
;-
;- (X, Y) = (R00, R01)
;-
;- Tweaked registers: R25, R24, R19, R21, R20
;---------------------------------------------------------------------
draw_player:
    MOV  R19,  PLAYER_COLOR  ; Set the draw-color to the player's color
    MOV  R21,  R01           ; Move the player's y coord into the draw y coord
    MOV  R20,  R00           ; Move the player's x coord into the draw x coord
    CALL draw_dot            ; Draw a dot at the location
    RET
;---------------------------------------------------------------------

;---------------------------------------------------------------------
;- Subroutine: draw_enemy
;-
;- This subroutine draws the enemy on the display at the correct coordinates.
;-
;- Enemy 1 (X, Y) = (R06, R07)
;- Enemy 2 (X, Y) = (R08, R09)
;- Enemy 3 (X, Y) = (R10, R11)
;-
;- Tweaked registers: R25, R24, R19, R21, R20
;---------------------------------------------------------------------
draw_enemy:                    ; spawns first enemy
    CMP  R06,  0xFE            ; Check if enemy is off screen
    BRNE spawn_enemy_two
    CMP  R06,  0x00            ; Check if enemy is in left wall
    BRNE spawn_enemy_two
    CMP  R06,  0x1E            ; Check if enemy is in right wall
    BRNE spawn_enemy_two
    CMP  R07,  0x00            ; Check if enemy is in top wall
    BRNE spawn_enemy_two
    CMP  R07,  0x13            ; Check if enemy is in left wall
    BRNE spawn_enemy_two
    IN   R05,  RAND_PORT       ; get a random number
    AND  R05,  0x1F            ; get a number less than 32
    MOV  R06,  R05             ; Move to new spawn
    IN   R05,  RAND_PORT       ; get a random number
    AND  R05,  0x1F            ; get a number less than 32
    MOV  R07,  R05             ; Move to new spawn

spawn_enemy_two:               ; spawns extra enemy if necessary
    CMP  R15,  0x02            ; Check if on level 2 or 3
    BRNE spawn_enemy_three
    CMP  R08,  0xFE            ; Check if enemy is off screen
    BRNE spawn_enemy_three
    CMP  R08,  0x00            ; Check if enemy is in left wall
    BRNE spawn_enemy_three
    CMP  R08,  0x1E            ; Check if enemy is in right wall
    BRNE spawn_enemy_three
    CMP  R09,  0x00            ; Check if enemy is in top wall
    BRNE spawn_enemy_three
    CMP  R09,  0x13            ; Check if enemy is in left wall
    BRNE spawn_enemy_three
    IN   R05,  RAND_PORT       ; get a random number
    AND  R05,  0x1F            ; get a number less than 32
    MOV  R08,  R05             ; Move enemy 2 x to new spawn
    IN   R05,  RAND_PORT       ; get a random number
    AND  R05,  0x1F            ; get a number less than 32
    MOV  R09,  R05             ; Move enemy 2 y to new spawn

spawn_enemy_three:             ; spawns both extra enemies if necessary
    CMP  R15,  0x03            ; Check if on level 2 or 3
    BRNE draw_enemy_continue
    CMP  R10,  0xFE            ; Check if enemy is off screen
    BRNE spawn_enemy_three_cont
    CMP  R10,  0x00            ; Check if enemy is in left wall
    BRNE spawn_enemy_three_cont
    CMP  R10,  0x1E            ; Check if enemy is in right wall
    BRNE spawn_enemy_three_cont
    CMP  R11,  0x00            ; Check if enemy is in top wall
    BRNE spawn_enemy_three_cont
    CMP  R11,  0x13            ; Check if enemy is in left wall
    BRNE spawn_enemy_three_cont
    IN   R05,  RAND_PORT       ; get a random number
    AND  R05,  0x1F            ; get a number less than 32
    MOV  R10,  R05             ; Move enemy 2 x to new spawn
    IN   R05,  RAND_PORT       ; get a random number
    AND  R05,  0x1F            ; get a number less than 32
    MOV  R11,  R05             ; Move enemy 2 y to new spawn
spawn_enemy_three_cont:
    CMP  R08,  0xFE            ; Check if enemy is off screen
    BRNE draw_enemy_continue
    CMP  R08,  0x00            ; Check if enemy is in left wall
    BRNE draw_enemy_continue 
    CMP  R08,  0x1E            ; Check if enemy is in right wall
    BRNE draw_enemy_continue 
    CMP  R09,  0x00            ; Check if enemy is in top wall
    BRNE draw_enemy_continue 
    CMP  R09,  0x13            ; Check if enemy is in left wall
    BRNE draw_enemy_continue 
    IN   R05,  RAND_PORT       ; get a random number
    AND  R05,  0x1F            ; get a number less than 32
    MOV  R08,  R05             ; Move enemy 3 x to new spawn
    IN   R05,  RAND_PORT       ; get a random number
    AND  R05,  0x1F            ; get a number less than 32
    MOV  R09,  R05             ; Move enemy 3 y to new spawn

draw_enemy_continue:
    MOV  R19,  ENEMY_COLOR     ; Set the draw-color to the player's color
    MOV  R20,  R06             ; Move enemy1 x into the draw x
    MOV  R21,  R07             ; Move enemy1 y into the draw x
    CALL draw_dot              ; Draw a dot at the location
    MOV  R20,  R08             ; Move enemy2 x into the draw x
    MOV  R21,  R09             ; Move enemy2 y into the draw y
    CALL draw_dot              ; Draw a dot at the location
    MOV  R20,  R10             ; Move enemy3 x into the draw x
    MOV  R21,  R11             ; Move enemy3 y into the draw y
    CALL draw_dot              ; Draw a dot at the location

draw_enemy_end:
    RET

;---------------------------------------------------------------------

;---------------------------------------------------------------------
;- Subroutine: move_enemy
;-
;- This subroutine moves the enemy
;-
;- (X, Y) = (R06, R07)
;-
;- Tweaked registers: R25, R24, R19, R21, R20
;---------------------------------------------------------------------
move_enemy:
    CMP  R06,  0xFE           ; 
    BRNE move_enemy_start
    RET

move_enemy_start:
    MOV  R20,  R06             ; draw over old location with floor
    MOV  R21,  R07             ;  |
    MOV  R19,  BG_COLOR        ;  |
    CALL draw_dot              ;  ▼

    IN   R05,  RAND_PORT       ; get a random number
    AND  R05,  0x03            ; get a number less than 4
    CMP  R05,  DIRECTION_UP    ; Random number determines the direction
    BREQ move_enemy_up         ;  |
    CMP  R05,  DIRECTION_LEFT  ;  |
    BREQ move_enemy_left       ;  |
    CMP  R05,  DIRECTION_DOWN  ;  |
    BREQ move_enemy_down       ;  |
    CMP  R05,  DIRECTION_RIGHT ;  |
    BREQ move_enemy_right      ;  ▼

move_enemy_up:                 ; Up one square
    SUB  R07,  0x01
    BRN  move_enemy_two
move_enemy_left:               ; Left one square
    SUB  R06,  0x01
    BRN  move_enemy_two
move_enemy_down:               ; Down one square
    ADD  R07,  0x01
    BRN  move_enemy_two
move_enemy_right:              ; Right one square
    ADD  R06,  0x01
    BRN  move_enemy_two

move_enemy_two:
    CMP  R15,  0x02            ; Only if level 2
    BRNE move_enemy_three 
    CMP  R08,  0xFE            ; Check if enemy is "dead"
    BRNE move_enemy_three

    MOV  R20,  R08             ; draw over old location with floor
    MOV  R21,  R09             ;  |
    CALL draw_dot              ;  ▼

    IN   R05,  RAND_PORT       ; get a random number
    AND  R05,  0x03            ; get a number less than 4
    CMP  R05,  DIRECTION_UP    ; Random number determines the direction
    BREQ move_enemy_two_up     ;  |
    CMP  R05,  DIRECTION_LEFT  ;  |
    BREQ move_enemy_two_left   ;  |
    CMP  R05,  DIRECTION_DOWN  ;  |
    BREQ move_enemy_two_down   ;  |
    CMP  R05,  DIRECTION_RIGHT ;  |
    BREQ move_enemy_two_right  ;  ▼

move_enemy_two_up:             ; Up one square
    SUB  R09,  0x01
    BRN  move_enemy_three
move_enemy_two_left:           ; Left one square
    SUB  R08,  0x01
    BRN  move_enemy_three
move_enemy_two_down:           ; Down one square
    ADD  R09,  0x01
    BRN  move_enemy_three
move_enemy_two_right:          ; Right one square
    ADD  R08,  0x01
    BRN  move_enemy_three

move_enemy_three:
    CMP  R15,  0x03            ; Only if level 3
    BRNE move_enemy_end 
    CMP  R10,  0xFE            ; Check if enemy is "dead"
    BRNE move_enemy_end

    MOV  R20,  R10             ; draw over old location with floor
    MOV  R21,  R11             ;  |
    CALL draw_dot              ;  ▼

    IN   R05,  RAND_PORT       ; get a random number
    AND  R05,  0x03            ; get a number less than 4
    CMP  R05,  DIRECTION_UP    ; Random number determines the direction
    BREQ move_enemy_three_up   ;  |
    CMP  R05,  DIRECTION_LEFT  ;  |
    BREQ move_enemy_three_left ;  |
    CMP  R05,  DIRECTION_DOWN  ;  |
    BREQ move_enemy_three_down ;  |
    CMP  R05,  DIRECTION_RIGHT ;  |
    BREQ move_enemy_three_right;  ▼

move_enemy_three_up:           ; Up one square
    SUB  R11,  0x01
    BRN  move_enemy_end
move_enemy_three_left:         ; Left one square
    SUB  R10,  0x01
    BRN  move_enemy_end
move_enemy_three_down:         ; Down one square
    ADD  R11,  0x01
    BRN  move_enemy_end
move_enemy_three_right:        ; Right one square
    ADD  R10,  0x01
    BRN  move_enemy_end

move_enemy_end:
    RET
;---------------------------------------------------------------------

;---------------------------------------------------------------------
;- Subroutine: draw_bullet
;-
;- This subroutine draws the bullet on the display at the correct coordinates
;-
;- (X, Y) = (R03, R04)
;-
;- Tweaked registers: R25, R24, R19, R21, R20
;---------------------------------------------------------------------
draw_bullet:
    MOV R19,  BULLET_COLOR     ; Set the draw-color to the bullet's color
    MOV R20,  R03              ; Move the bullet's x into the draw x
    MOV R21,  R04              ; Move the bullet's y into the draw y
    CALL draw_dot              ; Draw a dot at the location
    RET
;---------------------------------------------------------------------

;---------------------------------------------------------------------
;- Subroutine: delay_loop 
;-
;- Runs Through inside * middle * outside times
;-
;- Parameters:
;-  reg0 = loop count
;-
;- Tweaked Registers: reg0
;---------------------------------------------------------------------
delay_loop:
    MOV  R27,  DELAY       ; Move in the number of iterations to run the loop
    MOV  R28,  DELAY
    MOV  R29,  DELAY
delay_loop_inside:
    CMP  R27,  0x00      ; Check if the number of iterations remaining is 0
    BREQ delay_loop_middle    ; If no iterations remaining, end the delay
    SUB  R27,  0x01      ; Decrament the number of iterations remaining
    BRN  delay_loop_inside ; Restart loop
delay_loop_middle:
    CMP  R28,  0x00
    BREQ delay_loop_end;outside
    SUB  R28,  0x01
    MOV  R27,  DELAY
    BRN  delay_loop_inside
delay_loop_outside:
    CMP  R29,  0x00
    BREQ delay_loop_end
    SUB  R29,  0x01
    MOV  R28,  DELAY
    BRN  delay_loop_middle
delay_loop_end:
    RET
;---------------------------------------------------------------------

;--------------------------------------------------------------------------
;- Interrupt Stage
;--------------------------------------------------------------------------
.CSEG
.ORG 0x3FF
    BRN  isr  ; Handle the interrupt
