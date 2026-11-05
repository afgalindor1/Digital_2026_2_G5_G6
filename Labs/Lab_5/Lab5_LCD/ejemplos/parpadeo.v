// =============================================================================
// parpadeo.v
// Máquina de estados con estados de duración fija: un LED que se enciende
// T_ON_MS milisegundos y se apaga T_OFF_MS milisegundos, una y otra vez.
//
//          fin_on
//   +-----------------+
//   |                 v
//  ENCENDIDO      APAGADO
//   ^                 |
//   +-----------------+
//          fin_off
//
// Usa la misma estructura que lcd_escritura.v del código base:
//   - tres bloques: registro de estado, siguiente estado y salida;
//   - un solo contador que vuelve a cero cada vez que cambia el estado,
//     así en cada estado la cuenta empieza desde 0;
//   - la salida sale de un flip-flop.
// =============================================================================
`timescale 1ns/1ps
module parpadeo #(
    parameter CLK_FREQ = 50_000_000,        // Hz
    parameter T_ON_MS  = 200,               // tiempo encendido, en ms
    parameter T_OFF_MS = 800                // tiempo apagado, en ms
)(
    input  wire clk,
    input  wire rst,                        // reset síncrono, activo en alto
    output reg  led
);
    // ------------------------------------------------------------ tiempos en ciclos
    localparam N_ON  = (CLK_FREQ / 1000) * T_ON_MS;
    localparam N_OFF = (CLK_FREQ / 1000) * T_OFF_MS;
    localparam N_MAX = (N_ON > N_OFF) ? N_ON : N_OFF;
    localparam W     = $clog2(N_MAX);                   // bits del contador
    localparam [W-1:0] MAX_ON  = N_ON[W-1:0]  - 1'b1;   // último valor de la cuenta
    localparam [W-1:0] MAX_OFF = N_OFF[W-1:0] - 1'b1;

    // ------------------------------------------------------------ estados
    localparam ENCENDIDO = 1'b0,
               APAGADO   = 1'b1;

    reg         estado, siguiente;
    reg [W-1:0] cuenta;                     // ciclos que lleva la máquina en el estado actual

    wire fin_on  = (cuenta == MAX_ON);      // condiciones de salida de cada estado
    wire fin_off = (cuenta == MAX_OFF);

    // 1. Registro de estado: guarda el estado actual
    always @(posedge clk)
        if (rst) estado <= ENCENDIDO;
        else     estado <= siguiente;

    // 2. Lógica de siguiente estado: decide a dónde ir
    always @(*) begin
        siguiente = estado;                 // por defecto, quedarse
        case (estado)
            ENCENDIDO: if (fin_on)  siguiente = APAGADO;
            APAGADO:   if (fin_off) siguiente = ENCENDIDO;
            default:                siguiente = ENCENDIDO;
        endcase
    end

    // Contador de tiempo: vuelve a cero cada vez que cambia el estado
    always @(posedge clk)
        if (rst || estado != siguiente) cuenta <= 0;
        else                            cuenta <= cuenta + 1'b1;

    // 3. Salida registrada: vale 1 mientras la máquina está en ENCENDIDO
    always @(posedge clk)
        if (rst) led <= 1'b0;
        else     led <= (siguiente == ENCENDIDO);
endmodule
