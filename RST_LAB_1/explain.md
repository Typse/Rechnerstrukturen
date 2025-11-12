# Assembly-Code-Erklärung für absolute Anfänger

## Was dieses Programm macht

Dieses Programm steuert eine RGB-LED auf einer Mikrocontroller-Platine (vermutlich ein TI LaunchPad mit TM4C123 Chip). Es lässt ein Bitmuster nach links oder rechts rotieren, je nachdem ob ein Knopf gedrückt wird. Wenn der Knopf NICHT gedrückt ist, leuchtet die RGB-LED weiß und das Bit rotiert nach links. Wenn der Knopf gedrückt IS, schaltet sich die LED aus und das Bit rotiert nach rechts.

## Erst mal die super wichtigen Grundkonzepte

### Was ist Assembly?
Assembly ist eine sehr niedrigstufige Programmiersprache, die direkt mit dem Prozessor des Computers arbeitet. Statt Anweisungen wie `if(button.pressed)` in höherwertigen Sprachen muss man manuell Werte aus dem Speicher laden, sie vergleichen und zu verschiedenen Teilen des Codes springen.

### Register
Register sind winzige Speicherplätze direkt im Prozessor - wie super-schnelle, winzige Variablen. Bei ARM-Prozessoren (die diesen Code verwenden) gibt es Register namens R0 bis R12, plus ein paar spezielle. Stell dir sie als die Werkbank des Prozessors vor, wo er Daten bearbeitet.

### Speicheradressen
Der Mikrocontroller hat Speicherplätze mit spezifischen Adressen (wie 0x400FE608). Diese Adressen sind mit verschiedenen Hardware-Teilen verbunden. Das Schreiben in diese speziellen Speicheradressen steuert tatsächlich physische Dinge wie LEDs!

## Struktur des Programms

### Data-Bereich (`.section .data`)
Hier definieren wir Konstanten und reservieren Speicherplatz. Konstanten sind wie ein Wörterbuch mit Begriffen, die unser Programm verwendet.

### Text-Bereich (`.section .text`)
Hier ist der eigentliche Code, der ausgeführt wird.

## Jetzt gehen wir jeden Schritt durch

### Konstanten einrichten

```
.equ RCGC_GPIO_R,        0x400FE608
.equ RCGC_GPIO_PORT_F,   0x20
```

Diese Zeilen erstellen benannte Konstanten. `RCGC_GPIO_R` ist die Speicheradresse zum Aktivieren von Takten für GPIO-Ports (General Purpose Input/Output). Stell dir vor, einen Takt zu aktivieren ist wie Strom für einen Teil der Platine einzuschalten.

```
.equ GPIO_PORT_F_DATA_R, 0x400253FC
.equ GPIO_PORT_F_DEN_R,  0x4002551C
.equ GPIO_PORT_F_DIR_R,  0x40025400
.equ GPIO_PORT_F_PUR_R,  0x40025510
```

Dies sind Adressen zur Steuerung von Port F (eine spezifische Menge von Pins auf dem Mikrocontroller):
- `DATA_R` steuert die tatsächlichen Signale auf den Pins (an/aus)
- `DEN_R` aktiviert die digitale Funktionalität für Pins
- `DIR_R` legt fest, ob Pins Eingänge oder Ausgänge sind
- `PUR_R` aktiviert Pull-up-Widerstände (verhindert, dass Eingänge "floating" sind)

```
.equ PIN0, 0x01  (binär: 00000001)
.equ PIN1, 0x02  (binär: 00000010)
.equ PIN2, 0x04  (binär: 00000100)
.equ PIN3, 0x08  (binär: 00001000)
...
```

Diese definieren Bitpositionen für jeden Pin (0 bis 7). Jede Konstante hat nur ein Bit gesetzt, was uns ermöglicht, einzelne Pins zu manipulieren.

```
.equ LED_RGB_MASK, 0x0E  (binär: 00001110)
```
Diese Maske deckt Pins 1, 2 und 3 kombiniert ab (wo die RGB-LEDs angeschlossen sind).

```
.equ LED_WHITE, 0x0E
.equ LED_OFF, 0x00
.equ BUTTON_SW1, PIN4
```
Diese definieren die Werte zum Erleuchten der LED weiß (alle RGB-Komponenten an) oder zum Ausschalten, und welcher Pin mit dem Knopf verbunden ist.

```
.equ DELAY_COUNT, 16000000
```
Dies ist die Anzahl der Schleifeniterationen, um eine ~1-Sekunden-Verzögerung zu erzeugen.

### Debug-Werte speichern

```
rotating_bit_snapshot:
    .word 0

led_state_snapshot:
    .word 0
```
Diese reservieren Worte (4-Byte-Speicherplätze) im Speicher, um Werte zu speichern, die in einem Debugger beobachtet werden können.

### Main-Funktion und Programmfluss

```
main:
    bl enable_gpio_port_f
    bl init_gpio_port_f
    bl preload_runtime_constants
    b endless_loop
```

`main` ist der Ort, wo das Programm startet. Es:
1. Ruft (branch with link, `bl`) eine Funktion auf, um Port F's Takt zu aktivieren
2. Ruft eine Funktion auf, um die Pins zu konfigurieren
3. Lädt häufig verwendete Werte in Register
4. Springt zur Endlosschleife, die für immer läuft

### GPIO Port F aktivieren

```
enable_gpio_port_f:
    ldr r0, =RCGC_GPIO_R          @ load address of clock gating register
    ldr r1, [r0]                  @ fetch current register content
    movs r2, #RCGC_GPIO_PORT_F    @ bit mask for Port F clock gate
    orr r1, r1, r2                @ set the Port F bit (boolean OR)
    str r1, [r0]                  @ write back without disturbing other bits

    @ A few NOPs to allow the peripheral clock to stabilize
    nop
    nop
    nop
    bx lr
```

Diese Funktion:
1. Lädt die Adresse des Taktsteuerungsregisters in R0
2. Holt den aktuellen Wert von dieser Adresse in R1
3. Setzt die Port F Bitmaske in R2
4. Setzt das Port F Bit in R1 mit OR (behält andere Bits unverändert)
5. Speichert den geänderten Wert zurück zur Adresse
6. Wartet ein Bit (NOP = no operation)
7. Kehrt zum Aufrufer zurück (bx lr)

Das ist wie das Einschalten von Strom für Port F, ohne andere Ports zu beeinflussen.

### GPIO Port F einrichten

```
init_gpio_port_f:
```

Diese Funktion konfiguriert Port F Pins:
1. Aktiviert die digitale Funktionalität für LED-Pins und Button-Pin
2. Setzt LED-Pins als Ausgänge und Button-Pin als Eingang
3. Aktiviert einen Pull-up-Widerstand auf dem Button-Pin (hält ihn HIGH wenn nicht gedrückt)

Für jeden Schritt:
- Lädt die Adresse des Registers
- Holt den aktuellen Wert
- Modifiziert nur die Bits, die uns interessieren
- Schreibt das Ergebnis zurück

Die verwendeten Operationen sind:
- `orr`: OR-Operation (setzt Bits)
- `bic`: Bit Clear (löscht Bits)

### Konstanten vorausladen

```
preload_runtime_constants:
```

Diese Funktion lädt häufig verwendete Werte in die Register R4-R7:
- R4: Port F Datenregister Adresse
- R5: LED-Pins Maske
- R6: Button Maske
- R7: Das rotierende Bit (startet an Position 0)

Dies macht die Hauptschleife schneller, da sie diese Werte nicht jedes Mal neu laden muss.

### Die Hauptschleife

```
endless_loop:
    bl simple_delay               @ waits ~1 second
    bl read_button_state          @ checks if button is pressed
    cmp r0, #0                    @ compares result with 0
    beq handle_btn_pressed        @ if equal (button pressed), branch to handler
```

Die Schleife:
1. Wartet für ~1 Sekunde
2. Überprüft den Knopfzustand
3. Wenn der Knopf gedrückt ist (gibt 0 zurück), wird der entsprechende Handler aufgerufen
4. Sonst wird der "nicht gedrückt" Handler ausgeführt

```
handle_btn_not_pressed:
    bl rotate_left_with_wrap      @ shifts bit left
    bl render_led_white           @ turns LED white
    b  record_state_and_continue

handle_btn_pressed:
    bl rotate_right_with_wrap     @ shifts bit right
    bl render_led_off             @ turns LED off

record_state_and_continue:
    bl store_debug_snapshots
    b  endless_loop               @ repeats forever
```

Wenn der Knopf NICHT gedrückt ist:
- Rotiert das Bit nach links
- Stellt die LED auf weiß

Wenn der Knopf gedrückt ist:
- Rotiert das Bit nach rechts
- Schaltet die LED aus

Nach beiden Fällen:
- Speichert Werte zum Debuggen
- Wiederholt die Schleife

### Hilfsfunktionen

```
simple_delay:
```
Erstellt eine Verzögerung, indem von DELAY_COUNT bis Null heruntergezählt wird.

```
read_button_state:
```
Liest den Button-Pin-Wert und gibt zurück:
- 0 wenn gedrückt (LOW Signal)
- 1 wenn nicht gedrückt (HIGH Signal dank Pull-up)

```
rotate_left_with_wrap:
```
Verschiebt das Bit in R7 um eine Position nach links. Wenn es bereits bei Bit 7 ist, springt es zurück zu Bit 0.

```
rotate_right_with_wrap:
```
Verschiebt das Bit in R7 um eine Position nach rechts. Wenn es bereits bei Bit 0 ist, springt es zu Bit 7.

```
render_led_white:
```
Aktualisiert die LED-Pins, um weiße Farbe anzuzeigen.

```
render_led_off:
```
Schaltet die LED aus.

```
store_debug_snapshots:
```
Speichert aktuelle Werte im Speicher, damit sie in einem Debugger beobachtet werden können.

## Zusammenfassung: So funktioniert alles zusammen

1. **Initialisierung**:
   - Port F's Takt aktivieren
   - Pins konfigurieren (LEDs als Ausgänge, Button als Eingang mit Pull-up)
   - Häufig verwendete Werte in Register laden

2. **Hauptschleife** (wiederholt sich für immer):
   - Etwa 1 Sekunde warten
   - Knopfzustand überprüfen
   - Wenn Knopf NICHT gedrückt:
     - Bit nach links rotieren
     - LED auf weiß stellen
   - Wenn Knopf gedrückt:
     - Bit nach rechts rotieren
     - LED ausschalten
   - Debug-Werte speichern
   - Wiederholen

Die Bit-Rotation ist nur zur Demonstration - sie zeigt, dass der Prozessor etwas tut, und das Muster kann in einem Debugger-Fenster beobachtet werden.