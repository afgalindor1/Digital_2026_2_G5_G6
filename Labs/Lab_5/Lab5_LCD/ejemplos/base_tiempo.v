// =============================================================================
// base_tiempo.v
// Genera un pulso de un ciclo de reloj ("tick") cada PERIODO_MS milisegundos.
//
//   clk    _|‾|_|‾|_|‾|_|‾|_|‾|_ ... _|‾|_|‾|_|‾|_
//   tick   ____________________________|‾‾‾|______   (un ciclo de reloj)
//          |<-------- PERIODO_MS -------->|
//
// Usos típicos: avanzar un contador (por ejemplo, de segundos) o marcar
// el momento de una acción periódica (por ejemplo, refrescar la pantalla).
//
// El número de ciclos se calcula a partir de CLK_FREQ, de modo que el mismo
// módulo sirve en la tarjeta (50 MHz) y en simulación con valores reducidos.
// Requiere que el periodo sea de al menos 2 ciclos de reloj.
// =============================================================================
`timescale 1ns/1ps
module base_tiempo #(
    parameter CLK_FREQ   = 50_000_000,      // frecuencia del reloj en Hz
    parameter PERIODO_MS = 1000             // tiempo entre pulsos en ms
)(
    input  wire clk,
    input  wire rst,                        // reset síncrono, activo en alto
    output reg  tick                        // pulso de un ciclo cada PERIODO_MS
);
    localparam N = (CLK_FREQ / 1000) * PERIODO_MS;   // ciclos por periodo
    localparam W = $clog2(N);                        // bits necesarios para contar hasta N-1
    localparam [W-1:0] MAX = N[W-1:0] - 1'b1;        // último valor de la cuenta

    reg [W-1:0] cuenta;

    always @(posedge clk)
        if (rst) begin
            cuenta <= 0;
            tick   <= 1'b0;
        end else if (cuenta == MAX) begin
            cuenta <= 0;
            tick   <= 1'b1;
        end else begin
            cuenta <= cuenta + 1'b1;
            tick   <= 1'b0;
        end
endmodule
