# Laboratorio 5: Visualización en pantalla LCD 16x2 en modo paralelo

Máquinas de estados, unidad de control y ruta de datos, e interfaz con un periférico real.

**Duración:** 2 semanas, una parte por semana. La Parte 1 parte de un código base que controla la LCD y muestra texto fijo; en la Parte 2 el grupo modifica ese controlador para mostrar valores que cambian.

## [Parte 1: Controlador de la LCD 16x2 y texto estático](Parte1_Texto_Estatico.md)

## [Parte 2: Texto dinámico en la LCD 16x2](Parte2_Texto_Dinamico.md)

## [Fundamentos básicos](Fundamentos.md)

Las técnicas de Verilog que usa el laboratorio, cada una con un código sencillo y explicado: medir tiempo con un contador, máquinas de estados, *handshake* entre dos máquinas, textos, posición del cursor, conversión de números a caracteres, lectura de interruptores y simulación con el modelo de la LCD.

---

### Código base

| Carpeta | Archivos | Uso |
|---|---|---|
| [`src`](src) | `lcd_escritura.v`, `lcd_ctrl.v`, `lcd_top.v` | Controlador de la LCD en modo de 8 bits |
| [`test`](test) | `modelo_lcd.v`, `tb_lcd.v` | Modelo de la pantalla y testbench |

Cada grupo copia estas carpetas para su uso.

### Ejemplos de código

La carpeta [`ejemplos`](ejemplos) contiene los códigos de los fundamentos, completos, comentados y con su testbench.

| Archivo | Contenido |
|---|---|
| `base_tiempo.v` | Pulso de un ciclo cada *N* milisegundos, a partir de `CLK_FREQ` |
| `parpadeo.v` | Máquina de estados en tres bloques, con estados de duración fija |
| `semaforo.v`, `espera.v` | Maestro y trabajador que se comunican con `iniciar` y `listo` |
| `funciones_lcd.v` | Funciones para textos, posición del cursor y cifras |
| `bin6_a_bcd.v` | Conversión de 6 bits a dos cifras decimales |
| `sincronizador.v` | Sincronizador de dos flip-flops |
| `tb_revisar_pantalla.v` | Testbench que revisa una parte de la pantalla con el modelo de la LCD |

### Contenido de la carpeta

```
├── README.md
├── Parte1_Texto_Estatico.md
├── Parte2_Texto_Dinamico.md
├── Fundamentos.md           fundamentos básicos con códigos explicados
├── lcd016n002bcfhet.pdf     hoja de datos de la pantalla
├── figs/                    figuras de las guías
├── src/                     código base
├── test/                    modelo de la pantalla y testbench
└── ejemplos/                códigos de los fundamentos, con sus testbenches
```

### Simulación rápida

Desde esta carpeta:

```
iverilog -o sim.vvp test/tb_lcd.v test/modelo_lcd.v src/lcd_ctrl.v src/lcd_escritura.v
vvp sim.vvp
gtkwave tb_lcd.vcd
```

La simulación debe terminar con `Fallas: 0`.

### Material

- Tarjeta Cyclone IV del curso
- Pantalla LCD 16x2 (se conecta al *header* de la tarjeta)
- Software: Quartus Prime Lite, Icarus Verilog y GTKWave

### Documentación de apoyo

1. [Hoja de datos de la LCD 16x2](lcd016n002bcfhet.pdf): instrucciones (sección 11), tiempos (sección 12), inicialización (sección 13) y tabla de caracteres (sección 10).
2. Tutorial de implementación en Quartus del Lab 0.
3. Presentación de clase sobre diseño de máquinas de estados en Verilog.
4. C. Cummings y H. Chambers, *Finite State Machine (FSM) Design & Synthesis using SystemVerilog*, SNUG 2019: estilos de codificación de máquinas de estados.
