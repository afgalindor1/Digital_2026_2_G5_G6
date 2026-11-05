// =============================================================================
// bin6_a_bcd_sec.v
// Conversión de 6 bits (0 a 63) a dos dígitos BCD con "double dabble",
// versión secuencial: una iteración por ciclo de reloj.
//
// Es un ejemplo pequeño de unidad de control + ruta de datos con handshake,
// la misma idea que usan lcd_ctrl y lcd_escritura:
//
//   - quien usa el módulo pone el número en "bin" y da un pulso en "iniciar";
//   - el módulo hace las 6 iteraciones (una por ciclo);
//   - al terminar da un pulso en "listo"; desde ese momento "decenas" y
//     "unidades" son válidas y se mantienen hasta el siguiente "iniciar".
//
//   iniciar  _|‾‾‾|______________________________
//   estado    REPOSO |  CONVERTIR (6 ciclos)  | REPOSO
//   listo    _________________________________|‾‾‾|_
//
//   Desde el ciclo en que llega iniciar hasta listo pasan 7 ciclos:
//   1 para cargar el número y 6 iteraciones.
//
// Comparación con la versión combinacional (bin6_a_bcd.v): la combinacional
// repite la lógica de corrección una vez por iteración; la secuencial tiene un
// solo juego de correctores que reutiliza en cada ciclo, más un registro y un
// contador. Para pocos bits la combinacional resulta más pequeña; la secuencial
// conviene con números de muchos bits. A cambio, tarda varios ciclos y
// necesita la señal "listo".
// =============================================================================
`timescale 1ns/1ps
module bin6_a_bcd_sec (
    input  wire       clk,
    input  wire       rst,                  // reset síncrono, activo en alto
    input  wire       iniciar,              // pulso de un ciclo: comenzar
    input  wire [5:0] bin,                  // se lee en el ciclo en que llega iniciar
    output wire [3:0] decenas,              // válidas desde listo hasta el siguiente iniciar
    output wire [3:0] unidades,
    output reg        listo                 // pulso de un ciclo al terminar
);
    // ------------------------------------------------------------ estados
    localparam REPOSO    = 1'b0,
               CONVERTIR = 1'b1;

    reg        estado, siguiente;
    reg [2:0]  paso;                        // iteración actual: 0 a 5
    reg [13:0] r;                           // [13:10] decenas | [9:6] unidades | [5:0] binario

    wire ultimo = (paso == 3'd5);           // señal de estado hacia la unidad de control

    // ------------------------------------------------------------ unidad de control
    // 1. Registro de estado
    always @(posedge clk)
        if (rst) estado <= REPOSO;
        else     estado <= siguiente;

    // 2. Lógica de siguiente estado
    always @(*) begin
        siguiente = estado;
        case (estado)
            REPOSO:    if (iniciar) siguiente = CONVERTIR;
            CONVERTIR: if (ultimo)  siguiente = REPOSO;
            default:                siguiente = REPOSO;
        endcase
    end

    // 3. Salida registrada
    always @(posedge clk)
        if (rst) listo <= 1'b0;
        else     listo <= (estado == CONVERTIR) && ultimo;

    // ------------------------------------------------------------ ruta de datos
    // Corrección de un dígito: si vale 5 o más se le suma 3
    function [3:0] corregir(input [3:0] d);
        corregir = (d >= 4'd5) ? d + 4'd3 : d;
    endfunction

    wire [13:0] r_corregido = {corregir(r[13:10]), corregir(r[9:6]), r[5:0]};

    // Registro de trabajo y contador de iteraciones
    always @(posedge clk)
        if (rst) begin
            r    <= 14'd0;
            paso <= 3'd0;
        end else if (estado == REPOSO && iniciar) begin
            r    <= {8'd0, bin};            // cargar el número
            paso <= 3'd0;
        end else if (estado == CONVERTIR) begin
            r    <= r_corregido << 1;       // corregir y desplazar en el mismo ciclo
            paso <= paso + 1'b1;
        end

    assign decenas  = r[13:10];
    assign unidades = r[9:6];
endmodule
