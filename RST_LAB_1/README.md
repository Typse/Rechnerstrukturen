# Hinweise zur Bearbeitung

## GCC ASM Syntax

Wir nutzen im Rechnerstrukturen-Labor PlatformIO als Entwicklungsumgebung, wodurch eine größtmögliche Kompatibilität zwischen den meisten Betriebssystemem erreicht werden soll. Dadurch ist aber auch die Verwendung des GCC-Assemblers notwendig. Der GCC-Assembler verwendet eine andere Syntax als der *armasm*.

Im Folgenden finden Sie eine Liste von hilfreichen Links. 

- [Einführung in ARM Assembly](https://developer.arm.com/documentation/den0013/d/Introduction-to-Assembly-Language)

## Linux

Wenn der Upload unter Linux nicht funktioniert: [udev.rules](https://docs.platformio.org/en/stable/core/installation/udev-rules.html#platformio-udev-rules)

## Allgemeines

Folgende Fehlermeldungen brauchen Sie nicht beunruhigen, das ist ein bekannter Bug von Platformio:

```bash
Error: SRST error
Error: SRST error
target halted due to debug-request, current mode: Thread 
xPSR: 0x01000000 pc: 0x0000034c msp: 0x20000488
** Programming Started **
** Programming Finished **
** Verify Started **
** Verified OK **
** Resetting Target **
Error: SRST error
shutdown command invoked
```

Wenn Sie die Warnung "`WARNING: board/ek-tm4c123gxl.cfg is deprecated, please switch to board/ti_ek-tm4c123gxl.cfg`" beseitigen möchten, hilft dieser [Link](https://community.platformio.org/t/debug-server-options-are-not-being-seen/24839/2)

``` mermaid
graph LR
    I(init hardware)
    L(loop)
    T{timer expired?}
    B{Button pressed?}
    NOT_PRESSED(handle_not_pressed)
    PRESSED(handle_pressed)

    I --> L
    L --> T  -- no --> L
    T -- yes -->  B
    B -- yes --> PRESSED --> L
    B -- no --> NOT_PRESSED --> L
```

## Projektüberblick

Dieses Laborprojekt dreht ein einzelnes gesetztes Bit innerhalb des Registers `r7` und verwendet einen Taster (`SW1` auf Port F Pin 4), um die Drehrichtung vorzugeben. Gleichzeitig signalisiert die RGB-LED des Launchpads den aktuellen Zustand:

- **Taster nicht gedrückt** → Rotation nach links (`<<`) und LED **weiß** (alle Farbkanäle an).
- **Taster gedrückt** → Rotation nach rechts (`>>`) und LED **aus**.

Der komplette Ablauf orientiert sich an dem oben gezeigten Sequenzdiagramm. Das Programm besteht ausschließlich aus ARM-Thumb-Befehlen (ohne Rotationsbefehle wie `ROR`/`RRX`) und bearbeitet die GPIO-Konfigurationsregister nur über boolesche Operationen (`orr`, `bic`).

## Hardware-Initialisierung

1. **Takt freigeben** – In `enable_gpio_port_f` wird Bit 5 des Registers `RCGC_GPIO_R` gesetzt. Dabei wird das Register zunächst gelesen (`ldr r1, [r0]`), mit einer `orr`-Operation der gewünschte Port aktiviert und das Ergebnis wieder zurückgeschrieben. Dadurch bleiben alle anderen Ports unverändert.
2. **Digitale Funktion & Richtung** – `init_gpio_port_f` schaltet über das `DEN`-Register die Pins PF1…PF4 als digitale Pins frei. Anschließend werden PF1…PF3 als Ausgänge konfiguriert (`orr`) und PF4 als Eingang belassen (`bic`).
3. **Pull-up für den Taster** – Über das `PUR`-Register wird PF4 mit einem internen Pull-up versehen, sodass der Eingang logisch High ist, solange der Taster nicht gedrückt wird.

Nach der Initialisierung legt `preload_runtime_constants` häufig benötigte Adressen und Masken in den callee-saved Registern `r4`…`r7` ab. So müssen die Werte nicht in jedem Schleifendurchlauf erneut aus dem Literal-Pool geladen werden. Zusätzlich wird der Startwert des rotierenden Bits (`r7 = 0x01`) in den Speicherbereich `rotating_bit_snapshot` geschrieben. Dieser Speicherbereich – ebenso wie `led_state_snapshot` – kann im Debugger beobachtet werden, ohne das Programm anzuhalten.

## Hauptschleife & Timer

Die Funktion `endless_loop` bildet den Kern des Programms:

1. `simple_delay` baut mit einem Downcounter (`subs`/`bne`) eine grobe Wartezeit von ca. einer Sekunde auf (bei 16 MHz Systemtakt). Die Wartezeit lässt sich über die Konstante `DELAY_COUNT` anpassen.
2. `read_button_state` liest PF4 über das maskierte Datenregister. Wegen des Pull-ups liefert der Eingang den Wert `1`, solange der Taster nicht gedrückt ist. Das Ergebnis wird als boolesches Flag nach `r0` zurückgegeben.
3. Abhängig vom Flag wird entweder `handle_btn_not_pressed` (Rotation nach links, LED weiß) oder `handle_btn_pressed` (Rotation nach rechts, LED aus) aufgerufen. Beide Routinen führen die Drehoperation auf `r7` durch und aktualisieren anschließend die LED.
4. `store_debug_snapshots` sichert den aktuellen Inhalt von `r7` sowie den letzten LED-Zustand im RAM. So lässt sich im Debugger nachvollziehen, welcher Wert als Nächstes verschoben wird und welches LED-Muster tatsächlich geschrieben wurde.

### Drehoperation ohne ROR/RRX

- **Linksrotation (`rotate_left_with_wrap`)**: Solange `r7` ungleich `0x80` ist, erfolgt eine Linksschiebung (`lsls`). Erreicht das Bit die höchste Position, wird auf `0x01` zurückgesetzt.
- **Rechtsrotation (`rotate_right_with_wrap`)**: Analog dazu wird geschoben (`lsrs`), bis `r7` auf `0x01` angekommen ist; anschließend erfolgt der Sprung zurück auf `0x80`.

Durch dieses Vorgehen entsteht der gewünschte zyklische Verlauf:

```
0x01 → 0x02 → … → 0x80 → 0x01 → …
```

Sie können den Inhalt von `r7` oder der beiden Snapshot-Variablen jederzeit im Debugger beobachten, um den Fortschritt zu kontrollieren. Außerdem lässt sich – je nach Aufgabenstellung – ein Breakpoint auf die Labels `rotate_left_with_wrap` oder `rotate_right_with_wrap` setzen, um die Status-Flags (z. B. Zero-Flag nach `cmp`) auszuwerten.

## LEDs und Farbwahl

Die LED-Routinen `render_led_white` und `render_led_off` arbeiten nach demselben Schema:

1. Das aktuelle Datenregister (`GPIO_PORT_F_DATA_R`) wird gelesen.
2. Über `bic` werden nur die drei LED-Bits PF1..PF3 gelöscht, alle anderen Bits bleiben unberührt.
3. Für Weiß werden alle drei Bits gesetzt (`orr`), für „aus“ bleibt der Wert einfach gelöscht.

Falls Ihr Board invertierte LED-Logik verwendet, kann die Definition `LED_WHITE` im Kopf der Datei angepasst werden (z. B. auf `0x00`, wenn Low = LED an bedeutet).

## Häufige Fragen

### „Was laden und speichern wir da ganz am Anfang?“

- **Adresse laden:** Instruktionen wie `ldr r0, =GPIO_PORT_F_DEN_R` holen die absolute Adresse eines Registers in ein CPU-Register. So können wir später mit `[r0]` darauf zugreifen.
- **Register lesen/schreiben:** Mit `ldr r1, [r0]` lesen wir den aktuellen Inhalt eines Hardware-Registers, bearbeiten ihn lokal (z. B. `orr` oder `bic`) und schreiben ihn mit `str r1, [r0]` wieder zurück – immer nur die benötigten Bits werden verändert.
- **Konstanten puffern:** In `preload_runtime_constants` sichern wir häufig verwendete Werte (Datenregister, Masken, aktueller Bit-Status) in Register, damit die Endlosschleife ohne erneutes Laden auskommt.

Diese Technik ist typisch für embedded Assembly: Man vermeidet unmittelbare Literalkonstanten innerhalb der Schleife und arbeitet stattdessen mit bereits vorbereiteten Registern.

## Ausführen & Debuggen

1. Projekt kompilieren und auf das Launchpad flashen (z. B. mit PlatformIO „Upload“).
2. Im Debugger die Speicheradressen `rotating_bit_snapshot` und `led_state_snapshot` beobachten, um den aktuellen Wert von `r7` und den letzten LED-Schreibwert zu sehen.
3. Optional Breakpoints auf `handle_btn_not_pressed` bzw. `handle_btn_pressed` setzen, um die Status-Flags im Registersatz zu analysieren.

### Anpassung der Verzögerung

Ändern Sie bei Bedarf `DELAY_COUNT` am Kopf der Datei, falls Ihr Launchpad mit einem anderen Takt läuft oder Sie eine kürzere/langsamere LED-Animation wünschen.