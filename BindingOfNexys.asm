;--------------------------------------------------------------------------
;- The Binding of Nexys
;- Programmers: Matt Hennes & Tyler Heucke
;- Date: 11/20/14
;-
;- Description: ...
;--------------------------------------------------------------------------

;--------------------------------------------------------------------------
;- Port Constants
;--------------------------------------------------------------------------
.EQU SWITCH_PORT = 0x20 ; port for switches     INPUT
.EQU LED_PORT    = 0x40 ; port for LEDs         OUTPUT
.EQU BTN_PORT    = 0x21 ; port for buttons      INPUT
.EQU VGA_HADD    = 0x90
.EQU VGA_LADD    = 0x91
.EQU VGA_COLOR   = 0x92
.EQU KEYBOARD    = 0x25
.EQU SSEG        = 0x81
.EQU LEDS        = 0x40
;--------------------------------------------------------------------------

;--------------------------------------------------------------------------
;- Misc Constants
;--------------------------------------------------------------------------
.EQU DELAY					= 0xFF ; Delay timer

.EQU BG_COLOR     			= 0x00 ; Background:  black
.EQU WALL_COLOR   			= 0xFF ; Walls:       white
.EQU ENEMY_COLOR  			= 0xE0 ; red
.EQU PLAYER_COLOR 			= 0x1C ; green

.EQU BULLET_DIRECTION_UP	= 0x00
.EQU BULLET_DIRECTION_RIGHT	= 0x01
.EQU BULLET_DIRECTION_DOWN	= 0x02
.EQU BULLET_DIRECTION_LEFT	= 0x03

.EQU BULLET_COLOR 			= 0x03 ; blue

.EQU KEY_W        			= 0x1D
.EQU KEY_A        			= 0x1C
.EQU KEY_S        			= 0x1B
.EQU KEY_D        			= 0x23

.EQU ARROW_UP        		= 0x75
.EQU ARROW_DOWN      		= 0x72
.EQU ARROW_LEFT      		= 0x6B
.EQU ARROW_RIGHT     		= 0x74

.EQU KEY_UP       			= 0xF0 ; key release data
;--------------------------------------------------------------------------

;-------------------------------------------------------------
; INPUT PORTS
;-------------------------------------------------------------
;-- Keyboard Stuff -------------------------------------------
.EQU PS2_KEY_CODE = 0x44 ; Port for Key Code (data)
.EQU PS2_CONTROL  = 0x46 ; Ready for data control

.EQU int_flag     = 0x01 ; interrupt data from keyboard
;-------------------------------------------------------------

;-------------------------------------------------------------
; Global Register Usage
;-------------------------------------------------------------
;- r0: used for delay loop timing
;- r3: used for PS2 resetting
;- r4: used for drawing dots
;- r5: used for drawing dots
;- r6 is used for color
;- r7 is used for working Y coordinate
;- r8 is used for working X coordinate
;- r15: stores key-up info flag
;- r27: stores bullet direction of travel
;- r28: stores bullet x coordinate
;- r29: stores bullet y coordinate
;- r30: stores player x coordinate
;- r31: stores player y coordinate
;---------------------------------------------------------------------

;--------------------------------------------------------------------------
;- Program Start
;--------------------------------------------------------------------------
.CSEG
.ORG          0x01

init:         MOV   R15,    0x00    ; clear key-up flag
              CALL  draw_background ; draw using default color
              CALL  draw_walls      ; 4 lines around edge of screen
			  MOV	R30,	0x14	; Starting player x-coord = 20
			  MOV	R30,	0x0F	; Starting player y-coord = 15
              CALL  draw_player     ; draw green hero
              SEI

main:         CALL	move_bullet		; update the bullet's location based on its direction
			  CALL	draw_bullet		; draw the bullet in its new location
			  CALL	draw_player		; re-draw the player, just in case it was drawn over
			  CALL	delay_loop		; create a delay between in-game "ticks"
              BRN   main			; repeat main subroutine

;--------------------------------------------------------------
; Interrup Service Routine - Handles Interrupts from keyboard
;--------------------------------------------------------------
; Tweaked Registers; r2,r3,r15
;--------------------------------------------------------------
isr:      CMP   r15, int_flag        ; check key-up flag
          BRNE  continue
          MOV   r15, 0x00            ; clear key-up flag
          BRN   reset_ps2_register

continue: IN    r2, PS2_KEY_CODE     ; get keycode data

check_w:  CMP   r2,KEY_W             ; was 'w' pressed?
          BRNE  check_a
          CALL  move_up
          BRN   reset_ps2_register

check_a:  CMP   r2,KEY_A             ; was 'a' pressed?
          BRNE  check_s
          CALL  move_left
          BRN   reset_ps2_register

check_s:  CMP   r2,KEY_S             ; was 's' pressed?
          BRNE  check_d
          CALL  move_down
          BRN   reset_ps2_register

check_d:  CMP   r2,KEY_D             ; was 'd' pressed?
          BRNE  check_up
          CALL  move_right
          BRN   reset_ps2_register

check_up:  CMP   r2,ARROW_UP         ; was 'up' pressed?
          BRNE  check_down
          CALL  shoot_up
          BRN   reset_ps2_register

check_down:  CMP   r2,ARROW_DOWN     ; was 'down' pressed?
          BRNE  check_left
          CALL  shoot_down
          BRN   reset_ps2_register

check_left:  CMP   r2,ARROW_LEFT     ; was 'left' pressed?
          BRNE  check_right
          CALL  shoot_left
          BRN   reset_ps2_register

check_right:  CMP   r2,ARROW_RIGHT   ; was 'right' pressed?
          BRNE  key_up_check
          CALL  shoot_right
          BRN   reset_ps2_register

key_up_check:
          CMP   r2,KEY_UP            ; look for key-up code
          BREQ  set_skip_flag        ; branch if found

          BRN   reset_ps2_register


set_skip_flag:
          ADD   r15, 0x01            ; indicate key-up found
          BRN   reset_ps2_register

;reset_skip_flag:
;          MOV   r15, 0x00           ; indicate key-up handles
;          BRN   reset_ps2_register
;-------------------------------------------------------------------

;-------------------------------------------------------------------
; reset PS2 register which allow it to send more interrupts
;-------------------------------------------------------------------
reset_ps2_register:
          MOV    r3, 0x01
          OUT    r3, PS2_CONTROL
          MOV    r3, 0x00
          OUT    r3, PS2_CONTROL
          RETIE
;-------------------------------------------------------------------

;-------------------------------------------------------------------
; do something meaningful when particular keys are pressed
;-------------------------------------------------------------------
move_up:      CMP  R31,    0x01		; Check if player is already at the edge of the screen
              BREQ move_up_end		; If so, do not move the player
              MOV  R6,    BG_COLOR	; Set draw-color to the background color
			  MOV  R8,	   R30		; Set draw-x-coord to the player's old location
			  MOV  R7,	   R31		; Set draw-y-coord to the player's old location
              CALL draw_dot			; Fill in the player's old location with the background color
              SUB  R31,    0x01		; Move the player up
              CALL draw_player		; Draw the player in the new location
move_up_end:
              RET

move_left:    CMP  R30,    0x01		; Check if player is already at the edge of the screen
              BREQ move_left_end	; If so, do not move the player
              MOV  R6,    BG_COLOR	; Set draw-color to the background color
			  MOV  R8,	   R30		; Set draw-x-coord to the player's old location
			  MOV  R7,	   R31		; Set draw-y-coord to the player's old location
              CALL draw_dot			; Fill in the player's old location with the background color
              SUB  R30,    0x01		; Move the player left
              CALL draw_player		; Draw the player in the new location
move_left_end:
              RET

move_down:    CMP  R31,    0x1C		; Check if player is already at the edge of the screen
              BREQ move_down_end	; If so, do not move the player
              MOV  R6,    BG_COLOR	; Set draw-color to the background color
			  MOV  R8,	   R30		; Set draw-x-coord to the player's old location
			  MOV  R7,	   R31		; Set draw-y-coord to the player's old location
              CALL draw_dot			; Fill in the player's old location with the background color
              ADD  R31,    0x01		; Move the player down
              CALL draw_player		; Draw the player in the new location
move_down_end:
              RET

move_right:   CMP  R8,    0x26		; Check if player is already at the edge of the screen
              BREQ move_right_end	; If so, do not move the player
              MOV  R6,   BG_COLOR	; Set draw-color to the background color
			  MOV  R8,	   R30		; Set draw-x-coord to the player's old location
			  MOV  R7,	   R31		; Set draw-y-coord to the player's old location
              CALL draw_dot			; Fill in the player's old location with the background color
              ADD  R8,    0x01		; Move the player right
              CALL draw_player		; Draw th player in the new location
move_right_end:
              RET

shoot_up:     MOV  R27,	  BULLET_DIRECTION_UP		; Set the bullet direction to up
			  MOV  R28,	  R30						; Set the bullet x-coord to the player x-coord
			  MOV  R29,	  R31						; Set the bullet y-coord to the player y-coord

shoot_right:  MOV  R27,	  BULLET_DIRECTION_RIGHT	; Set the bullet direction to up
			  MOV  R28,	  R30						; Set the bullet x-coord to the player x-coord
			  MOV  R29,	  R31						; Set the bullet y-coord to the player y-coord

shoot_down:   MOV  R27,	  BULLET_DIRECTION_DOWN		; Set the bullet direction to down
			  MOV  R28,	  R30						; Set the bullet x-coord to the player x-coord
			  MOV  R29,	  R31						; Set the bullet y-coord to the player y-coord

shoot_left:   MOV  R27,	  BULLET_DIRECTION_LEFT		; Set the bullet direction to left
			  MOV  R28,	  R30						; Set the bullet x-coord to the player x-coord
			  MOV  R29,	  R31						; Set the bullet y-coord to the player y-coord
;--------------------------------------------------------------------

;--------------------------------------------------------------------
;- Subroutine: move_bullet
;-
;- Moves the bullet to the next location based on its move direction
;-
;- Parameters:
;-	r27 = bullet direction of motion
;-	r28 = bullet x-coordinate
;-	r29 = bullet y-coordinate
;-
;- Tweaked registers: r28, r29
;--------------------------------------------------------------------
move_bullet:
		CMP		R27, BULLET_DIRECTION_UP	; Check if the bullet was fired upwards
		BREQ	bullet_move_up				; Move it appropriately
		CMP		R27, BULLET_DIRECTION_RIGHT	; Check if the bullet was fired to the right
		BREQ	bullet_move_right			; Move it appropriately
		CMP		R27, BULLET_DIRECTION_DOWN	; Check if the bullet was fired downwards
		BREQ	bullet_move_down			; Move it appropriately
		CMP		R27, BULLET_DIRECTION_LEFT	; Check if the bullet was fired to the left
		BREQ	bullet_move_left			; Move it appropriately
bullet_move_up:
		SUB		R29, 0x01					; Move the bullet up
		RET
bullet_move_right:
		ADD		R28, 0x01					; Move the bullet to the right
		RET
bullet_move_down:
		ADD		R29, 0x01					; Move the bullet downwards
		RET
bullet_move_left:
		SUB		R28, 0x01					; Move the bullet to the left
		RET
;--------------------------------------------------------------------

;--------------------------------------------------------------------
;-  Subroutine: draw_horizontal_line
;-
;-  Draws a horizontal line from (r8,r7) to (r9,r7) using color in r6.
;-   This subroutine works by consecutive calls to drawdot, meaning
;-   that a horizontal line is nothing more than a bunch of dots.
;-
;-  Parameters:
;-   r8  = starting x-coordinate
;-   r7  = y-coordinate
;-   r9  = ending x-coordinate
;-   r6  = color used for line
;-
;- Tweaked registers: r8,r9
;--------------------------------------------------------------------
draw_horizontal_line:
        ADD    r9,0x01          ; go from r8 to r9 inclusive

draw_horiz1:
        CALL   draw_dot         ; draw tile
        ADD    r8,0x01          ; increment column (X) count
        CMP    r8,r9            ; see if there are more columns
        BRNE   draw_horiz1      ; branch if more columns
        RET
;--------------------------------------------------------------------


;---------------------------------------------------------------------
;-  Subroutine: draw_vertical_line
;-
;-  Draws a horizontal line from (r8,r7) to (r8,r9) using color in r6.
;-   This subroutine works by consecutive calls to drawdot, meaning
;-   that a vertical line is nothing more than a bunch of dots.
;-
;-  Parameters:
;-   r8  = x-coordinate
;-   r7  = starting y-coordinate
;-   r9  = ending y-coordinate
;-   r6  = color used for line
;-
;- Tweaked registers: r7,r9
;--------------------------------------------------------------------
draw_vertical_line:
         ADD    r9,0x01         ; go from r7 to r9 inclusive

draw_vert1:
         CALL   draw_dot        ; draw tile
         ADD    r7,0x01         ; increment row (y) count
         CMP    r7,R9           ; see if there are more rows
         BRNE   draw_vert1      ; branch if more rows
         RET
;--------------------------------------------------------------------

;---------------------------------------------------------------------
;-  Subroutine: draw_background
;-
;-  Fills the 30x40 grid with one color using successive calls to
;-  draw_horizontal_line subroutine.
;-
;-  Tweaked registers: r13,r7,r8,r9
;----------------------------------------------------------------------
draw_background:
         MOV   r6,BG_COLOR              ; use default color
         MOV   r13,0x00                 ; r13 keeps track of rows
start:   MOV   r7,r13                   ; load current row count
         MOV   r8,0x00                  ; restart x coordinates
         MOV   r9,0x27

         CALL  draw_horizontal_line     ; draw a complete line
         ADD   r13,0x01                 ; increment row count
         CMP   r13,0x1E                 ; see if more rows to draw
         BRNE  start                    ; branch to draw more rows
         RET
;---------------------------------------------------------------------

;---------------------------------------------------------------------
;-  Subroutine: draw_walls
;-
;-  Fills the edges of the 30x40 grid with one color using successive calls to
;-  draw_horizontal_line subroutine.
;-
;-  Tweaked registers: R9
;----------------------------------------------------------------------
draw_walls:
        MOV   R6, WALL_COLOR           ; use wall color

        MOV   R7, 0x00                 ; restart y position
        MOV   R8, 0x00                 ; restart x position
        MOV   R9, 0x28                 ; ending x position
        CALL  draw_horizontal_line     ; draw a complete line

        MOV   R7, 0x1D                 ; restart y position
        MOV   R8, 0x00                 ; restart x position
        MOV   R9, 0x28                 ; ending x position
        CALL  draw_horizontal_line     ; draw a complete line

        MOV   R7, 0x00                 ; restart y position
        MOV   R8, 0x00                 ; restart x position
        MOV   R9, 0x1E                 ; ending y position
        CALL  draw_vertical_line       ; draw a complete line

        MOV   R7, 0x00                 ; restart y position
        MOV   R8, 0x27                 ; restart x position
        MOV   R9, 0x1E                 ; ending y position
        CALL  draw_vertical_line       ; draw a complete line

        RET
;---------------------------------------------------------------------

;---------------------------------------------------------------------
;- Subrountine: draw_dot
;-
;- This subroutine draws a dot on the display the given coordinates:
;-
;- (X,Y) = (r8,r7)  with a color stored in r6
;-
;- Tweaked registers: r4,r5
;---------------------------------------------------------------------
draw_dot:
           MOV   r4,r7         ; copy Y coordinate
           MOV   r5,r8         ; copy X coordinate

           AND   r5,0x3F       ; make sure top 2 bits cleared
           AND   r4,0x1F       ; make sure top 3 bits cleared

           ;--- you need bottom two bits of r4 into top two bits of r5
           LSR   r4            ; shift LSB into carry
           BRCC  bit7          ; no carry, jump to next bit
           OR    r5,0x40       ; there was a carry, set bit
           CLC                 ; freshen bit, do one more left shift

bit7:      LSR   r4            ; shift LSB into carry
           BRCC  dd_out        ; no carry, jump to output
           OR    r5,0x80       ; set bit if needed

dd_out:    OUT   r5,VGA_LADD   ; write low 8 address bits to register
           OUT   r4,VGA_HADD   ; write hi 3 address bits to register
           OUT   r6,VGA_COLOR  ; write data to frame buffer
           RET
; --------------------------------------------------------------------

;---------------------------------------------------------------------
;- Subroutine: draw_player
;- 
;- This subroutine draws the player on the display at the correct coordinates.
;- 
;- (X, Y) = (r30, r31)
;- 
;- Tweaked registers: r4, r5, r6, r7, r8
;---------------------------------------------------------------------
draw_player:
		   MOV	R6, PLAYER_COLOR	; Set the draw-color to the player's color
		   MOV	R7,R31				; Move the player's y coord into the draw y coord
		   MOV	R8,R30				; Move the player's x coord into the draw x coord
		   CALL draw_dot			; Draw a dot of the specified color at the specified location
		   RET
;---------------------------------------------------------------------

;---------------------------------------------------------------------
;- Subroutine: draw_bullet
;-
;- This subroutine draws the bullet on the display at the correct coordinates
;-
;- (X, Y) = (r28, r29)
;-
;- Tweaked registers: r4, r5, r6, r7, r8
;---------------------------------------------------------------------
draw_bullet:
		MOV R6, BULLET_COLOR	; Set the draw-color to the bullet's color
		MOV R7, R29				; Move the bullet's y coord into the draw y coord
		MOV R8, R28				; Move the bullet's x coord into the draw x coord
		CALL draw_dot			; Draw a dot of the specified color at the specified location
		RET
;---------------------------------------------------------------------

;---------------------------------------------------------------------
;- Subroitine: delay_loop
;-
;- Parameters:
;-	r0 = loop count
;-
;- Tweaked Registers: r0
;---------------------------------------------------------------------
delay_loop:
		MOV R0, DELAY				; Move in the number of iterations to run the loop
delay_loop_inside:
		CMP		R0, 0x00			; Check if the number of iterations remaining is 0
		BREQ	delay_loop_end		; If no iterations remaining, end the delay
		SUB		R0, 0x01			; Decrament the number of iterations remaining
		BRN		delay_loop_inside	; Restart loop
delay_loop_end:
		RET
;---------------------------------------------------------------------

;--------------------------------------------------------------------------
;- Interrupt Stage
;--------------------------------------------------------------------------
.CSEG
.ORG 0x3FF
        BRN    isr	; Handle the interrupt