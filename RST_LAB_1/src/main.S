.section .data
.syntax unified

.equ RCGC_GPIO_R,        0x400FE608
.equ RCGC_GPIO_PORT_A,   0x01
.equ RCGC_GPIO_PORT_B,   0x02
.equ RCGC_GPIO_PORT_C,   0x04
.equ RCGC_GPIO_PORT_D,   0x08
.equ RCGC_GPIO_PORT_E,   0x10
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
.equ PIN_ALL, 0xFF

.equ LED_R,       PIN1
.equ LED_G,       PIN3
.equ LED_B,       PIN2
.equ SW1,         PIN4

.equ FIRST_BIT, PIN0
.equ LAST_BIT,  PIN7

.equ LED_RGB_MASK, 0x0E
.equ LED_WHITE,    0x0E @binär: 00001110
.equ LED_OFF,      0x00 @clear all LED bits
.equ BUTTON_SW1,   PIN4

.equ DELAY_COUNT,  0x00186a00

.section .text
.global main
.align 2

main:
init_hardware:
  // Clock für Port F aktivieren
    ldr r0, = RCGC_GPIO_R
    ldr r1, [r0]
    orr r1, r1, #RCGC_GPIO_PORT_F
    str r1, [r0]

    // kleine Wartezeit bis der Takt stabil ist
    mov r2, #100

clk_wait:
    subs r2, r2, #1
    bne  clk_wait
    // PF1..PF3 als Output (LEDs), PF4 als Input (SW1)
    ldr r0, = GPIO_PORT_F_DIR_R
    ldr r1, [r0]
    orr r1, r1, #(LED_R | LED_G | LED_B)   // LEDs werden Ausgänge
    mvn r3, #SW1                            // r3 = ~SW1
    and r1, r1, r3                          // SW1-Bit löschen -> Eingang
    str r1, [r0]
      // Digitale Funktion für PF1..PF4 aktivieren
    ldr r0, =GPIO_PORT_F_DEN_R
    ldr r1, [r0]
    orr r1, r1, #(LED_R | LED_G | LED_B | SW1)
    str r1, [r0]
     // Pull-up für SW1 aktivieren (aktiv-low: nicht gedrückt = 1)
    ldr r0, =GPIO_PORT_F_PUR_R
    ldr r1, [r0]
    orr r1, r1, #SW1
    str r1, [r0]
     // LEDs am Anfang aus: DATA = DATA & ~LED_MASK
    ldr r0, =GPIO_PORT_F_DATA_R
    ldr r1, [r0]
    mvn r3, #(LED_R | LED_G | LED_B)        // r3 = ~LED_MASK
    and r1, r1, r3                          // LED-Bits löschen
    str r1, [r0]
   // Erstes Bit in r7 setzen (Laufbit)
    mov r7, #FIRST_BIT

    
endless_loop:
 // Geprüft ob Knopf gedrückt wird (SW1 aktiv-low)
    ldr r0, =GPIO_PORT_F_DATA_R
    ldr r1, [r0]
    tst r1, #SW1                 // Z=1 wenn gedrückt (PF4==0), Z=0 wenn nicht gedrückt
    bne handle_btn_not_pressed   // nicht gedrückt (PF4==1) -> Z=0 -> BNE
    b   handle_btn_pressed       // gedrückt (PF4==0) -> Z=1 -> BNE nicht genommen

    b endless_loop
 
handle_btn_not_pressed:
   // Zeitverzögerung (~1 s)
    bl  delay
    // Weißes LED anschalten: DATA = (DATA & ~LED_MASK) | LED_MASK // OUTSOURCE IT AND CHECK ON GIO PORT F FOR BITS !0x0000001e! MUST BE THIS
    ldr r0, =GPIO_PORT_F_DATA_R                                    // IF NOT CHANGED SKIP (bne)    
    ldr r1, [r0]
    mvn r3, #(LED_R | LED_G | LED_B) // LED MASK invertieren
    and r1, r1, r3
    orr r1, r1, #(LED_R | LED_G | LED_B)
    str r1, [r0]
   // Bit um eine Stelle nach links verschieben, bei Überlauf zurücksetzen
    lsl r7, r7, #1
    cmp r7, #0
    bne l_left_ok
    mov r7, #FIRST_BIT
l_left_ok:
    b   endless_loop
handle_btn_pressed:
 // Zeitverzögerung (~1 s)
    bl  delay

    // LEDs aus: DATA = DATA & ~LED_MASK
    ldr r0, =GPIO_PORT_F_DATA_R
    ldr r1, [r0]
    mvn r3, #(LED_R | LED_G | LED_B)
    and r1, r1, r3
    str r1, [r0]
       // Bit um eine Stelle nach rechts verschieben, bei Unterlauf auf MSB setzen
    lsr r7, r7, #1
    cmp r7, #0
    bne l_right_ok
    movs r7, #LAST_BIT
l_right_ok:
    b   endless_loop
// Verzögerungsschleife (~1 s). Zahl ggf. anpassen.
delay:
    ldr r2, =DELAY_COUNT           // WICHTIG: kein '#' innerhalb '=...'
    // mov r2, #DELAY_COUNT
dly_loop:
    subs r2, r2, #1
    bne  dly_loop
    bx   lr
.end



// ...existing code...

; endless_loop:
;     ldr r0, =GPIO_PORT_F_DATA_R
;     ldr r1, [r0]
;     tst r1, #SW1
;     bne handle_btn_not_pressed
;     b   handle_btn_pressed

; handle_btn_not_pressed:
;     bl  delay
    
;     mov r0, #LED_WHITE              @ r0 = gewünschter LED-Zustand
;     bl  set_led_if_changed          @ Setze LED (nur wenn anders)
    
;     lsl r7, r7, #1
;     cmp r7, #0
;     bne l_left_ok
;     mov r7, #FIRST_BIT
; l_left_ok:
;     b   endless_loop

; handle_btn_pressed:
;     bl  delay
    
;     mov r0, #LED_OFF                @ r0 = LED aus
;     bl  set_led_if_changed          @ Setze LED (nur wenn anders)
    
;     lsr r7, r7, #1
;     cmp r7, #0
;     bne l_right_ok
;     movs r7, #LAST_BIT
; l_right_ok:
;     b   endless_loop

; // Funktion: Setze LED nur wenn Zustand sich ändert
; set_led_if_changed:
;     push {r1, r2, r3, lr}
    
;     ldr r1, =GPIO_PORT_F_DATA_R
;     ldr r2, [r1]
;     and r3, r2, #(LED_R | LED_G | LED_B)
    
;     cmp r3, r0                      @ Vergleiche aktuell vs. gewünscht
;     beq 1f                          @ Wenn gleich, überspringe
    
;     mvn r3, #(LED_R | LED_G | LED_B)
;     and r2, r2, r3
;     orr r2, r2, r0
;     str r2, [r1]
    
; 1:  pop {r1, r2, r3, pc}

; delay:
;     ldr r2, =DELAY_COUNT
; dly_loop:
;     subs r2, r2, #1
;     bne  dly_loop
;     bx   lr

; .end