// =============================================================================
// sincronizador.v
// Sincronizador de dos flip-flops para señales asíncronas (interruptores,
// pulsadores, señales de otro dominio de reloj).
//
//   d_async ──►[FF]── etapa1 ──►[FF]──► q_sync
//               ▲                ▲
//              clk              clk
//
// Si d_async cambia muy cerca del flanco de reloj, el primer flip-flop puede
// quedar metaestable; el segundo le da casi un ciclo completo para resolverse
// antes de que el valor se use en el resto del circuito.
//
// Cada bit se sincroniza por separado. Para un bus cuyos bits cambian a la vez
// (como un contador de otro reloj) este método no basta, pero sí para un grupo
// de interruptores independientes.
// =============================================================================
`timescale 1ns/1ps
module sincronizador #(
    parameter ANCHO = 1                     // número de bits
)(
    input  wire             clk,
    input  wire [ANCHO-1:0] d_async,        // entrada asíncrona
    output reg  [ANCHO-1:0] q_sync          // salida sincronizada (2 ciclos de retardo)
);
    reg [ANCHO-1:0] etapa1;

    always @(posedge clk) begin
        etapa1 <= d_async;
        q_sync <= etapa1;
    end
endmodule
