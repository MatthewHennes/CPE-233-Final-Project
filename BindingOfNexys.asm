;--------------------------------------------------------------------------
;- The Binding of Nexys
;- Programmers: Matt Hennes & Tyler Heucke
;- Creation Date: 11/20/14
;-
;- Version:     0.1.4
;- Description: A Binding of Isaac clone running on the RAT CPU
;--------------------------------------------------------------------------

;--------------------------------------------------------------------------
;- Port Constants
;--------------------------------------------------------------------------
.EQU SWITCH_PORT = 0x20 ; port for switches     INPUT
.EQU LED_PORT    = 0x40 ; port for LEDs         OUTPUT
.EQU RAND_PORT   = 0x50 ; port for random number
.EQU BTN_PORT    = 0x21 ; port for buttons      INPUT
.EQU VGA_HADD    = 0x90
.EQU VGA_LADD    = 0x91
.EQU VGA_COLOR   = 0x92
.EQU KEYBOARD    = 0x25
.EQU SSEG        = 0x81
.EQU LEDS        = 0x40

;-- Keyboard Stuff -------------------------------------------------------
.EQU PS2_KEY_CODE = 0x44 ; Port for Key Code (data)
.EQU PS2_CONTROL  = 0x46 ; Ready for data control

.EQU int_flag     = 0x01 ; interrupt data from keyboard
;--------------------------------------------------------------------------

;--------------------------------------------------------------------------
;- Game Constants
;--------------------------------------------------------------------------
.EQU DELAY                  = 0xBB ; Delay timer

.EQU BG_COLOR               = 0x00 ; Black
.EQU WALL_COLOR             = 0xFF ; White
.EQU ENEMY_COLOR            = 0xE0 ; Red
.EQU PLAYER_COLOR           = 0x1C ; Green

.EQU BULLET_DIRECTION_UP    = 0x00
.EQU BULLET_DIRECTION_RIGHT = 0x01
.EQU BULLET_DIRECTION_DOWN  = 0x02
.EQU BULLET_DIRECTION_LEFT  = 0x03
.EQU BULLET_DIRECTION_NONE  = 0x04

.EQU ENEMY_DIRECTION_UP    = 0x00
.EQU ENEMY_DIRECTION_RIGHT = 0x01
.EQU ENEMY_DIRECTION_DOWN  = 0x02
.EQU ENEMY_DIRECTION_LEFT  = 0x03

.EQU BULLET_COLOR           = 0x03 ; Blue
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
;- R15
;- R16
;- R17
;- R18
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
    CALL  draw_background   ; draw using default color
    CALL  draw_walls        ; 4 lines around edge of screen
    MOV   R00,    0x14      ; Starting player x-coord = 20
    MOV   R01,    0x0F      ; Starting player y-coord = 15
    CALL  draw_player       ; draw green hero
    MOV   R06,    0x05
    MOV   R07,    0x05
    CALL  draw_enemy
    SEI                     ; set interrupt to receive key presses

main:
    IN    R05,    RAND_PORT
    CALL  move_bullet       ; update the bullet's location
    CALL  draw_bullet       ; draw the bullet
    CALL  detect_hits
    CMP   R26, 0x00
    BRNE  no_move
    CALL  move_enemy
    MOV   R26, 0x30
no_move:
    SUB   R26, 0x01
    CALL  draw_player       ; draw the player
    CALL  draw_enemy
    CALL  delay_loop        ; create a delay between in-game "ticks"
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
    ADD   R30, 0x01            ; indicate key-up found
    BRN   reset_ps2_register

;reset_skip_flag:
;   MOV   R30, 0x00           ; indicate key-up handles
;   BRN   reset_ps2_register
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
    MOV  R18,    BG_COLOR  ; Set draw-color to the background color
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
    MOV  R18,    BG_COLOR  ; Set draw-color to the background color
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
    MOV  R18,    BG_COLOR  ; Set draw-color to the background color
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
    MOV  R18,   BG_COLOR ; Set draw-color to the background color
    MOV  R20,     R00    ; Set draw-x-coord to the player's old location
    MOV  R21,     R01    ; Set draw-y-coord to the player's old location
    CALL draw_dot     ; Fill in the player's old location with the background color
    ADD  R00,    0x01    ; Move the player right
    CALL draw_player    ; Draw th player in the new location
move_right_end:
    RET

shoot_up:
    MOV  R02,   BULLET_DIRECTION_UP   ; Set the bullet direction to up
    MOV  R03,   R00           ; Set the bullet x-coord to the player x-coord
    MOV  R04,   R01           ; Set the bullet y-coord to the player y-coord
    RET

shoot_right:
    MOV  R02,   BULLET_DIRECTION_RIGHT  ; Set the bullet direction to up
    MOV  R03,   R00           ; Set the bullet x-coord to the player x-coord
    MOV  R04,   R01           ; Set the bullet y-coord to the player y-coord
    RET

shoot_down:
    MOV  R02,   BULLET_DIRECTION_DOWN   ; Set the bullet direction to down
    MOV  R03,   R00           ; Set the bullet x-coord to the player x-coord
    MOV  R04,   R01           ; Set the bullet y-coord to the player y-coord
    RET

shoot_left:
    MOV  R02,   BULLET_DIRECTION_LEFT   ; Set the bullet direction to left
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
    CALL  check_walls
    CMP   R02,  BULLET_DIRECTION_NONE
    BREQ  bullet_stop
    MOV   R20,  R03
    MOV   R21,  R04
    MOV   R18,  BG_COLOR
    CALL  draw_dot
    CMP   R02,  BULLET_DIRECTION_UP  ; Check if the bullet was fired upwards
    BREQ  bullet_move_up        ; Move it appropriately
    CMP   R02,  BULLET_DIRECTION_RIGHT ; Check if the bullet was fired to the right
    BREQ  bullet_move_right     ; Move it appropriately
    CMP   R02,  BULLET_DIRECTION_DOWN  ; Check if the bullet was fired downwards
    BREQ  bullet_move_down      ; Move it appropriately
    CMP   R02,  BULLET_DIRECTION_LEFT  ; Check if the bullet was fired to the left
    BREQ  bullet_move_left      ; Move it appropriately
bullet_stop:
    MOV   R03,  0xFF
    MOV   R04,  0xFF
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
    CMP   R03,  0x00
    BREQ  stop_bullet
    CMP   R03,  0x27
    BREQ  stop_bullet
    CMP   R04,  0x00
    BREQ  stop_bullet
    CMP   R04,  0x1D
    BREQ  stop_bullet
    RET
stop_bullet:
    MOV   R02,  BULLET_DIRECTION_NONE
    RET
;-------------------------------------------------------------------

;--------------------------------------------------------------------
;-  Subroutine: draw_horizontal_line
;-
;-  Draws a horizontal line from (R20,R21) to (R22,R21) using color in R18.
;-   This subroutine works by consecutive calls to drawdot, meaning
;-   that a horizontal line is nothing more than a bunch of dots.
;-
;-  Parameters:
;-   R20  = starting x-coordinate
;-   R21  = y-coordinate
;-   R22  = ending x-coordinate
;-   R18  = color used for line
;-
;- Tweaked registers: R20,R22
;--------------------------------------------------------------------
draw_horizontal_line:
    ADD    R22,  0x01          ; go from R20 to R22 inclusive

draw_horiz1:
    CALL   draw_dot         ; draw tile
    ADD    R20,  0x01          ; increment column (X) count
    CMP    R20,  R22            ; see if there are more columns
    BRNE   draw_horiz1      ; branch if more columns
    RET
;--------------------------------------------------------------------


;---------------------------------------------------------------------
;-  Subroutine: draw_vertical_line
;-
;-  Draws a horizontal line from (R20,R21) to (R20,R22) using color in R18.
;-   This subroutine works by consecutive calls to drawdot, meaning
;-   that a vertical line is nothing more than a bunch of dots.
;-
;-  Parameters:
;-   R20  = x-coordinate
;-   R21  = starting y-coordinate
;-   R22  = ending y-coordinate
;-   R18  = color used for line
;-
;- Tweaked registers: R21,R22
;--------------------------------------------------------------------
draw_vertical_line:
    ADD    R22,  0x01         ; go from R21 to R22 inclusive

draw_vert1:
    CALL   draw_dot        ; draw tile
    ADD    R21,  0x01         ; increment row (y) count
    CMP    R21,  R22           ; see if there are more rows
    BRNE   draw_vert1      ; branch if more rows
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
    MOV   R18,  BG_COLOR              ; use default color
    MOV   R23,  0x00                 ; R28 keeps track of rows
start:
    MOV   R21,  R23                   ; load current row count
    MOV   R20,  0x00                  ; restart x coordinates
    MOV   R22,  0x27                  ; ending coordinate
    CALL  draw_horizontal_line     ; draw a complete line
    ADD   R23,  0x01                 ; increment row count
    CMP   R23,  0x1E                 ; see if more rows to draw
    BRNE  start                    ; branch to draw more rows
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
    MOV   R18,  WALL_COLOR           ; use wall color

    MOV   R21,  0x00                 ; restart y position
    MOV   R20,  0x00                 ; restart x position
    MOV   R22,  0x28                 ; ending x position
    CALL  draw_horizontal_line     ; draw a complete line

    MOV   R21,  0x1D                 ; restart y position
    MOV   R20,  0x00                 ; restart x position
    MOV   R22,  0x28                 ; ending x position
    CALL  draw_horizontal_line     ; draw a complete line

    MOV   R21,  0x00                 ; restart y position
    MOV   R20,  0x00                 ; restart x position
    MOV   R22,  0x1E                 ; ending y position
    CALL  draw_vertical_line       ; draw a complete line

    MOV   R21,  0x00                 ; restart y position
    MOV   R20,  0x27                 ; restart x position
    MOV   R22,  0x1E                 ; ending y position
    CALL  draw_vertical_line       ; draw a complete line

    RET
;---------------------------------------------------------------------

;---------------------------------------------------------------------
;- Subrountine: draw_dot
;-
;- This subroutine draws a dot on the display the given coordinates:
;-
;- (X,Y) = (R20,R21)  with a color stored in R18
;-
;- Tweaked registers: R25,R24
;---------------------------------------------------------------------
draw_dot:
    MOV   R25,  R21         ; copy Y coordinate
    MOV   R24,  R20         ; copy X coordinate

    AND   R24,  0x3F       ; make sure top 2 bits cleared
    AND   R25,  0x1F       ; make sure top 3 bits cleared

    ;--- you need bottom two bits of R25 into top two bits of R24
    LSR   R25            ; shift LSB into carry
    BRCC  bit7          ; no carry, jump to next bit
    OR    R24,  0x40       ; there was a carry, set bit
    CLC                 ; freshen bit, do one more left shift

bit7:
    LSR   R25            ; shift LSB into carry
    BRCC  dd_out        ; no carry, jump to output
    OR    R24,  0x80       ; set bit if needed

dd_out:
    OUT   R24,  VGA_LADD   ; write low 8 address bits to register
    OUT   R25,  VGA_HADD   ; write hi 3 address bits to register
    OUT   R18,  VGA_COLOR  ; write data to frame buffer
    RET
; --------------------------------------------------------------------

;---------------------------------------------------------------------
;- Subroutine: detect_hits
;-
;- Detects the player's shot hitting enemies
;-
;- Player (X, Y) = (R00, R01)
;- Shot (X, Y) = (R03, R04)
;- Enemy (X, Y) = (R06, R07)
;-
;- Tweaked registers: R25, R24, R18, R21, R20
;---------------------------------------------------------------------
detect_hits:
    CMP  R03,  R06
    BREQ hit_check_one
    RET

hit_check_one:
    CMP  R04,  R07
    BREQ hit_check_two
    RET

hit_check_two:
    MOV  R06,  0xFE
    MOV  R07,  0xFE

    RET
;---------------------------------------------------------------------

;---------------------------------------------------------------------
;- Subroutine: draw_player
;-
;- This subroutine draws the player on the display at the correct coordinates.
;-
;- (X, Y) = (R00, R01)
;-
;- Tweaked registers: R25, R24, R18, R21, R20
;---------------------------------------------------------------------
draw_player:
    MOV  R18,  PLAYER_COLOR  ; Set the draw-color to the player's color
    MOV  R21,  R01        ; Move the player's y coord into the draw y coord
    MOV  R20,  R00        ; Move the player's x coord into the draw x coord
    CALL draw_dot      ; Draw a dot of the specified color at the specified location
    RET
;---------------------------------------------------------------------

;---------------------------------------------------------------------
;- Subroutine: draw_enemy
;-
;- This subroutine draws the enemy on the display at the correct coordinates.
;-
;- (X, Y) = (R06, R07)
;-
;- Tweaked registers: R25, R24, R18, R21, R20
;---------------------------------------------------------------------
draw_enemy:
    CMP  R06,  0xFE
    BRNE draw_enemy_continue
    CMP  R07,  0xFE
    BRNE draw_enemy_continue
    MOV  R06,  0x10
    MOV  R07,  0x10

draw_enemy_continue:
    MOV  R18,  ENEMY_COLOR  ; Set the draw-color to the player's color
    MOV  R20,  R06        ; Move the player's y coord into the draw y coord
    MOV  R21,  R07        ; Move the player's x coord into the draw x coord
    CALL draw_dot      ; Draw a dot of the specified color at the specified location
    RET
;---------------------------------------------------------------------

;---------------------------------------------------------------------
;- Subroutine: move_enemy
;-
;- This subroutine moves the enemy
;-
;- (X, Y) = (R06, R07)
;-
;- Tweaked registers: R25, R24, R18, R21, R20
;---------------------------------------------------------------------
move_enemy:
    CMP  R06,  0xFE
    BREQ enemy_in_wall
    BRN  move_enemy_start

enemy_in_wall:
    MOV  R06,  0xFE
    MOV  R07,  0xFE
    RET

move_enemy_start:
    MOV  R20,  R06
    MOV  R21,  R07
    MOV  R18,  BG_COLOR
    CALL draw_dot

    AND  R05,  0x03
    CMP  R05,  ENEMY_DIRECTION_UP
    BREQ move_enemy_up
    CMP  R05,  ENEMY_DIRECTION_LEFT
    BREQ move_enemy_left
    CMP  R05,  ENEMY_DIRECTION_DOWN
    BREQ move_enemy_down
    CMP  R05,  ENEMY_DIRECTION_RIGHT
    BREQ move_enemy_right

move_enemy_up:
    SUB  R07,  0x01
    RET
move_enemy_left:
    SUB  R06,  0x01
    RET
move_enemy_down:
    ADD  R07,  0x01
    RET
move_enemy_right:
    ADD  R06,  0x01
    RET
;---------------------------------------------------------------------

;---------------------------------------------------------------------
;- Subroutine: draw_bullet
;-
;- This subroutine draws the bullet on the display at the correct coordinates
;-
;- (X, Y) = (R03, R04)
;-
;- Tweaked registers: R25, R24, R18, R21, R20
;---------------------------------------------------------------------
draw_bullet:
    MOV R18,  BULLET_COLOR  ; Set the draw-color to the bullet's color
    MOV R21,  R04       ; Move the bullet's y coord into the draw y coord
    MOV R20,  R03       ; Move the bullet's x coord into the draw x coord
    CALL draw_dot     ; Draw a dot of the specified color at the specified location
    RET
;---------------------------------------------------------------------

;---------------------------------------------------------------------
;- Subroutine: delay_loop
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
