# Ejemplos de código Verilog

Módulos pequeños, comentados y probados, que muestran técnicas útiles para el Laboratorio 5. Cada uno tiene su testbench.

Ninguno es la solución de una parte del laboratorio: son piezas para estudiar, adaptar o reutilizar. Si el grupo usa uno de estos módulos, debe explicarlo en la bitácora como cualquier otro código de su diseño.

| Archivo | Qué muestra | Dónde puede servir |
|---|---|---|
| [`base_tiempo.v`](base_tiempo.v) | Pulso de un ciclo cada *N* milisegundos, calculado a partir de `CLK_FREQ` | Contador de segundos, periodo de refresco |
| [`sincronizador.v`](sincronizador.v) | Sincronizador de dos flip-flops con ancho configurable | Interruptores DIP |
| [`bin6_a_bcd.v`](bin6_a_bcd.v) | *Double dabble* combinacional: 6 bits (0 a 63) a dos dígitos BCD | Conversión de binario a decimal |
| [`bin6_a_bcd_sec.v`](bin6_a_bcd_sec.v) | *Double dabble* secuencial, una iteración por ciclo, con *handshake* `iniciar` / `listo` | Alternativa de conversión; ejemplo de unidad de control y ruta de datos |
| [`funciones_lcd.v`](funciones_lcd.v) | Funciones: dirección de la DDRAM, dígito a ASCII, hexadecimal a ASCII, carácter de un texto | Armar los bytes que se envían a la LCD |
| [`tb_revisar_pantalla.v`](tb_revisar_pantalla.v) | Testbench que revisa un campo de la pantalla (fila, columna y número de caracteres) con el modelo de la LCD | Testbench de la Parte 2 |

El documento de [fundamentos](../Fundamentos.md) explica la teoría detrás de cada ejemplo.

---

## Cómo simular

Desde la carpeta del laboratorio (la que contiene `src`, `test` y `ejemplos`):

```
iverilog -o sim_bt.vvp ejemplos/tb_base_tiempo.v ejemplos/base_tiempo.v
vvp sim_bt.vvp

iverilog -o sim_bcd.vvp ejemplos/tb_bin6_a_bcd.v ejemplos/bin6_a_bcd.v
vvp sim_bcd.vvp

iverilog -o sim_bcd_sec.vvp ejemplos/tb_bin6_a_bcd_sec.v ejemplos/bin6_a_bcd_sec.v
vvp sim_bcd_sec.vvp
gtkwave tb_bin6_a_bcd_sec.vcd

iverilog -o sim_fun.vvp ejemplos/tb_funciones_lcd.v ejemplos/funciones_lcd.v
vvp sim_fun.vvp

iverilog -o sim_rev.vvp ejemplos/tb_revisar_pantalla.v test/modelo_lcd.v src/lcd_ctrl.v src/lcd_escritura.v
vvp sim_rev.vvp
```

Cada testbench imprime sus resultados y termina con el número de errores. `tb_revisar_pantalla.v` incluye a propósito una comparación que falla, para mostrar cómo se ve un error.

---

## `base_tiempo.v`

Genera un pulso de un ciclo (`tick`) cada `PERIODO_MS` milisegundos. Ejemplo de instancia para un pulso por segundo:

```verilog
wire tick_1s;

base_tiempo #(.CLK_FREQ(CLK_FREQ), .PERIODO_MS(1000)) u_1s (
    .clk(clk), .rst(rst), .tick(tick_1s)
);
```

`tick_1s` se usa como **habilitación**, nunca como reloj. Cualquier registro que deba cambiar una vez por segundo sigue usando `clk` y solo cambia cuando `tick_1s` vale 1:

```verilog
always @(posedge clk)
    if (rst)          ...
    else if (tick_1s) ...      // cambia una vez por segundo
```

Un `always @(posedge tick_1s)` crearía un segundo dominio de reloj generado por lógica, con retardos que el sintetizador no controla.

**En simulación.** `tb_base_tiempo.v` usa un reloj de 10 kHz para que el periodo sea de pocos ciclos. Esto sirve para probar módulos aislados. Cuando el testbench incluye el modelo de la LCD, `CLK_FREQ` debe coincidir con el reloj del testbench (50 MHz), porque el modelo revisa tiempos reales (ver [fundamentos, sección 12](../Fundamentos.md#12-simulación-con-el-modelo-de-la-pantalla)); para acortar la simulación se reduce el periodo (`PERIODO_MS`), no la frecuencia.

---

## `sincronizador.v`

```verilog
wire [7:0] sw_sinc;

sincronizador #(.ANCHO(8)) u_sinc (
    .clk(clk), .d_async(sw_n), .q_sync(sw_sinc)
);
```

La salida tiene la misma polaridad que la entrada: si las entradas son activas en bajo, la salida también lo es. La inversión puede hacerse antes o después del sincronizador.

---

## `bin6_a_bcd.v` y `bin6_a_bcd_sec.v`

Las dos versiones implementan el mismo algoritmo (*double dabble*) para números de 6 bits. El registro de trabajo tiene un grupo de 4 bits por cada dígito BCD y, a la derecha, el número binario:

```
   13     10 9       6 5            0
  +---------+---------+--------------+
  | decenas | unidades|   binario    |
  +---------+---------+--------------+
```

En cada iteración se corrigen los dígitos (se suma 3 a los que valen 5 o más) y luego se desplaza todo el registro un bit a la izquierda. Hay una iteración por cada bit del número.

Para usar el algoritmo con otro número de bits, conviene responder primero estas preguntas y comprobar las respuestas haciendo la conversión a mano para un valor:

1. ¿Cuál es el mayor valor que puede tomar el número? ¿Cuántos dígitos decimales tiene?
2. ¿Cuántos bits necesita el registro de trabajo?
3. ¿Cuántas iteraciones se hacen?
4. ¿Qué grupos de 4 bits se corrigen en cada iteración?

**Versión combinacional.** Dentro de `always @(*)` se usan asignaciones bloqueantes (`=`): cada línea usa el resultado de la anterior, como en un programa. El `for` tiene límites fijos y el sintetizador lo desenrolla en etapas de lógica; `r` no es un registro (no hay flip-flops), sino el nombre de las señales intermedias entre etapas.

**Versión secuencial.** Hace una iteración por ciclo de reloj y avisa con `listo`. Es un ejemplo completo y pequeño de unidad de control (estados `REPOSO` y `CONVERTIR`) y ruta de datos (registro `r` y contador `paso`), con el mismo *handshake* que usan `lcd_ctrl` y `lcd_escritura`. Su diagrama de estados está en los [fundamentos, sección 9](../Fundamentos.md#9-máquinas-de-estados-en-verilog).

En una síntesis de prueba con tablas de búsqueda (LUT) de 4 entradas, como las de los elementos lógicos de la Cyclone IV, la versión combinacional de 6 bits ocupa 9 LUT y la secuencial 20 LUT y 19 flip-flops: para números pequeños la combinacional es más económica. El grupo puede comparar sus propias versiones en Quartus (*Compilation Report → Flow Summary*).

---

## `funciones_lcd.v`

| Función | Resultado | Ejemplo |
|---|---|---|
| `dir_ddram(fila, columna)` | Instrucción Set DDRAM Address | `dir_ddram(1, 5)` = 0xC5 |
| `ascii_digito(d)` | Carácter `'0'` a `'9'` | `ascii_digito(4)` = 0x34 |
| `ascii_hex(h)` | Carácter `'0'` a `'9'` o `'A'` a `'F'` | `ascii_hex(4'hA)` = 0x41 |
| `ascii_bit(b)` | Carácter `'0'` o `'1'` | `ascii_bit(1)` = 0x31 |
| `caracter(texto, c)` | Carácter número *c* de un texto de 16 caracteres | `caracter("Hola, FPGA 2026!", 6)` = `'F'` |

Una función de Verilog pertenece al módulo donde se declara: se copia dentro del módulo que la usa. Por ejemplo, en la lógica que elige el byte que se envía:

```verilog
always @(*) begin
    dato_sel = 8'h00;
    case (estado)
        ...
        POSICION_X: dato_sel = dir_ddram(1'b1, 4'd5);       // fila 2, columna 5
        DIGITO_X:   dato_sel = ascii_digito(digito_actual);
        ...
    endcase
end
```

---

## `tb_revisar_pantalla.v`

Muestra tres técnicas para el testbench de la Parte 2:

1. **Esperar escrituras en lugar de un estado.** Un controlador con lazo de refresco nunca llega a un estado final. El testbench puede esperar a que el modelo haya recibido un número de bytes (`wait (lcd.escrituras == N)`) o un tiempo fijo. Para escoger *N*, hay que contar cuántas escrituras hace la inicialización y cuántas cada refresco.
2. **Leer la pantalla del modelo** con `lcd.caracter(fila, columna)`; filas y columnas empiezan en 0.
3. **Comparar un campo** con la tarea `revisar_texto(fila, columna, "texto", n)`. Un texto entre comillas más corto que el vector que lo recibe se completa con ceros a la izquierda, así que basta comparar los 8·*n* bits menos significativos.

Al probar varios valores de entrada, después de cambiarlos hay que esperar al menos un periodo de refresco completo antes de revisar la pantalla.
