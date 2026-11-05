# Laboratorio 5 – Parte 2: Texto dinámico en la LCD 16x2

**Semana 12**

---

## Contenido

1. Objetivos de aprendizaje  
2. Fundamento teórico  
   2.1 Texto dinámico y refresco de la pantalla  
   2.2 Representación decimal de un número binario  
   2.3 Algoritmo *double dabble* (desplazar y sumar 3)  
   2.4 Del dígito al carácter  
   2.5 Entradas externas y coherencia de los datos  
   2.6 Modificar una máquina de estados existente  
3. Especificación  
4. Pre-informe  
5. Implementación y criterios de validación  
6. Resultados y análisis  

---

## 1. Objetivos de aprendizaje

- Modificar una máquina de estados existente para agregar un nuevo comportamiento sin romper el anterior.
- Ubicar el cursor de la LCD en posiciones específicas con la instrucción Set DDRAM Address.
- Convertir un número binario de 8 bits a tres dígitos decimales (BCD) y estos a códigos ASCII.
- Integrar entradas externas (interruptores) y señales internas (un contador) en un sistema de visualización.

---

## 2. Fundamento teórico

Esta sección resume lo necesario para la Parte 2. El documento de [fundamentos](Fundamentos.md) (secciones 6 y 8 a 12) amplía cada tema, y la carpeta [`ejemplos`](ejemplos) contiene módulos de apoyo comentados y probados: base de tiempo, sincronizador, conversión a BCD de 6 bits (combinacional y secuencial), funciones para armar los bytes y un testbench que revisa un campo de la pantalla.

### 2.1 Texto dinámico y refresco de la pantalla

En la Parte 1 el controlador escribe el texto una sola vez y se detiene. La LCD conserva los caracteres en su DDRAM, así que el texto permanece en pantalla sin que la FPGA tenga que volver a enviarlo.

Para mostrar un valor que cambia no es necesario reescribir toda la pantalla. Basta con:

1. Ubicar el cursor en la primera posición del valor con **Set DDRAM Address** (Parte 1, secciones 2.4 y 2.7).
2. Escribir los caracteres del valor; el contador de direcciones avanza solo después de cada uno.
3. Repetir este proceso periódicamente: a esto se le llama **refrescar** la pantalla.

No se debe usar Clear Display para actualizar un valor. Esa instrucción borra toda la pantalla y tarda 1,53 ms, de modo que el texto desaparecería y volvería a aparecer en cada actualización (parpadeo).

¿Cada cuánto refrescar? La hoja de datos indica que el cristal líquido tarda entre 150 ms y 200 ms en cambiar de estado (sección 6, *Response Time*). Actualizar la pantalla mucho más rápido que eso no se percibe. En cambio, reescribir unos pocos caracteres toma menos de un milisegundo, así que un periodo de refresco del orden de 100 ms deja a la LCD libre casi todo el tiempo.

### 2.2 Representación decimal de un número binario

Un número de 8 bits puede valer de 0 a 255. Para mostrarlo en decimal, cada cifra debe enviarse a la LCD como un carácter distinto, así que primero hay que separar el número en sus tres cifras:

$$N = 100 \cdot C + 10 \cdot D + U$$

donde *C*, *D* y *U* son las centenas, las decenas y las unidades, cada una entre 0 y 9. Cuando cada cifra decimal se guarda en 4 bits, la representación se llama **BCD** (*Binary-Coded Decimal*). Por ejemplo, 243 en binario es `1111 0011`, y en BCD es `0010 0100 0011` (2, 4, 3).

Hay varias formas de hacer esta conversión en hardware:

| Método | Idea | Comentario |
|---|---|---|
| Tabla de búsqueda | Una tabla `case` con el resultado de cada valor de entrada | Sencillo para pocos bits (el ejemplo de clase convierte 4 bits con 16 casos); para 8 bits se necesitan 256 casos |
| Divisiones y restas | *C* = N / 100, *D* = (N mod 100) / 10, *U* = N mod 10 | Los operadores `/` y `%` producen divisores combinacionales grandes; también puede hacerse por restas sucesivas, de forma secuencial |
| *Double dabble* | Desplazar el número bit a bit hacia los dígitos BCD, corrigiendo cada dígito | Solo usa comparaciones, sumas de 3 y desplazamientos; es el método más usado en hardware |

### 2.3 Algoritmo *double dabble* (desplazar y sumar 3)

El algoritmo usa un registro con espacio para los tres dígitos BCD y el número binario, y repite 8 veces (una por cada bit) estos dos pasos:

1. **Corregir:** a cada dígito BCD que valga 5 o más se le suma 3.
2. **Desplazar:** todo el registro se desplaza un bit a la izquierda.

Al terminar, los tres dígitos BCD contienen el número en decimal.

**¿Por qué sumar 3?** Desplazar a la izquierda multiplica por 2. Si un dígito vale 5 o más, al duplicarse llegaría a 10 o más, que no es un dígito decimal válido: ese exceso debe pasar como acarreo al dígito siguiente. En binario, un grupo de 4 bits solo pasa acarreo al llegar a 16, no a 10. Sumar 3 antes de desplazar equivale a sumar 6 después de desplazar, y 6 es justamente la diferencia entre 16 y 10: así el acarreo aparece en el momento correcto.

Ejemplo con 243 (`1111 0011`):

| Paso | Operación | Centenas | Decenas | Unidades | Binario |
|---|---|---|---|---|---|
| 0 | Valor inicial | 0000 | 0000 | 0000 | 11110011 |
| 1 | Desplazar | 0000 | 0000 | 0001 | 11100110 |
| 2 | Desplazar | 0000 | 0000 | 0011 | 11001100 |
| 3 | Desplazar | 0000 | 0000 | 0111 | 10011000 |
| 4 | Sumar 3 a unidades | 0000 | 0000 | 1010 | 10011000 |
| 4 | Desplazar | 0000 | 0001 | 0101 | 00110000 |
| 5 | Sumar 3 a unidades | 0000 | 0001 | 1000 | 00110000 |
| 5 | Desplazar | 0000 | 0011 | 0000 | 01100000 |
| 6 | Desplazar | 0000 | 0110 | 0000 | 11000000 |
| 7 | Sumar 3 a decenas | 0000 | 1001 | 0000 | 11000000 |
| 7 | Desplazar | 0001 | 0010 | 0001 | 10000000 |
| 8 | Desplazar | **0010** | **0100** | **0011** | 00000000 |

Resultado: 2, 4, 3.

El algoritmo puede implementarse de dos formas:

- **Combinacional:** las 8 iteraciones se describen como 8 etapas de lógica (por ejemplo, con un `for` de límites fijos dentro de un bloque `always @(*)`, que el sintetizador desenrolla). El resultado está disponible en el mismo ciclo.
- **Secuencial:** una iteración por ciclo de reloj, con un registro de desplazamiento y un contador. Reutiliza la misma lógica de corrección en cada ciclo, lo que ahorra lógica cuando el número tiene muchos bits; a cambio, tarda varios ciclos y necesita una señal de "listo".

### 2.4 Del dígito al carácter

La LCD no recibe números, recibe códigos de caracteres. En la tabla de caracteres, los dígitos `0` a `9` tienen los códigos 0x30 a 0x39, así que:

$$\text{código} = \texttt{0x30} + d$$

En binario, 0x30 es `0011 0000`. Como *d* nunca pasa de 9 (`1001`), sumar 0x30 equivale a poner `0011` en los 4 bits altos y el dígito en los 4 bits bajos. Por ejemplo, el dígito 7 (`0111`) se envía como `0011 0111` = 0x37, el carácter `7`.

### 2.5 Entradas externas y coherencia de los datos

En esta parte la pantalla muestra dos valores: uno viene de interruptores físicos y otro de un contador interno. Esto plantea dos problemas:

- **Sincronización.** Los interruptores son señales asíncronas: pueden cambiar en cualquier momento respecto al reloj. Como en el Lab 4, deben pasar por un sincronizador de dos flip-flops antes de usarse.
- **Coherencia.** Escribir los tres dígitos de un número toma unos 150 µs. Si el número cambia en medio de esa escritura, la pantalla puede mostrar una mezcla del valor anterior y del nuevo: por ejemplo, si el contador pasa de 199 a 200 justo después de escribir las centenas, la pantalla muestra `100` hasta el siguiente refresco. La solución es **muestrear**: copiar los valores de entrada en registros al comenzar cada refresco y escribir los dígitos a partir de esas copias, que no cambian durante la escritura.

### 2.6 Modificar una máquina de estados existente

Agregar un comportamiento a una máquina de estados que ya funciona requiere el mismo método que diseñarla desde cero:

1. Definir las nuevas entradas y salidas.
2. Dividir el nuevo comportamiento en estados.
3. Actualizar el diagrama de estados: qué estados se agregan, cuáles cambian y por dónde se conecta el nuevo lazo con la secuencia anterior.
4. Actualizar la tabla de transiciones.
5. Modificar la descripción en HDL.
6. Simular, primero lo que ya funcionaba y luego lo nuevo.
7. Sintetizar e implementar.

Al modificar el código base se debe tener en cuenta cómo se genera la señal `iniciar`: cada estado nuevo que **no** deba escribir en la LCD (por ejemplo, un estado de espera) tiene que excluirse de esa lógica, igual que se excluye el estado `FIN`.

---

## 3. Especificación

### 3.1 Descripción general

El sistema debe mostrar dos números de 8 bits en decimal, junto a un texto fijo:

- **Valor A:** el número binario formado por los 8 interruptores DIP de la tarjeta.
- **Valor B:** un contador de segundos que va de 0 a 255 y vuelve a 0.

Ejemplo de pantalla:

```
+----------------+
|Switches:    045|
|Segundos:    128|
+----------------+
```

### 3.2 Distribución de la pantalla

| Fila | Columnas 0 a 11 | Columna 12 | Columnas 13 a 15 |
|---|---|---|---|
| 1 | Texto fijo elegido por el grupo | espacio | Valor A en decimal |
| 2 | Texto fijo elegido por el grupo | espacio | Valor B en decimal |

Cada valor se muestra siempre con tres dígitos, con ceros a la izquierda (por ejemplo, `005`).

### 3.3 Comportamiento

1. Al salir del reset, el controlador inicializa la LCD y escribe el texto fijo de las dos filas, como en la Parte 1.
2. Luego entra en un lazo que se repite indefinidamente:
    1. Muestrear los valores A y B.
    2. Ubicar el cursor en la fila 1, columna 13, y escribir los tres dígitos de A.
    3. Ubicar el cursor en la fila 2, columna 13, y escribir los tres dígitos de B.
    4. Esperar el periodo de refresco y volver al paso 1.

### 3.4 Interfaz

El módulo superior debe tener, como mínimo, estos puertos:

| Puerto | Dirección | Descripción |
|---|---|---|
| `clk` | entrada | Reloj de 50 MHz |
| `rst_n` | entrada | Reset, pulsador activo en bajo |
| `sw_n[7:0]` | entrada | Interruptores DIP, activos en bajo (encendido = 0) |
| `lcd_rs`, `lcd_rw`, `lcd_e`, `lcd_data[7:0]` | salida | Señales de la LCD, como en la Parte 1 |

El controlador de la LCD debe recibir los dos valores como entradas de 8 bits (por ejemplo, `num_a[7:0]` y `num_b[7:0]`), de modo que pueda probarse en simulación con cualquier valor.

### 3.5 Requisitos

Los módulos de la carpeta [`ejemplos`](ejemplos) pueden usarse o adaptarse; en ese caso se explican en la bitácora como parte del diseño del grupo.

1. Se debe reutilizar `lcd_escritura.v` sin cambios.
2. El lazo de refresco no debe usar Clear Display: solo reescribe los seis dígitos y las dos instrucciones de posición.
3. Los valores se muestrean al comenzar cada refresco.
4. Los interruptores pasan por un sincronizador de dos flip-flops y se invierten en el módulo superior.
5. El periodo de refresco (`T_REFRESCO_MS`, 100 ms) y la frecuencia del reloj (`CLK_FREQ`) son parámetros, para poder usar valores reducidos en simulación.
6. El contador de segundos usa una base de tiempo derivada de `CLK_FREQ`, como en el Lab 4.
7. El método de conversión a BCD queda a elección del grupo y debe justificarse.

---

## 4. Pre-informe

- **Diseño del sistema:**
  - Diagrama de bloques de la arquitectura modificada, con nombres y anchos de todas las señales. Debe mostrar los bloques nuevos: sincronizador, contador de segundos, registros de muestreo, conversión a BCD, conversión a ASCII y los cambios en la ruta de datos del controlador.
  - Diagrama de estados y tabla de transiciones de la máquina principal modificada, señalando los estados y transiciones nuevos.
  - Instrucciones Set DDRAM Address para la columna 13 de cada fila, en hexadecimal y en binario, con el cálculo.
  - Conversión a BCD hecha a mano, paso a paso como en la sección 2.3, para 255 y para un valor elegido por el grupo.
  - Tabla de los códigos que se envían para los dígitos 0 a 9.
  - Tabla de tiempos:

    | Tiempo | Valor | Ciclos a 50 MHz | Bits del contador |
    |---|---|---|---|
    | Duración de un refresco (2 instrucciones y 6 caracteres) | | | — |
    | Periodo de refresco | 100 ms | | |
    | Base de tiempo del contador de segundos | 1 s | | |

- **Descripción en HDL:**
  - Código de los módulos nuevos y de las modificaciones al controlador.
  - Explicación del lazo de refresco: cómo se pasa del texto fijo al lazo, cómo se escogen los dígitos y cómo se genera `iniciar` en los estados nuevos.
  - Explicación del método de conversión a BCD elegido.
- **Simulación:**
  - Testbench del controlador que pruebe al menos cuatro pares de valores, incluidos 0, un valor de un dígito, uno de dos dígitos y 255, y verifique con el modelo de la LCD las columnas 13 a 15 de cada fila (función `caracter(fila, columna)` del modelo).
  - Prueba del convertidor a BCD con los 256 valores de entrada.
  - Salida de consola con las pantallas impresas por el modelo, sin errores de tiempo.
  - Captura de GTKWave de un refresco completo, con `lcd_data` en hexadecimal.
  - Valor de `T_REFRESCO_MS` usado en la simulación y por qué.

---

## 5. Implementación y criterios de validación

### 5.1 Implementación (informe)

1. Asignar los pines de la LCD como en la Parte 1, incluida la configuración del pin 101.
2. Asignar los interruptores DIP:

    | Posición del interruptor | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
    |---|---|---|---|---|---|---|---|---|
    | Pin | PIN_58 | PIN_59 | PIN_60 | PIN_64 | PIN_65 | PIN_66 | PIN_67 | PIN_68 |

    El grupo decide qué posición corresponde al bit menos significativo y lo documenta.

3. Probar al menos estos casos y registrar foto o video de cada uno:

    | Interruptores | Valor esperado |
    |---|---|
    | todos apagados | `000` |
    | solo el bit 0 | `001` |
    | `0000 0101` | `005` |
    | `0110 0100` | `100` |
    | todos encendidos | `255` |

4. Verificar que el contador de segundos avanza un número por segundo y vuelve a `000` después de 255 (unos 4 minutos y 16 segundos).
5. Registrar las observaciones de la prueba en hardware y los ajustes realizados.

### 5.2 Criterios de validación

- El texto fijo permanece en pantalla sin parpadeo mientras los valores cambian.
- El valor A coincide con los interruptores en todos los casos de prueba.
- El valor B avanza cada segundo y pasa de 255 a 000.
- La simulación verifica al menos cuatro pares de valores y el convertidor con los 256 valores, sin errores del modelo de la LCD.

---

## 6. Resultados y análisis

- Comparación entre lo diseñado, lo simulado y lo implementado en las dos partes.
- Análisis de la interfaz eléctrica: comparar el nivel alto de salida de la FPGA (3,3 V) con el nivel alto mínimo de entrada de la LCD (V<sub>IH</sub>) según la hoja de datos, para la alimentación usada. Explicar por qué R/W debe permanecer en 0.
- Recursos usados en Quartus (elementos lógicos y registros, en *Compilation Report → Flow Summary*) en la Parte 1 y en la Parte 2. ¿Cuánto aporta la conversión a BCD?
- Problemas encontrados y cómo se resolvieron.
- Código HDL e imágenes de simulación en el `README.md` del repositorio, que debe incluir:
  - Descripción breve del sistema y de cada módulo.
  - Comandos para simular, por ejemplo:

    ```
    iverilog -o sim.vvp test/tb_lcd.v test/modelo_lcd.v src/*.v
    vvp sim.vvp
    gtkwave tb_lcd.vcd
    ```

  - Diagramas de estados e imágenes de simulación.
  - Enlace al video de la demostración.

Estructura sugerida del repositorio:

```
Lab_5/
├── src/          # módulos Verilog
├── test/         # testbenches y modelo de la LCD
├── sim/          # capturas de GTKWave
└── README.md
```

El historial de commits debe mostrar el progreso real del trabajo (un commit por módulo, por testbench y por corrección), con mensajes que expliquen qué se hizo y por qué.

Se valorará ir más allá de lo pedido, por ejemplo:

- Suprimir los ceros a la izquierda (`  5` en lugar de `005`).
- Mostrar también el valor A en hexadecimal o en binario.
- Refrescar la pantalla solo cuando un valor cambia.
- Definir un carácter personalizado en la CGRAM.
- Usar la LCD en modo de 4 bits.
