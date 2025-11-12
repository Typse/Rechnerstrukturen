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

//=============================================================================
// init_hardware: Initialisierung von SysTick und GPIO Port F
//=============================================================================
init_hardware:
    //-------------------------------------------------------------------------
    // SysTick Konfiguration für 1ms Interrupt
    //-------------------------------------------------------------------------
    // Systemtakt: 16 MHz = 16.000.000 Hz
    // Für 1ms Tick: 16.000.000 Hz / 1000 = 16.000 Takte pro ms
    // RELOAD-Wert: 16.000 - 1 = 15.999 (da Counter bei 0 startet)
    
    ldr r0, =ST_RELOAD_R        @ Lade Adresse des STRELOAD-Registers
    ldr r2, =15999              @ Lade Reload-Wert für 1ms bei 16MHz
    str r2, [r0]                @ Schreibe Reload-Wert
    
    // Clear STCURRENT Register (Reset des Counters)
    ldr r1, =ST_CURRENT_R       @ Lade Adresse des STCURRENT-Registers
    mov r0, #0                  @ Wert 0 zum Löschen
    str r0, [r1]                @ Schreibe 0 -> Counter wird zurückgesetzt
    
    // Konfiguriere STCTRL Register
    // - BIT0 (ENABLE): SysTick aktivieren
    // - BIT2 (CLK_SRC): Systemtakt als Quelle (16 MHz)
    // - BIT1 (INTEN): Interrupt NICHT aktiviert (wir pollen)
    ldr r0, =ST_CTRL_R          @ Lade Adresse des STCTRL-Registers
    ldr r1, =(ST_CTRL_ENABLE | ST_CTRL_CLK_SRC)  @ Enable + CLK_SRC setzen
    str r1, [r0]                @ Schreibe Konfiguration
    
    //-------------------------------------------------------------------------
    // GPIO Port F Konfiguration (für LEDs)
    //-------------------------------------------------------------------------
    // Aktiviere Clock für Port F
    ldr r0, =RCGC_GPIO_R        @ Lade Adresse des RCGC GPIO Registers
    ldr r1, [r0]                @ Lese aktuellen Wert
    orr r1, r1, #RCGC_GPIO_PORT_F  @ Setze Bit für Port F
    str r1, [r0]                @ Schreibe zurück
    
    // Kleine Verzögerung, damit Clock stabil ist
    nop
    nop
    nop
    
    // Aktiviere Digital Enable (DEN) für Pins 1-3 (LEDs)
    ldr r0, =GPIO_PORT_F_DEN_R  @ Lade Adresse des DEN Registers
    ldr r1, [r0]                @ Lese aktuellen Wert
    orr r1, r1, #(LED_R | LED_B | LED_G)  @ Aktiviere Pins 1, 2, 3
    str r1, [r0]                @ Schreibe zurück
    
    // Setze Direction (DIR) für Pins 1-3 auf Output
    ldr r0, =GPIO_PORT_F_DIR_R  @ Lade Adresse des DIR Registers
    ldr r1, [r0]                @ Lese aktuellen Wert
    orr r1, r1, #(LED_R | LED_B | LED_G)  @ Setze Pins 1, 2, 3 als Output
    str r1, [r0]                @ Schreibe zurück
    
    // Initialisiere LEDs im AUS-Zustand
    ldr r0, =GPIO_PORT_F_DATA_R @ Lade Adresse des Data Registers
    mov r1, #0                  @ Alle LEDs aus
    str r1, [r0]                @ Schreibe 0
    
    b main_loop                 @ Springe zur Hauptschleife

//=============================================================================
// TEIL I - SysTick Handler
//=============================================================================
// Diese Subroutine wird jede Millisekunde aufgerufen (entweder durch Polling
// in main_loop oder durch einen Interrupt). Da sie asynchron aufgerufen wird,
// müssen ALLE verwendeten Register gesichert und wiederhergestellt werden.
//
// Funktionalität:
// - Inkrementiert ms (Millisekunden) bei jedem Aufruf
// - Wenn ms == 1000 erreicht: Reset ms auf 0 und inkrementiere s (Sekunden)
// - LED blinkt mit 0,5 Hz (an für 1 Sek, aus für 1 Sek = Periode 2 Sek)
//=============================================================================

.thumb_func
sys_tick_handler:
    // Register r0-r3, r12, LR, PC und CPSR werden bei Interrupts automatisch gesichert
    // Wir sichern zusätzlich r4-r11 (Arbeitsregister), um sicher zu gehen
    push {r4-r11, lr}           @ Sichert alle verwendeten Register auf dem Stack
    
    //-------------------------------------------------------------------------
    // Millisekunden inkrementieren
    //-------------------------------------------------------------------------
    ldr r0, =ms                 @ Lade Adresse der ms-Variable
    ldr r1, [r0]                @ Lade aktuellen Wert von ms
    add r1, r1, #1              @ ms++
    
    // Prüfen ob 1000 ms erreicht (= 1 Sekunde)
    ldr r2, =1000
    cmp r1, r2
    bge increase_second         @ Wenn ms >= 1000, springe zu increase_second
    
    // Noch keine volle Sekunde erreicht
    str r1, [r0]                @ Speichere neuen ms-Wert
    pop {r4-r11, pc}            @ Stelle Register wieder her und kehre zurück
    
increase_second:
    //-------------------------------------------------------------------------
    // Eine volle Sekunde ist vergangen
    //-------------------------------------------------------------------------
    mov r1, #0                  @ Reset ms auf 0
    str r1, [r0]                @ Speichere ms = 0
    
    ldr r0, =s                  @ Lade Adresse der s-Variable
    ldr r1, [r0]                @ Lade aktuellen Wert von s
    add r1, r1, #1              @ s++
    str r1, [r0]                @ Speichere neuen s-Wert
    
    //-------------------------------------------------------------------------
    // LED Toggle-Logik (0,5 Hz = LED wechselt jede Sekunde)
    //-------------------------------------------------------------------------
    // Prüfe ob s gerade oder ungerade ist
    // Gerade (Bit 0 = 0) -> LED AUS
    // Ungerade (Bit 0 = 1) -> LED AN
    and r2, r1, #0x1            @ Extrahiere Bit 0 von s (gerade/ungerade)
    cmp r2, #0
    beq led_off                 @ Wenn gerade (0), schalte LED aus
    b led_on                    @ Wenn ungerade (1), schalte LED an

led_on:
    //-------------------------------------------------------------------------
    // LED einschalten (Grüne LED = BIT3 auf 1)
    //-------------------------------------------------------------------------
    ldr r0, =GPIO_PORT_F_DATA_R @ Lade Adresse des GPIO Data Registers
    ldr r1, [r0]                @ Lese aktuellen Wert
    orr r1, r1, #LED_G          @ Setze LED_G (BIT3) auf 1
    str r1, [r0]                @ Schreibe zurück
    pop {r4-r11, pc}            @ Stelle Register wieder her und kehre zurück

led_off:
    //-------------------------------------------------------------------------
    // LED ausschalten (Grüne LED = BIT3 auf 0)
    //-------------------------------------------------------------------------
    ldr r0, =GPIO_PORT_F_DATA_R @ Lade Adresse des GPIO Data Registers
    ldr r1, [r0]                @ Lese aktuellen Wert
    bic r1, r1, #LED_G          @ Lösche LED_G (BIT3), setze auf 0
    str r1, [r0]                @ Schreibe zurück
    pop {r4-r11, pc}            @ Stelle Register wieder her und kehre zurück

main: 
    b init_hardware             @ Springe zur Hardware-Initialisierung

//=============================================================================
// main_loop: Hauptschleife des Programms
//=============================================================================
// Hier wird das SysTick COUNT-Flag gepollt. Wenn es gesetzt ist (=1),
// bedeutet dies, dass der Counter auf 0 heruntergezählt hat und 1ms vergangen ist.
// In diesem Fall wird sys_tick_handler aufgerufen.
//=============================================================================
main_loop:
    // Kommentiere die nächste Zeile aus, um TEIL III (Zeitmessung) zu aktivieren
    // b zeitmessung
    
    //-------------------------------------------------------------------------
    // SysTick Polling: Prüfe COUNT-Flag (BIT16 in ST_CTRL)
    //-------------------------------------------------------------------------
    ldr r1, =ST_CTRL_R          @ Lade Adresse des SysTick Control Registers
    ldr r0, [r1]                @ Lese aktuellen Wert
    ands r0, r0, #ST_CTRL_COUNT @ Prüfe COUNT-Flag (BIT16)
                                @ ands setzt Zero-Flag wenn Ergebnis = 0
    bne sys_tick_handler        @ Wenn COUNT-Flag gesetzt (!=0), rufe Handler auf
    
    b main_loop                 @ Wiederhole Schleife


//=============================================================================
// TEIL II - Debugger Memory Reiter
//=============================================================================
// Aufgaben zum Debuggen (werden im Debugger ausgeführt, nicht im Code):
//
// 1. Peripherieregister im Memory finden:
//    - Wähle ein GPIO-Register (z.B. GPIO_PORT_F_DATA_R = 0x400253FC)
//    - Öffne Memory-Reiter und gib Adresse ein: 0x400253FC
//    - Vergleiche Wert mit dem im Peripherals-Reiter
//    - Beide sollten identisch sein!
//
// 2. Stack-Beobachtung mit push:
//    - Setze Breakpoint bei "push_test" Label (unten)
//    - Notiere SP-Wert (Stack Pointer) vor push
//    - Öffne Memory-Reiter mit SP-Adresse
//    - Führe "push {r1, r2}" aus und beobachte:
//      * SP wird um 8 Bytes dekrementiert (2 Register × 4 Bytes)
//      * Werte von r1 und r2 erscheinen im Stack-Speicher
//    - Führe "push {r2, r1}" aus:
//      * SP wird wieder um 8 Bytes dekrementiert
//      * WICHTIG: Reihenfolge im Speicher ist GLEICH! (r1 zuerst, dann r2)
//      * ARM speichert Register immer in aufsteigender Reihenfolge
//
// 3. Maschinencode von push-Befehlen:
//    - Öffne Disassembly-View oder Memory-Reiter bei PC (Program Counter)
//    - Schaue dir Maschinencode an:
//      * push {r1, r2} -> Maschinencode: z.B. 0x06 0xB4
//      * push {r2, r1} -> Maschinencode: z.B. 0x06 0xB4
//    - BEOBACHTUNG: Beide Befehle haben IDENTISCHEN Maschinencode!
//    - ERKLÄRUNG: Der Assembler sortiert die Register automatisch
//                 Die Registermaske kodiert nur WELCHE Register (nicht Reihenfolge)
//                 {r1, r2} und {r2, r1} ergeben dieselbe Maske: 0b00000110
//
//=============================================================================

push_test:
    // Test-Code für TEIL II (mit Breakpoint verwenden)
    mov r1, #0x11               @ Lade Test-Wert in r1
    mov r2, #0x22               @ Lade Test-Wert in r2
    push {r1, r2}               @ Push in einer Reihenfolge
    push {r2, r1}               @ Push in anderer Reihenfolge (gleicher Maschinencode!)
    // Setze hier Breakpoint und untersuche Stack im Memory-Reiter!


//=============================================================================
// TEIL III - CPI Messung (Cycles Per Instruction)
//=============================================================================
// Methode zur Zeitmessung:
// 1. SysTick CURRENT-Register VOR Befehlsausführung auslesen
// 2. Befehl(e) mehrfach ausführen
// 3. SysTick CURRENT-Register NACH Befehlsausführung auslesen
// 4. Differenz berechnen: Zyklen = CURRENT_vorher - CURRENT_nachher
//    (SysTick zählt RÜCKWÄRTS von RELOAD bis 0)
//
// WICHTIG: Breakpoints verursachen Pipeline-Flush und verfälschen Messung!
//          Daher: Messungen OHNE Breakpoints durchführen
//          Lösung: Werte in Register speichern und nach Ende ablesen
//
// Alternative: COUNT-Flag beobachten, wie oft es während einer Schleife gesetzt wird
//=============================================================================

zeitmessung:
    //-------------------------------------------------------------------------
    // Messung 1: nop-Befehl
    //-------------------------------------------------------------------------
    // Erwartung: 1 Zyklus (nop = No Operation, einfachster Befehl)
    ldr r5, =ST_CURRENT_R       @ Lade Adresse von CURRENT-Register
    ldr r3, [r5]                @ Lese Startwert (vorher)
    
    nop                         @ Zu messender Befehl
    
    ldr r4, [r5]                @ Lese Endwert (nachher)
    sub r6, r3, r4              @ Berechne Differenz (Zyklen)
    // Ergebnis in r6: ca. 1 Zyklus
    
    //-------------------------------------------------------------------------
    // Messung 2: ldr r0, [sp] - Load aus Stack
    //-------------------------------------------------------------------------
    // Erwartung: 2 Zyklen (Speicherzugriff benötigt mehr Zeit)
    ldr r3, [r5]                @ Startwert
    
    ldr r0, [sp]                @ Zu messender Befehl
    
    ldr r4, [r5]                @ Endwert
    sub r7, r3, r4              @ Differenz
    // Ergebnis in r7: ca. 2 Zyklen
    
    //-------------------------------------------------------------------------
    // Messung 3: str r0, [sp, #-4] - Store mit Offset (ohne Writeback)
    //-------------------------------------------------------------------------
    // Erwartung: 2 Zyklen (Speicherzugriff)
    ldr r3, [r5]                @ Startwert
    
    str r0, [sp, #-4]           @ Zu messender Befehl (SP bleibt unverändert)
    
    ldr r4, [r5]                @ Endwert
    sub r8, r3, r4              @ Differenz
    // Ergebnis in r8: ca. 2 Zyklen
    
    //-------------------------------------------------------------------------
    // Messung 4: str r0, [sp, #-4]! - Store mit Writeback (!)
    //-------------------------------------------------------------------------
    // Erwartung: 2+ Zyklen (Speicherzugriff + SP-Update)
    // ACHTUNG: Dieser Befehl dauert LÄNGER als str ohne "!"
    // Grund: Writeback (!) bedeutet SP wird aktualisiert -> zusätzliche Operation
    ldr r3, [r5]                @ Startwert
    
    str r0, [sp, #-4]!          @ Zu messender Befehl (SP = SP - 4)
    
    ldr r4, [r5]                @ Endwert
    sub r9, r3, r4              @ Differenz
    // Ergebnis in r9: ca. 2-4 Zyklen (länger wegen Writeback!)
    
    //-------------------------------------------------------------------------
    // ERKLÄRUNG: Warum ist str mit "!" langsamer?
    // - Ohne "!": Nur Speicherzugriff, SP bleibt gleich
    // - Mit "!":  Speicherzugriff + SP muss aktualisiert werden
    //             Dies ist eine zusätzliche Register-Operation
    //             Kann zu Stalls führen, wenn nachfolgender Befehl SP braucht
    //-------------------------------------------------------------------------
    
    //-------------------------------------------------------------------------
    // Messung 5: mul - Multiplikation
    //-------------------------------------------------------------------------
    // Erwartung: 1-3 Zyklen auf Cortex-M4 (abhängig vom Prozessor)
    ldr r1, =0x2                @ Lade Operand
    ldr r3, [r5]                @ Startwert
    
    mul r0, r1, r1              @ Zu messender Befehl (r0 = r1 * r1)
    
    ldr r4, [r5]                @ Endwert
    sub r10, r3, r4             @ Differenz
    // Ergebnis in r10: ca. 1-3 Zyklen
    
    //-------------------------------------------------------------------------
    // Messung 6: sdiv - Vorzeichenbehaftete Division
    //-------------------------------------------------------------------------
    // Erwartung: 2-12 Zyklen (Division ist VIEL langsamer als Multiplikation!)
    ldr r1, =0x100              @ Lade Operand
    ldr r2, =0x2                @ Divisor
    ldr r3, [r5]                @ Startwert
    
    sdiv r0, r1, r2             @ Zu messender Befehl (r0 = r1 / r2)
    
    ldr r4, [r5]                @ Endwert
    sub r11, r3, r4             @ Differenz
    // Ergebnis in r11: ca. 2-12 Zyklen (VIEL langsamer als mul!)
    
    //-------------------------------------------------------------------------
    // Messung 7: sdiv mit getauschten Operanden
    //-------------------------------------------------------------------------
    ldr r2, =0x100              @ Lade Operand (getauscht)
    ldr r1, =0x2                @ Divisor (getauscht)
    ldr r3, [r5]                @ Startwert
    
    sdiv r0, r2, r1             @ Zu messender Befehl
    
    ldr r4, [r5]                @ Endwert
    // Ergebnis: Ähnlich wie vorher, Operandenreihenfolge ändert Zeit kaum
    
    //-------------------------------------------------------------------------
    // Messung 8: push mit verschiedener Anzahl Register
    //-------------------------------------------------------------------------
    // Hypothese: Jedes Register = +1 Zyklus (lineare Abhängigkeit)
    
    // push mit 1 Register
    ldr r1, =0x11
    ldr r3, [r5]                @ Startwert
    
    push {r1}                   @ 1 Register
    
    ldr r4, [r5]                @ Endwert
    // Erwartung: ca. 1-2 Zyklen
    
    // push mit 2 Registern
    ldr r1, =0x11
    ldr r2, =0x22
    ldr r3, [r5]                @ Startwert
    
    push {r1, r2}               @ 2 Register
    
    ldr r4, [r5]                @ Endwert
    // Erwartung: ca. 2-3 Zyklen
    
    // push mit 3 Registern
    ldr r1, =0x11
    ldr r2, =0x22
    ldr r3, =0x33
    ldr r0, [r5]                @ Startwert (nicht r3, das wird gepusht!)
    
    push {r1, r2, r3}           @ 3 Register
    
    ldr r4, [r5]                @ Endwert
    // Erwartung: ca. 3-4 Zyklen
    
    //-------------------------------------------------------------------------
    // BEOBACHTUNG: push-Zeit steigt mit Anzahl der Register
    // Jedes zusätzliche Register = ca. +1 Zyklus Speicherzugriff
    //-------------------------------------------------------------------------
    
    b zeitmessung               @ Endlosschleife für kontinuierliche Messung
.end