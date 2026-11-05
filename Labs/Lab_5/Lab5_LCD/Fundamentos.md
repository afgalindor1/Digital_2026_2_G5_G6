# Laboratorio 5 – Fundamentos básicos

Este documento resume la teoría básica que se necesita para el laboratorio. Cada tema explica los **términos más importantes** y muestra un **código genérico en Verilog** de cómo se hace. Los códigos son fragmentos cortos para entender la técnica, no archivos para copiar tal cual.

| Parte | Temas más útiles |
|---|---|
| Parte 1: entender el código base | 1 a 5 y 9 |
| Parte 2: mostrar valores que cambian | 2, 4, 6, 7, 8 y 9 |

---

## Contenido

1. [La LCD vista desde la FPGA](#1-la-lcd-vista-desde-la-fpga)
2. [Medir tiempo con un contador](#2-medir-tiempo-con-un-contador)
3. [Máquinas de estados](#3-máquinas-de-estados)
4. [Unidad de control, ruta de datos y *handshake*](#4-unidad-de-control-ruta-de-datos-y-handshake)
5. [Textos en Verilog](#5-textos-en-verilog)
6. [Ubicar el cursor](#6-ubicar-el-cursor)
7. [Del número a los caracteres](#7-del-número-a-los-caracteres)
8. [Leer los interruptores](#8-leer-los-interruptores)
9. [Simular con el modelo de la LCD](#9-simular-con-el-modelo-de-la-lcd)
10. [Problemas frecuentes en la tarjeta](#10-problemas-frecuentes-en-la-tarjeta)

---

## 1. La LCD vista desde la FPGA

**Términos clave**

- **Instrucción:** byte que le da una orden a la LCD (borrar, encender, ubicar el cursor). Se envía con `RS = 0`.
- **Dato:** byte con el código del carácter que se va a mostrar. Se envía con `RS = 1`.
- **E (*Enable*):** señal que indica a la LCD cuándo leer el bus. La LCD captura el byte en el **flanco de bajada** de E (cuando E pasa de 1 a 0).
- **Tiempo de ejecución:** lo que tarda la LCD en procesar un byte: 39 µs a 43 µs, o 1,53 ms para Clear Display. Durante ese tiempo ignora cualquier byte nuevo.
- **Inicialización:** secuencia de instrucciones que deja la LCD lista para escribir después de encenderla (Parte 1, sección 2.6).

Para enviar un byte, la FPGA pone `RS` y el byte en el bus, sube E, baja E y espera el tiempo de ejecución. `R/W` vale siempre 0, porque la LCD solo se escribe.

<p align="center">
 <img src="figs/ciclo_escritura.png" alt="Ciclo de escritura" width=750 >
</p>
<p align="center">
 Figura 1: Ciclo de escritura de un byte
</p>

Por ejemplo, para escribir `A` al comienzo de la fila 2 se envían dos bytes:

| Byte | RS | Significado |
|---|---|---|
| 0xC0 | 0 | Instrucción: ubicar el cursor en la fila 2, columna 0 (tema 6) |
| 0x41 | 1 | Carácter `A` |

**En el laboratorio:** `lcd_escritura.v` envía un byte; `lcd_ctrl.v` decide qué bytes enviar y en qué orden.

---

## 2. Medir tiempo con un contador

**Términos clave**

- **Ciclo de reloj:** con un reloj de 50 MHz, cada ciclo dura 20 ns. Un intervalo *t* equivale a *N* = *t* · *f*<sub>clk</sub> ciclos: 1 µs son 50 ciclos, 1 ms son 50 000 y 1 s son 50 000 000.
- **`localparam`:** constante calculada al sintetizar. No genera hardware; si cambia la frecuencia del reloj, se recalcula sola.
- **`$clog2(N)`:** número de bits que necesita un contador para contar de 0 a *N* – 1.
- **Habilitación (*tick*):** pulso de un ciclo que indica "ahora". Se usa con `if (tick)` dentro de un bloque con `clk`, **nunca como reloj**.

**Cómo se hace en Verilog:** un contador que da un pulso cada `PERIODO_MS` milisegundos.

```verilog
localparam N = (CLK_FREQ / 1000) * PERIODO_MS;   // ciclos por periodo
localparam W = $clog2(N);                        // bits del contador

reg [W-1:0] cuenta;
reg         tick;

always @(posedge clk)
    if (rst) begin
        cuenta <= 0;
        tick   <= 1'b0;
    end else if (cuenta == N - 1) begin          // llegó al final del periodo
        cuenta <= 0;
        tick   <= 1'b1;                          // pulso de un ciclo
    end else begin
        cuenta <= cuenta + 1'b1;
        tick   <= 1'b0;
    end

// Uso del pulso como habilitación: un contador de segundos (con PERIODO_MS = 1000)
always @(posedge clk)
    if (rst)       segundos <= 0;
    else if (tick) segundos <= segundos + 1'b1;
```

**En el laboratorio:** así se miden los tiempos de cada byte y la espera de encendido. En la Parte 2 sirve para el contador del valor B y para el periodo de refresco.

---

## 3. Máquinas de estados

**Términos clave**

- **Estado:** cada paso de una secuencia. La máquina está en un solo estado a la vez.
- **Transición:** paso de un estado a otro cuando se cumple una **condición**.
- **Máquina de Moore:** las salidas dependen solo del estado actual.
- **Registro de estado:** los flip-flops que guardan el estado actual.
- **Lógica de siguiente estado:** lógica combinacional que decide el próximo estado según el estado actual y las entradas.
- **Lógica de salida:** decide el valor de las salidas en cada estado.
- **Diagrama de estados:** círculos (estados) y flechas (transiciones) con su condición.
- **Tabla de transiciones:** la misma información que el diagrama, en forma de tabla.

**Cómo se hace en Verilog:** tres bloques, uno por cada parte. El ejemplo es un LED que está encendido un tiempo y apagado otro.

```verilog
localparam ENCENDIDO = 1'b0,
           APAGADO   = 1'b1;

reg estado, siguiente;

// 1. Registro de estado
always @(posedge clk)
    if (rst) estado <= ENCENDIDO;              // estado inicial
    else     estado <= siguiente;

// 2. Lógica de siguiente estado
always @(*) begin
    siguiente = estado;                        // por defecto, quedarse
    case (estado)
        ENCENDIDO: if (fin_on)  siguiente = APAGADO;
        APAGADO:   if (fin_off) siguiente = ENCENDIDO;
        default:                siguiente = ENCENDIDO;
    endcase
end

// Contador de tiempo: vuelve a cero cada vez que cambia el estado
always @(posedge clk)
    if (rst || estado != siguiente) cuenta <= 0;
    else                            cuenta <= cuenta + 1'b1;

assign fin_on  = (cuenta == N_ON  - 1);        // condiciones de salida de cada estado
assign fin_off = (cuenta == N_OFF - 1);

// 3. Lógica de salida (registrada)
always @(posedge clk)
    if (rst) led <= 1'b0;
    else     led <= (siguiente == ENCENDIDO);
```

- En los bloques con `posedge clk` se usa `<=`; en `always @(*)` se usa `=`.
- `siguiente = estado;` al comienzo del bloque evita olvidar casos: si no se cumple ninguna condición, la máquina se queda en el mismo estado.
- **Estados con duración:** un solo contador mide el tiempo de todos los estados, porque vuelve a 0 cada vez que la máquina cambia de estado.
- **Salida registrada:** la salida sale de un flip-flop, sin pulsos espurios. Usar `siguiente` en lugar de `estado` evita que cambie un ciclo tarde.

**Del código al diagrama:**

1. Los **estados** son las constantes `localparam` del registro de estado.
2. Cada `if` del bloque de siguiente estado es una **flecha**, y su condición es la etiqueta.
3. `siguiente = estado;` es la flecha que vuelve al mismo estado cuando la condición no se cumple.
4. El **estado inicial** es el que se asigna en el reset.

<p align="center">
 <img src="figs/fsm_parpadeo.png" alt="Diagrama de estados" width=650 >
</p>
<p align="center">
 Figura 2: Diagrama de estados del código anterior
</p>

| Estado actual | Condición | Siguiente estado | Salida |
|---|---|---|---|
| ENCENDIDO | `fin_on = 0` | ENCENDIDO | `led = 1` |
| ENCENDIDO | `fin_on = 1` | APAGADO | `led = 1` |
| APAGADO | `fin_off = 0` | APAGADO | `led = 0` |
| APAGADO | `fin_off = 1` | ENCENDIDO | `led = 0` |

**Errores frecuentes:**

- Una señal que no recibe valor en todos los casos de un `always @(*)` crea un *latch* (Quartus avisa: *inferring latch(es)*).
- Asignar la misma señal en dos bloques `always` es un error (*multiple constant drivers*).
- Usar una señal como reloj (`always @(posedge tick)`) causa problemas en la tarjeta.

**En el laboratorio:** `lcd_escritura.v` y `lcd_ctrl.v` usan esta misma estructura.

---

## 4. Unidad de control, ruta de datos y *handshake*

**Términos clave**

- **Ruta de datos:** registros, contadores, memorias y multiplexores que guardan y transforman los datos.
- **Unidad de control:** la máquina de estados que decide qué hace la ruta de datos en cada momento.
- **Señal de control:** de la unidad de control a la ruta de datos (por ejemplo, "incrementa el contador").
- **Señal de estado:** de la ruta de datos a la unidad de control (por ejemplo, "el contador llegó a 15").
- **Maestro y trabajador:** cuando una tarea se repite muchas veces, se pone en un módulo propio (trabajador) que sabe **cómo** hacerla; otro módulo (maestro) decide **qué** hacer y cuándo.
- ***Handshake*:** acuerdo de comunicación entre el maestro y el trabajador con dos señales:
    - **`iniciar`** (maestro → trabajador): pulso de un ciclo que pide la tarea. Los datos de la tarea deben estar listos en ese mismo ciclo.
    - **`listo`** (trabajador → maestro): pulso de un ciclo que avisa que la tarea terminó.

<p align="center">
 <img src="figs/handshake.png" alt="Handshake iniciar listo" width=750 >
</p>
<p align="center">
 Figura 3: Handshake entre un maestro y un trabajador
</p>

**Cómo se hace en Verilog:**

```verilog
// ---------------- Trabajador: espera la orden, hace la tarea y avisa
always @(*) begin
    siguiente = estado;
    case (estado)
        REPOSO:  if (iniciar)   siguiente = OCUPADO;
        OCUPADO: if (fin_tarea) siguiente = REPOSO;
        default:                siguiente = REPOSO;
    endcase
end

always @(posedge clk)                            // guarda el dato al recibir la orden
    if (estado == REPOSO && iniciar) dato_guardado <= dato;

always @(posedge clk)                            // pulso de un ciclo al terminar
    if (rst) listo <= 1'b0;
    else     listo <= (estado == OCUPADO) && fin_tarea;


// ---------------- Maestro: avanza de paso cada vez que el trabajador termina
always @(*) begin
    siguiente = estado;
    case (estado)
        PASO_A:  if (listo) siguiente = PASO_B;
        PASO_B:  if (listo) siguiente = PASO_C;
        PASO_C:  if (listo) siguiente = FIN;
        default:            siguiente = estado;
    endcase
end

always @(*)                                      // dato de la tarea según el paso (multiplexor)
    case (estado)
        PASO_A:  dato = VALOR_A;
        PASO_B:  dato = VALOR_B;
        default: dato = VALOR_C;
    endcase

always @(posedge clk) en_reset <= rst;           // vale 1 en el primer ciclo después del reset

always @(posedge clk)                            // primera orden al salir del reset y
    if (rst) iniciar <= 1'b0;                    // una nueva un ciclo después de cada listo
    else     iniciar <= en_reset || (listo && siguiente != FIN);
```

- El maestro no sabe cómo se hace la tarea; el trabajador no sabe qué paso de la secuencia se está ejecutando.
- `iniciar` sube un ciclo después de `listo`. En ese ciclo el estado del maestro ya cambió, así que `dato` ya corresponde al nuevo paso.
- Un estado del maestro que no deba pedir tareas (como `FIN`, o un estado de espera) se excluye de la lógica de `iniciar`.

**En el laboratorio:** `lcd_ctrl.v` es el maestro y `lcd_escritura.v` el trabajador; el dato de la tarea es el byte y `RS`. En la Parte 2, los estados nuevos piden bytes de la misma forma.

---

## 5. Textos en Verilog

**Términos clave**

- **Código ASCII:** número de 8 bits que representa un carácter. En la LCD, letras, cifras y signos comunes usan los códigos ASCII (`A` = 0x41, `0` = 0x30, espacio = 0x20).
- **Cadena:** texto entre comillas. Verilog la guarda como un vector de 8 bits por carácter, con el **primer carácter en los bits más significativos**.
- **Selección indexada (`+:`):** toma un grupo de bits a partir de una posición que puede ser una señal.

**Cómo se hace en Verilog:**

```verilog
localparam [8*16-1:0] TEXTO = "Hola mundo      ";   // exactamente 16 caracteres
// TEXTO[127:120] = "H" = 8'h48   (primer carácter)
// TEXTO[7:0]     = " " = 8'h20   (último carácter)

// Carácter número c (0 = el de la izquierda)
function [7:0] caracter(input [8*16-1:0] texto, input [3:0] c);
    caracter = texto[8*(15 - c) +: 8];               // 8 bits desde el bit 8*(15-c)
endfunction
```

**Cuidado:** si la cadena tiene menos caracteres que el vector, Verilog completa con ceros a la izquierda, y el código 0x00 no es un espacio en la LCD (muestra un carácter con cualquier dibujo). Por eso los textos tienen exactamente 16 caracteres, completando con espacios.

**En el laboratorio:** `lcd_ctrl.v` usa esta función con el contador `col` para enviar los 16 caracteres de cada fila.

---

## 6. Ubicar el cursor

**Términos clave**

- **DDRAM:** memoria de la LCD donde se guarda el código de cada carácter que se ve. Cada posición de la pantalla tiene una dirección: la fila 1 va de 0x00 a 0x0F y la fila 2 de 0x40 a 0x4F.
- **Contador de direcciones (AC):** indica dónde se guarda el siguiente carácter. Avanza solo después de cada carácter.
- **Set DDRAM Address:** instrucción que mueve el cursor. Es un 1 en el bit 7 seguido de la dirección: instrucción = 0x80 + dirección.

| Posición | Dirección | Instrucción | Binario |
|---|---|---|---|
| Fila 1, columna 9 | 0x09 | 0x89 | `1000 1001` |
| Fila 2, columna 5 | 0x45 | 0xC5 | `1100 0101` |

**Cómo se hace en Verilog:**

```verilog
// fila: 0 = superior, 1 = inferior; columna: 0 a 15
function [7:0] dir_ddram(input fila, input [3:0] columna);
    dir_ddram = {1'b1, fila, 2'b00, columna};        // 1 | fila | 00 | columna
endfunction

// dir_ddram(1'b1, 4'd5) = 8'b1100_0101 = 8'hC5
```

Las llaves `{ }` concatenan los campos: el bit 7 en 1, la fila en el bit 6, dos ceros y la columna en los bits 3 a 0.

**Cuidado:** si se escriben más de 16 caracteres seguidos, los sobrantes **no** pasan a la fila 2: quedan en posiciones de la DDRAM que no se ven. Para escribir en la fila 2 siempre se ubica el cursor primero.

<p align="center">
 <img src="figs/ddram_ventana.png" alt="Ventana visible de la DDRAM" width=800 >
</p>
<p align="center">
 Figura 4: Cada fila de la DDRAM tiene 40 posiciones, pero solo se ven las primeras 16
</p>

**En el laboratorio:** `lcd_ctrl.v` envía 0x80 y 0xC0 antes de cada fila. En la Parte 2 se usa para ir a la posición de cada valor.

---

## 7. Del número a los caracteres

**Términos clave**

- **Cifra a carácter:** en la LCD las cifras `0` a `9` tienen los códigos 0x30 a 0x39, es decir, código = 0x30 + cifra.
- **Nibble:** grupo de 4 bits. Un número de 8 bits tiene dos: `num[7:4]` y `num[3:0]`. Cada nibble es una cifra hexadecimal (0 a F).
- **BCD (*Binary-Coded Decimal*):** cada cifra decimal guardada en 4 bits. Por ejemplo, 243 en BCD es `0010 0100 0011`.
- ***Double dabble*:** algoritmo para pasar de binario a BCD con desplazamientos y sumas de 3 (Parte 2, sección 2.2).

**Cómo se hace en Verilog: hexadecimal** (2 caracteres por número de 8 bits).

```verilog
// Nibble (0 a 15) -> carácter '0'-'9' o 'A'-'F'
function [7:0] ascii_hex(input [3:0] h);
    ascii_hex = (h < 4'd10) ? 8'h30 + h      // '0' a '9'
                            : 8'h37 + h;     // 'A' a 'F': 'A' = 0x41 = 0x37 + 10
endfunction

// Ejemplo: num = 8'hB7
// ascii_hex(num[7:4]) = 8'h42 ('B')    ascii_hex(num[3:0]) = 8'h37 ('7')
```

**Cómo se hace en Verilog: decimal.** Primero se convierte a BCD y luego cada cifra se convierte en carácter. Este código aplica el *double dabble* a un número de 6 bits (0 a 63, dos cifras):

```verilog
integer i;
reg [13:0] r;              // [13:10] decenas | [9:6] unidades | [5:0] número binario

always @(*) begin
    r = {8'd0, bin};                                     // cifras en cero, número a la derecha
    for (i = 0; i < 6; i = i + 1) begin                  // una vez por cada bit
        if (r[9:6]   >= 4'd5) r[9:6]   = r[9:6]   + 4'd3;    // corregir unidades
        if (r[13:10] >= 4'd5) r[13:10] = r[13:10] + 4'd3;    // corregir decenas
        r = r << 1;                                      // desplazar
    end
    decenas  = r[13:10];
    unidades = r[9:6];
end

// Cifra -> carácter
assign car_decenas  = 8'h30 + decenas;
assign car_unidades = 8'h30 + unidades;
```

- El `for` tiene límites fijos: el sintetizador lo convierte en 6 etapas de lógica. No es un lazo que se ejecute en el tiempo.
- Para 8 bits hay que ajustar: cuántas cifras tiene el mayor valor (255), cuántos bits ocupa el registro, cuántas veces se repite el lazo y qué cifras se corrigen.

**En el laboratorio:** en la Parte 2, según el formato que escoja el grupo.

---

## 8. Leer los interruptores

**Términos clave**

- **Activo en bajo:** el interruptor vale 0 cuando está encendido. Para trabajar con encendido = 1 se invierte con `~`.
- **Señal asíncrona:** puede cambiar en cualquier momento respecto al reloj, como un interruptor.
- **Metaestabilidad:** si una entrada cambia justo en el flanco de reloj, el flip-flop puede quedar un instante en un valor indefinido.
- **Sincronizador:** dos flip-flops en serie; el segundo entrega un valor estable.
- **Muestreo:** copiar un valor en un registro en un momento elegido, para usar esa copia mientras el original cambia.

**Cómo se hace en Verilog:**

```verilog
// Inversión y sincronizador de dos flip-flops
reg [7:0] sw_s1, sw_s2;
always @(posedge clk) begin
    sw_s1 <= ~sw_n;          // primer flip-flop (puede quedar indefinido un instante)
    sw_s2 <= sw_s1;          // segundo flip-flop: valor estable, encendido = 1
end

// Muestreo: copiar el valor antes de escribir sus cifras
always @(posedge clk)
    if (rst)            copia <= 8'd0;
    else if (muestrear) copia <= sw_s2;     // muestrear: pulso de un ciclo
```

<p align="center">
 <img src="figs/sincronizador.png" alt="Sincronizador" width=650 >
</p>
<p align="center">
 Figura 5: Sincronizador de dos flip-flops
</p>

¿Por qué muestrear? Escribir las cifras de un número toma varias escrituras. Si el número cambia en medio, la pantalla puede mostrar una mezcla: si un contador pasa de 59 a 60 justo después de escribir las decenas, se ve `50`.

**En el laboratorio:** en la Parte 2, para el valor A (interruptores) y el valor B.

---

## 9. Simular con el modelo de la LCD

**Términos clave**

- **Testbench:** módulo de simulación que genera las entradas del diseño y revisa sus salidas. No se sintetiza.
- **Modelo de comportamiento:** código que imita a un dispositivo real. [`test/modelo_lcd.v`](test/modelo_lcd.v) se comporta como la LCD: captura cada byte en el flanco de bajada de E, guarda los caracteres, revisa los tiempos de la hoja de datos e imprime la pantalla en la consola.
- **Nombre jerárquico:** acceso desde el testbench a algo interno de otro módulo, con un punto: `lcd.caracter(...)`, `dut.estado`.
- **VCD:** archivo con las formas de onda que se abre en GTKWave.

Desde el testbench se puede consultar el modelo (instancia `lcd`):

| Elemento | Uso |
|---|---|
| `lcd.caracter(fila, columna)` | Código del carácter en esa posición (filas y columnas desde 0) |
| `lcd.imprimir_pantalla` | Muestra la pantalla en la consola |
| `lcd.errores` | Número de errores de tiempo o de protocolo |
| `lcd.escrituras` | Número de bytes recibidos |

**Cómo se hace en Verilog:** un testbench que cambia los valores de entrada y revisa una parte de la pantalla.

```verilog
// Compara n caracteres de la pantalla, desde (fila, columna), con un texto
task revisar_texto(input integer fila, input integer columna,
                   input [8*16-1:0] esperado, input integer n);
    integer k;
    reg [8*16-1:0] visto;
    begin
        visto = 0;
        for (k = 0; k < n; k = k + 1)
            visto[8*(n-1-k) +: 8] = lcd.caracter(fila, columna + k);
        if (visto === esperado) $display("OK     fila %0d: %0s", fila + 1, visto);
        else                    $display("FALLO  fila %0d: se esperaba %0s y se ve %0s",
                                         fila + 1, esperado, visto);
    end
endtask

initial begin
    #200 rst = 1'b0;
    wait (lcd.escrituras == 39);            // inicialización y texto: 5 + 2 + 32 bytes
    num_a = 8'hB7;                          // nuevo valor de entrada
    #5_000_000;                             // esperar al menos un refresco (5 ms)
    lcd.imprimir_pantalla;
    revisar_texto(0, 14, "B7", 2);          // fila 1, columnas 14 y 15
    $finish;
end
```

- `"B7"` tiene menos de 16 caracteres, así que Verilog lo completa con ceros a la izquierda; `visto` también empieza en ceros, y la comparación funciona.
- `wait (lcd.escrituras == ...)` sirve aunque la máquina nunca llegue a un estado final, como en el lazo de refresco de la Parte 2.
- Las posiciones, el formato y los tiempos del ejemplo dependen del diseño de cada grupo.

**Mensajes del modelo:**

| Mensaje | Qué revisar |
|---|---|
| `escritura antes de 40 ms desde el encendido` | La espera de encendido |
| `escritura mientras la instruccion anterior se ejecuta` | La espera después de cada byte |
| `pulso E de ... ns` | El ancho del pulso de E |
| `RS o dato indefinidos (x/z)` | Señales sin reset o sin conectar |
| `Function Set en modo 4 bits` | El comando Function Set |

**Velocidad de la simulación:** el modelo revisa tiempos reales, así que `CLK_FREQ` debe ser 50 MHz, igual que el reloj del testbench. Lo que sí se reduce es el periodo de refresco de la Parte 2: con 100 ms, probar varios valores tomaría mucho tiempo de simulación.

**En GTKWave:** mostrar `lcd_data` en hexadecimal y `estado` en decimal (clic derecho sobre la señal → *Data Format*). Como un pulso de E dura 1 µs y la simulación decenas de milisegundos, hay que ampliar bastante (*zoom*) para ver un byte.

---

## 10. Problemas frecuentes en la tarjeta

| Lo que se ve | Causa probable | Qué revisar |
|---|---|---|
| Nada, ni bloques | Alimentación o contraste | Selector de alimentación de la LCD, potenciómetro de contraste, orientación del conector |
| Fila 1 con 16 bloques, fila 2 vacía | La LCD no se inicializó | Reset (¿queda activo todo el tiempo?), asignación de pines, pin 101 (nCEO), reloj |
| Caracteres equivocados | Bits del bus en desorden | Asignación de `lcd_data[7:0]` en el Pin Planner |
| Caracteres extraños al comienzo de una fila | Texto de menos de 16 caracteres | Longitud de los textos (tema 5) |
| La fila 2 no aparece | Falta ubicar el cursor | Instrucción Set DDRAM Address (tema 6) |
| La pantalla parpadea al actualizar | Se usa Clear Display en cada actualización | Actualizar solo los caracteres que cambian |
| Funciona en simulación pero no en la tarjeta | Diferencias entre testbench y tarjeta | `CLK_FREQ`, polaridad del reset, pines, pin 101, archivo `.sof` programado |

---

## Referencias

1. Hoja de datos de la LCD 16x2 ([en esta carpeta](lcd016n002bcfhet.pdf)): instrucciones (sección 11), tiempos (sección 12), inicialización (sección 13) y tabla de caracteres (sección 10).
2. D. M. Harris y S. L. Harris, *Digital Design and Computer Architecture*: máquinas de estados y descripción en HDL.
3. P. P. Chu, *FPGA Prototyping by Verilog Examples*: máquinas de estados con ruta de datos y conversión de binario a BCD.
