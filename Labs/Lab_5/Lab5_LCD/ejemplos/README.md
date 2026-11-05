# Ejemplos de código Verilog

Códigos cortos, comentados y probados, que muestran las técnicas que usa el laboratorio. Cada uno tiene su testbench. Los [fundamentos básicos](../Fundamentos.md) explican cada ejemplo paso a paso.

Ninguno es la solución de una parte del laboratorio: son piezas para estudiar, adaptar o reutilizar. Si el grupo usa uno de estos módulos, lo explica en la bitácora como parte de su diseño.

| Archivo | Qué muestra | Fundamentos | Relación con el laboratorio |
|---|---|---|---|
| [`base_tiempo.v`](base_tiempo.v) | Pulso de un ciclo cada *N* milisegundos | [Sección 2](../Fundamentos.md#2-medir-tiempo-con-un-contador) | Tiempos del código base; contador y refresco de la Parte 2 |
| [`parpadeo.v`](parpadeo.v) | Máquina de estados en tres bloques, con estados de duración fija | [Sección 3](../Fundamentos.md#3-máquinas-de-estados-en-verilog) | Misma estructura que `lcd_escritura.v` |
| [`semaforo.v`](semaforo.v) y [`espera.v`](espera.v) | Un maestro y un trabajador que se comunican con `iniciar` y `listo` | [Sección 4](../Fundamentos.md#4-dos-máquinas-que-trabajan-juntas-handshake) | Misma organización que `lcd_ctrl.v` y `lcd_escritura.v` |
| [`funciones_lcd.v`](funciones_lcd.v) | Funciones para extraer caracteres de un texto, ubicar el cursor y convertir cifras en caracteres | Secciones [5](../Fundamentos.md#5-textos-en-verilog), [6](../Fundamentos.md#6-ubicar-el-cursor) y [7](../Fundamentos.md#7-del-número-a-los-caracteres) | Texto del código base; valores de la Parte 2 |
| [`bin6_a_bcd.v`](bin6_a_bcd.v) | Conversión de 6 bits a dos cifras decimales (*double dabble*) | [Sección 7.3](../Fundamentos.md#73-un-número-en-decimal-3-caracteres) | Parte 2, si se escoge el formato decimal |
| [`sincronizador.v`](sincronizador.v) | Sincronizador de dos flip-flops | [Sección 8](../Fundamentos.md#8-leer-los-interruptores) | Interruptores de la Parte 2 |
| [`tb_revisar_pantalla.v`](tb_revisar_pantalla.v) | Testbench que revisa una parte de la pantalla con el modelo de la LCD | [Sección 9](../Fundamentos.md#9-simular-con-el-modelo-de-la-lcd) | Testbench de la Parte 2 |

---

## Cómo simular

Desde la carpeta del laboratorio (la que contiene `src`, `test` y `ejemplos`):

```
iverilog -o sim_bt.vvp ejemplos/tb_base_tiempo.v ejemplos/base_tiempo.v
vvp sim_bt.vvp

iverilog -o sim_parpadeo.vvp ejemplos/tb_parpadeo.v ejemplos/parpadeo.v
vvp sim_parpadeo.vvp
gtkwave tb_parpadeo.vcd

iverilog -o sim_semaforo.vvp ejemplos/tb_semaforo.v ejemplos/semaforo.v ejemplos/espera.v
vvp sim_semaforo.vvp
gtkwave tb_semaforo.vcd

iverilog -o sim_fun.vvp ejemplos/tb_funciones_lcd.v ejemplos/funciones_lcd.v
vvp sim_fun.vvp

iverilog -o sim_bcd.vvp ejemplos/tb_bin6_a_bcd.v ejemplos/bin6_a_bcd.v
vvp sim_bcd.vvp

iverilog -o sim_rev.vvp ejemplos/tb_revisar_pantalla.v test/modelo_lcd.v src/lcd_ctrl.v src/lcd_escritura.v
vvp sim_rev.vvp
```

Cada testbench imprime sus resultados y termina con el número de errores. `tb_revisar_pantalla.v` incluye a propósito una comparación que falla, para mostrar cómo se ve un error.

Los ejemplos sin LCD (`parpadeo`, `semaforo`, `base_tiempo`) se simulan con un reloj de 10 kHz para que los tiempos sean de pocos ciclos. Cuando el testbench incluye el modelo de la LCD, el reloj debe ser de 50 MHz, porque el modelo revisa tiempos reales.

---

## Probar en la tarjeta

`parpadeo.v` y `semaforo.v` también funcionan en la tarjeta: basta con conectar `clk` al reloj de 50 MHz, el reset a un pulsador (invertido, porque es activo en bajo) y las salidas a los LED de la tarjeta, según su manual. Es una forma rápida de ver funcionar una máquina de estados antes de trabajar con la LCD.
