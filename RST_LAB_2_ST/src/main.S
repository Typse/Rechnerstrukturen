.section .data
.syntax unified
.thumb

// definiert BIT0 bis BIT31
.altmacro
.macro define_bit a
    .equ BIT\a, (1 << \a)
.endm

.set i, 0
.rept 32
    define_bit %i
    .set i,i+1
.endr

.equ RCGC_GPIO_R, 0x400FE608
.equ RCGC_GPIO_PORT_A, BIT0
.equ RCGC_GPIO_PORT_B, BIT1
.equ RCGC_GPIO_PORT_C, BIT2
.equ RCGC_GPIO_PORT_D, BIT3
.equ RCGC_GPIO_PORT_E, BIT4
.equ RCGC_GPIO_PORT_F, BIT5

.equ LED_R, BIT1
.equ LED_B, BIT2
.equ LED_G, BIT3

.equ GPIO_PORT_F_BASE,   0x40025000
.equ GPIO_DATA_OFF,       0x3FC
.equ GPIO_DIR_OFF,        0x400
.equ GPIO_PUR_OFF,        0x510
.equ GPIO_DEN_OFF,        0x51C
.equ GPIO_PORT_F_DATA_R, GPIO_PORT_F_BASE + GPIO_DATA_OFF
.equ GPIO_PORT_F_DIR_R,  GPIO_PORT_F_BASE + GPIO_DIR_OFF
.equ GPIO_PORT_F_PUR_R,  GPIO_PORT_F_BASE + GPIO_PUR_OFF
.equ GPIO_PORT_F_DEN_R,  GPIO_PORT_F_BASE + GPIO_DEN_OFF

.equ ST_BASE,           0xE000E000
.equ ST_CTRL_OFF,       0x10
.equ ST_RELOAD_OFF,     0x14
.equ ST_CURRENT_OFF,    0x18
.equ ST_CTRL_R,         ST_BASE + ST_CTRL_OFF
.equ ST_RELOAD_R,       ST_BASE + ST_RELOAD_OFF
.equ ST_CURRENT_R,      ST_BASE + ST_CURRENT_OFF 
.equ ST_CTRL_ENABLE,    BIT0
.equ ST_CTRL_INTEN,     BIT1
.equ ST_CTRL_CLK_SRC,   BIT2
.equ ST_CTRL_COUNT,     BIT16

s:
.word 0
ms:
.word 0

.section .text
.global main
.global sys_tick_handler
.align

init_hardware:
// Programm value in STRELOAD-Register
// 16.000 für 1ms TICK
ldr r0, =ST_RELOAD_R
ldr r1, [r0]
ldr r2, =15999
str r2, [r0]


// Clear the STCURRENT register by writing to it with any value.
ldr r1, =ST_CURRENT_R
mov r0, 0
str r0, [r1]

// Configure the STCTRL register for the required operation. 
ldr r0, =ST_CTRL_R
ldr r1, =ST_CTRL_ENABLE | BIT2
ldr r2, [r0]
orr r4, r2, r1

str r4, [r0]

// aktivieren der Clock für den Port F mit der Portmaske
ldr r0, =RCGC_GPIO_R
ldr r1, [r0]
ldr r2, =RCGC_GPIO_PORT_F
orr r1, r1, r2
str r1, [r0]

// aktivieren von GPIO port F Digital Enable (DEN). Für PIN1, PIN2 und PIN3 aktiviert
ldr r0, =GPIO_PORT_F_DEN_R
ldr r1, [r0]
ldr r2, =BIT1
orr r1, r1, r2
ldr r2, =BIT2
orr r1, r1, r2
ldr r2, =BIT3
orr r1, r1, r2
str r1, [r0]

// aktivieren von GPIO Port F (DIR) direction bestimmt INPUT oder OUTPUt
ldr r0, =GPIO_PORT_F_DIR_R
ldr r1, [r0]
ldr r2, =BIT1
orr r1, r1, r2
ldr r2, =BIT2
orr r1, r1, r2
ldr r2, =BIT3 
orr r1, r1, r2
str r1, [r0]

b main_loop

.thumb_func
sys_tick_handler:
push {r0 - r12} @ Speichert Register r0 bis r12 auf dem Stack

// call this method every millisecond by ST
ldr r0, =ms
ldr r1, [r0]
add r1, r1, 1

cmp r1, 1000
beq increase_second

str r1, [r0]
pop {r0 - r12}
b main_loop

increase_second:
// hier werden ms auf 0 gesetzt
ldr r0, =ms
mov r1, 0
str r1, [r0]

ldr r1, =s
ldr r3, [r1]
add r2, r3, 1

and r5, r2, 0x1
cmp r5, 0x1
beq decrease_second
str r2, [r1]
pop {r0 - r12} @ Laedt Register r0 bis r12 aus dem Stack
b main_loop

// Wenn zwei sekunden erreicht sind, dann lampe anschalten
decrease_second:
mov r3, 0
ldr r2, =s
str r3, [r2]

// hier logik für die lampen
ldr r0, =GPIO_PORT_F_DATA_R
ldr r1, [r0]
ldr r2, =LED_G
orr r2, r1, r2
cmp r1, r2
beq led_off
bne led_on

led_on:
mov r7, 1
ldr r0, =GPIO_PORT_F_DATA_R
ldr r1, [r0]
mov r3, #0x0E @ maske für pins 1-3 (hex 14)
bic r1, r1, r3 @ setzt pins 1-3 auf 0
ldr r2, =LED_G
orr r1, r1, r2
str r1, [r0]
pop {r0 - r12}
b main_loop

led_off:
mov r7, 0
@ LED OFF
ldr r0, =GPIO_PORT_F_DATA_R
ldr r1, [r0]
mov r3, #0x0E
bic r1, r1, r3
str r1, [r0]
pop {r0 - r12}
b main_loop

main: 


b init_hardware

main_loop:

//A3
b zeitmessung

// infinite loop here
ldr r1, =ST_CTRL_R
ldr r0, [r1]
ands r0, r0, ST_CTRL_COUNT
bne sys_tick_handler

b main_loop


// A2 A3
zeitmessung:
// A2
// Maschinenccode: 06 B4 | 06 B4
// Die Befehle sind im Maschinencode gleich
mov r0, 0
push {r1,r2}
push {r2, r1}

// zeit aufgabe

// nop = 1 sysTick bei 1 Ausführungen
nop

// ldr r0, [sp] = 2 sysTick bei 1 Ausführungen
ldr r0, [sp]
ldr r0, [sp]
ldr r0, [sp]
ldr r0, [sp]
ldr r0, [sp]

// str r0, [sp, #-4] = 2 sysTick bei 1 Ausführungen
str r0, [sp, #-4]
str r0, [sp, #-4]

// str r0, [sp, #-4]! = 4 sysTick bei 1 Ausführungen
str r0, [sp, #-4]!
str r0, [sp, #-4]!


// mul r0, r1, r1 = 2 sysTick
ldr r1, =0x2
mul r0, r1, r1

ldr r1, =0x2
sdiv r0, r1, r1

// push r1  = 1 sysTick
ldr r1, =0x2
push {r1}

// push r1, r2  = 2 sysTick
ldr r1, =0x2
ldr r2, =0x1
push {r1, r2}

// push r1, r2, r3  = 3 sysTick
ldr r1, =0x2
ldr r2, =0x1
ldr r3, = 0x10
push {r1, r2, r3}

b zeitmessung
.end