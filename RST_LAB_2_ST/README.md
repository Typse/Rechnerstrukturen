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