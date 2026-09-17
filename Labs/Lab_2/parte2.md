
## Parte 2: Sumador/restador de 4 bits 


Contenido:

1. [Objetivos de aprendizaje](#1-objetivos-de-aprendizaje)

2. [Fundamento teórico](#2-fundamento-teórico)

3. [Entregables](#3-entregables)

## 1. Objetivos de aprendizaje

* Implementar un circuito restador usando complemento a 2.

* Reutilizar un sumador de 4 bits para operaciones de resta.

* Aprender a verificar y validar el funcionamiento del diseño en un entorno de simulación, identificando y corrigiendo errores antes de la implementación física en *hardware*.


## 2. Fundamento teórico

#### 2.1 Operación complemento a 2.

En sistemas digitales, las operaciones aritméticas con números negativos requieren una representación eficiente. El complemento a 2 resuelve este problema al permitir:

1. Codificar números positivos y negativos en binario.

2. Convertir restas en sumas, simplificando el diseño de circuitos.

Al aplicar complemento a 2 a un número $B$, la resta $A−B$ se transforma en una suma:

  $$A−B=A+(∼B+1)$$


donde $∼B$ es la inversión bit a bit (complemento a 1) y $+1$ completa la conversión.

En este laboratorio, aprovecharemos esta propiedad para construir un **sumador/restador** de 4 bits reutilizando un sumador existente, añadiendo solo compuertas ```XOR ```y una señal de control (```Sel```). El bit de acarreo final (```Co```) indicará automáticamente si el resultado es positivo o negativo.


El complemento a 2 se cálcula como sigue:   

* ##### Paso 1: Inversión de Bits

    Invertir todos los bits del número. Por ejemplo, si el número binario es $1101_2$​, su inversión de bits será $0010_2$​.


* ##### Paso 2: Paso 1 + 1:

    Se suma 1 al número binario invertido. Continuando con el ejemplo anterior, $0010_2+1 = 0011_2$​.


    El resultado final, $0011_2$​, es el complemento a 2 de $1101_2$​, que representa el número $−3$ en décimal.


##### Ejemplo:

Ejemplo: Se requiere calcular $7−5$.

1. Se debe convertir el número $5$ en $-5$ usando estos pasos:

    * **Paso 1**: Invertir los bits de $5$ (complemento a 1):

        $$0101→1010$$

    * **Paso 2**: Sumar $1$ al resultado (complemento a 2):

        $$1010+1=1011 \rightarrow$$ Esto representa un $-5$.

    * Ahora se debe sumar en lugar de restar:

        $$0111_2 (7) +1011_2 (−5) = 10010_2$$ 
    
    * Sin tener en cuenta el bit de acarreo, es decir, el ```MSB```: $$0010_2=2$$.

 #### 2.2. ¿Cómo se ve el completo a 2 a nivel de circuito?

1. Compuertas ```XOR```:

    * Cuando ```Sel = 1```, actúan como un interruptor que invierte los bits de $B$ (Paso 1).

    * Si ```Sel = 0```, dejan pasar $B$ sin cambios (para suma).

2. El bit ```Sel``` hace dos cosas:

    * Controla las ```XOR``` (Paso 1).

    * Se conecta al acarreo inicial (```Cin```) para sumar el $1$ del Paso 2.

3. El resultado final:

    * Si el acarreo final (```Co```) es $1$: El resultado es positivo (como el 2 del ejemplo).

    * Si es $0$: El resultado es negativo (está en  complemento a $2$).

        Ejemplo: $3−7=1100$ → $-4$ en complemento a $2$.

A continuación se muestra el circuito del complemento a $2$:

<p align="center">
 <img src="/Labs/figs/lab02/Restador.png" alt="alt text" width=700 >
</p>

Para realizar la operación de resta, el circuito presenta el siguiente comportamiento: 

1. **Complemento a 1**: Al fijar la entrada ```Sel = 1```, las compuertas ```XOR``` invierten los bits de ```B``` (el sustraendo de la operación) obteniendo así el complemento a 1 de la entrada ```B```. 

2. **Complemento a 2**: Cuando ```Sel = 1```, también sucede que el acarreo de entrada del primer sumador de 1 bit es 1, lo que conlleva a que se sume el complemento a 1  de ```B```en su con 1 lo que representa el complemento a 2.

3. **Resultado final**: El circuito adicionalmente suma ```A``` (el minuendo de la operación) con el complemento a 2 de ```B```, obtenido en el paso anterior, representando la operación  $A−B$. Al igual que en la suma, el acarreo de salida se propaga de un bloque a otro.

Cuando la entrada ```Sel = 0``` la salida de las compuertas ```XOR``` es simplemente la misma entrada ```B```, por lo tanto se ejecuta la operación de suma $A+B$.

## 4. Reto de diseño: Control térmico de proceso en caldera industrial
---

En una planta de producción química se utiliza una caldera para calentar una mezcla hasta una temperatura específica necesaria para que ocurra correctamente la reacción del proceso.

Durante la operación del sistema se presentan tres estados posibles:

- Si la temperatura es menor a la temperatura objetivo → el producto aún está en proceso de fabricación.  
- Si la temperatura es exactamente igual a la temperatura objetivo → el producto alcanzó la condición ideal de fabricación.  
- Si la temperatura supera la temperatura objetivo → el producto se quema y se pierde el lote.  

Por motivos de seguridad industrial, la planta requiere un sistema digital simple, independiente del software principal, que permita indicar estas condiciones usando únicamente lógica hardware.

---

### 4.2 Problema de ingeniería

Se dispone de:

- Un sensor digital que entrega la temperatura actual de la caldera.  
- Un valor digital fijo configurado como temperatura objetivo del proceso.  

Se debe utilizar el sumador/restador diseñado previamente en este laboratorio para realizar la comparación entre ambas temperaturas.

---

### 4.3 Especificación del sistema

**Entradas**

| Señal | Descripción |
|---|---|
| T[3:0] | Temperatura medida en la caldera |
| L[3:0] | Temperatura objetivo del proceso |
| Sel | Señal de control del sumador/restador (modo resta) |

---

**Operación obligatoria**

R = T - L


---

### 4.4 Salidas del sistema

| Señal | Significado |
|---|---|
| PERFECT_LED | Temperatura perfecta del proceso |
| PROCESS_LED | Producto aún en proceso de fabricación |
| BURN_LED | Producto quemado por exceso de temperatura |

---

### 4.5 Comportamiento esperado del sistema

Dado que:

R = T - L


El sistema debe permitir identificar el estado del proceso térmico:

| Resultado | Estado del proceso |
|---|---|
R < 0 | Producto en fabricación |
R = 0 | Producto en condición ideal |
R > 0 | Producto quemado |

---

### 4.6 Restricciones de diseño

El sistema debe cumplir obligatoriamente:

- Usar el sumador/restador desarrollado en el laboratorio.  
- No usar comparadores dedicados.  
- No usar microcontroladores.  
- Implementarse únicamente usando lógica combinacional adicional.  

---

### 4.7 Validación del sistema

Se recomienda verificar el comportamiento del diseño probando al menos las siguientes condiciones:

- Temperatura menor que la temperatura objetivo.  
- Temperatura igual a la temperatura objetivo.  
- Temperatura mayor que la temperatura objetivo.  



---


## 3. Entregables

1. Descripción de hardware del sumador/restador.

2. Documentación del ítem anterior en su respectivo archivo ```README.md```.

3. Realice la respectiva simulaciones y muestre evidencias en su archivo ```README.md```.

4. Implemente la descripción HDL en la tarjeta de desarrollo, empleando la ```IDE Quartus``` y muestre en el laboratorio el funcionamiento, empleando los periféricos que requiera.
## 4. Material de apoyo
- [Guia Primeros pasos verilog](https://www.youtube.com/watch?v=3Xm6fgKAO94)
- [Introduccion a FPGA y verilog](https://www.youtube.com/watch?v=Bn3R0gwxk4s)
- [Primer Proyecto Quartus](/Labs/Lab_2/proyectoQuartus.md)
- [Primeros pasos Verilog,icarus y gtkwave (English)](https://www.youtube.com/watch?v=vN1wzM0NO4c)