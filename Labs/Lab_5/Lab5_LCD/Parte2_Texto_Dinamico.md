# Laboratorio 5 – Parte 2: Texto dinámico en la LCD 16x2

**Semana 12**

---

## Contenido

1. Objetivos de aprendizaje  
2. Fundamento teórico  
   2.1 Texto dinámico y actualización de la pantalla  
   2.2 Del número a los caracteres: hexadecimal o decimal  
   2.3 Entradas desde los interruptores  
   2.4 Modificar una máquina de estados existente  
3. Especificación  
   3.1 Descripción general  
   3.2 Comportamiento  
   3.3 Interfaz  
   3.4 Requisitos  
   3.5 Recomendaciones  
   3.6 Pasos sugeridos  
4. Pre-informe  
5. Implementación y criterios de validación  
6. Resultados y análisis  

---

## 1. Objetivos de aprendizaje

- Modificar una máquina de estados existente para agregar un nuevo comportamiento sin romper el anterior.
- Ubicar el cursor de la LCD en posiciones específicas con la instrucción Set DDRAM Address.
- Convertir un número binario de 8 bits en los caracteres que la LCD puede mostrar.

---

## 2. Fundamento teórico

Esta sección resume lo necesario para la Parte 2. Los [fundamentos básicos](Fundamentos.md) explican cada técnica con un código sencillo, y la carpeta [`ejemplos`](ejemplos) contiene esos códigos completos, comentados y con su testbench.

### 2.1 Texto dinámico y actualización de la pantalla

En la Parte 1 el controlador escribe el texto una sola vez y se detiene. La LCD conserva los caracteres en su memoria (DDRAM), así que el texto permanece en pantalla sin que la FPGA tenga que volver a enviarlo.

Para mostrar un valor que cambia no hace falta reescribir toda la pantalla. Basta con:

1. Ubicar el cursor en la primera posición del valor con **Set DDRAM Address** (Parte 1, secciones 2.4 y 2.7).
2. Escribir los caracteres del valor; el contador de direcciones de la LCD avanza solo después de cada uno.
3. Repetir estos dos pasos cada cierto tiempo. A esto se le llama **refrescar** la pantalla.

No se debe usar Clear Display para actualizar un valor: esa instrucción borra toda la pantalla, de modo que el texto desaparecería y volvería a aparecer en cada actualización (parpadeo).

¿Cada cuánto refrescar? La hoja de datos indica que el cristal líquido tarda entre 150 ms y 200 ms en cambiar (sección 6, *Response Time*), así que actualizar mucho más rápido que eso no se nota. Un periodo de unos 100 ms es suficiente.

### 2.2 Del número a los caracteres: hexadecimal o decimal

La LCD no recibe números: recibe **códigos de caracteres** (Parte 1, sección 2.8). Para mostrar un número de 8 bits hay que convertirlo en los caracteres de sus cifras. El grupo puede mostrarlo en hexadecimal o en decimal.

**En hexadecimal (2 caracteres).** Los 8 bits se separan en dos grupos de 4 bits (*nibbles*), y cada nibble se convierte en un carácter de `0` a `9` o de `A` a `F`:

| Valor del nibble | Carácter | Código |
|---|---|---|
| 0 a 9 | `0` a `9` | 0x30 a 0x39 (0x30 + valor) |
| 10 a 15 | `A` a `F` | 0x41 a 0x46 (0x37 + valor) |

Ejemplo: 183 = `1011 0111` = 0xB7. El nibble alto `1011` (11) se envía como `B` = 0x42 y el nibble bajo `0111` (7) como `7` = 0x37.

**En decimal (3 caracteres).** Primero hay que separar el número en centenas, decenas y unidades, cada una de 0 a 9. Cuando cada cifra se guarda en 4 bits, la representación se llama **BCD** (*Binary-Coded Decimal*). Por ejemplo, 243 en BCD es `0010 0100 0011` (2, 4, 3). Luego cada cifra se convierte en su carácter sumándole 0x30.

La conversión a BCD más usada en hardware es el algoritmo ***double dabble*** (desplazar y sumar 3). Usa un registro con espacio para las cifras BCD y el número binario, y repite 8 veces (una por cada bit):

1. **Corregir:** a cada cifra BCD que valga 5 o más se le suma 3.
2. **Desplazar:** todo el registro se desplaza un bit a la izquierda.

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

| | Hexadecimal | Decimal |
|---|---|---|
| Caracteres por valor | 2 | 3 |
| Conversión | Separar los nibbles y convertir cada uno | Convertir a BCD y luego cada cifra |
| Código de apoyo | Función `ascii_hex` de [`ejemplos/funciones_lcd.v`](ejemplos/funciones_lcd.v) | [`ejemplos/bin6_a_bcd.v`](ejemplos/bin6_a_bcd.v) (6 bits, hay que llevarlo a 8) y función `ascii_digito` |

### 2.3 Entradas desde los interruptores

Los interruptores DIP de la tarjeta son **activos en bajo**: encendido = 0. Para que un interruptor encendido valga 1, la entrada se invierte (`~sw_n`) en el módulo superior.

Los interruptores pueden cambiar en cualquier momento respecto al reloj. Como en el Lab 4, se recomienda pasarlos por un **sincronizador de dos flip-flops** antes de usarlos ([`ejemplos/sincronizador.v`](ejemplos/sincronizador.v)).

También se recomienda **copiar los dos valores en registros al comenzar cada refresco** y escribir los caracteres a partir de esas copias. Así, si un valor cambia mientras se escriben sus cifras, la pantalla no muestra una mezcla del valor anterior y del nuevo.

### 2.4 Modificar una máquina de estados existente

Agregar un comportamiento a una máquina de estados que ya funciona sigue el mismo método que diseñarla desde cero:

1. Definir las nuevas entradas y salidas.
2. Dividir el nuevo comportamiento en estados.
3. Actualizar el diagrama de estados: qué estados se agregan, cuáles cambian y por dónde se conecta el nuevo lazo con la secuencia anterior.
4. Actualizar la tabla de transiciones.
5. Modificar la descripción en HDL.
6. Simular, primero lo que ya funcionaba y luego lo nuevo.
7. Sintetizar e implementar.

Al modificar el código base se debe tener en cuenta cómo se genera la señal `iniciar`: un estado nuevo que **no** deba escribir en la LCD (por ejemplo, un estado de espera) tiene que excluirse de esa lógica, igual que se excluye el estado `FIN`. Si no, la LCD recibe una escritura de más.

---

## 3. Especificación

### 3.1 Descripción general

El sistema debe mostrar dos valores numéricos de 8 bits que cambian, junto al texto estático de la Parte 1:

- **Valor A:** el número formado por los 8 interruptores DIP de la tarjeta.
- **Valor B:** un contador que avanza solo, por ejemplo uno por segundo (de 0 a 255 y vuelve a 0).

Cada grupo escoge el formato (hexadecimal o decimal) y la posición de los valores, siempre después del texto estático. Ejemplos de pantalla:

```
En hexadecimal        En decimal
+----------------+    +----------------+
|Switches:     2D|    |Switches:    045|
|Segundos:     80|    |Segundos:    128|
+----------------+    +----------------+
```

### 3.2 Comportamiento

1. Al salir del reset, el controlador inicializa la LCD y escribe el texto estático de las dos filas, como en la Parte 1.
2. Luego entra en un lazo que se repite indefinidamente:
    1. Ubicar el cursor en la posición del valor A y escribir sus caracteres.
    2. Ubicar el cursor en la posición del valor B y escribir sus caracteres.
    3. Esperar el periodo de refresco y volver al paso 1.

### 3.3 Interfaz

El módulo superior debe tener, como mínimo, estos puertos:

| Puerto | Dirección | Descripción |
|---|---|---|
| `clk` | entrada | Reloj de 50 MHz |
| `rst_n` | entrada | Reset, pulsador activo en bajo |
| `sw_n[7:0]` | entrada | Interruptores DIP, activos en bajo |
| `lcd_rs`, `lcd_rw`, `lcd_e`, `lcd_data[7:0]` | salida | Señales de la LCD, como en la Parte 1 |

El controlador de la LCD debe recibir los dos valores como **entradas de 8 bits** (por ejemplo, `num_a[7:0]` y `num_b[7:0]`), para poder probarlo en simulación con cualquier valor.

### 3.4 Requisitos

1. Se reutiliza `lcd_escritura.v` sin cambios.
2. El controlador recibe los dos valores como entradas de 8 bits.
3. La actualización de los valores no usa Clear Display.
4. Los interruptores se invierten para que encendido = 1.

### 3.5 Recomendaciones

- Sincronizar los interruptores y copiar los valores al comenzar cada refresco (sección 2.3).
- Escribir el periodo de refresco como un parámetro (por ejemplo, `T_REFRESCO_MS`), para usar un valor pequeño en simulación y 100 ms en la tarjeta.
- Generar el pulso de cada segundo con [`ejemplos/base_tiempo.v`](ejemplos/base_tiempo.v).
- Usar las funciones de [`ejemplos/funciones_lcd.v`](ejemplos/funciones_lcd.v) para armar las instrucciones de posición y los códigos de los caracteres.

Los módulos de la carpeta `ejemplos` pueden usarse o adaptarse; en ese caso se explican en la bitácora como parte del diseño del grupo.

### 3.6 Pasos sugeridos

1. Copiar `lcd_ctrl.v` en un archivo nuevo (por ejemplo, `lcd_ctrl_din.v`) y agregarle las entradas `num_a` y `num_b`.
2. Escoger la posición de cada valor y calcular su instrucción Set DDRAM Address.
3. Dibujar el diagrama de estados modificado: qué estados nuevos forman el lazo de refresco y cómo se llega a ellos desde la secuencia de la Parte 1.
4. Agregar a la ruta de datos lo necesario para el lazo: un contador para saber qué carácter del valor se envía, la conversión del valor a caracteres y las nuevas entradas del multiplexor `dato_sel`.
5. Ajustar la lógica de `iniciar` para el estado de espera (sección 2.4).
6. Simular el controlador con valores fijos en el testbench y cambiarlos durante la simulación. [`ejemplos/tb_revisar_pantalla.v`](ejemplos/tb_revisar_pantalla.v) muestra cómo revisar una parte de la pantalla.
7. Cuando la simulación funcione, crear el módulo superior con los interruptores y el contador, y llevar el diseño a la tarjeta.

---

## 4. Pre-informe

- **Diseño del sistema:**
  - Diagrama de bloques de la arquitectura modificada, señalando los bloques nuevos.
  - Diagrama de estados de la máquina principal modificada, con la condición de cada transición y señalando los estados nuevos.
  - Formato y posición elegidos para cada valor, e instrucción Set DDRAM Address de cada posición, en hexadecimal y en binario, con el cálculo.
  - Un ejemplo de conversión: para un valor elegido por el grupo, los caracteres y los códigos que se envían a la LCD, paso a paso.
- **Descripción en HDL:**
  - Código del controlador modificado y de los módulos nuevos.
  - Explicación de los cambios: estados nuevos, cambios en la ruta de datos y cómo se convierte cada valor en caracteres.
- **Simulación:**
  - Testbench que pruebe al menos tres pares de valores, incluidos 0 y 255, y salida de consola con las pantallas impresas por el modelo, sin errores de tiempo.
  - Captura de GTKWave de una actualización completa, con `lcd_data` en hexadecimal, y su explicación.

En simulación conviene usar un periodo de refresco pequeño (por ejemplo, 1 ms): con 100 ms, probar varios pares de valores tomaría mucho tiempo de simulación. `CLK_FREQ` se deja en 50 MHz, porque el modelo de la LCD revisa tiempos reales.

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

    | Interruptores | Hexadecimal | Decimal |
    |---|---|---|
    | todos apagados | `00` | `000` |
    | solo el bit 0 | `01` | `001` |
    | un valor elegido por el grupo | | |
    | todos encendidos | `FF` | `255` |

4. Verificar que el valor B avanza y que el texto estático permanece en pantalla.
5. Registrar las observaciones de la prueba en la tarjeta y los ajustes realizados.

### 5.2 Criterios de validación

- El texto estático permanece en pantalla, sin parpadeo, mientras los valores cambian.
- El valor A coincide con los interruptores en los casos de prueba.
- El valor B avanza solo.
- La simulación muestra al menos tres pares de valores correctos, sin errores del modelo de la LCD.

---

## 6. Resultados y análisis

- Comparación entre lo diseñado, lo simulado y lo implementado en las dos partes.
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

- Mostrar los valores en decimal, si se eligió hexadecimal, o en los dos formatos.
- Suprimir los ceros a la izquierda (`  5` en lugar de `005`).
- Mostrar el valor A también en binario.
- Refrescar la pantalla solo cuando un valor cambia.
- Definir un carácter personalizado en la CGRAM.
