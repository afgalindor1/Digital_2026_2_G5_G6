// =============================================================================
// funciones_lcd.v
// Funciones útiles para armar los bytes que se envían a la LCD.
//
// En Verilog-2001 una función pertenece al módulo donde se declara. Para usar
// una de estas funciones, cópiela dentro del módulo que la necesita. Este
// módulo no tiene puertos: solo agrupa las funciones para poder probarlas
// (tb_funciones_lcd.v).
//
// Una función describe lógica combinacional: el sintetizador la reemplaza por
// compuertas y multiplexores en cada lugar donde se usa.
// =============================================================================
`timescale 1ns/1ps
module funciones_lcd;

    // Instrucción Set DDRAM Address para una fila (0 = superior, 1 = inferior)
    // y una columna (0 a 15). La fila superior empieza en la dirección 0x00 y
    // la inferior en 0x40; el bit 7 en 1 identifica la instrucción.
    //
    //   bit:   7     6     5   4   3   2   1   0
    //          1   fila    0   0   [  columna   ]
    function [7:0] dir_ddram(input fila, input [3:0] columna);
        dir_ddram = {1'b1, fila, 2'b00, columna};
    endfunction

    // Dígito decimal (0 a 9) -> código del carácter '0' a '9' (0x30 a 0x39)
    function [7:0] ascii_digito(input [3:0] d);
        ascii_digito = {4'h3, d};
    endfunction

    // Valor de 4 bits (0 a 15) -> carácter hexadecimal '0' a '9' o 'A' a 'F'.
    // Las letras no siguen a los dígitos en la tabla: '9' = 0x39 y 'A' = 0x41,
    // por eso para 10 a 15 se suma 0x37 (0x37 + 10 = 0x41).
    function [7:0] ascii_hex(input [3:0] h);
        ascii_hex = (h < 4'd10) ? {4'h3, h} : 8'h37 + {4'h0, h};
    endfunction

    // Bit -> carácter '0' o '1' (para mostrar un número en binario)
    function [7:0] ascii_bit(input b);
        ascii_bit = b ? 8'h31 : 8'h30;
    endfunction

    // Carácter número c (0 = el de la izquierda) de un texto de 16 caracteres.
    // Verilog guarda el primer carácter de una cadena en los bits más significativos.
    function [7:0] caracter(input [8*16-1:0] texto, input [3:0] c);
        caracter = texto[8*(15 - c) +: 8];
    endfunction

endmodule
