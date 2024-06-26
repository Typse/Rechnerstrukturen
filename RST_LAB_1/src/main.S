.section .data
.syntax unified

.equ RCGC_GPIO_R, 0x400FE608
.equ RCGC_GPIO_PORT_A, 0x01
.equ RCGC_GPIO_PORT_B, 0x02
.equ RCGC_GPIO_PORT_C, 0x04
.equ RCGC_GPIO_PORT_D, 0x08
.equ RCGC_GPIO_PORT_E, 0x10
.equ RCGC_GPIO_PORT_F, 0x20

.equ GPIO_PORT_F_DATA_R, 0x400253FC
.equ GPIO_PORT_F_DEN_R, 0x4002551C
.equ GPIO_PORT_F_DIR_R, 0x40025400
.equ GPIO_PORT_F_PUR_R, 0x40025510

.equ PIN0, 0x01
.equ PIN1, 0x02
.equ PIN2, 0x04
.equ PIN3, 0x08
.equ PIN4, 0x10
.equ PIN5, 0x20
.equ PIN6, 0x40
.equ PIN7, 0x80
.equ ALL_PINS, 0xFF

.section .text
.global main
.align

main:
@ aktivieren der Clock für den Port F mit der Portmaske
ldr r0, =RCGC_GPIO_R
ldr r1, [r0]
ldr r2, =RCGC_GPIO_PORT_F
orr r1, r1, r2
str r1, [r0]

@ aktivieren von GPIO port F Digital Enable (DEN). Für PIN1, PIN2 und PIN3 aktiviert
ldr r0, =GPIO_PORT_F_DEN_R
ldr r1, [r0]
ldr r2, =PIN1
orr r1, r1, r2 @ Value = 1 : Digitale Funktion des PINs wird aktiviert
ldr r2, =PIN2
orr r1, r1, r2 @ Value = 1 : Digitale Funktion des PINs wird aktiviert
ldr r2, =PIN3
orr r1, r1, r2 @ Value = 1 : Digitale Funktion des PINs wird aktiviert
ldr r2, =PIN4
orr r1, r1, r2 @ Value = 1 : Digitale Funktion des PINs wird aktiviert
str r1, [r0]

@ aktivieren von GPIO Port F (DIR) 
ldr r0, =GPIO_PORT_F_DIR_R
ldr r1, [r0]
ldr r2, =PIN1
orr r1, r1, r2 @ Value = 1 : Corresponding pin is an output.
ldr r2, =PIN2
orr r1, r1, r2 @ Value = 1 : Corresponding pin is an output.
ldr r2, =PIN3
orr r1, r1, r2 @ Value = 1 : Corresponding pin is an output.
ldr r2, =PIN4
bic r1, r1, r2 @ PIN4 / button muss auf 0 gesetzt werden für den input
str r1, [r0]

@ aktivieren von GPIO port f (PUR) 
@ nur button braucht PUR
ldr r0, =GPIO_PORT_F_PUR_R
ldr r1, [r0]
ldr r2, =PIN4
orr r1, r1, r2 @ Pull-UP Widerstand wird aktiviert, weil Wert 1
str r1, [r0]

@ write something to r7
mov r7, #0x1 @ zustand
b delay

@ laden den Wert vom Knopf und verlgeichen ihn mit 1 und wenn er 1 ist gehen wir in den branch pressed wenn 0 dann notpressed
loop:
ldr r0, =GPIO_PORT_F_DATA_R @ 
ldr r1, [r0]
ldr r2, =PIN4
and r1, r2, r1
cmp r1, r2
bne pressed
b notpressed


notpressed:
@ LED Farbe auf weiß setzen
ldr r0, =GPIO_PORT_F_DATA_R
ldr r1, [r0]
mov r3, #0x0E @ maske für pins 1-3 (hex 14)
bic r1, r1, r3 @ setzt pins 1-3 auf 0
mov r2, #0x0E @ aktiviere 
orr r1, r1, r2
str r1, [r0]

@ einmal nach links shiften
ldr r6, =0x10000000
cmp r7, r6
beq left_shift_of


left_shift_of:
cmp r7, 0x10000000
beq set_bit_to_right
lsl r7, r7, #4
b loop

right_shift_of:
cmp r7, 0x00000001
beq set_bit_to_left
lsr r7, r7, #4
b loop

set_bit_to_left:
ldr r7, =0x10000000
b loop

set_bit_to_right:
ldr r7, =0x00000001
b loop

pressed:
@ LED Farbe auf blau setzen
ldr r0, =GPIO_PORT_F_DATA_R
ldr r1, [r0]
mov r3, #0x0E @ maske für pins 1-3 (hex 14)
bic r1, r1, r3 @ setzt pins 1-3 auf 0
mov r2, #0x04 @ aktiviere
orr r1, r1, r2
str r1, [r0]

@ Shift auf right setzen


b right_shift_of


delay:
ldr r4, = 750000
ldr r5, = 0x0000000
delay_loop:
add r5, #0x01
cmp r4, r5
bne delay_loop
b loop



.end