.section .data
.syntax unified

.equ RCGC_GPIO_R,        0x400FE608
.equ RCGC_GPIO_PORT_F,   0x20

.equ GPIO_PORT_F_DATA_R, 0x400253FC
.equ GPIO_PORT_F_DEN_R,  0x4002551C
.equ GPIO_PORT_F_DIR_R,  0x40025400
.equ GPIO_PORT_F_PUR_R,  0x40025510

.equ PIN0, 0x01
.equ PIN1, 0x02
.equ PIN2, 0x04
.equ PIN3, 0x08
.equ PIN4, 0x10
.equ PIN5, 0x20
.equ PIN6, 0x40
.equ PIN7, 0x80

.equ LED_RGB_MASK, 0x0E
.equ LED_WHITE,    0x0E
.equ LED_OFF,      0x00
.equ BUTTON_SW1,   PIN4

.equ DELAY_COUNT,  16000000

@ Reserve a word for debugging so the rotating bit pattern can be
@ inspected easily in the memory window of the debugger.
rotating_bit_snapshot:
    .word 0

led_state_snapshot:
    .word 0

.section .text
.global main
.align

@ ---------------------------------------------------------------------------
@ main -> enable clock, configure GPIO, then enter the endless control loop.
@ ---------------------------------------------------------------------------
main:
    bl enable_gpio_port_f
    bl init_gpio_port_f
    bl preload_runtime_constants

    b endless_loop

@ ---------------------------------------------------------------------------
@ enable_gpio_port_f
@ Enables the AHB clock supply for Port F by setting bit 5 in RCGC GPIO
@ without touching any other port clock configuration bits.
@ ---------------------------------------------------------------------------
enable_gpio_port_f:
    ldr r0, =RCGC_GPIO_R          @ load address of clock gating register
    ldr r1, [r0]                  @ fetch current register content
    movs r2, #RCGC_GPIO_PORT_F    @ bit mask for Port F clock gate
    orr r1, r1, r2                @ set the Port F bit (boolean OR)
    str r1, [r0]                  @ write back without disturbing other bits

    @ A few NOPs to allow the peripheral clock to stabilize before we touch
    @ the port registers.
    nop
    nop
    nop
    bx lr

@ ---------------------------------------------------------------------------
@ init_gpio_port_f
@ Configures the RGB LED pins (PF1..PF3) as digital outputs and enables the
@ internal pull-up on PF4 so that SW1 reads logic high when released.
@ All configuration is done with boolean operations to preserve unrelated bits.
@ ---------------------------------------------------------------------------
init_gpio_port_f:
    ldr r0, =GPIO_PORT_F_DEN_R    @ Digital enable register address
    ldr r1, [r0]
    movs r2, #LED_RGB_MASK
    movs r3, #BUTTON_SW1
    orr r2, r2, r3
    orr r1, r1, r2                @ enable digital function on PF1..PF4
    str r1, [r0]

    ldr r0, =GPIO_PORT_F_DIR_R    @ Direction register address
    ldr r1, [r0]
    movs r2, #LED_RGB_MASK        @ LED pins shall be outputs
    orr r1, r1, r2
    bic r1, r1, #BUTTON_SW1       @ SW1 shall remain input -> clear the bit
    str r1, [r0]

    ldr r0, =GPIO_PORT_F_PUR_R    @ Pull-up resistor configuration
    ldr r1, [r0]
    movs r2, #BUTTON_SW1
    orr r1, r1, r2                @ activate pull-up on PF4
    str r1, [r0]

    bx lr

@ ---------------------------------------------------------------------------
@ preload_runtime_constants
@ Stores the frequently used addresses and masks in callee-saved registers so
@ the endless loop can run without repeatedly loading literal constants.
@ ---------------------------------------------------------------------------
preload_runtime_constants:
    ldr r4, =GPIO_PORT_F_DATA_R   @ r4 -> Port F data register (masked)
    movs r5, #LED_RGB_MASK        @ r5 -> mask for the RGB LED pins
    movs r6, #BUTTON_SW1          @ r6 -> mask for SW1 (PF4)
    movs r7, #PIN0                @ r7 -> rotating bit starts at LSB position

    ldr r0, =rotating_bit_snapshot
    str r7, [r0]                  @ store initial pattern for debugging

    bx lr

@ ---------------------------------------------------------------------------
@ endless_loop
@ Implements the timer driven polling loop from the sequence diagram.
@ ---------------------------------------------------------------------------
endless_loop:
    bl simple_delay               @ blocks for roughly 1 second
    bl read_button_state          @ r0 = 0 (pressed) or 1 (released)
    cmp r0, #0
    beq handle_btn_pressed

handle_btn_not_pressed:
    bl rotate_left_with_wrap      @ r7 <<= 1 (wrap to bit0)
    bl render_led_white
    b  record_state_and_continue

handle_btn_pressed:
    bl rotate_right_with_wrap     @ r7 >>= 1 (wrap to bit7)
    bl render_led_off

record_state_and_continue:
    bl store_debug_snapshots
    b  endless_loop

@ ---------------------------------------------------------------------------
@ simple_delay
@ Busy-wait loop that consumes DELAY_COUNT iterations to create a visible
@ pause (~1 second on a 16 MHz system clock). Adjust the constant if needed.
@ ---------------------------------------------------------------------------
simple_delay:
    ldr r0, =DELAY_COUNT
1:
    subs r0, r0, #1
    bne 1b
    bx lr

@ ---------------------------------------------------------------------------
@ read_button_state
@ Reads PF4 via the masked data register. Because of the pull-up, the input
@ is logic high when the button is NOT pressed. Returns:
@   r0 = 0 -> button pressed
@   r0 = 1 -> button released
@ ---------------------------------------------------------------------------
read_button_state:
    ldr r0, [r4]                  @ fetch masked port data
    and r0, r0, r6                @ isolate PF4
    cmp r0, #0
    beq 4f
    movs r0, #1                   @ high level -> released
    bx lr
4:
    movs r0, #0                   @ low level -> pressed
    bx lr

@ ---------------------------------------------------------------------------
@ rotate_left_with_wrap
@ Increments the single set bit in r7 towards the MSB. Once the bit reaches
@ position 7 it wraps around to position 0 so the pattern stays cyclic.
@ ---------------------------------------------------------------------------
rotate_left_with_wrap:
    cmp r7, #PIN7
    beq 2f
    lsls r7, r7, #1
    bx lr
2:
    movs r7, #PIN0
    bx lr

@ ---------------------------------------------------------------------------
@ rotate_right_with_wrap
@ Decrements the set bit in r7 towards the LSB. When the bit is already at
@ position 0 it wraps to position 7.
@ ---------------------------------------------------------------------------
rotate_right_with_wrap:
    cmp r7, #PIN0
    beq 3f
    lsrs r7, r7, #1
    bx lr
3:
    movs r7, #PIN7
    bx lr

@ ---------------------------------------------------------------------------
@ render_led_white / render_led_off
@ Update the RGB LED according to the current button state. The LED pins are
@ cleared with a boolean AND (bic) before the desired value is applied, so we
@ never disturb unrelated bits in the data register.
@ ---------------------------------------------------------------------------
render_led_white:
    ldr r0, [r4]
    bic r0, r0, r5
    movs r1, #LED_WHITE
    orr r0, r0, r1
    str r0, [r4]
    bx lr

render_led_off:
    ldr r0, [r4]
    bic r0, r0, r5
    str r0, [r4]
    bx lr

@ ---------------------------------------------------------------------------
@ store_debug_snapshots
@ Stores the current rotation pattern (r7) and the LED state into memory so
@ they can be inspected in the debugger without having to halt execution.
@ ---------------------------------------------------------------------------
store_debug_snapshots:
    ldr r0, =rotating_bit_snapshot
    str r7, [r0]

    ldr r0, =led_state_snapshot
    ldr r1, [r4]
    str r1, [r0]
    bx lr
@end of file
