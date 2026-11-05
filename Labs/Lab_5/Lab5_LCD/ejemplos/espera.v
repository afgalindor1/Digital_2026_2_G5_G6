// =============================================================================
// espera.v
// Módulo "trabajador": cuando recibe un pulso en iniciar, espera el número
// de ciclos indicado en "ciclos" y avisa con un pulso en listo.
//
//   iniciar  _|‾|___________________________
//   ciclos   =X= N =X=======================   (se lee junto con iniciar)
//   estado    REPOSO |  CONTANDO (N ciclos)  | REPOSO
//   listo    ________________________________|‾|_
//
// Es la misma idea de lcd_escritura.v: el módulo que pide la tarea no sabe
// cómo se hace, solo da la orden y espera el aviso de que terminó.
// =============================================================================
`timescale 1ns/1ps
module espera #(
    parameter ANCHO = 28                    // bits de "ciclos" (2^28 ciclos = 5,3 s a 50 MHz)
)(
    input  wire             clk,
    input  wire             rst,            // reset síncrono, activo en alto
    input  wire             iniciar,        // pulso de un ciclo: empezar a esperar
    input  wire [ANCHO-1:0] ciclos,         // duración de la espera, en ciclos (al menos 2)
    output reg              listo           // pulso de un ciclo al terminar
);
    localparam REPOSO   = 1'b0,
               CONTANDO = 1'b1;

    reg             estado, siguiente;
    reg [ANCHO-1:0] cuenta;                 // ciclos transcurridos
    reg [ANCHO-1:0] limite;                 // copia de "ciclos" para esta espera

    wire fin = (cuenta == limite - 1'b1);

    // 1. Registro de estado
    always @(posedge clk)
        if (rst) estado <= REPOSO;
        else     estado <= siguiente;

    // 2. Siguiente estado
    always @(*) begin
        siguiente = estado;
        case (estado)
            REPOSO:   if (iniciar) siguiente = CONTANDO;
            CONTANDO: if (fin)     siguiente = REPOSO;
            default:               siguiente = REPOSO;
        endcase
    end

    // Ruta de datos: al recibir la orden se guarda la duración pedida
    always @(posedge clk)
        if (rst)
            limite <= 0;
        else if (estado == REPOSO && iniciar)
            limite <= ciclos;

    // Contador: cuenta solo mientras espera
    always @(posedge clk)
        if (rst || estado != CONTANDO) cuenta <= 0;
        else                           cuenta <= cuenta + 1'b1;

    // 3. Salida registrada: pulso de un ciclo al terminar
    always @(posedge clk)
        if (rst) listo <= 1'b0;
        else     listo <= (estado == CONTANDO) && fin;
endmodule
