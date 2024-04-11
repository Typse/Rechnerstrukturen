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
.equ GPIO_PORT_F_DEN_R,  0x4002551C
.equ GPIO_PORT_F_DIR_R,  0x40025400
.equ GPIO_PORT_F_PUR_R,  0x40025510

.equ GPIO_PORT_D_DATA_R, 0x400253FC
.equ GPIO_PORT_D_DEN_R,  0x4002551C
.equ GPIO_PORT_D_DIR_R,  0x40025400
.equ GPIO_PORT_D_PUR_R,  0x40025510

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
init_hardware:
    bl init_hardware

endless_loop:
    b endless_loop
    bl check_timer

    // Lese den Zustand des Tasters
    ldr r0, []   // Lese den GPIO-Port, an den der Taster angeschlossen ist
    ands r0, r0, #SW1_MASK // Wende Maske an, um den Tasterzustand zu isolieren
    beq handle_btn_not_pressed // Wenn der Taster nicht gedrückt ist, gehe zu handle_btn_not_pressed

handle_btn_not_pressed:

    lsr r7, r7, #1
    bcs clear_bit
    bl set_LED_white

handle_btn_pressed:
    lsl r7, r7, #1
    bcs set_bit
    bl set_LED_blue
    b endless_loop

set_bit:
    or r7 , r7, #0x80000000
    b endless_loop

clear_bit:
    orr r7, r7, #0x00000001
    b endless_loop

.end
