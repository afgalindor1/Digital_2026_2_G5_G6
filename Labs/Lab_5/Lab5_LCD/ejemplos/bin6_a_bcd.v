// =============================================================================
// bin6_a_bcd.v
// Conversión de un número binario de 6 bits (0 a 63) a dos dígitos BCD con el
// algoritmo "double dabble" (desplazar y sumar 3). Versión combinacional.
//
// Registro de trabajo r (14 bits):
//
//    13     10 9       6 5            0
//   +---------+---------+--------------+
//   | decenas | unidades|   binario    |
//   +---------+---------+--------------+
//
// Se repite una vez por cada bit del número (6 veces):
//   1. a cada dígito BCD que valga 5 o más se le suma 3;
//   2. todo el registro se desplaza un bit a la izquierda.
//
// El "for" tiene límites fijos: el sintetizador lo desenrolla en 6 etapas de
// lógica combinacional (comparadores y sumadores de 4 bits). No es un lazo
// que se ejecute en el tiempo.
//
// Para otro número de bits hay que revisar tres cosas: cuántos dígitos BCD
// se necesitan, el ancho del registro y el número de iteraciones.
// =============================================================================
`timescale 1ns/1ps
module bin6_a_bcd (
    input  wire [5:0] bin,                  // 0 a 63
    output reg  [3:0] decenas,
    output reg  [3:0] unidades
);
    integer i;
    reg [13:0] r;

    always @(*) begin
        r = {8'd0, bin};                    // dígitos en cero, número a la derecha
        for (i = 0; i < 6; i = i + 1) begin
            if (r[9:6]   >= 4'd5) r[9:6]   = r[9:6]   + 4'd3;   // corregir unidades
            if (r[13:10] >= 4'd5) r[13:10] = r[13:10] + 4'd3;   // corregir decenas
            r = r << 1;                                         // desplazar
        end
        decenas  = r[13:10];
        unidades = r[9:6];
    end
endmodule
