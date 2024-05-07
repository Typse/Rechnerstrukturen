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
@ Aktivieren der Clock für Port F
ldr r0, =RCGC_GPIO_R
ldr r1, [r0]
ldr r2, =RCGC_GPIO_PORT_F
orr r1, r1, r2
str r1, [r0]

@ Aktivieren von GPIO Port F Digital Enable (DEN) für PIN1, PIN2 und PIN3
ldr r0, =GPIO_PORT_F_DEN_R
ldr r1, [r0]
ldr r2, =PIN1 | PIN2 | PIN3
orr r1, r1, r2
str r1, [r0]

@ Konfigurieren von GPIO Port F Richtung (DIR)
ldr r0, =GPIO_PORT_F_DIR_R
ldr r1, [r0]
ldr r2, =PIN1 | PIN2 | PIN3
orr r1, r1, r2
ldr r2, =PIN4
bic r1, r1, r2 @ PIN4 ist Eingang
str r1, [r0]

@ Aktivieren von Pull-Up-Widerstand für PIN4
ldr r0, =GPIO_PORT_F_PUR_R
ldr r1, [r0]
ldr r2, =PIN4
orr r1, r1, r2
str r1, [r0]

@ Initialisiere r7
mov r7, #0x1

loop:
@ Überprüfe Tasterstatus
ldr r0, =GPIO_PORT_F_DATA_R
ldr r1, [r0]
ldr r2, =PIN4
and r1, r1, r2
cmp r1, #0
beq notpressed
b pressed

notpressed:
@ Setze LED-Farbe auf Weiß (alle Pins setzen)
ldr r0, =GPIO_PORT_F_DATA_R
mov r1, #0x0E @ Pins 1-3 aktivieren
str r1, [r0]
b delay

pressed:
@ Setze LED-Farbe auf Blau (nur PIN2)
ldr r0, =GPIO_PORT_F_DATA_R
mov r1, #0x04 @ Nur Pin 2 setzen
str r1, [r0]
b delay

delay:
@ Einfacher Delay-Loop, adjustiere Zähler für 500ms-1000ms Delay
ldr r2, =16000000 @ Annahme: 16MHz, adjustiere basierend auf der genauen Taktrate
delay_loop:
subs r2, #1
bne delay_loop
b loop

.end
